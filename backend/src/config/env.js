import 'dotenv/config';

function bool(value, fallback) {
  if (value == null || value === '') return fallback;
  return ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
}

const nodeEnv = process.env.NODE_ENV || 'development';
const port = Number(process.env.PORT) || 5001;

export const env = {
  port,
  nodeEnv,

  // SHARED with the admin dashboard backend — this is that project's SQLite file, so reports
  // filed from the phone appear in the web dashboard and vice versa. The path is relative to this
  // backend's folder (App/backend), hence the climb out to the sibling Backend repo.
  dbPath: process.env.DB_PATH || '../../Backend/data/admin.sqlite',

  // Two processes write this file, so a write that collides waits instead of failing outright.
  busyTimeoutMs: Number(process.env.DB_BUSY_TIMEOUT_MS) || 5000,

  // Where uploaded images are written. Override in production to a mounted volume — the
  // repo-local default does not survive most container redeploys.
  uploadsDir: process.env.UPLOADS_DIR || './uploads',

  // Base URL the phone can reach this server on; used to build absolute image URLs.
  publicUrl: (process.env.PUBLIC_URL || `http://localhost:${port}`).replace(/\/$/, ''),

  jwtSecret: process.env.JWT_SECRET || 'dev_only_secret_change_me',
  accessTokenExpiresIn: process.env.ACCESS_TOKEN_EXPIRES_IN || '15m',
  refreshTokenDays: Number(process.env.REFRESH_TOKEN_DAYS) || 30,

  // The mobile client sends no Origin header, so this only affects browser callers.
  corsOrigin: (process.env.CORS_ORIGIN || '*')
    .split(',')
    .map((s) => s.trim())
    .filter(Boolean),

  // Google Sign-In: the OAuth client ID the Flutter app authenticates against.
  // Empty = /auth/google returns 503 rather than accepting unverified tokens.
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',

  // Feed defaults and the auto-matcher.
  defaultRadiusKm: Number(process.env.DEFAULT_RADIUS_KM) || 25,
  matchThreshold: Number(process.env.MATCH_THRESHOLD) || 55,
  matchWindowDays: Number(process.env.MATCH_WINDOW_DAYS) || 90,
  // How often to check whether an admin approved a match in the dashboard's process.
  matchSweepIntervalMs: Number(process.env.MATCH_SWEEP_INTERVAL_MS) || 30000,

  // OTP delivery is stubbed until an email/SMS provider is chosen; outside production the code
  // is logged and echoed in the response so the flow is testable end to end.
  otpTtlMinutes: Number(process.env.OTP_TTL_MINUTES) || 15,
  exposeOtpInResponse: bool(process.env.EXPOSE_OTP_IN_RESPONSE, nodeEnv !== 'production'),

  // Firebase Cloud Messaging server key. Empty = push is logged, not sent.
  fcmServerKey: process.env.FCM_SERVER_KEY || '',

  // Test-suite escape hatch. Deliberately ignored in production: rate limiting is a control,
  // not a preference, and must not be switchable by an env var on a live server.
  rateLimitDisabled: nodeEnv !== 'production' && bool(process.env.RATE_LIMIT_DISABLED, false),
};
