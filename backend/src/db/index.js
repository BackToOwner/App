import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { env } from '../config/env.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const resolvedDbPath = path.isAbsolute(env.dbPath) ? env.dbPath : path.resolve(process.cwd(), env.dbPath);

fs.mkdirSync(path.dirname(resolvedDbPath), { recursive: true });

export const db = new DatabaseSync(resolvedDbPath);
export const dbPath = resolvedDbPath;

db.exec('PRAGMA journal_mode = WAL');
db.exec('PRAGMA foreign_keys = ON');

// This file is shared with the admin dashboard backend, so two processes write to it. WAL allows
// concurrent readers alongside one writer, but two simultaneous writes still collide — without a
// busy timeout the loser fails instantly with SQLITE_BUSY. Waiting is the correct behaviour here:
// the conflicting write is milliseconds long.
db.exec(`PRAGMA busy_timeout = ${env.busyTimeoutMs}`);

db.exec(fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf-8'));

/**
 * Adds the columns the app needs to tables the admin backend also owns.
 *
 * These cannot live in schema.sql: that file re-runs on every boot and ALTER TABLE is not
 * idempotent. Whichever service creates `users`/`reports` first wins, and this fills in the gap
 * afterwards. SQLite forbids non-constant defaults in ALTER TABLE ADD COLUMN, so anything needing
 * a timestamp is added nullable and back-filled.
 *
 * Every column here is nullable or has a constant default, which is why the admin dashboard is
 * unaffected: its INSERTs name their columns explicitly and its SELECT * simply ignores the extras.
 */
const ADDED_COLUMNS = {
  users: [
    ['first_name', 'TEXT'],
    ['last_name', 'TEXT'],
    ['password_hash', 'TEXT'],
    ['google_id', 'TEXT'],
    ['id_verification_no', 'TEXT'],
    ['id_verified', 'INTEGER NOT NULL DEFAULT 0'],
    ['email_verified', 'INTEGER NOT NULL DEFAULT 0'],
    ['phone_verified', 'INTEGER NOT NULL DEFAULT 0'],
    ['items_returned', 'INTEGER NOT NULL DEFAULT 0'],
    ['last_login_at', 'TEXT'],
    ['updated_at', 'TEXT'],
    ['deleted_at', 'TEXT'],
  ],
  categories: [
    ['emoji', "TEXT NOT NULL DEFAULT '📦'"],
    ['bg_hex', "TEXT NOT NULL DEFAULT 'F1F5F9'"],
    ['sort_order', 'INTEGER NOT NULL DEFAULT 100'],
  ],
  reports: [
    ['owner_user_id', 'TEXT REFERENCES users(id) ON DELETE SET NULL'],
    ['source', "TEXT NOT NULL DEFAULT 'admin'"],
    ['emoji', 'TEXT'],
    ['reward_currency', "TEXT NOT NULL DEFAULT 'LKR'"],
    ['contact_visibility', "TEXT NOT NULL DEFAULT 'on_claim_accepted'"],
    ['view_count', 'INTEGER NOT NULL DEFAULT 0'],
    ['comment_count', 'INTEGER NOT NULL DEFAULT 0'],
    ['claim_count', 'INTEGER NOT NULL DEFAULT 0'],
    ['resolved_at', 'TEXT'],
    ['deleted_at', 'TEXT'],
  ],
  matches: [
    ['source', "TEXT NOT NULL DEFAULT 'admin'"],
    ['score_breakdown', "TEXT NOT NULL DEFAULT '{}'"],
    ['dismissed_by', 'TEXT'],
  ],
};

function ensureColumns() {
  for (const [table, columns] of Object.entries(ADDED_COLUMNS)) {
    const existing = new Set(db.prepare(`PRAGMA table_info(${table})`).all().map((c) => c.name));
    for (const [name, definition] of columns) {
      if (existing.has(name)) continue;
      db.exec(`ALTER TABLE ${table} ADD COLUMN ${name} ${definition}`);
    }
  }

  // Back-fill the timestamp that could not carry a default, and split any name the admin
  // dashboard created into the first/last pair the app's Edit Profile screen edits.
  db.exec(`UPDATE users SET updated_at = COALESCE(updated_at, joined_at) WHERE updated_at IS NULL`);
  db.exec(`
    UPDATE users
       SET first_name = CASE WHEN instr(name, ' ') > 0 THEN substr(name, 1, instr(name, ' ') - 1) ELSE name END,
           last_name  = CASE WHEN instr(name, ' ') > 0 THEN substr(name, instr(name, ' ') + 1) ELSE '' END
     WHERE first_name IS NULL`);
  db.exec(`UPDATE reports SET resolved_at = updated_at WHERE status = 'returned' AND resolved_at IS NULL`);
}

function ensureIndexes() {
  const statements = [
    `CREATE UNIQUE INDEX IF NOT EXISTS idx_users_google  ON users(google_id) WHERE google_id IS NOT NULL`,
    `CREATE UNIQUE INDEX IF NOT EXISTS idx_users_email_l ON users(lower(email)) WHERE email IS NOT NULL`,
    `CREATE INDEX        IF NOT EXISTS idx_users_phone   ON users(phone)`,
    `CREATE INDEX        IF NOT EXISTS idx_users_status  ON users(status)`,
    `CREATE INDEX        IF NOT EXISTS idx_reports_owner   ON reports(owner_user_id)`,
    `CREATE INDEX        IF NOT EXISTS idx_reports_created ON reports(created_at DESC)`,
    `CREATE INDEX        IF NOT EXISTS idx_reports_geo     ON reports(lat, lng)`,
    `CREATE INDEX        IF NOT EXISTS idx_reports_feed    ON reports(deleted_at, type, status, created_at DESC)`,
    `CREATE UNIQUE INDEX IF NOT EXISTS idx_matches_pair    ON matches(lost_item_id, found_item_id)`,
    `CREATE INDEX        IF NOT EXISTS idx_matches_status  ON matches(status)`,
  ];
  for (const sql of statements) db.exec(sql);
}

/**
 * Full-text search over reports, kept in sync by triggers.
 *
 * The triggers live in the database, not in this process, so reports the admin dashboard creates
 * are indexed too. The one-time back-fill uses FTS5's 'rebuild' command rather than a plain
 * INSERT..SELECT, which would duplicate every row on each boot.
 */
function ensureFts() {
  db.exec(`
    CREATE VIRTUAL TABLE IF NOT EXISTS reports_fts USING fts5(
      title, description, location, content='reports', content_rowid='rowid'
    );
    CREATE TRIGGER IF NOT EXISTS reports_fts_ai AFTER INSERT ON reports BEGIN
      INSERT INTO reports_fts(rowid, title, description, location)
      VALUES (new.rowid, new.title, new.description, new.location);
    END;
    CREATE TRIGGER IF NOT EXISTS reports_fts_ad AFTER DELETE ON reports BEGIN
      INSERT INTO reports_fts(reports_fts, rowid, title, description, location)
      VALUES ('delete', old.rowid, old.title, old.description, old.location);
    END;
    CREATE TRIGGER IF NOT EXISTS reports_fts_au AFTER UPDATE ON reports BEGIN
      INSERT INTO reports_fts(reports_fts, rowid, title, description, location)
      VALUES ('delete', old.rowid, old.title, old.description, old.location);
      INSERT INTO reports_fts(rowid, title, description, location)
      VALUES (new.rowid, new.title, new.description, new.location);
    END;
  `);

  const indexed = db.prepare('SELECT COUNT(*) AS c FROM reports_fts').get().c;
  const reports = db.prepare('SELECT COUNT(*) AS c FROM reports').get().c;
  if (indexed === 0 && reports > 0) {
    db.exec("INSERT INTO reports_fts(reports_fts) VALUES('rebuild')");
  }
}

ensureColumns();
ensureIndexes();
ensureFts();

// node:sqlite's DatabaseSync has no built-in `.transaction()` helper (unlike better-sqlite3) -
// this is a tiny drop-in replacement used the same way:
//   const run = withTransaction(() => { ...statements... });
//   run();
export function withTransaction(fn) {
  return (...args) => {
    db.exec('BEGIN');
    try {
      const result = fn(...args);
      db.exec('COMMIT');
      return result;
    } catch (err) {
      db.exec('ROLLBACK');
      throw err;
    }
  };
}

export default db;
