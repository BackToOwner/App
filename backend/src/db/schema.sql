-- BackToOwner — mobile app backend schema
--
-- IMPORTANT: this runs against the SAME SQLite file as the admin dashboard backend in
-- ../../../Backend. Both services boot against it, so everything here must be idempotent and
-- must not conflict with that project's schema.sql.
--
-- Three rules follow from sharing the file:
--
--   1. Shared tables (users, categories, reports, matches) are declared here EXACTLY as the admin
--      backend declares them. Whichever service boots first creates them; the other's
--      CREATE TABLE IF NOT EXISTS is then a no-op. The extra columns the app needs are added
--      afterwards by ensureColumns() in index.js, because ALTER TABLE cannot live in a file that
--      re-runs on every boot.
--
--   2. `notifications` belongs to the admin backend (geo-broadcasts). The app's per-user inbox is
--      a separate table, `user_notifications` — same name would have silently collided.
--
--   3. `matches.status` keeps the admin backend's CHECK values, so match suggestions flow into
--      the dashboard's existing approval queue rather than a parallel one.

-- ─────────────────────────────────────────────────────────────────────────
-- Shared tables — declarations must stay byte-compatible with ../Backend/src/db/schema.sql
-- ─────────────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  label TEXT NOT NULL,
  icon TEXT DEFAULT 'Package',
  color TEXT DEFAULT '#00D2B4',
  description TEXT DEFAULT '',
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT UNIQUE,
  phone TEXT,
  role TEXT NOT NULL DEFAULT 'Verified Citizen',
  avatar TEXT,
  items_reported INTEGER NOT NULL DEFAULT 0,
  items_found INTEGER NOT NULL DEFAULT 0,
  trust_score REAL NOT NULL DEFAULT 95,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'banned')),
  joined_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS reports (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('lost', 'found')),
  category TEXT NOT NULL DEFAULT 'other',
  status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'in_review', 'matched', 'returned', 'closed')),
  location TEXT DEFAULT 'Unknown Location',
  lat REAL,
  lng REAL,
  distance_km REAL DEFAULT 0,
  occurred_at TEXT,
  reward REAL,
  matched INTEGER NOT NULL DEFAULT 0,
  matched_with_id TEXT,
  match_score REAL,
  reporter_name TEXT,
  reporter_contact TEXT,
  finder_name TEXT,
  finder_contact TEXT,
  description TEXT DEFAULT '',
  images TEXT NOT NULL DEFAULT '[]',
  verification_details TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (matched_with_id) REFERENCES reports(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_reports_type ON reports(type);
CREATE INDEX IF NOT EXISTS idx_reports_status ON reports(status);
CREATE INDEX IF NOT EXISTS idx_reports_category ON reports(category);

CREATE TABLE IF NOT EXISTS matches (
  id TEXT PRIMARY KEY,
  lost_item_id TEXT NOT NULL,
  found_item_id TEXT NOT NULL,
  match_score REAL NOT NULL DEFAULT 80,
  confidence_label TEXT NOT NULL DEFAULT 'Moderate Confidence',
  match_factors TEXT NOT NULL DEFAULT '[]',
  status TEXT NOT NULL DEFAULT 'pending_admin_approval' CHECK (status IN ('pending_admin_approval', 'approved', 'rejected')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  resolved_at TEXT,
  FOREIGN KEY (lost_item_id) REFERENCES reports(id) ON DELETE CASCADE,
  FOREIGN KEY (found_item_id) REFERENCES reports(id) ON DELETE CASCADE
);

-- The admin backend owns `notifications` (geo-broadcasts). Declared here only so this service can
-- boot first against an empty file without the admin's table going missing.
CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  title TEXT NOT NULL,
  message TEXT NOT NULL DEFAULT '',
  type TEXT NOT NULL DEFAULT 'info',
  radius_km REAL,
  priority TEXT NOT NULL DEFAULT 'normal',
  read INTEGER NOT NULL DEFAULT 0,
  meta TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS admins (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'admin',
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Indexes over the columns ensureColumns() adds. Created after that runs, from index.js.

-- ─────────────────────────────────────────────────────────────────────────
-- App-only tables — none of these exist in the admin backend
-- ─────────────────────────────────────────────────────────────────────────

-- Refresh-token sessions. Access JWTs stay short-lived; these carry the long session and can be
-- revoked server-side when a phone is lost.
CREATE TABLE IF NOT EXISTS user_sessions (
  id                 TEXT PRIMARY KEY,
  user_id            TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  refresh_token_hash TEXT NOT NULL UNIQUE,                  -- sha256, never the token itself
  device_id          TEXT,
  platform           TEXT,
  user_agent         TEXT,
  ip                 TEXT,
  expires_at         TEXT NOT NULL,
  revoked_at         TEXT,
  created_at         TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions(user_id, revoked_at);

CREATE TABLE IF NOT EXISTS user_devices (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fcm_token    TEXT NOT NULL UNIQUE,
  platform     TEXT NOT NULL,
  app_version  TEXT,
  last_seen_at TEXT NOT NULL DEFAULT (datetime('now')),
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_devices_user ON user_devices(user_id);

CREATE TABLE IF NOT EXISTS user_settings (
  user_id          TEXT PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  push_matches     INTEGER NOT NULL DEFAULT 1,
  push_comments    INTEGER NOT NULL DEFAULT 1,
  push_claims      INTEGER NOT NULL DEFAULT 1,
  email_digest     INTEGER NOT NULL DEFAULT 0,
  search_radius_km REAL    NOT NULL DEFAULT 25,
  language         TEXT    NOT NULL DEFAULT 'en',
  updated_at       TEXT    NOT NULL DEFAULT (datetime('now'))
);

-- Email verification, password reset and phone OTP share one table, split by `purpose`.
CREATE TABLE IF NOT EXISTS otp_codes (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose     TEXT NOT NULL CHECK (purpose IN ('email_verify','password_reset','phone_verify')),
  code_hash   TEXT NOT NULL,                                -- hashed, never the plain code
  expires_at  TEXT NOT NULL,
  consumed_at TEXT,
  attempts    INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_otp_lookup ON otp_codes(user_id, purpose, consumed_at);

-- Server-driven help content, so help_support_screen.dart stops shipping hard-coded text.
CREATE TABLE IF NOT EXISTS faqs (
  id         TEXT PRIMARY KEY,
  question   TEXT NOT NULL,
  answer     TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 100,
  active     INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Hotline number, support email, social links, minimum supported app version.
CREATE TABLE IF NOT EXISTS app_config (
  key        TEXT PRIMARY KEY,
  value      TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- Source of truth for media. reports.images (a JSON array) is kept in sync on every write, so the
-- admin dashboard's existing serializer keeps rendering images with no change on its side.
CREATE TABLE IF NOT EXISTS report_images (
  id          TEXT PRIMARY KEY,
  report_id   TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  url         TEXT NOT NULL,
  storage_key TEXT,
  width       INTEGER,
  height      INTEGER,
  bytes       INTEGER,
  is_primary  INTEGER NOT NULL DEFAULT 0,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  uploaded_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_report_images ON report_images(report_id, sort_order);

CREATE TABLE IF NOT EXISTS report_status_history (
  id              TEXT PRIMARY KEY,
  report_id       TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  from_status     TEXT,
  to_status       TEXT NOT NULL,
  changed_by_type TEXT NOT NULL CHECK (changed_by_type IN ('user','admin','system')),
  changed_by_id   TEXT,
  note            TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_status_history ON report_status_history(report_id, created_at);

CREATE TABLE IF NOT EXISTS report_comments (
  id         TEXT PRIMARY KEY,
  report_id  TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  user_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  parent_id  TEXT REFERENCES report_comments(id) ON DELETE CASCADE,   -- one level of replies
  body       TEXT NOT NULL,
  is_hidden  INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_comments_report ON report_comments(report_id, created_at);

-- Backs "your report has been viewed 24 times this week".
CREATE TABLE IF NOT EXISTS report_views (
  id        TEXT PRIMARY KEY,
  report_id TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  user_id   TEXT REFERENCES users(id) ON DELETE SET NULL,   -- NULL = anonymous
  viewed_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_views_report ON report_views(report_id, viewed_at);
CREATE INDEX IF NOT EXISTS idx_views_dedup  ON report_views(report_id, user_id, viewed_at);

CREATE TABLE IF NOT EXISTS saved_reports (
  user_id    TEXT NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  report_id  TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, report_id)
);

-- The claim / handover flow behind "Item Marked as Returned".
CREATE TABLE IF NOT EXISTS claims (
  id                    TEXT PRIMARY KEY,
  report_id             TEXT NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
  claimant_user_id      TEXT NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  message               TEXT DEFAULT '',
  proof                 TEXT NOT NULL DEFAULT '{}',          -- answers to the owner's questions
  status                TEXT NOT NULL DEFAULT 'pending'
                          CHECK (status IN ('pending','accepted','rejected','withdrawn','completed')),
  meeting_place         TEXT,
  meeting_at            TEXT,
  owner_confirmed_at    TEXT,                                -- both sides must confirm the handover
  claimant_confirmed_at TEXT,
  decided_by_user_id    TEXT REFERENCES users(id) ON DELETE SET NULL,
  decided_at            TEXT,
  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at            TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX        IF NOT EXISTS idx_claims_report   ON claims(report_id, status);
CREATE INDEX        IF NOT EXISTS idx_claims_claimant ON claims(claimant_user_id, status);
-- One open claim per person per report; competing claims from other people are still allowed.
CREATE UNIQUE INDEX IF NOT EXISTS idx_claims_one_open
  ON claims(report_id, claimant_user_id) WHERE status IN ('pending','accepted');

-- The app's per-user inbox. Deliberately NOT called `notifications` — that name belongs to the
-- admin backend's broadcast table in this same file. The `type` values are exactly
-- notifications_screen.dart's enum plus 'claim', so the app's icon switch needs no remapping.
CREATE TABLE IF NOT EXISTS user_notifications (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type         TEXT NOT NULL CHECK (type IN ('match','comment','claim','returned','info','reminder')),
  title        TEXT NOT NULL,
  body         TEXT NOT NULL DEFAULT '',
  report_id    TEXT REFERENCES reports(id)         ON DELETE CASCADE,
  match_id     TEXT REFERENCES matches(id)         ON DELETE CASCADE,
  comment_id   TEXT REFERENCES report_comments(id) ON DELETE CASCADE,
  claim_id     TEXT REFERENCES claims(id)          ON DELETE CASCADE,
  data         TEXT NOT NULL DEFAULT '{}',                   -- deep-link payload for the app
  read_at      TEXT,
  push_sent_at TEXT,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_notif_inbox  ON user_notifications(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notif_unread ON user_notifications(user_id, read_at);

CREATE TABLE IF NOT EXISTS support_tickets (
  id         TEXT PRIMARY KEY,
  user_id    TEXT REFERENCES users(id) ON DELETE SET NULL,
  subject    TEXT NOT NULL,
  category   TEXT NOT NULL DEFAULT 'general',
  status     TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','pending','resolved','closed')),
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_tickets_user ON support_tickets(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS support_messages (
  id          TEXT PRIMARY KEY,
  ticket_id   TEXT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,
  sender_type TEXT NOT NULL CHECK (sender_type IN ('user','support')),
  sender_id   TEXT,
  body        TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_support_thread ON support_messages(ticket_id, created_at);
