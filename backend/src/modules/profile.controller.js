import bcrypt from 'bcryptjs';
import { db, withTransaction } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { nowSql } from '../utils/time.js';
import { hashToken } from '../utils/tokens.js';
import { q } from '../middleware/validate.js';
import { serializeUserProfile, serializeReport } from '../serializers/index.js';
import { BCRYPT_ROUNDS, ensureSettingsRow } from './auth.controller.js';

const fullUser = (id) => db.prepare('SELECT * FROM users WHERE id = ?').get(id);

function serializeSettings(s) {
  return {
    pushMatches: Boolean(s.push_matches),
    pushComments: Boolean(s.push_comments),
    pushClaims: Boolean(s.push_claims),
    emailDigest: Boolean(s.email_digest),
    searchRadiusKm: s.search_radius_km,
    language: s.language,
  };
}

// GET /api/v1/me
export const getProfile = asyncHandler(async (req, res) => {
  res.json({ success: true, data: serializeUserProfile(fullUser(req.user.id)) });
});

// PATCH /api/v1/me   — backs edit_profile_screen.dart
export const updateProfile = asyncHandler(async (req, res) => {
  const current = fullUser(req.user.id);
  const b = req.body;

  if (b.email && b.email !== current.email) {
    const taken = db
      .prepare('SELECT id FROM users WHERE lower(email) = ? AND id <> ? AND deleted_at IS NULL')
      .get(b.email, current.id);
    if (taken) throw new ApiError(409, 'That email address is already in use');
  }

  const firstName = b.firstName ?? current.first_name;
  const lastName = b.lastName ?? current.last_name;

  db.prepare(
    `UPDATE users
        SET first_name = @firstName,
            last_name  = @lastName,
            name       = @name,
            email      = @email,
            phone      = @phone,
            -- changing the email un-verifies it: the old verification proved a different address
            email_verified = CASE WHEN @email <> @currentEmail THEN 0 ELSE email_verified END,
            updated_at = @now
      WHERE id = @id`
  ).run({
    id: current.id,
    firstName,
    lastName,
    // `name` is kept in sync so the column stays usable as a single display name.
    name: [firstName, lastName].filter(Boolean).join(' ').trim() || current.name,
    email: b.email ?? current.email,
    currentEmail: current.email,
    phone: b.phone ?? current.phone,
    now: nowSql(),
  });

  res.json({ success: true, data: serializeUserProfile(fullUser(current.id)) });
});

// POST /api/v1/me/avatar   (multipart/form-data, field "image")
export const uploadAvatar = asyncHandler(async (req, res) => {
  if (!req.file) throw new ApiError(400, 'No image uploaded');
  db.prepare('UPDATE users SET avatar = ?, updated_at = ? WHERE id = ?').run(
    `/uploads/${req.file.filename}`,
    nowSql(),
    req.user.id
  );
  res.status(201).json({ success: true, data: serializeUserProfile(fullUser(req.user.id)) });
});

// PATCH /api/v1/me/password   — backs privacy_security_screen.dart
export const changePassword = asyncHandler(async (req, res) => {
  const user = fullUser(req.user.id);
  if (!user.password_hash) {
    throw new ApiError(400, 'This account signs in with Google and has no password set');
  }
  if (!bcrypt.compareSync(req.body.currentPassword, user.password_hash)) {
    throw new ApiError(400, 'Current password is incorrect');
  }

  // The app may send its refresh token so this device stays signed in.
  const keepHash = req.body.refreshToken ? hashToken(req.body.refreshToken) : null;

  const tx = withTransaction(() => {
    db.prepare('UPDATE users SET password_hash = ?, updated_at = ? WHERE id = ?').run(
      bcrypt.hashSync(req.body.newPassword, BCRYPT_ROUNDS),
      nowSql(),
      user.id
    );
    // Every *other* session is revoked: a password change is how a user evicts someone else.
    // The caller keeps working — they just proved they know the old password.
    db.prepare(
      `UPDATE user_sessions SET revoked_at = ?
        WHERE user_id = ? AND revoked_at IS NULL ${keepHash ? 'AND refresh_token_hash <> ?' : ''}`
    ).run(...[nowSql(), user.id, ...(keepHash ? [keepHash] : [])]);
  });
  tx();

  res.json({ success: true, data: { changed: true } });
});

