# BackToOwner

A lost-and-found platform: a Flutter mobile app backed by a Node.js/Express/SQLite API, sharing
its database with a separate admin dashboard (`../Backend`, `../AdminDashBoard`) so a report filed
from the phone appears in the web dashboard and vice versa.

This is a **monorepo**: the Flutter client lives at this root; its backend is in [`backend/`](backend/readme.md).

| | |
|---|---|
| Client | Flutter (this directory) |
| Backend | Node.js + Express + SQLite — see [`backend/readme.md`](backend/readme.md) |
| Backend port | 5001 (`/api/v1/*`) |

## Getting started

```bash
# 1. Backend
cd backend
npm install
copy .env.example .env      # or `cp` on macOS/Linux
npm run seed                 # categories, FAQs, config, demo users and reports
npm run dev                  # http://localhost:5001

# 2. Flutter app (from the repo root)
flutter pub get
flutter run
```

Point the app at the backend via `lib/config/api_config.dart` / `PUBLIC_URL` — see
[Pointing the Flutter app at it](backend/readme.md#pointing-the-flutter-app-at-it) for the emulator
vs. physical-device address to use.

## Demo login credentials

`npm run seed` (in `backend/`) creates two **local development accounts only** — not real users,
not present in any deployed environment:

| Email | Password |
|---|---|
| `ahmed.khalid@example.com` | `Test@12345` |
| `sara.fernando@example.com` | `Test@12345` |

Sign in with either from the app's auth screen once the backend is running and seeded. Defined in
[`backend/src/db/seed.js`](backend/src/db/seed.js); change or remove them there if you need
different fixtures.

⚠️ These are fixed, publicly-visible credentials meant for local development. Never seed them into
a shared or production database, and never reuse this password for a real account.

## Tests

```bash
flutter test                        # app unit + widget tests
cd backend && npm run test:api      # API integration suite (throwaway DB, ~150 checks)
```

## More detail

See [`backend/readme.md`](backend/readme.md) for the API reference, auth flow, the shared-database
rules, how matching works, and what's not wired up yet.
