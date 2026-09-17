import { db, withTransaction } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { newId } from '../utils/id.js';
import { nowSql } from '../utils/time.js';
import { q } from '../middleware/validate.js';
import { serializeClaim } from '../serializers/index.js';
import { setReportStatus } from '../services/reports.service.js';
import { notify } from '../services/notify.service.js';

const CLAIM_SELECT = `
  SELECT c.*, r.title AS report_title, r.owner_user_id AS report_owner_id,
         u.name AS claimant_name, u.avatar AS claimant_avatar, u.trust_score AS claimant_trust_score,
         u.email AS claimant_email, u.phone AS claimant_phone
    FROM claims c
    JOIN reports r ON r.id = c.report_id
    JOIN users u ON u.id = c.claimant_user_id`;

function loadClaim(id) {
  const row = db.prepare(`${CLAIM_SELECT} WHERE c.id = ?`).get(id);
  if (!row) throw new ApiError(404, 'Claim not found');
  return row;
}

function requireReportOwner(claim, userId) {
  if (claim.report_owner_id !== userId) throw new ApiError(403, 'Only the report owner can do this');
}

// POST /api/v1/reports/:id/claims
export const createClaim = asyncHandler(async (req, res) => {
  const report = db.prepare('SELECT * FROM reports WHERE id = ? AND deleted_at IS NULL').get(req.params.id);
  if (!report) throw new ApiError(404, 'Report not found');
  if (report.owner_user_id === req.user.id) throw new ApiError(409, 'You cannot claim your own report');
  if (!report.owner_user_id) throw new ApiError(409, 'This report has no owner to review a claim');
  if (['returned', 'closed'].includes(report.status)) throw new ApiError(409, `This report is already ${report.status}`);

  // idx_claims_one_open enforces this in the database too; checking here gives a clear message
  // instead of a raw constraint error.
  const open = db
    .prepare("SELECT id, status FROM claims WHERE report_id = ? AND claimant_user_id = ? AND status IN ('pending','accepted')")
    .get(report.id, req.user.id);
  if (open) throw new ApiError(409, `You already have a ${open.status} claim on this report`);

  const id = newId('CLM');
  const tx = withTransaction(() => {
    db.prepare(
      'INSERT INTO claims (id, report_id, claimant_user_id, message, proof, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).run(id, report.id, req.user.id, req.body.message, JSON.stringify(req.body.proof), nowSql(), nowSql());
    db.prepare('UPDATE reports SET claim_count = claim_count + 1 WHERE id = ?').run(report.id);
    // A claim means someone is actively working the report.
    if (report.status === 'open') setReportStatus(report.id, 'in_review', 'system', null, 'Claim filed');
  });
  tx();

  notify(report.owner_user_id, 'claim', {
    title: 'Someone Claimed Your Item',
    body: `${req.user.name} filed a claim on "${report.title}".`,
    reportId: report.id,
    claimId: id,
    data: { reportId: report.id, claimId: id },
  });

  res.status(201).json({ success: true, data: serializeClaim(loadClaim(id), { includeContacts: true }) });
});

// GET /api/v1/reports/:id/claims   (report owner only)
export const listReportClaims = asyncHandler(async (req, res) => {
  const report = db.prepare('SELECT * FROM reports WHERE id = ? AND deleted_at IS NULL').get(req.params.id);
  if (!report) throw new ApiError(404, 'Report not found');
  if (report.owner_user_id !== req.user.id) throw new ApiError(403, 'Only the report owner can see the claims on it');

  const rows = db.prepare(`${CLAIM_SELECT} WHERE c.report_id = ? ORDER BY c.created_at DESC`).all(report.id);
  res.json({ success: true, data: rows.map((row) => serializeClaim(row, { includeContacts: true })) });
});

// GET /api/v1/me/claims
export const myClaims = asyncHandler(async (req, res) => {
  const { page, pageSize } = q(req);
  const total = db.prepare('SELECT COUNT(*) AS count FROM claims WHERE claimant_user_id = ?').get(req.user.id).count;
  const rows = db
    .prepare(`${CLAIM_SELECT} WHERE c.claimant_user_id = @userId ORDER BY c.created_at DESC LIMIT @limit OFFSET @offset`)
    .all({ userId: req.user.id, limit: pageSize, offset: (page - 1) * pageSize });

  res.json({
    success: true,
    data: rows.map((row) => serializeClaim(row, { includeContacts: true })),
    pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) || 1 },
  });
});

// POST /api/v1/claims/:id/accept   (report owner)
export const acceptClaim = asyncHandler(async (req, res) => {
  const claim = loadClaim(req.params.id);
  requireReportOwner(claim, req.user.id);
  if (claim.status !== 'pending') throw new ApiError(409, `Cannot accept a ${claim.status} claim`);

  const tx = withTransaction(() => {
    db.prepare(
      `UPDATE claims
          SET status = 'accepted', meeting_place = @meetingPlace, meeting_at = @meetingAt,
              decided_by_user_id = @actorId, decided_at = @now, updated_at = @now
        WHERE id = @id`
    ).run({
      id: claim.id,
      meetingPlace: req.body.meetingPlace ?? null,
      meetingAt: req.body.meetingAt ?? null,
      actorId: req.user.id,
      now: nowSql(),
    });
    // Competing claims on the same report are declined — one item, one owner.
    db.prepare(
      "UPDATE claims SET status = 'rejected', decided_at = ?, updated_at = ? WHERE report_id = ? AND id <> ? AND status = 'pending'"
    ).run(nowSql(), nowSql(), claim.report_id, claim.id);
  });
  tx();

  // Accepting is what unlocks contact details for both sides (see canSeeContacts).
  notify(claim.claimant_user_id, 'claim', {
    title: 'Your Claim Was Accepted 🎉',
    body: `You can now contact the owner of "${claim.report_title}" to arrange the handover.`,
    reportId: claim.report_id,
    claimId: claim.id,
    data: { reportId: claim.report_id, claimId: claim.id },
  });

  res.json({ success: true, data: serializeClaim(loadClaim(claim.id), { includeContacts: true }) });
});

