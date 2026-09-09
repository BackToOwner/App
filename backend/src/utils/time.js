// The schema stores timestamps in SQLite's datetime('now') format: 'YYYY-MM-DD HH:MM:SS' in UTC.
// Application code writes the same shape so ORDER BY and BETWEEN keep working, and so a future
// Postgres port is a straight cast to timestamptz.

export function nowSql(date = new Date()) {
  return date.toISOString().slice(0, 19).replace('T', ' ');
}

export function sqlDaysFromNow(days) {
  return nowSql(new Date(Date.now() + days * 24 * 60 * 60 * 1000));
}

export function sqlMinutesFromNow(minutes) {
  return nowSql(new Date(Date.now() + minutes * 60 * 1000));
}

// Accepts either 'YYYY-MM-DD HH:MM:SS' (SQLite, UTC) or a full ISO string.
export function parseSqlDate(value) {
  if (!value) return null;
  const normalized = /\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}/.test(value) ? `${value.replace(' ', 'T')}Z` : value;
  const date = new Date(normalized);
  return Number.isNaN(date.getTime()) ? null : date;
}

export function isPast(sqlDate) {
  const date = parseSqlDate(sqlDate);
  return date == null || date.getTime() < Date.now();
}

// The app renders relative times ("2h ago") itself, so it receives ISO-8601 and formats locally.
export function toIso(sqlDate) {
  const date = parseSqlDate(sqlDate);
  return date ? date.toISOString() : null;
}
