# BackToOwner — Mobile App Backend

Node.js + Express + SQLite REST API serving the Flutter app this folder lives inside.

This is a **monorepo**: the Flutter client is at the repository root, its backend is here in
`backend/`. They are one repo and one git history.

The backend is its own service, but it **shares its database** with the admin dashboard backend in
`../../Backend`. A report filed from the phone appears in the web dashboard, and an edit made in
the dashboard is visible in the app.

| | Admin dashboard | Mobile app |
|---|---|---|
| Backend | `BCI/Backend` | `BCI/App/backend` (here) |
| Client | `BCI/AdminDashBoard` (React) | `BCI/App` (Flutter) |
| Base path | `/api/*` | `/api/v1/*` |
| Default port | 5000 | 5001 |
| Database | **`Backend/data/admin.sqlite` — shared by both** | |

The two services run side by side against that one file. Nothing in `Backend/` was modified to
make this work: this backend adapts to that schema rather than the other way round (see
[Sharing one database](#sharing-one-database)).

## Stack
- Express 4
- **`node:sqlite`** — Node's built-in SQLite driver (file-based, no native modules to compile)
- JWT access tokens + rotating refresh tokens, `bcryptjs` password hashing
- `zod` request validation, `helmet`, `express-rate-limit`
- `multer` for image uploads, with magic-byte content verification

> Requires **Node.js 22.5+**. `node:sqlite` ships unflagged from Node 23.4+ / 24.x, which is what
> this was built and tested against.

## Setup

```bash
cd App/backend
npm install
copy .env.example .env      # (or `cp` on macOS/Linux) then edit values
npm run seed                 # categories, FAQs, app config, demo users and reports
npm run dev                  # starts on http://localhost:5001
```

`DB_PATH` defaults to `../../Backend/data/admin.sqlite`. That file must be reachable — set up the
admin backend first (or just let this one create it; either service can create the schema).
`schema.sql` runs on every boot and is idempotent, so restarting is safe.

The startup log prints which database file it opened. Check it if something looks unshared.

Demo accounts created by `npm run seed` — password `Test@12345`:
`ahmed.khalid@example.com`, `sara.fernando@example.com`

### Verify it works

```bash
npm run test:api             # 141 checks; uses a throwaway DB and uploads dir
```

The suite covers auth and session rotation, contact privacy, ownership rules, the claim handover,
auto-matching, uploads, and input validation. It never touches `data/app.sqlite` or `uploads/`.

### Images and the dashboard

Uploads are written to `backend/uploads/` and stored in the shared database as relative paths
(`/uploads/x.jpg`). The admin dashboard resolves those against **its own** uploads folder, so a
photo taken in the app shows as a broken image there by default. If you want them to render in
both, point this backend at the dashboard's folder:

```
UPLOADS_DIR=../../Backend/uploads
```

### Pointing the Flutter app at it

Set `PUBLIC_URL` to an address the **phone** can reach — `localhost` on a device means the device
itself, not your machine:

| Running on | `PUBLIC_URL` |
|---|---|
| Android emulator | `http://10.0.2.2:5001` |
| iOS simulator | `http://localhost:5001` |
| Physical device | `http://<your-machine-LAN-IP>:5001` |

This is what image URLs are built from, so getting it wrong shows broken images rather than an
obvious error. The server prints a reminder at startup if it is still set to localhost.

## Auth

```
Authorization: Bearer <access token>
```

`POST /api/v1/auth/login` returns a **15-minute access token** plus a **30-day refresh token**.
Refresh tokens are stored hashed in `user_sessions` and rotate on every use; presenting an
already-rotated token revokes the entire session family, because reuse means the token leaked.

An expired access token returns `401` with `details.code === "TOKEN_EXPIRED"` — the app should
treat that as a cue to refresh silently, not to sign the user out. A suspended or banned account
returns `403` with `ACCOUNT_SUSPENDED` / `ACCOUNT_BANNED`.

## API reference (`/api/v1`)

Every response uses `{ success, data }`, or `{ success: false, message, details }` on error.
List endpoints add `pagination: { page, pageSize, total, totalPages }`.

### Auth
| Method | Route | Notes |
|---|---|---|
| POST | `/auth/register` | email, password, firstName, lastName, phone, idVerificationNo |
| POST | `/auth/login` | email or phone + password |
| POST | `/auth/google` | verifies a Google ID token; 503 unless `GOOGLE_CLIENT_ID` is set |
| POST | `/auth/refresh` | rotates the refresh token |
| POST | `/auth/logout` | revokes this session (or all, with no body) |
| POST | `/auth/forgot-password` · `/auth/reset-password` | OTP flow; reset revokes all sessions |
| POST | `/auth/request-email-verification` · `/auth/verify-email` | OTP flow |
| GET | `/auth/me` | profile + settings + unread count, for app boot |

### Profile
| Method | Route | Flutter screen |
|---|---|---|
| GET · PATCH | `/me` | `profile_screen`, `edit_profile_screen` |
| POST | `/me/avatar` | `edit_profile_screen` (multipart, field `image`) |
| PATCH | `/me/password` | `privacy_security_screen` |
| GET · PATCH | `/me/settings` | notification preferences, search radius |
| GET | `/me/reports` | `my_reports_screen` |
| GET | `/me/saved` · `/me/claims` · `/me/matches` | |
| DELETE | `/me` | soft delete |

### Reports
| Method | Route | Notes |
|---|---|---|
| GET | `/reports` | `type`, `category`, `status`, `q`, `lat`/`lng`/`radiusKm`, `sort`, `page`, `pageSize` |
| GET | `/reports/:id` | readable signed out; adds `isMine`, `isSaved`, `myClaim` when signed in |
| POST | `/reports` | `report_item_modal` |
| PATCH · DELETE | `/reports/:id` | owner only; delete is a soft delete |
| POST | `/reports/:id/images` | multipart, field `images`, max 5 |
| DELETE | `/reports/:id/images/:imageId` | owner only |
| POST | `/reports/:id/view` | de-duplicated per user per 24h; the owner's own views don't count |
| PUT · DELETE | `/reports/:id/save` | bookmark toggle |

`status=active` is a shorthand for open + in_review + matched.

### Matches, comments, claims
| Method | Route |
|---|---|
| POST | `/matches/:id/dismiss` (approval is the dashboard's; the app can only dismiss) |
| GET · POST | `/reports/:id/comments` |
| DELETE | `/comments/:id` (author or report owner) |
| GET · POST | `/reports/:id/claims` (GET is owner-only) |
| POST | `/claims/:id/accept` · `/reject` · `/withdraw` · `/confirm-return` |

### Notifications, meta, support
| Method | Route |
|---|---|
| GET | `/notifications` · `/notifications/unread-count` |
| PATCH · POST · DELETE | `/notifications/:id/read` · `/notifications/read-all` · `/notifications/:id` |
| POST · DELETE | `/devices` (FCM token) |
| GET | `/categories` · `/faqs` · `/config` · `/stats/home` — all public |
| GET · POST | `/support/tickets`, `/support/tickets/:id`, `/support/tickets/:id/messages` |

## Four rules worth knowing before changing this code

**1. Contact details are gated.** A report's `reporter_contact` / `finder_contact` never appear in
a response unless the caller is the report owner or holds an `accepted`/`completed` claim. This is
enforced in `serializeReport()` via `canSeeContacts()` — not in controllers, so no endpoint can
forget it. When withheld, the `contacts` key is **absent** rather than null, so the app can tell
"not allowed to see" from "not provided"; `contactsVisible` states which case applies.

**2. Notifications have one entry point.** Everything that notifies a user goes through `notify()`
in `src/services/notify.service.js`. No controller inserts into `notifications` directly, so the
push fan-out and per-user settings filter stay in one place.

**3. A handover needs both parties.** `POST /claims/:id/confirm-return` only completes when *both*
the owner and the claimant have confirmed. A one-sided "done" is the obvious way to fake a return
and inflate a trust score, so the first confirmation just records itself and notifies the other
side.

**4. Matching is a suggestion, not a decision.** The matcher writes candidates into the dashboard's
approval queue and notifies nobody. Users hear about a match only after an admin approves it. See
[How matching works](#how-matching-works).

## Sharing one database

Both services open `Backend/data/admin.sqlite`. Three collisions had to be resolved, and they
explain most of what looks unusual in `src/db/`:

**Shared tables are declared identically.** `users`, `categories`, `reports` and `matches` appear
in both projects' `schema.sql`. This one repeats the admin backend's definitions byte-for-byte, so
whichever service boots first creates them and the other's `CREATE TABLE IF NOT EXISTS` is a no-op.

**Extra columns are added at runtime, not in schema.sql.** The app needs `users.password_hash`,
`reports.owner_user_id` and a dozen others. `ALTER TABLE` is not idempotent and `schema.sql` re-runs
every boot, so `ensureColumns()` in [src/db/index.js](src/db/index.js) reads `PRAGMA table_info`
and adds only what is missing. Every added column is nullable or has a constant default, which is
why the dashboard is unaffected — its INSERTs name their columns and its `SELECT *` ignores extras.

**`notifications` was already taken.** That table is the dashboard's geo-broadcast feed. The app's
per-user inbox is a separate table, `user_notifications`. Same name would have silently collided.

Two other consequences worth knowing:

- `PRAGMA busy_timeout` is set (default 5s). WAL allows concurrent readers with one writer, but two
  simultaneous *writes* still collide, and without a timeout the loser fails instantly with
  `SQLITE_BUSY`. Verified with 10 interleaved cross-service writes: no failures.
- The FTS5 search index is defined here but maintained by database triggers, so reports created in
  the dashboard are indexed too.

## How matching works

On every new report, the matcher scores it against reports of the opposite type from the last 90
days (a bounding-box pre-filter on `idx_reports_geo` keeps this to tens of comparisons):

| Signal | Weight | Rule |
|---|---:|---|
| Category | 30 | exact match = 30, `other` on either side = 10, else 0 |
| Text similarity | 25 | Jaccard token overlap on title + description, stop-words removed |
| Geo proximity | 25 | `25 × max(0, 1 − distance/radius)`, radius 25 km, haversine |
| Time window | 20 | found date ≥ lost date, decaying over 30 days |

Signals that can't be evaluated (no coordinates, no dates) score **0** rather than a neutral
midpoint — an unknown is not evidence of a match. A user's own lost report is never paired with
their own found report.

Pairs scoring ≥ `MATCH_THRESHOLD` (default 55) are written as `pending_admin_approval` — the exact
status the dashboard's match queue already filters on, so suggestions from the phone appear there
with no change on that side.

**Nobody is notified until an admin approves.** That approval happens in the dashboard's process,
which this project does not modify, so there is no callback to hook. Instead
[matchNotifier.service.js](src/services/matchNotifier.service.js) sweeps for matches that are
`approved` but whose owners have no match notification yet, and fills the gap. It runs on a timer
(`MATCH_SWEEP_INTERVAL_MS`, default 30s) and again whenever the app opens `/me/matches`, so a user
looking at the screen sees the result immediately.

The "not yet notified" test is a `NOT EXISTS` against `user_notifications` rather than a flag
column, which makes it idempotent — running it twice, or from both callers at once, cannot produce
a duplicate.

A user can `dismiss` a suggestion involving their own report ("that isn't mine"), which rejects it
in the shared queue too — the owner saying no is better evidence than a similarity score saying
yes. Users cannot approve; that stays with an admin.

## Project layout

```
src/
  config/       env.js (settings), paths.js (uploads dir)
  db/           index.js (connection), schema.sql (full schema), seed.js
  middleware/   auth guards, zod validate, rate limits, error handler
  modules/      controllers, zod schemas, upload handling, index.js (the router)
  serializers/  response shapes — contact privacy is enforced here
  services/     notify, push, matching, reports (image sync, status history, counters)
  utils/        ApiError, asyncHandler, jwt, tokens, time, geo, id, parseJson
  app.js / server.js
tests/
  api.test.js   end-to-end suite (npm run test:api)
```

### Schema changes
Because the file is shared, where a change goes depends on what it touches:

- **A new app-only table** → add it to `schema.sql` with `CREATE TABLE IF NOT EXISTS`.
- **A new column on a shared table** (`users`, `reports`, `categories`, `matches`) → add it to
  `ADDED_COLUMNS` in [src/db/index.js](src/db/index.js), nullable or with a constant default.
  SQLite rejects non-constant defaults in `ALTER TABLE ADD COLUMN`, so anything needing a timestamp
  is added nullable and back-filled with an `UPDATE`.
- **Changing an existing shared column** → don't. The dashboard reads it too.

Never edit the shared-table declarations in `schema.sql` out of step with
`Backend/src/db/schema.sql`; they are duplicated deliberately so either service can create the
file first.

## Wiring up the Flutter app

The app's service layer is already written against interfaces, so this is a swap, not a rewrite:

- `IAuthService` ← replace `MockAuthService` with an `ApiAuthService`
- `IReportRepository` ← replace `InMemoryReportRepository` with an `ApiReportRepository`

Change the two constructor calls in `main.dart` and no screen or view-model needs to change for
the swap itself. Beyond that:

- add `dio` + `flutter_secure_storage`, with an interceptor that refreshes on a `TOKEN_EXPIRED` 401
- extend `ReportItem` with `category`, `description`, `images`, `ownerId`, `status`, `createdAt`,
  coordinates, `viewCount`, `commentCount`, plus `fromJson`
- replace the hard-coded `timeAgo: '2h ago'` strings with a `createdAt` DateTime formatted locally
- drop the hard-coded emoji/colour maps — `/categories` supplies `emoji` and `bgHex`
- drop the hard-coded FAQ and contact lists — `/faqs` and `/config` supply them
- replace the hard-coded "Ahmed Khalid" in `profile_screen` and `dashboard_screen` with `/auth/me`

## Not wired up yet

| Feature | State | To finish |
|---|---|---|
| Google sign-in | `/auth/google` returns 503 | set `GOOGLE_CLIENT_ID` to the OAuth client ID the app uses |
| Push notifications | inbox rows are written; delivery is logged, not sent | implement `deliver()` in `src/services/push.service.js` against FCM v1 (needs a service-account JSON, plus an APNs key for iOS) |
| Email / SMS | OTP codes are logged to the console and returned as `devCode` outside production | pick a provider and send from `issueOtp()`; set `EXPOSE_OTP_IN_RESPONSE=false` |
| Image storage | local `uploads/` | point `UPLOADS_DIR` at a mounted volume, or move to object storage |
| Admin-side match notifications | picked up by a 30s sweep | a direct call from `Backend`'s approve endpoint would be instant, but that means editing that repo |

`push_sent_at` is deliberately left null while push is unconfigured, so the column never claims a
delivery that did not happen.

## Before deploying

- Set a real `JWT_SECRET` — the default is a placeholder and is not safe.
- Set `NODE_ENV=production`. This also hard-disables `RATE_LIMIT_DISABLED` and `devCode` OTP echo,
  regardless of what the environment says.
- Set `PUBLIC_URL` to the public address, and `UPLOADS_DIR` to persistent storage.
- Back up `Backend/data/admin.sqlite` on a schedule. SQLite is a single file, there is no replica,
  and both services depend on it.
- Run only one instance of this backend. Two processes on one SQLite file already needs a busy
  timeout; more would need Postgres.
