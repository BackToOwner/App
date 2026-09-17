import { verifyToken } from '../utils/jwt.js';
import { ApiError } from '../utils/ApiError.js';
import { db } from '../db/index.js';

const USER_COLUMNS = `id, name, first_name, last_name, email, phone, role, avatar,
  items_reported, items_found, items_returned, trust_score, status,
  email_verified, phone_verified, id_verified, joined_at, last_login_at, deleted_at`;

function bearerToken(req) {
  const header = req.headers.authorization || '';
  return header.startsWith('Bearer ') ? header.slice(7).trim() : null;
}

function loadUser(token) {
  const payload = verifyToken(token);
  const user = db.prepare(`SELECT ${USER_COLUMNS} FROM users WHERE id = ?`).get(payload.sub);
  if (!user || user.deleted_at) throw new ApiError(401, 'Account no longer exists');

  // A suspended or banned account holds a structurally valid token, so this is 403 (identity
  // known, access refused) rather than 401 — the app shows a different screen for each.
  if (user.status === 'banned') {
    throw new ApiError(403, 'This account has been banned', { code: 'ACCOUNT_BANNED' });
  }
  if (user.status === 'suspended') {
    throw new ApiError(403, 'This account is suspended', { code: 'ACCOUNT_SUSPENDED' });
  }
  return user;
}

export function requireAuth(req, res, next) {
  try {
    const token = bearerToken(req);
    if (!token) throw new ApiError(401, 'Missing or invalid Authorization header');
    req.user = loadUser(token);
    next();
  } catch (err) {
    if (err instanceof ApiError) return next(err);
    if (err?.name === 'TokenExpiredError') {
      // The app watches for this code to trigger a silent refresh rather than a sign-out.
      return next(new ApiError(401, 'Access token expired', { code: 'TOKEN_EXPIRED' }));
    }
    next(new ApiError(401, 'Invalid or expired token'));
  }
}

// For endpoints that are public but richer when signed in (feed, report detail): never throws.
export function optionalAuth(req, res, next) {
  const token = bearerToken(req);
  if (!token) return next();
  try {
    req.user = loadUser(token);
  } catch {
    // An expired or rejected token degrades to anonymous rather than failing the request.
  }
  next();
}
