import { db, withTransaction } from '../db/index.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { newId } from '../utils/id.js';
import { nowSql } from '../utils/time.js';
import { haversineKm, boundingBox } from '../utils/geo.js';
import { q } from '../middleware/validate.js';
import { serializeReport } from '../serializers/index.js';
import { syncImagesJson, recordStatusChange } from '../services/reports.service.js';
import { generateMatchesForReport } from '../services/matching.service.js';
import { notifyApprovedMatches } from '../services/matchNotifier.service.js';

const VIEW_DEDUP_HOURS = 24;

/**
 * FTS5 treats punctuation and bare operators (AND, OR, NEAR, ", *, -) as query syntax, so raw
 * user input can both error out and search for the wrong thing. Every token is quoted and given a
 * prefix wildcard, turning the input into a safe "starts-with all terms" query.
 */
function toFtsQuery(input) {
  const terms = String(input)
    .toLowerCase()
    .replace(/["*()\-:^]/g, ' ')
    .split(/\s+/)
    .filter((t) => t.length > 1);
  if (terms.length === 0) return null;
  return terms.map((t) => `"${t}"*`).join(' AND ');
}

function loadReport(id) {
  const row = db.prepare('SELECT * FROM reports WHERE id = ? AND deleted_at IS NULL').get(id);
  if (!row) throw new ApiError(404, 'Report not found');
  return row;
}

function requireOwner(row, userId) {
  if (row.owner_user_id !== userId) throw new ApiError(403, 'You can only modify your own reports');
  return row;
}

// GET /api/v1/reports   — the dashboard feed, plus the Lost and Found tabs
export const listReports = asyncHandler(async (req, res) => {
  const { type, category, status, q: search, lat, lng, radiusKm, sort, page, pageSize } = q(req);

  const clauses = ['r.deleted_at IS NULL'];
  const params = {};

  if (type !== 'all') {
    clauses.push('r.type = @type');
    params.type = type;
  }
  if (category !== 'all') {
    clauses.push('r.category = @category');
    params.category = category;
  }
  if (status !== 'all') {
    // The feed defaults to items still worth acting on, not the whole archive.
    if (status === 'active') {
      clauses.push("r.status IN ('open','in_review','matched')");
    } else {
      clauses.push('r.status = @status');
      params.status = status;
    }
  }

  // Full-text search when the index can serve it; the LIKE fallback keeps short queries working.
  let joins = '';
  if (search) {
    const ftsQuery = toFtsQuery(search);
    if (ftsQuery) {
      joins = 'JOIN reports_fts f ON f.rowid = r.rowid';
      clauses.push('reports_fts MATCH @ftsQuery');
      params.ftsQuery = ftsQuery;
    } else {
      clauses.push('(r.title LIKE @like OR r.location LIKE @like OR r.description LIKE @like)');
      params.like = `%${search}%`;
    }
  }

  const hasGeo = lat != null && lng != null;
  const radius = radiusKm ?? env.defaultRadiusKm;
  if (hasGeo) {
    // Bounding box first (index-friendly), exact haversine after. Reports without coordinates are
    // excluded from a geo-filtered feed rather than silently ranked last.
    Object.assign(params, boundingBox(lat, lng, radius));
    clauses.push('r.lat BETWEEN @minLat AND @maxLat AND r.lng BETWEEN @minLng AND @maxLng');
  }

  const where = `WHERE ${clauses.join(' AND ')}`;
  const viewerId = req.user?.id ?? null;

  // With a geo filter the exact distance test runs in JS, so pagination is applied after it.
  if (hasGeo) {
    const rows = db.prepare(`SELECT r.* FROM reports r ${joins} ${where} ORDER BY r.created_at DESC`).all(params);
    const withDistance = rows
      .map((row) => ({ row, distance: haversineKm(lat, lng, row.lat, row.lng) }))
      .filter((entry) => entry.distance != null && entry.distance <= radius);

    if (sort === 'nearest') withDistance.sort((a, b) => a.distance - b.distance);

    const total = withDistance.length;
    const slice = withDistance.slice((page - 1) * pageSize, page * pageSize);
    return res.json({
      success: true,
      data: slice.map(({ row, distance }) => ({
        ...serializeReport(row, viewerId),
        distanceKm: Number(distance.toFixed(2)),
      })),
      pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) || 1 },
    });
  }

  const total = db.prepare(`SELECT COUNT(*) AS count FROM reports r ${joins} ${where}`).get(params).count;
  const rows = db
    .prepare(`SELECT r.* FROM reports r ${joins} ${where} ORDER BY r.created_at DESC LIMIT @limit OFFSET @offset`)
    .all({ ...params, limit: pageSize, offset: (page - 1) * pageSize });

  res.json({
    success: true,
    data: rows.map((row) => serializeReport(row, viewerId)),
    pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) || 1 },
  });
});

