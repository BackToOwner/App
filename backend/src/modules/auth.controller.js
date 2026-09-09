import bcrypt from 'bcryptjs';
import { OAuth2Client } from 'google-auth-library';
import { db, withTransaction } from '../db/index.js';
import { env } from '../config/env.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { newId } from '../utils/id.js';
import { signAccessToken } from '../utils/jwt.js';
import { generateRefreshToken, hashToken, generateOtpCode } from '../utils/tokens.js';
import { nowSql, sqlDaysFromNow, sqlMinutesFromNow, isPast } from '../utils/time.js';
import { serializeUserProfile } from '../serializers/index.js';
import { unreadCount } from '../services/notify.service.js';

export const BCRYPT_ROUNDS = 12;
const OTP_MAX_ATTEMPTS = 5;

// A real bcrypt hash of a value nobody will submit, used to equalise login timing (see login()).
const DUMMY_HASH = '$2a$12$C6UzMDM.H6dfI/f/IKcEe.Ie/n5Y9lS3.2sVQxq3D1lqCS3RJZOfi';

const googleClient = env.googleClientId ? new OAuth2Client(env.googleClientId) : null;

const fullUser = (id) => db.prepare('SELECT * FROM users WHERE id = ?').get(id);

function displayName(firstName, lastName) {
  return [firstName, lastName].filter(Boolean).join(' ').trim() || 'BackToOwner User';
}

export function ensureSettingsRow(userId) {
  db.prepare('INSERT OR IGNORE INTO user_settings (user_id, updated_at) VALUES (?, ?)').run(userId, nowSql());
}

function assertUsable(user) {
  if (!user || user.deleted_at) throw new ApiError(401, 'Invalid credentials');
  if (user.status === 'banned') throw new ApiError(403, 'This account has been banned', { code: 'ACCOUNT_BANNED' });
  if (user.status === 'suspended') throw new ApiError(403, 'This account is suspended', { code: 'ACCOUNT_SUSPENDED' });
}

