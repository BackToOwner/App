import { db } from '../db/index.js';
import { newId } from '../utils/id.js';
import { nowSql } from '../utils/time.js';

export const REPORT_STATUSES = ['open', 'in_review', 'matched', 'returned', 'closed'];

/**
 * report_images is the source of truth; reports.images (JSON) is a denormalised mirror kept in
 * step so the column matches the shape the admin dashboard backend expects. Always call this
 * inside the same transaction as the image write that caused it.
 */
export function syncImagesJson(reportId) {
  const urls = db
    .prepare('SELECT url FROM report_images WHERE report_id = ? ORDER BY sort_order, created_at')
    .all(reportId)
    .map((r) => r.url);
  db.prepare('UPDATE reports SET images = ? WHERE id = ?').run(JSON.stringify(urls), reportId);
  return urls;
}

export function recordStatusChange(reportId, fromStatus, toStatus, actorType, actorId, note = null) {
  if (fromStatus === toStatus) return;
  db.prepare(
    `INSERT INTO report_status_history (id, report_id, from_status, to_status, changed_by_type, changed_by_id, note, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(newId('RSH'), reportId, fromStatus, toStatus, actorType, actorId ?? null, note, nowSql());
}

export function setReportStatus(reportId, toStatus, actorType, actorId, note = null) {
  const current = db.prepare('SELECT status FROM reports WHERE id = ?').get(reportId);
  if (!current) return;
  const resolvedAt = toStatus === 'returned' ? nowSql() : null;
  db.prepare(
    `UPDATE reports
        SET status = ?,
            resolved_at = COALESCE(?, resolved_at),
            updated_at = ?
      WHERE id = ?`
  ).run(toStatus, resolvedAt, nowSql(), reportId);
  recordStatusChange(reportId, current.status, toStatus, actorType, actorId, note);
}

// Counters are maintained transactionally at write time; this re-derives them from the truth for
// a periodic reconciliation job and after bulk imports.
export function reconcileCounters(reportId = null) {
  const where = reportId ? 'WHERE r.id = @reportId' : '';
  const params = reportId ? { reportId } : {};
  db.prepare(
    `UPDATE reports AS r
        SET comment_count = (SELECT COUNT(*) FROM report_comments c WHERE c.report_id = r.id AND c.is_hidden = 0),
            claim_count   = (SELECT COUNT(*) FROM claims cl WHERE cl.report_id = r.id),
            view_count    = (SELECT COUNT(*) FROM report_views v WHERE v.report_id = r.id)
      ${where}`
  ).run(params);
}

export function isOwner(report, userId) {
  return Boolean(userId) && report.owner_user_id === userId;
}

/**
 * Contact details are released only to the owner, or to a claimant whose claim was accepted.
 * This is the enforcement point for that rule; the serializer calls it, never a controller.
 */
export function canSeeContacts(report, userId) {
  if (!userId) return false;
  if (isOwner(report, userId)) return true;
  const claim = db
    .prepare(
      `SELECT id FROM claims
        WHERE report_id = ? AND claimant_user_id = ? AND status IN ('accepted','completed')
        LIMIT 1`
    )
    .get(report.id, userId);
  return Boolean(claim);
}
