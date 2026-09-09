import { db } from '../db/index.js';
import { newId } from '../utils/id.js';
import { nowSql } from '../utils/time.js';
import { pushAllowed, sendPushToUser } from './push.service.js';

/**
 * The single entry point for anything that notifies a user.
 *
 * Every producer (comments, claims, matches) goes through notify(); no controller inserts into
 * `notifications` directly. That keeps the push fan-out, the settings filter and the deep-link
 * payload in one place instead of drifting across six controllers.
 */
export function notify(userId, type, { title, body = '', reportId, matchId, commentId, claimId, data = {} }) {
  if (!userId) return null;

  const id = newId('NOTIF');
  db.prepare(
    `INSERT INTO user_notifications
       (id, user_id, type, title, body, report_id, match_id, comment_id, claim_id, data, created_at)
     VALUES (@id, @userId, @type, @title, @body, @reportId, @matchId, @commentId, @claimId, @data, @createdAt)`
  ).run({
    id,
    userId,
    type,
    title,
    body,
    reportId: reportId ?? null,
    matchId: matchId ?? null,
    commentId: commentId ?? null,
    claimId: claimId ?? null,
    data: JSON.stringify(data),
    createdAt: nowSql(),
  });

  // Push is fire-and-forget: a provider outage must never fail the request that triggered it.
  if (pushAllowed(userId, type)) {
    sendPushToUser(userId, { title, body, data: { ...data, type, notificationId: id, reportId: reportId ?? '' } })
      .then((result) => {
        if (result.delivered) {
          db.prepare('UPDATE user_notifications SET push_sent_at = ? WHERE id = ?').run(nowSql(), id);
        }
      })
      .catch((err) => console.error('[notify] push failed:', err.message));
  }

  return id;
}

export function unreadCount(userId) {
  return db
    .prepare('SELECT COUNT(*) AS count FROM user_notifications WHERE user_id = ? AND read_at IS NULL')
    .get(userId).count;
}
