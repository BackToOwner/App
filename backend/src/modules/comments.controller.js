import { db, withTransaction } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { newId } from '../utils/id.js';
import { nowSql } from '../utils/time.js';
import { q } from '../middleware/validate.js';
import { serializeComment } from '../serializers/index.js';
import { notify } from '../services/notify.service.js';

const COMMENT_SELECT = `
  SELECT c.*, u.name AS author_name, u.avatar AS author_avatar, u.trust_score AS author_trust_score
    FROM report_comments c
    JOIN users u ON u.id = c.user_id`;

function loadReport(id) {
  const row = db.prepare('SELECT * FROM reports WHERE id = ? AND deleted_at IS NULL').get(id);
  if (!row) throw new ApiError(404, 'Report not found');
  return row;
}

// GET /api/v1/reports/:id/comments
export const listComments = asyncHandler(async (req, res) => {
  const report = loadReport(req.params.id);
  const { page, pageSize } = q(req);

  const total = db
    .prepare('SELECT COUNT(*) AS count FROM report_comments WHERE report_id = ? AND is_hidden = 0')
    .get(report.id).count;
  const rows = db
    .prepare(
      `${COMMENT_SELECT} WHERE c.report_id = @reportId AND c.is_hidden = 0
       ORDER BY c.created_at ASC LIMIT @limit OFFSET @offset`
    )
    .all({ reportId: report.id, limit: pageSize, offset: (page - 1) * pageSize });

  res.json({
    success: true,
    data: rows.map(serializeComment),
    pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) || 1 },
  });
});

// POST /api/v1/reports/:id/comments
export const createComment = asyncHandler(async (req, res) => {
  const report = loadReport(req.params.id);
  const { body, parentId } = req.body;

  if (parentId) {
    const parent = db
      .prepare('SELECT id, parent_id FROM report_comments WHERE id = ? AND report_id = ?')
      .get(parentId, report.id);
    if (!parent) throw new ApiError(404, 'The comment being replied to does not exist on this report');
    // One level of replies only — deeper threads are unreadable on a phone.
    if (parent.parent_id) throw new ApiError(409, 'Replies cannot be nested further');
  }

  const id = newId('CMT');
  const tx = withTransaction(() => {
    db.prepare(
      'INSERT INTO report_comments (id, report_id, user_id, parent_id, body, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).run(id, report.id, req.user.id, parentId ?? null, body, nowSql(), nowSql());
    db.prepare('UPDATE reports SET comment_count = comment_count + 1 WHERE id = ?').run(report.id);
  });
  tx();

  // Notify the report owner, and the parent comment's author when that is someone else.
  const recipients = new Set();
  if (report.owner_user_id && report.owner_user_id !== req.user.id) recipients.add(report.owner_user_id);
  if (parentId) {
    const parentAuthor = db.prepare('SELECT user_id FROM report_comments WHERE id = ?').get(parentId)?.user_id;
    if (parentAuthor && parentAuthor !== req.user.id) recipients.add(parentAuthor);
  }
  for (const userId of recipients) {
    notify(userId, 'comment', {
      title: userId === report.owner_user_id ? 'New Reply on Your Report' : 'New Reply to Your Comment',
      body: `${req.user.name} commented on "${report.title}".`,
      reportId: report.id,
      commentId: id,
      data: { reportId: report.id, commentId: id },
    });
  }

  res.status(201).json({ success: true, data: serializeComment(db.prepare(`${COMMENT_SELECT} WHERE c.id = ?`).get(id)) });
});

// DELETE /api/v1/comments/:id
export const deleteComment = asyncHandler(async (req, res) => {
  const comment = db.prepare('SELECT * FROM report_comments WHERE id = ?').get(req.params.id);
  if (!comment) throw new ApiError(404, 'Comment not found');

  const report = db.prepare('SELECT owner_user_id FROM reports WHERE id = ?').get(comment.report_id);
  const isAuthor = comment.user_id === req.user.id;
  const isReportOwner = report?.owner_user_id === req.user.id;
  if (!isAuthor && !isReportOwner) {
    throw new ApiError(403, 'Only the comment author or the report owner can remove this comment');
  }

  const tx = withTransaction(() => {
    db.prepare('DELETE FROM report_comments WHERE id = ?').run(comment.id);
    db.prepare('UPDATE reports SET comment_count = MAX(0, comment_count - 1) WHERE id = ?').run(comment.report_id);
  });
  tx();

  res.json({ success: true, data: { id: comment.id, deleted: true } });
});