// GET /api/v1/reports/:id
export const getReport = asyncHandler(async (req, res) => {
  const row = loadReport(req.params.id);
  const viewerId = req.user?.id ?? null;

  const isSaved = viewerId
    ? Boolean(db.prepare('SELECT 1 AS x FROM saved_reports WHERE user_id = ? AND report_id = ?').get(viewerId, row.id))
    : false;
  const myClaim = viewerId
    ? db
        .prepare('SELECT id, status FROM claims WHERE report_id = ? AND claimant_user_id = ? ORDER BY created_at DESC LIMIT 1')
        .get(row.id, viewerId)
    : null;

  res.json({
    success: true,
    data: {
      ...serializeReport(row, viewerId),
      isSaved,
      myClaim: myClaim ? { id: myClaim.id, status: myClaim.status } : null,
    },
  });
});

// POST /api/v1/reports   — backs report_item_modal.dart
export const createReport = asyncHandler(async (req, res) => {
  const b = req.body;
  const id = newId(b.type === 'lost' ? 'LST' : 'FND');
  const now = nowSql();

  // An unknown or inactive category falls back to 'other' rather than creating a dangling value.
  const category = db.prepare('SELECT id FROM categories WHERE id = ? AND active = 1').get(b.category)
    ? b.category
    : 'other';

  const tx = withTransaction(() => {
    db.prepare(
      `INSERT INTO reports
         (id, title, type, category, status, location, lat, lng, occurred_at, reward, reward_currency,
          description, images, emoji, owner_user_id,
          reporter_name, reporter_contact, finder_name, finder_contact, created_at, updated_at)
       VALUES (@id, @title, @type, @category, 'open', @location, @lat, @lng, @occurredAt, @reward, @rewardCurrency,
               @description, '[]', @emoji, @ownerId,
               @reporterName, @reporterContact, @finderName, @finderContact, @now, @now)`
    ).run({
      id,
      title: b.title,
      type: b.type,
      category,
      location: b.location,
      lat: b.lat ?? null,
      lng: b.lng ?? null,
      occurredAt: b.occurredAt ?? now,
      reward: b.reward ?? null,
      rewardCurrency: b.rewardCurrency ?? 'LKR',
      description: b.description ?? '',
      emoji: b.emoji ?? null,
      ownerId: req.user.id,
      // These columns keep the row shape compatible with the admin backend's. They are never
      // exposed by the serializer except to the owner or an accepted claimant.
      reporterName: b.type === 'lost' ? req.user.name : null,
      reporterContact: b.type === 'lost' ? req.user.email || req.user.phone : null,
      finderName: b.type === 'found' ? req.user.name : null,
      finderContact: b.type === 'found' ? req.user.email || req.user.phone : null,
      now,
    });

    if (b.images?.length) {
      const insert = db.prepare(
        'INSERT INTO report_images (id, report_id, url, sort_order, is_primary, uploaded_by, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
      );
      b.images.forEach((url, index) => insert.run(newId('IMG'), id, url, index, index === 0 ? 1 : 0, req.user.id, now));
      syncImagesJson(id);
    }

    const column = b.type === 'lost' ? 'items_reported' : 'items_found';
    db.prepare(`UPDATE users SET ${column} = ${column} + 1, updated_at = ? WHERE id = ?`).run(now, req.user.id);

    recordStatusChange(id, null, 'open', 'user', req.user.id, 'Report created');
  });
  tx();

  // Matching runs outside the insert transaction: a matcher failure must not lose the report the
  // user just filed.
  let matches = [];
  try {
    matches = generateMatchesForReport(id);
  } catch (err) {
    console.error('[matching] failed for', id, err.message);
  }

  res.status(201).json({
    success: true,
    data: { ...serializeReport(loadReport(id), req.user.id), suggestedMatches: matches.length },
  });
});

