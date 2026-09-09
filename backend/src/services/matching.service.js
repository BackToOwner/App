import { db } from '../db/index.js';
import { env } from '../config/env.js';
import { newId } from '../utils/id.js';
import { nowSql, parseSqlDate } from '../utils/time.js';
import { haversineKm, boundingBox } from '../utils/geo.js';

const STOP_WORDS = new Set([
  'a', 'an', 'and', 'at', 'for', 'from', 'in', 'is', 'it', 'my', 'near', 'of', 'on',
  'or', 'the', 'to', 'with', 'lost', 'found', 'item', 'items', 'please', 'help', 'was', 'were',
]);

export function tokenize(text) {
  return new Set(
    String(text || '')
      .toLowerCase()
      .replace(/[^a-z0-9\s]/g, ' ')
      .split(/\s+/)
      .filter((t) => t.length > 2 && !STOP_WORDS.has(t))
  );
}

// Jaccard similarity: shared tokens over the union. Symmetric, and it does not reward a long
// description simply for containing more words.
export function textSimilarity(a, b) {
  const setA = tokenize(a);
  const setB = tokenize(b);
  if (setA.size === 0 || setB.size === 0) return 0;
  let shared = 0;
  for (const token of setA) if (setB.has(token)) shared += 1;
  return shared / (setA.size + setB.size - shared);
}

/**
 * Scores a lost/found pair out of 100:
 *   category 30 · text 25 · geo 25 · time 20
 * Signals that cannot be evaluated (no coordinates, no dates) score 0 rather than a neutral
 * midpoint — an unknown is not evidence of a match.
 */
export function scoreMatch(lost, found, { radiusKm = env.defaultRadiusKm } = {}) {
  const factors = [];

  let category = 0;
  if (lost.category === found.category && lost.category !== 'other') {
    category = 30;
    factors.push(`Same category (${lost.category})`);
  } else if (lost.category === 'other' || found.category === 'other') {
    category = 10;
  }

  const similarity = textSimilarity(
    `${lost.title} ${lost.description}`,
    `${found.title} ${found.description}`
  );
  const text = Math.round(similarity * 25);
  if (text >= 10) factors.push(`Description overlap ${Math.round(similarity * 100)}%`);

  let geo = 0;
  let distanceKm = null;
  if (lost.lat != null && lost.lng != null && found.lat != null && found.lng != null) {
    distanceKm = haversineKm(lost.lat, lost.lng, found.lat, found.lng);
    if (distanceKm != null) {
      geo = Math.round(25 * Math.max(0, 1 - distanceKm / radiusKm));
      if (geo > 0) factors.push(`Within ${distanceKm.toFixed(1)} km`);
    }
  }

  // An item can only be found after it was lost; the signal decays over 30 days.
  let time = 0;
  const lostAt = parseSqlDate(lost.occurred_at || lost.created_at);
  const foundAt = parseSqlDate(found.occurred_at || found.created_at);
  if (lostAt && foundAt) {
    const gapDays = (foundAt.getTime() - lostAt.getTime()) / 86400000;
    if (gapDays >= -1) {
      time = Math.round(20 * Math.max(0, 1 - Math.max(0, gapDays) / 30));
      if (time > 0) factors.push(`Reported ${Math.max(0, Math.round(gapDays))} day(s) apart`);
    }
  }

  return {
    score: category + text + geo + time,
    breakdown: { category, text, geo, time, similarity: Number(similarity.toFixed(3)), distanceKm },
    factors,
  };
}

// Labels match the vocabulary the admin dashboard already renders in its match queue.
export function confidenceLabel(score) {
  if (score >= 95) return 'Very High Confidence';
  if (score >= 85) return 'High Confidence';
  if (score >= 70) return 'Moderate Confidence';
  return 'Low Confidence';
}

/**
 * Finds and persists candidate matches for a newly created report.
 *
 * Because this backend shares its database with the admin dashboard, candidates land in that
 * dashboard's existing queue as 'pending_admin_approval' — the same rows its match screen already
 * lists. Nothing is auto-linked and nobody is notified here: users hear about a match only once an
 * admin approves it, which notifyApprovedMatches() picks up (see matchNotifier.service.js).
 */
export function generateMatchesForReport(reportId) {
  const report = db.prepare('SELECT * FROM reports WHERE id = ? AND deleted_at IS NULL').get(reportId);
  if (!report) return [];

  const params = {
    type: report.type === 'lost' ? 'found' : 'lost',
    windowDays: `-${env.matchWindowDays} days`,
  };

  // Bounding-box pre-filter uses idx_reports_geo so haversine runs over tens of rows, not the
  // whole table. Reports without coordinates stay eligible — geo simply scores 0 for them.
  let geoClause = '';
  if (report.lat != null && report.lng != null) {
    Object.assign(params, boundingBox(report.lat, report.lng, env.defaultRadiusKm * 2));
    geoClause =
      'AND (lat IS NULL OR lng IS NULL OR (lat BETWEEN @minLat AND @maxLat AND lng BETWEEN @minLng AND @maxLng))';
  }

  const candidates = db
    .prepare(
      `SELECT * FROM reports
        WHERE type = @type
          AND deleted_at IS NULL
          AND status IN ('open', 'in_review')
          AND created_at >= datetime('now', @windowDays)
          ${geoClause}`
    )
    .all(params);

  const created = [];
  for (const candidate of candidates) {
    const lost = report.type === 'lost' ? report : candidate;
    const found = report.type === 'lost' ? candidate : report;

    // Never pair a user's own lost report with their own found report.
    if (lost.owner_user_id && lost.owner_user_id === found.owner_user_id) continue;

    const { score, breakdown, factors } = scoreMatch(lost, found);
    if (score < env.matchThreshold) continue;

    // idx_matches_pair enforces this too; checking first avoids a pointless constraint error.
    if (db.prepare('SELECT id FROM matches WHERE lost_item_id = ? AND found_item_id = ?').get(lost.id, found.id)) {
      continue;
    }

    const id = newId('MATCH');
    db.prepare(
      `INSERT INTO matches
         (id, lost_item_id, found_item_id, match_score, confidence_label, match_factors,
          score_breakdown, status, source, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'pending_admin_approval', 'auto', ?)`
    ).run(
      id,
      lost.id,
      found.id,
      score,
      confidenceLabel(score),
      JSON.stringify(factors),
      JSON.stringify(breakdown),
      nowSql()
    );
    created.push({ id, score });
  }

  return created;
}
