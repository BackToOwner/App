import { db } from '../db/index.js';
import { env } from '../config/env.js';

/**
 * Push delivery adapter.
 *
 * Not wired to a real provider yet: FCM v1 needs a service-account JSON (and an APNs key for
 * iOS) that this project does not have, and the retired legacy server-key API is deliberately
 * not used. Until credentials exist, sends are logged and reported as not-delivered, which keeps
 * `push_sent_at` honest rather than recording phantom deliveries.
 *
 * To go live, implement `deliver()` against FCM v1 and leave every call site untouched.
 */
async function deliver(tokens, message) {
  if (!env.fcmServerKey) {
    if (env.nodeEnv !== 'test') {
      console.log(`[push] (not configured) would send "${message.title}" to ${tokens.length} device(s)`);
    }
    return { delivered: false, reason: 'not_configured' };
  }
  console.log('[push] FCM credentials present but the v1 sender is not implemented yet');
  return { delivered: false, reason: 'not_implemented' };
}

const SETTING_BY_TYPE = {
  match: 'push_matches',
  comment: 'push_comments',
  claim: 'push_claims',
  returned: 'push_claims',
};

// Respects user_settings: a user who turned a category off still gets the inbox row, no push.
export function pushAllowed(userId, type) {
  const settingKey = SETTING_BY_TYPE[type];
  if (!settingKey) return true;
  const settings = db.prepare(`SELECT ${settingKey} AS enabled FROM user_settings WHERE user_id = ?`).get(userId);
  if (!settings) return true; // no row yet = defaults, which are all on
  return Boolean(settings.enabled);
}

export async function sendPushToUser(userId, { title, body, data = {} }) {
  const devices = db.prepare('SELECT fcm_token FROM user_devices WHERE user_id = ?').all(userId);
  if (devices.length === 0) return { delivered: false, reason: 'no_devices' };
  return deliver(
    devices.map((d) => d.fcm_token),
    { title, body, data }
  );
}
