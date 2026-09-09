import crypto from 'node:crypto';

// Refresh tokens and OTP codes are stored hashed: a database leak must not hand out sessions.
export function generateRefreshToken() {
  return crypto.randomBytes(48).toString('base64url');
}

export function hashToken(token) {
  return crypto.createHash('sha256').update(String(token)).digest('hex');
}

export function generateOtpCode() {
  return String(crypto.randomInt(100000, 1000000));
}
