import { db } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { newId } from '../utils/id.js';
import { nowSql } from '../utils/time.js';
import { q } from '../middleware/validate.js';
import { serializeNotification } from '../serializers/index.js';
import { unreadCount } from '../services/notify.service.js';

// GET /api/v1/notifications   — backs notifications_screen.dart
export const listNotifications = asyncHandler(async (req, res) => {
  const { page, pageSize } = q(req);
  const total = db.prepare('SELECT COUNT(*) AS count FROM user_notifications WHERE user_id = ?').get(req.user.id).count;
  const rows = db
    .prepare(
      `SELECT * FROM user_notifications
        WHERE user_id = @userId
        ORDER BY created_at DESC LIMIT @limit OFFSET @offset`
    )
    .all({ userId: req.user.id, limit: pageSize, offset: (page - 1) * pageSize });

  res.json({
    success: true,
    data: rows.map(serializeNotification),
    meta: { unread: unreadCount(req.user.id) },
    pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) || 1 },
  });
});

// GET /api/v1/notifications/unread-count   — the bottom-nav badge
export const getUnreadCount = asyncHandler(async (req, res) => {
  res.json({ success: true, data: { unread: unreadCount(req.user.id) } });
});

// PATCH /api/v1/notifications/:id/read
export const markRead = asyncHandler(async (req, res) => {
  const result = db
    .prepare('UPDATE user_notifications SET read_at = ? WHERE id = ? AND user_id = ? AND read_at IS NULL')
    .run(nowSql(), req.params.id, req.user.id);

  if (result.changes === 0) {
    const exists = db.prepare('SELECT id FROM user_notifications WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
    if (!exists) throw new ApiError(404, 'Notification not found');
    // Already read — idempotent, not an error.
  }

  res.json({
    success: true,
    data: serializeNotification(db.prepare('SELECT * FROM user_notifications WHERE id = ?').get(req.params.id)),
  });
});

// POST /api/v1/notifications/read-all   — "Mark all read"
export const markAllRead = asyncHandler(async (req, res) => {
  const result = db
    .prepare('UPDATE user_notifications SET read_at = ? WHERE user_id = ? AND read_at IS NULL')
    .run(nowSql(), req.user.id);
  res.json({ success: true, data: { marked: result.changes, unread: 0 } });
});

// DELETE /api/v1/notifications/:id
export const deleteNotification = asyncHandler(async (req, res) => {
  const result = db.prepare('DELETE FROM user_notifications WHERE id = ? AND user_id = ?').run(req.params.id, req.user.id);
  if (result.changes === 0) throw new ApiError(404, 'Notification not found');
  res.json({ success: true, data: { id: req.params.id, deleted: true } });
});

// POST /api/v1/devices   — register or refresh this install's FCM token
export const registerDevice = asyncHandler(async (req, res) => {
  const { fcmToken, platform, appVersion } = req.body;

  // A token identifies an install, not a user: if the phone was handed to another account, the
  // token must move with it rather than delivering the previous user's notifications.
  const existing = db.prepare('SELECT id FROM user_devices WHERE fcm_token = ?').get(fcmToken);
  if (existing) {
    db.prepare('UPDATE user_devices SET user_id = ?, platform = ?, app_version = ?, last_seen_at = ? WHERE id = ?').run(
      req.user.id,
      platform,
      appVersion ?? null,
      nowSql(),
      existing.id
    );
    return res.json({ success: true, data: { id: existing.id, registered: true } });
  }

  const id = newId('DEV');
  db.prepare(
    'INSERT INTO user_devices (id, user_id, fcm_token, platform, app_version, last_seen_at, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
  ).run(id, req.user.id, fcmToken, platform, appVersion ?? null, nowSql(), nowSql());

  res.status(201).json({ success: true, data: { id, registered: true } });
});

// DELETE /api/v1/devices   — called on sign-out so a shared phone stops receiving pushes
export const unregisterDevice = asyncHandler(async (req, res) => {
  db.prepare('DELETE FROM user_devices WHERE fcm_token = ? AND user_id = ?').run(req.body.fcmToken, req.user.id);
  res.json({ success: true, data: { unregistered: true } });
});
