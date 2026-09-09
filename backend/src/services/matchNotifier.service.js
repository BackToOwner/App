import { db } from '../db/index.js';
import { notify } from './notify.service.js';

/**
 * Tells report owners that an admin approved their match.
 *
 * The approval happens in the *other* process — the admin dashboard backend, whose code this
 * project does not modify. So there is no hook to fire on; instead this looks for matches that are
 * `approved` but whose owners have no match notification yet, and fills the gap.
 *
 * The "no notification yet" test is a NOT EXISTS against user_notifications rather than a flag
 * column, which makes the whole thing idempotent: running it twice, or from two callers at once,
 * cannot produce a duplicate. Deleting a notification would re-send it, which is the harmless
 * direction to be wrong in.
 *
 * Called on an interval from server.js, and opportunistically when the app fetches /me/matches so
 * a user who opens the screen sees the result without waiting for the next sweep.
 */
export function notifyApprovedMatches() {
  const pending = db
    .prepare(
      `SELECT m.id AS match_id,
              lr.id AS lost_id,   lr.title AS lost_title,   lr.owner_user_id AS lost_owner,
              fr.id AS found_id,  fr.title AS found_title,  fr.owner_user_id AS found_owner
         FROM matches m
         JOIN reports lr ON lr.id = m.lost_item_id  AND lr.deleted_at IS NULL
         JOIN reports fr ON fr.id = m.found_item_id AND fr.deleted_at IS NULL
        WHERE m.status = 'approved'
          AND (lr.owner_user_id IS NOT NULL OR fr.owner_user_id IS NOT NULL)`
    )
    .all();

  const alreadyNotified = db.prepare(
    `SELECT 1 AS x FROM user_notifications WHERE match_id = ? AND user_id = ? AND type = 'match' LIMIT 1`
  );

  let sent = 0;
  for (const row of pending) {
    const sides = [
      { userId: row.lost_owner, reportId: row.lost_id, mine: row.lost_title, theirs: row.found_title, otherId: row.found_id },
      { userId: row.found_owner, reportId: row.found_id, mine: row.found_title, theirs: row.lost_title, otherId: row.lost_id },
    ];

    for (const side of sides) {
      if (!side.userId) continue;
      if (alreadyNotified.get(row.match_id, side.userId)) continue;

      notify(side.userId, 'match', {
        title: 'Possible Match Found! 🎉',
        body: `Someone reported "${side.theirs}", which matches your "${side.mine}".`,
        reportId: side.reportId,
        matchId: row.match_id,
        data: { reportId: side.reportId, matchedReportId: side.otherId, matchId: row.match_id },
      });
      sent += 1;
    }
  }

  return sent;
}

let timer = null;

export function startMatchNotifier(intervalMs) {
  if (timer || intervalMs <= 0) return;
  timer = setInterval(() => {
    try {
      const sent = notifyApprovedMatches();
      if (sent > 0) console.log(`[matches] notified ${sent} user(s) of admin-approved matches`);
    } catch (err) {
      console.error('[matches] approval sweep failed:', err.message);
    }
  }, intervalMs);
  timer.unref(); // never hold the process open on this alone
}

export function stopMatchNotifier() {
  if (timer) clearInterval(timer);
  timer = null;
}