// POST /api/v1/claims/:id/reject   (report owner)
export const rejectClaim = asyncHandler(async (req, res) => {
  const claim = loadClaim(req.params.id);
  requireReportOwner(claim, req.user.id);
  if (!['pending', 'accepted'].includes(claim.status)) throw new ApiError(409, `Cannot reject a ${claim.status} claim`);

  db.prepare("UPDATE claims SET status = 'rejected', decided_by_user_id = ?, decided_at = ?, updated_at = ? WHERE id = ?").run(
    req.user.id,
    nowSql(),
    nowSql(),
    claim.id
  );

  notify(claim.claimant_user_id, 'claim', {
    title: 'Claim Declined',
    body: `Your claim on "${claim.report_title}" was declined${req.body.reason ? `: ${req.body.reason}` : '.'}`,
    reportId: claim.report_id,
    claimId: claim.id,
    data: { reportId: claim.report_id, claimId: claim.id },
  });

  res.json({ success: true, data: serializeClaim(loadClaim(claim.id)) });
});

// POST /api/v1/claims/:id/withdraw   (claimant)
export const withdrawClaim = asyncHandler(async (req, res) => {
  const claim = loadClaim(req.params.id);
  if (claim.claimant_user_id !== req.user.id) throw new ApiError(403, 'Only the claimant can withdraw this claim');
  if (!['pending', 'accepted'].includes(claim.status)) throw new ApiError(409, `Cannot withdraw a ${claim.status} claim`);

  db.prepare("UPDATE claims SET status = 'withdrawn', updated_at = ? WHERE id = ?").run(nowSql(), claim.id);

  notify(claim.report_owner_id, 'claim', {
    title: 'Claim Withdrawn',
    body: `${req.user.name} withdrew their claim on "${claim.report_title}".`,
    reportId: claim.report_id,
    claimId: claim.id,
    data: { reportId: claim.report_id, claimId: claim.id },
  });

  res.json({ success: true, data: serializeClaim(loadClaim(claim.id)) });
});

/**
 * POST /api/v1/claims/:id/confirm-return
 *
 * Both parties must confirm before the item counts as returned — a one-sided "done" is the
 * obvious way to fake a successful handover and inflate a trust score. The claim only reaches
 * `completed` on the second confirmation, and that is what flips the report to `returned`.
 */
export const confirmReturn = asyncHandler(async (req, res) => {
  const claim = loadClaim(req.params.id);
  const isOwner = claim.report_owner_id === req.user.id;
  const isClaimant = claim.claimant_user_id === req.user.id;
  if (!isOwner && !isClaimant) throw new ApiError(403, 'You are not a party to this claim');
  if (claim.status !== 'accepted') {
    throw new ApiError(409, `Only an accepted claim can be confirmed (this one is ${claim.status})`);
  }

  const column = isOwner ? 'owner_confirmed_at' : 'claimant_confirmed_at';
  if (claim[column]) throw new ApiError(409, 'You have already confirmed this handover');

  const bothConfirmed = Boolean(isOwner ? claim.claimant_confirmed_at : claim.owner_confirmed_at);

  const tx = withTransaction(() => {
    db.prepare(`UPDATE claims SET ${column} = ?, updated_at = ? WHERE id = ?`).run(nowSql(), nowSql(), claim.id);

    if (bothConfirmed) {
      db.prepare("UPDATE claims SET status = 'completed', updated_at = ? WHERE id = ?").run(nowSql(), claim.id);
      setReportStatus(claim.report_id, 'returned', 'user', req.user.id, 'Handover confirmed by both parties');

      // Credit both sides and nudge trust upward, capped at 100.
      for (const userId of [claim.report_owner_id, claim.claimant_user_id]) {
        db.prepare(
          `UPDATE users
              SET items_returned = items_returned + 1,
                  trust_score = MIN(100, trust_score + 1),
                  updated_at = ?
            WHERE id = ?`
        ).run(nowSql(), userId);
      }
    }
  });
  tx();

  if (bothConfirmed) {
    for (const userId of [claim.report_owner_id, claim.claimant_user_id]) {
      notify(userId, 'returned', {
        title: 'Item Marked as Returned',
        body: `Great news — "${claim.report_title}" was successfully returned to its owner.`,
        reportId: claim.report_id,
        claimId: claim.id,
        data: { reportId: claim.report_id, claimId: claim.id },
      });
    }
  } else {
    notify(isOwner ? claim.claimant_user_id : claim.report_owner_id, 'claim', {
      title: 'Confirm the Handover',
      body: `${req.user.name} confirmed the handover of "${claim.report_title}". Confirm to close it.`,
      reportId: claim.report_id,
      claimId: claim.id,
      data: { reportId: claim.report_id, claimId: claim.id },
    });
  }

  res.json({
    success: true,
    data: {
      ...serializeClaim(loadClaim(claim.id), { includeContacts: true }),
      completed: bothConfirmed,
      awaitingOtherParty: !bothConfirmed,
    },
  });
});