// PATCH /api/v1/reports/:id
export const updateReport = asyncHandler(async (req, res) => {
  const current = requireOwner(loadReport(req.params.id), req.user.id);
  const b = req.body;

  if (['matched', 'returned'].includes(current.status) && b.status) {
    throw new ApiError(409, `A ${current.status} report's status is managed by the match and claim flow`);
  }

  const next = {
    id: current.id,
    title: b.title ?? current.title,
    category: b.category ?? current.category,
    description: b.description ?? current.description,
    location: b.location ?? current.location,
    lat: b.lat === undefined ? current.lat : b.lat,
    lng: b.lng === undefined ? current.lng : b.lng,
    occurredAt: b.occurredAt ?? current.occurred_at,
    reward: b.reward === undefined ? current.reward : b.reward,
    rewardCurrency: b.rewardCurrency ?? current.reward_currency,
    emoji: b.emoji === undefined ? current.emoji : b.emoji,
    status: b.status ?? current.status,
    now: nowSql(),
  };

  const tx = withTransaction(() => {
    db.prepare(
      `UPDATE reports
          SET title = @title, category = @category, description = @description, location = @location,
              lat = @lat, lng = @lng, occurred_at = @occurredAt, reward = @reward,
              reward_currency = @rewardCurrency, emoji = @emoji, status = @status, updated_at = @now
        WHERE id = @id`
    ).run(next);
    if (next.status !== current.status) {
      recordStatusChange(current.id, current.status, next.status, 'user', req.user.id);
    }
  });
  tx();

  res.json({ success: true, data: serializeReport(loadReport(current.id), req.user.id) });
});

// DELETE /api/v1/reports/:id   (soft delete)
export const deleteReport = asyncHandler(async (req, res) => {
  const current = requireOwner(loadReport(req.params.id), req.user.id);

  const tx = withTransaction(() => {
    db.prepare('UPDATE reports SET deleted_at = ?, updated_at = ? WHERE id = ?').run(nowSql(), nowSql(), current.id);
    // Outstanding suggestions pointing at a deleted report are meaningless.
    db.prepare(
      "UPDATE matches SET status = 'rejected', resolved_at = ? WHERE (lost_item_id = ? OR found_item_id = ?) AND status = 'pending_admin_approval'"
    ).run(nowSql(), current.id, current.id);
    recordStatusChange(current.id, current.status, 'closed', 'user', req.user.id, 'Report deleted by owner');
  });
  tx();

  res.json({ success: true, data: { id: current.id, deleted: true } });
});