// GET /api/v1/me/settings
export const getSettings = asyncHandler(async (req, res) => {
  ensureSettingsRow(req.user.id);
  const s = db.prepare('SELECT * FROM user_settings WHERE user_id = ?').get(req.user.id);
  res.json({ success: true, data: serializeSettings(s) });
});

// PATCH /api/v1/me/settings
export const updateSettings = asyncHandler(async (req, res) => {
  ensureSettingsRow(req.user.id);
  const s = db.prepare('SELECT * FROM user_settings WHERE user_id = ?').get(req.user.id);
  const b = req.body;
  const bit = (value, fallback) => (value == null ? fallback : value ? 1 : 0);

  db.prepare(
    `UPDATE user_settings
        SET push_matches = @pushMatches, push_comments = @pushComments, push_claims = @pushClaims,
            email_digest = @emailDigest, search_radius_km = @searchRadiusKm,
            language = @language, updated_at = @now
      WHERE user_id = @userId`
  ).run({
    userId: req.user.id,
    pushMatches: bit(b.pushMatches, s.push_matches),
    pushComments: bit(b.pushComments, s.push_comments),
    pushClaims: bit(b.pushClaims, s.push_claims),
    emailDigest: bit(b.emailDigest, s.email_digest),
    searchRadiusKm: b.searchRadiusKm ?? s.search_radius_km,
    language: b.language ?? s.language,
    now: nowSql(),
  });

  res.json({
    success: true,
    data: serializeSettings(db.prepare('SELECT * FROM user_settings WHERE user_id = ?').get(req.user.id)),
  });
});

// GET /api/v1/me/reports   — backs my_reports_screen.dart
export const myReports = asyncHandler(async (req, res) => {
  const { page, pageSize } = q(req);
  const offset = (page - 1) * pageSize;

  const total = db
    .prepare('SELECT COUNT(*) AS count FROM reports WHERE owner_user_id = ? AND deleted_at IS NULL')
    .get(req.user.id).count;
  const rows = db
    .prepare(
      `SELECT * FROM reports
        WHERE owner_user_id = @userId AND deleted_at IS NULL
        ORDER BY created_at DESC LIMIT @limit OFFSET @offset`
    )
    .all({ userId: req.user.id, limit: pageSize, offset });

  res.json({
    success: true,
    data: rows.map((r) => serializeReport(r, req.user.id)),
    pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) || 1 },
  });
});

// GET /api/v1/me/saved
export const savedReports = asyncHandler(async (req, res) => {
  const { page, pageSize } = q(req);
  const offset = (page - 1) * pageSize;

  const total = db
    .prepare(
      `SELECT COUNT(*) AS count FROM saved_reports s
         JOIN reports r ON r.id = s.report_id AND r.deleted_at IS NULL
        WHERE s.user_id = ?`
    )
    .get(req.user.id).count;
  const rows = db
    .prepare(
      `SELECT r.* FROM saved_reports s
         JOIN reports r ON r.id = s.report_id AND r.deleted_at IS NULL
        WHERE s.user_id = @userId
        ORDER BY s.created_at DESC LIMIT @limit OFFSET @offset`
    )
    .all({ userId: req.user.id, limit: pageSize, offset });

  res.json({
    success: true,
    data: rows.map((r) => serializeReport(r, req.user.id)),
    pagination: { page, pageSize, total, totalPages: Math.ceil(total / pageSize) || 1 },
  });
});

// DELETE /api/v1/me   — soft delete, so the user's reports and comments survive
export const deleteAccount = asyncHandler(async (req, res) => {
  const tx = withTransaction(() => {
    db.prepare(
      `UPDATE users
          SET deleted_at = @now, status = 'suspended', email = NULL, phone = NULL,
              google_id = NULL, password_hash = NULL, id_verification_no = NULL, updated_at = @now
        WHERE id = @id`
    ).run({ id: req.user.id, now: nowSql() });
    db.prepare('UPDATE user_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL').run(
      nowSql(),
      req.user.id
    );
    db.prepare('DELETE FROM user_devices WHERE user_id = ?').run(req.user.id);
  });
  tx();

  res.json({ success: true, data: { deleted: true } });
});