// Issues an access token plus a fresh refresh-token session row.
function issueSession(user, req) {
  const refreshToken = generateRefreshToken();
  db.prepare(
    `INSERT INTO user_sessions (id, user_id, refresh_token_hash, device_id, platform, user_agent, ip, expires_at, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    newId('SESS'),
    user.id,
    hashToken(refreshToken),
    req.get('x-device-id') || null,
    req.get('x-platform') || null,
    req.get('user-agent') || null,
    req.ip || null,
    sqlDaysFromNow(env.refreshTokenDays),
    nowSql()
  );

  db.prepare('UPDATE users SET last_login_at = ? WHERE id = ?').run(nowSql(), user.id);

  return { accessToken: signAccessToken({ sub: user.id }), refreshToken, expiresIn: env.accessTokenExpiresIn };
}

function authPayload(user, req) {
  const tokens = issueSession(user, req);
  return {
    ...tokens,
    user: serializeUserProfile(fullUser(user.id)),
    unreadNotifications: unreadCount(user.id),
  };
}

// POST /api/v1/auth/register
export const register = asyncHandler(async (req, res) => {
  const { email, password, phone, idVerificationNo } = req.body;
  const firstName = req.body.firstName ?? (req.body.name ? req.body.name.split(' ')[0] : null);
  const lastName = req.body.lastName ?? (req.body.name ? req.body.name.split(' ').slice(1).join(' ') : '');

  const existing = db.prepare('SELECT id, deleted_at FROM users WHERE lower(email) = ?').get(email);
  if (existing && !existing.deleted_at) throw new ApiError(409, 'An account with this email already exists');

  const id = newId('USR');
  const name = displayName(firstName, lastName);

  const tx = withTransaction(() => {
    db.prepare(
      `INSERT INTO users (id, name, first_name, last_name, email, phone, password_hash, id_verification_no,
                          role, status, joined_at, updated_at)
       VALUES (@id, @name, @firstName, @lastName, @email, @phone, @passwordHash, @idVerificationNo,
               'Verified Citizen', 'active', @now, @now)`
    ).run({
      id,
      name,
      firstName: firstName || name,
      lastName: lastName || '',
      email,
      phone: phone || null,
      passwordHash: bcrypt.hashSync(password, BCRYPT_ROUNDS),
      idVerificationNo: idVerificationNo || null,
      now: nowSql(),
    });
    ensureSettingsRow(id);
  });
  tx();

  res.status(201).json({ success: true, data: authPayload(fullUser(id), req) });
});

// POST /api/v1/auth/login
export const login = asyncHandler(async (req, res) => {
  const { email, phone, password } = req.body;
  if (!email && !phone) throw new ApiError(400, 'email or phone is required');

  const user = email
    ? db.prepare('SELECT * FROM users WHERE lower(email) = ?').get(email)
    : db.prepare('SELECT * FROM users WHERE phone = ?').get(phone);

  // A missing account and a wrong password must be indistinguishable. Bcrypt against a real hash
  // takes ~200ms while a missing user would return instantly, so hash a dummy to level the timing.
  if (!user || !user.password_hash) {
    bcrypt.compareSync(password, DUMMY_HASH);
    throw new ApiError(401, 'Invalid email or password');
  }
  if (!bcrypt.compareSync(password, user.password_hash)) throw new ApiError(401, 'Invalid email or password');
  assertUsable(user);

  ensureSettingsRow(user.id);
  res.json({ success: true, data: authPayload(user, req) });
});

// POST /api/v1/auth/google
export const googleAuth = asyncHandler(async (req, res) => {
  if (!googleClient) {
    throw new ApiError(503, 'Google sign-in is not configured on this server (set GOOGLE_CLIENT_ID)');
  }

  let payload;
  try {
    const ticket = await googleClient.verifyIdToken({ idToken: req.body.idToken, audience: env.googleClientId });
    payload = ticket.getPayload();
  } catch {
    throw new ApiError(401, 'Invalid Google ID token');
  }
  if (!payload?.email) throw new ApiError(401, 'Google account did not provide an email address');

  const email = payload.email.toLowerCase();
  let user =
    db.prepare('SELECT * FROM users WHERE google_id = ?').get(payload.sub) ||
    db.prepare('SELECT * FROM users WHERE lower(email) = ?').get(email);

  if (user) {
    assertUsable(user);
    // Link the Google identity to the existing email account on first Google sign-in.
    if (!user.google_id) {
      db.prepare('UPDATE users SET google_id = ?, email_verified = 1, updated_at = ? WHERE id = ?').run(
        payload.sub,
        nowSql(),
        user.id
      );
    }
  } else {
    const id = newId('USR');
    const firstName = payload.given_name || payload.name || email.split('@')[0];
    const lastName = payload.family_name || '';
    const tx = withTransaction(() => {
      db.prepare(
        `INSERT INTO users (id, name, first_name, last_name, email, google_id, avatar, email_verified,
                            role, status, joined_at, updated_at)
         VALUES (@id, @name, @firstName, @lastName, @email, @googleId, @avatar, 1,
                 'Verified Citizen', 'active', @now, @now)`
      ).run({
        id,
        name: displayName(firstName, lastName),
        firstName,
        lastName,
        email,
        googleId: payload.sub,
        avatar: payload.picture || null,
        now: nowSql(),
      });
      ensureSettingsRow(id);
    });
    tx();
    user = fullUser(id);
  }

  ensureSettingsRow(user.id);
  res.json({ success: true, data: authPayload(fullUser(user.id), req) });
});

// POST /api/v1/auth/refresh
export const refresh = asyncHandler(async (req, res) => {
  const tokenHash = hashToken(req.body.refreshToken);
  const session = db.prepare('SELECT * FROM user_sessions WHERE refresh_token_hash = ?').get(tokenHash);
  if (!session) throw new ApiError(401, 'Invalid refresh token');

  // Reuse of an already-rotated token means the token leaked: kill every session for that user.
  if (session.revoked_at) {
    db.prepare('UPDATE user_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').run(
      nowSql(),
      session.user_id
    );
    throw new ApiError(401, 'Refresh token was already used — all sessions have been revoked', {
      code: 'TOKEN_REUSE_DETECTED',
    });
  }
  if (isPast(session.expires_at)) throw new ApiError(401, 'Refresh token has expired');

  const user = fullUser(session.user_id);
  assertUsable(user);

  // Rotate: the presented token is retired and a new session row replaces it.
  const rotated = withTransaction(() => {
    db.prepare('UPDATE user_sessions SET revoked_at = ? WHERE id = ?').run(nowSql(), session.id);
    return issueSession(user, req);
  })();

  res.json({ success: true, data: { ...rotated, user: serializeUserProfile(fullUser(user.id)) } });
});

// POST /api/v1/auth/logout
export const logout = asyncHandler(async (req, res) => {
  const { refreshToken } = req.body || {};
  if (refreshToken) {
    db.prepare('UPDATE user_sessions SET revoked_at = ? WHERE refresh_token_hash = ? AND revoked_at IS NULL').run(
      nowSql(),
      hashToken(refreshToken)
    );
  } else if (req.user) {
    db.prepare('UPDATE user_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').run(
      nowSql(),
      req.user.id
    );
  }
  res.json({ success: true, data: { loggedOut: true } });
});

// Creates a single-use code. Any previous unconsumed code for the same purpose is invalidated, so
// a user cannot hold several valid codes at once.
function issueOtp(userId, purpose) {
  const code = generateOtpCode();
  const tx = withTransaction(() => {
    db.prepare('UPDATE otp_codes SET consumed_at = ? WHERE user_id = ? AND purpose = ? AND consumed_at IS NULL').run(
      nowSql(),
      userId,
      purpose
    );
    db.prepare(
      'INSERT INTO otp_codes (id, user_id, purpose, code_hash, expires_at, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(newId('OTP'), userId, purpose, hashToken(code), sqlMinutesFromNow(env.otpTtlMinutes), nowSql());
  });
  tx();

  // No email/SMS provider is configured yet, so the code goes to the console.
  console.log(`[otp] ${purpose} code for user ${userId}: ${code}`);
  return code;
}

function consumeOtp(userId, purpose, code) {
  const row = db
    .prepare(
      `SELECT * FROM otp_codes
        WHERE user_id = ? AND purpose = ? AND consumed_at IS NULL
        ORDER BY created_at DESC LIMIT 1`
    )
    .get(userId, purpose);

  if (!row) throw new ApiError(400, 'No verification code was requested — request a new one');
  if (isPast(row.expires_at)) throw new ApiError(400, 'This code has expired — request a new one');
  if (row.attempts >= OTP_MAX_ATTEMPTS) throw new ApiError(429, 'Too many incorrect attempts — request a new code');

  if (row.code_hash !== hashToken(code)) {
    db.prepare('UPDATE otp_codes SET attempts = attempts + 1 WHERE id = ?').run(row.id);
    throw new ApiError(400, 'Incorrect verification code');
  }

  db.prepare('UPDATE otp_codes SET consumed_at = ? WHERE id = ?').run(nowSql(), row.id);
}

// POST /api/v1/auth/forgot-password
export const forgotPassword = asyncHandler(async (req, res) => {
  const user = db.prepare('SELECT id, deleted_at FROM users WHERE lower(email) = ?').get(req.body.email);

  // Always the same response: whether an email is registered is not something to leak.
  const data = { sent: true };
  if (user && !user.deleted_at) {
    const code = issueOtp(user.id, 'password_reset');
    if (env.exposeOtpInResponse) data.devCode = code;
  }
  res.json({ success: true, data });
});

// POST /api/v1/auth/reset-password
export const resetPassword = asyncHandler(async (req, res) => {
  const { email, code, newPassword } = req.body;
  const user = db.prepare('SELECT * FROM users WHERE lower(email) = ?').get(email);
  if (!user || user.deleted_at) throw new ApiError(400, 'Incorrect verification code');

  consumeOtp(user.id, 'password_reset', code);

  const tx = withTransaction(() => {
    db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').run(
      bcrypt.hashSync(newPassword, BCRYPT_ROUNDS),
      nowSql(),
      user.id
    );
    // A password reset invalidates every existing session — that is the point of the reset.
    db.prepare('UPDATE user_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').run(
      nowSql(),
      user.id
    );
  });
  tx();

  res.json({ success: true, data: { reset: true } });
});

// POST /api/v1/auth/request-email-verification
export const requestEmailVerification = asyncHandler(async (req, res) => {
  if (req.user.email_verified) throw new ApiError(400, 'This email is already verified');
  const code = issueOtp(req.user.id, 'email_verify');
  const data = { sent: true };
  if (env.exposeOtpInResponse) data.devCode = code;
  res.json({ success: true, data });
});

// POST /api/v1/auth/verify-email
export const verifyEmail = asyncHandler(async (req, res) => {
  consumeOtp(req.user.id, 'email_verify', req.body.code);
  db.prepare('UPDATE users SET email_verified = 1, updated_at = ? WHERE id = ?').run(nowSql(), req.user.id);
  res.json({ success: true, data: serializeUserProfile(fullUser(req.user.id)) });
});

// GET /api/v1/auth/me
export const me = asyncHandler(async (req, res) => {
  ensureSettingsRow(req.user.id);
  const settings = db.prepare('SELECT * FROM user_settings WHERE user_id = ?').get(req.user.id);
  res.json({
    success: true,
    data: {
      user: serializeUserProfile(fullUser(req.user.id)),
      settings: {
        pushMatches: Boolean(settings.push_matches),
        pushComments: Boolean(settings.push_comments),
        pushClaims: Boolean(settings.push_claims),
        emailDigest: Boolean(settings.email_digest),
        searchRadiusKm: settings.search_radius_km,
        language: settings.language,
      },
      unreadNotifications: unreadCount(req.user.id),
    },
  });
});