// POST /api/v1/reports/:id/images   (multipart, field "images", up to 5)
export const addImages = asyncHandler(async (req, res) => {
  const report = requireOwner(loadReport(req.params.id), req.user.id);
  const files = req.files || [];
  if (files.length === 0) throw new ApiError(400, 'No images uploaded');

  const existing = db.prepare('SELECT COUNT(*) AS count FROM report_images WHERE report_id = ?').get(report.id).count;
  if (existing + files.length > 5) {
    throw new ApiError(409, `A report can hold at most 5 images (it already has ${existing})`);
  }

  const tx = withTransaction(() => {
    const insert = db.prepare(
      `INSERT INTO report_images (id, report_id, url, storage_key, bytes, sort_order, is_primary, uploaded_by, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    );
    files.forEach((file, index) => {
      const order = existing + index;
      insert.run(
        newId('IMG'),
        report.id,
        `/uploads/${file.filename}`,
        file.filename,
        file.size,
        order,
        order === 0 ? 1 : 0,
        req.user.id,
        nowSql()
      );
    });
    syncImagesJson(report.id);
  });
  tx();

  res.status(201).json({ success: true, data: serializeReport(loadReport(report.id), req.user.id) });
});

// DELETE /api/v1/reports/:id/images/:imageId
export const deleteImage = asyncHandler(async (req, res) => {
  const report = requireOwner(loadReport(req.params.id), req.user.id);

  const tx = withTransaction(() => {
    const result = db.prepare('DELETE FROM report_images WHERE id = ? AND report_id = ?').run(req.params.imageId, report.id);
    if (result.changes === 0) throw new ApiError(404, 'Image not found on this report');
    // Promote whatever is now first, so the card always has a primary image.
    const first = db
      .prepare('SELECT id FROM report_images WHERE report_id = ? ORDER BY sort_order, created_at LIMIT 1')
      .get(report.id);
    db.prepare('UPDATE report_images SET is_primary = 0 WHERE report_id = ?').run(report.id);
    if (first) db.prepare('UPDATE report_images SET is_primary = 1 WHERE id = ?').run(first.id);
    syncImagesJson(report.id);
  });
  tx();

  res.json({ success: true, data: serializeReport(loadReport(report.id), req.user.id) });
});

// POST /api/v1/reports/:id/view
export const recordView = asyncHandler(async (req, res) => {
  const report = loadReport(req.params.id);
  const viewerId = req.user?.id ?? null;

  // The owner looking at their own report is not a view, and a repeat view within 24h is not a
  // new one — otherwise "viewed 24 times" measures refreshes, not interest.
  if (viewerId && report.owner_user_id === viewerId) {
    return res.json({ success: true, data: { counted: false, viewCount: report.view_count } });
  }

  let counted = true;
  if (viewerId) {
    const recent = db
      .prepare(
        `SELECT 1 AS x FROM report_views
          WHERE report_id = ? AND user_id = ? AND viewed_at >= datetime('now', ?)
          LIMIT 1`
      )
      .get(report.id, viewerId, `-${VIEW_DEDUP_HOURS} hours`);
    counted = !recent;
  }
  // Anonymous views are not de-duplicated: there is no stable identity to key on.

  if (counted) {
    const tx = withTransaction(() => {
      db.prepare('INSERT INTO report_views (id, report_id, user_id, viewed_at) VALUES (?, ?, ?, ?)').run(
        newId('VW'),
        report.id,
        viewerId,
        nowSql()
      );
      db.prepare('UPDATE reports SET view_count = view_count + 1 WHERE id = ?').run(report.id);
    });
    tx();
  }

  res.json({
    success: true,
    data: { counted, viewCount: db.prepare('SELECT view_count FROM reports WHERE id = ?').get(report.id).view_count },
  });
});

// PUT /api/v1/reports/:id/save
export const saveReport = asyncHandler(async (req, res) => {
  const report = loadReport(req.params.id);
  db.prepare('INSERT OR IGNORE INTO saved_reports (user_id, report_id, created_at) VALUES (?, ?, ?)').run(
    req.user.id,
    report.id,
    nowSql()
  );
  res.json({ success: true, data: { reportId: report.id, isSaved: true } });
});

// DELETE /api/v1/reports/:id/save
export const unsaveReport = asyncHandler(async (req, res) => {
  db.prepare('DELETE FROM saved_reports WHERE user_id = ? AND report_id = ?').run(req.user.id, req.params.id);
  res.json({ success: true, data: { reportId: req.params.id, isSaved: false } });
});

// ── Matches ───────────────────────────────────────────────────────────────
// Suggestions are generated here but approved in the admin dashboard, which shares this database.
// The app can therefore read them and dismiss its own, but cannot approve — that stays with an
// admin, matching the queue the dashboard already has.

function loadMatchForUser(matchId, userId) {
  const row = db
    .prepare(
      `SELECT m.*, lr.owner_user_id AS lost_owner, fr.owner_user_id AS found_owner,
              lr.title AS lost_title, fr.title AS found_title
         FROM matches m
         JOIN reports lr ON lr.id = m.lost_item_id
         JOIN reports fr ON fr.id = m.found_item_id
        WHERE m.id = ?`
    )
    .get(matchId);
  if (!row) throw new ApiError(404, 'Match not found');
  if (row.lost_owner !== userId && row.found_owner !== userId) {
    throw new ApiError(403, 'This match does not involve your reports');
  }
  return row;
}

function serializeMatchForUser(row, userId) {
  const mineIsLost = row.lost_owner === userId;
  const myReportId = mineIsLost ? row.lost_item_id : row.found_item_id;
  const otherReportId = mineIsLost ? row.found_item_id : row.lost_item_id;
  return {
    id: row.id,
    matchScore: row.match_score,
    confidenceLabel: row.confidence_label,
    status: row.status,
    // 'pending_admin_approval' is the dashboard's vocabulary; the app shows a simpler idea.
    awaitingReview: row.status === 'pending_admin_approval',
    myReport: serializeReport(db.prepare('SELECT * FROM reports WHERE id = ?').get(myReportId), userId),
    matchedReport: serializeReport(db.prepare('SELECT * FROM reports WHERE id = ?').get(otherReportId), userId),
    createdAt: row.created_at,
  };
}

// GET /api/v1/me/matches
export const myMatches = asyncHandler(async (req, res) => {
  // Pick up anything an admin approved since the last sweep, so opening the screen is immediate.
  try {
    notifyApprovedMatches();
  } catch (err) {
    console.error('[matches] approval sweep failed:', err.message);
  }

  const { status = 'active' } = req.query;
  const rows = db
    .prepare(
      `SELECT m.*, lr.owner_user_id AS lost_owner, fr.owner_user_id AS found_owner
         FROM matches m
         JOIN reports lr ON lr.id = m.lost_item_id  AND lr.deleted_at IS NULL
         JOIN reports fr ON fr.id = m.found_item_id AND fr.deleted_at IS NULL
        WHERE (lr.owner_user_id = @userId OR fr.owner_user_id = @userId)
          AND (@status = 'all'
               OR (@status = 'active' AND m.status <> 'rejected')
               OR m.status = @status)
        ORDER BY m.match_score DESC, m.created_at DESC`
    )
    .all({ userId: req.user.id, status: String(status) });

  res.json({ success: true, data: rows.map((row) => serializeMatchForUser(row, req.user.id)) });
});

// POST /api/v1/matches/:id/dismiss
// "That is not my item." Rejecting it removes it from the app and from the admin's queue —
// the owner saying no is better evidence than a similarity score saying yes.
export const dismissMatch = asyncHandler(async (req, res) => {
  const match = loadMatchForUser(req.params.id, req.user.id);
  if (match.status === 'rejected') throw new ApiError(409, 'This match is already dismissed');
  if (match.status === 'approved') {
    throw new ApiError(409, 'This match has been approved by an admin and can no longer be dismissed');
  }

  db.prepare("UPDATE matches SET status = 'rejected', dismissed_by = ?, resolved_at = ? WHERE id = ?").run(
    req.user.id,
    nowSql(),
    match.id
  );
  res.json({ success: true, data: { id: match.id, status: 'rejected' } });
});
