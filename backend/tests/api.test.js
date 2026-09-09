/**
 * End-to-end smoke test for the mobile app API.
 *
 * Boots the server against a throwaway SQLite file and uploads directory (never the real
 * data/app.sqlite or uploads/), walks the flows the Flutter screens depend on, and asserts the
 * security rules that are easy to regress: contact privacy, ownership, session rotation, and the
 * two-sided handover.
 *
 * Run: npm run test:api
 */
import { spawn, spawnSync } from 'node:child_process';
import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');

const PORT = 5187;
const BASE = `http://localhost:${PORT}`;
const API = `${BASE}/api/v1`;

const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bto-app-test-'));
const dbPath = path.join(tmpDir, 'test.sqlite');

let passed = 0;
let failed = 0;
const failures = [];

function check(name, condition, detail = '') {
  if (condition) {
    passed += 1;
    console.log(`  ok   ${name}`);
  } else {
    failed += 1;
    failures.push(`${name}${detail ? ` — ${detail}` : ''}`);
    console.log(`  FAIL ${name}${detail ? ` — ${detail}` : ''}`);
  }
}

const section = (title) => console.log(`\n${title}`);

async function call(method, url, { token, body } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body) headers['Content-Type'] = 'application/json';
  const res = await fetch(url.startsWith('http') ? url : `${API}${url}`, {
    method,
    headers,
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = null;
  try {
    json = await res.json();
  } catch {
    /* non-JSON response */
  }
  return { status: res.status, body: json };
}

const get = (url, opts) => call('GET', url, opts);
const post = (url, body, opts) => call('POST', url, { ...opts, body });
const patch = (url, body, opts) => call('PATCH', url, { ...opts, body });
const put = (url, body, opts) => call('PUT', url, { ...opts, body });
const del = (url, body, opts) => call('DELETE', url, { ...opts, body });

async function waitForServer(timeoutMs = 20000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      if ((await fetch(`${BASE}/health`)).ok) return true;
    } catch {
      /* not up yet */
    }
    await new Promise((r) => setTimeout(r, 200));
  }
  return false;
}

const childEnv = {
  ...process.env,
  PORT: String(PORT),
  DB_PATH: dbPath,
  UPLOADS_DIR: path.join(tmpDir, 'uploads'),
  PUBLIC_URL: BASE,
  NODE_ENV: 'development',
  JWT_SECRET: 'test_secret_for_the_api_smoke_test',
  CORS_ORIGIN: '*',
  // The suite issues far more than 120 requests a minute; limits are exercised separately.
  RATE_LIMIT_DISABLED: '1',
};

// A fresh install runs `npm run seed`, so the test database is built the same way.
const seedResult = spawnSync(process.execPath, [path.join(rootDir, 'src', 'db', 'seed.js')], {
  cwd: rootDir,
  env: childEnv,
  encoding: 'utf-8',
});
if (seedResult.status !== 0) {
  console.error(`Seeding failed:\n${seedResult.stdout}\n${seedResult.stderr}`);
  process.exit(1);
}

const server = spawn(process.execPath, [path.join(rootDir, 'src', 'server.js')], {
  cwd: rootDir,
  env: childEnv,
  stdio: ['ignore', 'pipe', 'pipe'],
});

const serverLog = [];
server.stdout.on('data', (d) => serverLog.push(d.toString()));
server.stderr.on('data', (d) => serverLog.push(d.toString()));

function shutdown(code) {
  server.kill();
  try {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  } catch {
    /* the OS will clean the temp dir up */
  }
  process.exit(code);
}

try {
  if (!(await waitForServer())) {
    console.error('Server failed to start:\n' + serverLog.join(''));
    shutdown(1);
  }

  // ── Auth ────────────────────────────────────────────────────────────────
  section('Auth');

  const alice = { email: 'alice@example.com', password: 'Str0ngPass!', firstName: 'Alice', lastName: 'Perera' };
  const reg = await post('/auth/register', { ...alice, phone: '+94770000001', idVerificationNo: 'NIC123' });
  check('register returns 201', reg.status === 201, `got ${reg.status} ${JSON.stringify(reg.body)}`);
  check('register returns access + refresh tokens', Boolean(reg.body?.data?.accessToken && reg.body?.data?.refreshToken));
  check('register never echoes idVerificationNo', !JSON.stringify(reg.body).includes('NIC123'));
  check('register never echoes a password hash', !JSON.stringify(reg.body).includes('$2a$'));

  let aliceToken = reg.body.data.accessToken;
  const aliceRefresh = reg.body.data.refreshToken;

  check('duplicate email is rejected with 409', (await post('/auth/register', alice)).status === 409);
  check(
    'a password under 8 chars is rejected',
    (await post('/auth/register', { email: 'weak@example.com', password: 'short' })).status === 400
  );
  check(
    'a wrong password gives 401',
    (await post('/auth/login', { email: alice.email, password: 'WrongPass1!' })).status === 401
  );

  const login = await post('/auth/login', { email: alice.email, password: alice.password });
  check('login succeeds', login.status === 200 && Boolean(login.body?.data?.accessToken), `got ${login.status}`);
  check('a protected route without a token gives 401', (await get('/me')).status === 401);
  check('a garbage token is refused', (await get('/me', { token: 'not-a-jwt' })).status === 401);

  const bob = await post('/auth/register', {
    email: 'bob@example.com',
    password: 'Str0ngPass!',
    firstName: 'Bob',
    lastName: 'Silva',
    phone: '+94770000002',
  });
  const bobToken = bob.body.data.accessToken;

  const seededLogin = await post('/auth/login', { email: 'ahmed.khalid@example.com', password: 'Test@12345' });
  check('the seeded demo account can sign in', seededLogin.status === 200, `got ${seededLogin.status}`);

  // ── Refresh rotation ────────────────────────────────────────────────────
  section('Refresh token rotation');

  const refreshed = await post('/auth/refresh', { refreshToken: aliceRefresh });
  check('refresh returns a new access token', refreshed.status === 200 && Boolean(refreshed.body?.data?.accessToken));
  check('refresh rotates the refresh token', refreshed.body?.data?.refreshToken !== aliceRefresh);
  const aliceRefresh2 = refreshed.body.data.refreshToken;

  const reuse = await post('/auth/refresh', { refreshToken: aliceRefresh });
  check('reusing a rotated refresh token is refused', reuse.status === 401, `got ${reuse.status}`);
  check('token reuse is reported as such', reuse.body?.details?.code === 'TOKEN_REUSE_DETECTED');
  check(
    'reuse revokes the whole session family',
    (await post('/auth/refresh', { refreshToken: aliceRefresh2 })).status === 401
  );

  const aliceLogin = await post('/auth/login', { email: alice.email, password: alice.password });
  aliceToken = aliceLogin.body.data.accessToken;
  const aliceRefresh3 = aliceLogin.body.data.refreshToken;

  // ── Profile ─────────────────────────────────────────────────────────────
  section('Profile');

  const profile = await patch('/me', { firstName: 'Alicia', lastName: 'Pereira' }, { token: aliceToken });
  check('profile update succeeds', profile.status === 200, `got ${profile.status}`);
  check('the display name is kept in sync', profile.body?.data?.name === 'Alicia Pereira', profile.body?.data?.name);

  check(
    'a wrong current password is refused',
    (await patch('/me/password', { currentPassword: 'nope', newPassword: 'NewStr0ng!' }, { token: aliceToken })).status === 400
  );

  const okPassword = await patch(
    '/me/password',
    { currentPassword: alice.password, newPassword: 'NewStr0ng!1', refreshToken: aliceRefresh3 },
    { token: aliceToken }
  );
  check('password change succeeds', okPassword.status === 200, `got ${okPassword.status}`);
  const stillWorks = await post('/auth/refresh', { refreshToken: aliceRefresh3 });
  check('the calling device stays signed in after a password change', stillWorks.status === 200);
  aliceToken = stillWorks.body.data.accessToken;

  // ── Reports ─────────────────────────────────────────────────────────────
  section('Reports');

  const created = await post(
    '/reports',
    {
      title: 'Black Leather Wallet',
      type: 'lost',
      category: 'wallets',
      description: 'Black bifold wallet with bank cards inside, lost near the fountain',
      location: 'Viharamahadevi Park, Colombo',
      lat: 6.9149,
      lng: 79.8615,
      reward: 5000,
    },
    { token: aliceToken }
  );
  check('create report returns 201', created.status === 201, `got ${created.status} ${JSON.stringify(created.body)}`);
  const reportId = created.body?.data?.id;
  check('the report is owned by its creator', created.body?.data?.isMine === true);
  check('category visuals come from the server', created.body?.data?.emoji === '👛', created.body?.data?.emoji);

  const mine = await get('/me/reports', { token: aliceToken });
  check('my reports lists it', mine.body?.data?.some((r) => r.id === reportId));
  check(
    "my reports excludes another user's report",
    !(await get('/me/reports', { token: bobToken })).body?.data?.some((r) => r.id === reportId)
  );

  check(
    'a non-owner cannot edit a report',
    (await patch(`/reports/${reportId}`, { title: 'Hijacked' }, { token: bobToken })).status === 403
  );
  check('a non-owner cannot delete a report', (await del(`/reports/${reportId}`, null, { token: bobToken })).status === 403);

  // ── Contact privacy ─────────────────────────────────────────────────────
  section('Contact privacy');

  check('the owner sees contact details', (await get(`/reports/${reportId}`, { token: aliceToken })).body?.data?.contactsVisible === true);

  const asStranger = await get(`/reports/${reportId}`, { token: bobToken });
  check('a stranger does not see contactsVisible', asStranger.body?.data?.contactsVisible === false);
  check('a stranger response carries no contacts object', asStranger.body?.data?.contacts === undefined);
  check('no phone number leaks to a stranger', !JSON.stringify(asStranger.body).includes('+94770000001'));

  const anon = await get(`/reports/${reportId}`);
  check('report detail is readable signed out', anon.status === 200, `got ${anon.status}`);
  check('no contact details leak to anonymous readers', !JSON.stringify(anon.body).includes('alice@example.com'));

  const feedAnon = await get('/reports?type=lost');
  check('the feed is readable signed out', feedAnon.status === 200, `got ${feedAnon.status}`);
  check('no email leaks into the public feed', !JSON.stringify(feedAnon.body).includes('alice@example.com'));

  // ── Search & geo ────────────────────────────────────────────────────────
  section('Search and geo filtering');

  check('full-text search finds the report', (await get('/reports?q=wallet')).body?.data?.some((r) => r.id === reportId));
  check('search covers the description', (await get('/reports?q=fountain')).body?.data?.some((r) => r.id === reportId));
  check('FTS operators in user input do not error', (await get('/reports?q=%22wallet%22%20AND%20*')).status === 200);
  check('a non-matching search returns nothing', (await get('/reports?q=zzzznothing')).body?.data?.length === 0);

  const near = await get('/reports?lat=6.9149&lng=79.8615&radiusKm=5');
  check('a nearby geo search finds it', near.body?.data?.some((r) => r.id === reportId));
  check('distance is returned for geo searches', typeof near.body?.data?.[0]?.distanceKm === 'number');
  check(
    'a distant geo search excludes it',
    !(await get('/reports?lat=51.5074&lng=-0.1278&radiusKm=5')).body?.data?.some((r) => r.id === reportId)
  );

  // ── Views ───────────────────────────────────────────────────────────────
  section('View counting');

  check(
    'the owner viewing their own report is not counted',
    (await post(`/reports/${reportId}/view`, null, { token: aliceToken })).body?.data?.counted === false
  );
  check(
    "another user's view is counted",
    (await post(`/reports/${reportId}/view`, null, { token: bobToken })).body?.data?.counted === true
  );
  check(
    'a repeat view within 24h is not double-counted',
    (await post(`/reports/${reportId}/view`, null, { token: bobToken })).body?.data?.counted === false
  );

  // ── Comments ────────────────────────────────────────────────────────────
  section('Comments');

  const comment = await post(`/reports/${reportId}/comments`, { body: 'I think I saw this near the gate.' }, { token: bobToken });
  check('a comment is created', comment.status === 201, `got ${comment.status}`);
  const commentId = comment.body?.data?.id;

  check(
    'the report owner is notified of the comment',
    (await get('/notifications', { token: aliceToken })).body?.data?.some((n) => n.type === 'comment')
  );

  const reply = await post(`/reports/${reportId}/comments`, { body: 'Thanks!', parentId: commentId }, { token: aliceToken });
  check('a reply is accepted', reply.status === 201, `got ${reply.status}`);
  check(
    'replies cannot nest further than one level',
    (await post(`/reports/${reportId}/comments`, { body: 'deep', parentId: reply.body.data.id }, { token: bobToken })).status === 409
  );

  const carol = await post('/auth/register', { email: 'carol@example.com', password: 'Str0ngPass!', firstName: 'Carol' });
  check(
    "a stranger cannot delete someone else's comment",
    (await del(`/comments/${commentId}`, null, { token: carol.body.data.accessToken })).status === 403
  );

  // ── Claims and the two-sided handover ───────────────────────────────────
  section('Claims and handover');

  check(
    'you cannot claim your own report',
    (await post(`/reports/${reportId}/claims`, { message: 'mine' }, { token: aliceToken })).status === 409
  );

  const claim = await post(
    `/reports/${reportId}/claims`,
    { message: 'It has my ID inside.', proof: { colour: 'black', contents: 'bank card and NIC' } },
    { token: bobToken }
  );
  check('a claim is filed', claim.status === 201, `got ${claim.status}`);
  const claimId = claim.body?.data?.id;

  check(
    'a second open claim by the same user is refused',
    (await post(`/reports/${reportId}/claims`, { message: 'again' }, { token: bobToken })).status === 409
  );
  check('only the report owner can list claims', (await get(`/reports/${reportId}/claims`, { token: bobToken })).status === 403);
  check(
    'a pending claim does not unlock contacts',
    (await get(`/reports/${reportId}`, { token: bobToken })).body?.data?.contactsVisible === false
  );
  check(
    'a claimant cannot accept their own claim',
    (await post(`/claims/${claimId}/accept`, {}, { token: bobToken })).status === 403
  );

  const accept = await post(`/claims/${claimId}/accept`, { meetingPlace: 'Park entrance' }, { token: aliceToken });
  check('the owner can accept the claim', accept.status === 200, `got ${accept.status}`);

  const afterAccept = await get(`/reports/${reportId}`, { token: bobToken });
  check('an accepted claim unlocks contacts for the claimant', afterAccept.body?.data?.contactsVisible === true);
  check('the unlocked contacts actually contain the detail', JSON.stringify(afterAccept.body).includes('alice@example.com'));

  const firstConfirm = await post(`/claims/${claimId}/confirm-return`, null, { token: bobToken });
  check('one confirmation does not complete the handover', firstConfirm.body?.data?.completed === false);
  check('the first confirmation reports it is waiting', firstConfirm.body?.data?.awaitingOtherParty === true);
  check(
    'the same party cannot confirm twice',
    (await post(`/claims/${claimId}/confirm-return`, null, { token: bobToken })).status === 409
  );
  check(
    'the report is not returned until both confirm',
    (await get(`/reports/${reportId}`, { token: aliceToken })).body?.data?.status !== 'returned'
  );

  const secondConfirm = await post(`/claims/${claimId}/confirm-return`, null, { token: aliceToken });
  check('the second confirmation completes the handover', secondConfirm.body?.data?.completed === true);

  const returned = await get(`/reports/${reportId}`, { token: aliceToken });
  check('the report is now returned', returned.body?.data?.status === 'returned', returned.body?.data?.status);
  check('resolvedAt is set', Boolean(returned.body?.data?.resolvedAt));
  check(
    'itemsReturned is credited',
    (await get('/me', { token: aliceToken })).body?.data?.itemsReturned === 1
  );
  check(
    'both parties get a returned notification',
    (await get('/notifications', { token: bobToken })).body?.data?.some((n) => n.type === 'returned')
  );

  // ── Matching ────────────────────────────────────────────────────────────
  // The database is shared with the admin dashboard, so suggestions land in that dashboard's
  // approval queue. Users are only told once an admin approves — and because the approval happens
  // in the other process, this suite performs it with a direct write, exactly as the dashboard
  // would, then checks the sweep picks it up.
  section('Matching (admin-approved, shared database)');

  const lost2 = await post(
    '/reports',
    {
      title: 'Sony Wireless Headphones',
      type: 'lost',
      category: 'electronics',
      description: 'Black Sony WH-1000XM5 headphones in a hard case',
      location: 'Fort Railway Station',
      lat: 6.9337,
      lng: 79.8501,
    },
    { token: aliceToken }
  );
  check('lost report created for matching', lost2.status === 201, `got ${lost2.status}`);

  const found2 = await post(
    '/reports',
    {
      title: 'Sony Headphones Found',
      type: 'found',
      category: 'electronics',
      description: 'Found black Sony WH-1000XM5 headphones with a hard case',
      location: 'Fort Railway Station platform 2',
      lat: 6.934,
      lng: 79.8505,
    },
    { token: bobToken }
  );
  check('the matcher created a candidate', found2.body?.data?.suggestedMatches >= 1, String(found2.body?.data?.suggestedMatches));

  const suggestions = await get('/me/matches', { token: aliceToken });
  check('the suggestion appears in my matches', suggestions.body?.data?.length >= 1, String(suggestions.body?.data?.length));
  const matchId = suggestions.body?.data?.[0]?.id;
  check('it is queued for admin review', suggestions.body?.data?.[0]?.awaitingReview === true, suggestions.body?.data?.[0]?.status);
  check('a suggestion carries both reports', Boolean(suggestions.body?.data?.[0]?.myReport && suggestions.body?.data?.[0]?.matchedReport));
  check(
    'a suggestion does not change either report status',
    (await get(`/reports/${lost2.body.data.id}`)).body?.data?.status === 'open'
  );
  check(
    'nobody is notified before an admin approves',
    !(await get('/notifications', { token: aliceToken })).body?.data?.some((n) => n.type === 'match')
  );

  check(
    'an uninvolved user cannot dismiss the match',
    (await post(`/matches/${matchId}/dismiss`, null, { token: carol.body.data.accessToken })).status === 403
  );

  // Stand in for the admin dashboard: approve the row directly in the shared file.
  const adminDb = new DatabaseSync(dbPath);
  adminDb.exec(`UPDATE matches SET status = 'approved' WHERE id = '${matchId}'`);
  adminDb.close();

  const afterApproval = await get('/me/matches', { token: aliceToken });
  check('the approval is visible to the app', afterApproval.body?.data?.[0]?.status === 'approved', afterApproval.body?.data?.[0]?.status);
  check(
    'the sweep notifies the owner once approved',
    (await get('/notifications', { token: aliceToken })).body?.data?.some((n) => n.type === 'match')
  );
  check(
    'the other owner is notified too',
    (await get('/notifications', { token: bobToken })).body?.data?.some((n) => n.type === 'match')
  );

  const beforeCount = (await get('/notifications', { token: aliceToken })).body?.data?.filter((n) => n.type === 'match').length;
  await get('/me/matches', { token: aliceToken });
  const afterCount = (await get('/notifications', { token: aliceToken })).body?.data?.filter((n) => n.type === 'match').length;
  check('the sweep is idempotent — no duplicate notification', beforeCount === afterCount, `${beforeCount} then ${afterCount}`);

  check(
    'an approved match can no longer be dismissed',
    (await post(`/matches/${matchId}/dismiss`, null, { token: aliceToken })).status === 409
  );

  // ── Notifications ───────────────────────────────────────────────────────
  section('Notifications');

  check('the unread count is returned', typeof (await get('/notifications/unread-count', { token: aliceToken })).body?.data?.unread === 'number');
  const readAll = await post('/notifications/read-all', null, { token: aliceToken });
  check('mark-all-read works', readAll.status === 200 && readAll.body?.data?.unread === 0);
  check('the unread count drops to zero', (await get('/notifications/unread-count', { token: aliceToken })).body?.data?.unread === 0);

  const bobNotifs = await get('/notifications', { token: bobToken });
  if (bobNotifs.body?.data?.[0]) {
    check(
      "a user cannot read another user's notification",
      (await patch(`/notifications/${bobNotifs.body.data[0].id}/read`, null, { token: aliceToken })).status === 404
    );
  }

  // ── Saved reports ───────────────────────────────────────────────────────
  section('Saved reports');

  const savedId = lost2.body.data.id;
  check('saving a report works', (await put(`/reports/${savedId}/save`, null, { token: bobToken })).status === 200);
  check('the saved list contains it', (await get('/me/saved', { token: bobToken })).body?.data?.some((r) => r.id === savedId));
  await put(`/reports/${savedId}/save`, null, { token: bobToken });
  check(
    'saving twice does not duplicate',
    (await get('/me/saved', { token: bobToken })).body?.data?.filter((r) => r.id === savedId).length === 1
  );
  await del(`/reports/${savedId}/save`, null, { token: bobToken });
  check('unsaving removes it', !(await get('/me/saved', { token: bobToken })).body?.data?.some((r) => r.id === savedId));

  // ── Settings ────────────────────────────────────────────────────────────
  section('Settings');

  check('settings are returned', (await get('/me/settings', { token: aliceToken })).body?.data?.pushMatches === true);
  const setUpdate = await patch('/me/settings', { pushComments: false, searchRadiusKm: 10 }, { token: aliceToken });
  check('settings update works', setUpdate.body?.data?.pushComments === false && setUpdate.body?.data?.searchRadiusKm === 10);
  const setPersist = await get('/me/settings', { token: aliceToken });
  check('settings persist', setPersist.body?.data?.pushComments === false);
  check('an unset field is left alone', setPersist.body?.data?.pushMatches === true);
  check('an out-of-range radius is rejected', (await patch('/me/settings', { searchRadiusKm: 9999 }, { token: aliceToken })).status === 400);

  // ── Devices ─────────────────────────────────────────────────────────────
  section('Device registration');

  const fcm = 'test-fcm-token-abcdefghij';
  check('a device registers', (await post('/devices', { fcmToken: fcm, platform: 'android', appVersion: '1.0.0' }, { token: aliceToken })).status === 201);
  check('re-registering the same token updates rather than duplicating', (await post('/devices', { fcmToken: fcm, platform: 'android' }, { token: aliceToken })).status === 200);
  check('a token follows the phone to a new account', (await post('/devices', { fcmToken: fcm, platform: 'android' }, { token: bobToken })).status === 200);
  check('an unknown platform is rejected', (await post('/devices', { fcmToken: fcm, platform: 'symbian' }, { token: aliceToken })).status === 400);
  check('a device unregisters', (await del('/devices', { fcmToken: fcm }, { token: bobToken })).status === 200);

  // ── OTP: password reset ─────────────────────────────────────────────────
  section('Password reset via OTP');

  const forgotUnknown = await post('/auth/forgot-password', { email: 'nobody-here@example.com' });
  check('forgot-password does not reveal whether an email exists', forgotUnknown.status === 200 && forgotUnknown.body?.data?.sent === true);
  check('no code is issued for an unknown email', forgotUnknown.body?.data?.devCode === undefined);

  const forgot = await post('/auth/forgot-password', { email: alice.email });
  check('forgot-password issues a code for a real account', Boolean(forgot.body?.data?.devCode));
  const resetCode = forgot.body.data.devCode;

  check(
    'a wrong reset code is rejected',
    (await post('/auth/reset-password', { email: alice.email, code: '000000', newPassword: 'Another1Pass!' })).status === 400
  );
  check(
    'a correct reset code changes the password',
    (await post('/auth/reset-password', { email: alice.email, code: resetCode, newPassword: 'Another1Pass!' })).status === 200
  );
  check(
    'a reset code cannot be replayed',
    (await post('/auth/reset-password', { email: alice.email, code: resetCode, newPassword: 'YetAnother1!' })).status === 400
  );
  check('the old password no longer works', (await post('/auth/login', { email: alice.email, password: 'NewStr0ng!1' })).status === 401);

  const newPassLogin = await post('/auth/login', { email: alice.email, password: 'Another1Pass!' });
  check('the new password works', newPassLogin.status === 200);
  aliceToken = newPassLogin.body.data.accessToken;
  check('a password reset revokes every existing session', (await post('/auth/refresh', { refreshToken: aliceRefresh3 })).status === 401);

  // ── OTP: email verification ─────────────────────────────────────────────
  section('Email verification');

  const verifyReq = await post('/auth/request-email-verification', null, { token: aliceToken });
  check('an email verification code is issued', Boolean(verifyReq.body?.data?.devCode));
  check('a wrong verification code is rejected', (await post('/auth/verify-email', { code: '000000' }, { token: aliceToken })).status === 400);
  const verify = await post('/auth/verify-email', { code: verifyReq.body.data.devCode }, { token: aliceToken });
  check('the correct code verifies the email', verify.status === 200 && verify.body?.data?.emailVerified === true);
  check('an already-verified email cannot re-request', (await post('/auth/request-email-verification', null, { token: aliceToken })).status === 400);

  // ── Image upload ────────────────────────────────────────────────────────
  section('Image upload');

  // A 1x1 PNG — real magic bytes, so it survives the content check.
  const pngBytes = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    'base64'
  );

  async function uploadImage(url, token, { bytes = pngBytes, filename = 'test.png', field = 'images', contentType = 'image/png' } = {}) {
    const form = new FormData();
    form.append(field, new Blob([bytes], { type: contentType }), filename);
    const res = await fetch(`${API}${url}`, { method: 'POST', headers: { Authorization: `Bearer ${token}` }, body: form });
    return { status: res.status, body: await res.json().catch(() => null) };
  }

  const uploadTarget = await post('/reports', { title: 'Item With Photos', type: 'found', location: 'Test Location' }, { token: aliceToken });
  const uploadId = uploadTarget.body.data.id;

  const upload = await uploadImage(`/reports/${uploadId}/images`, aliceToken);
  check('an image uploads', upload.status === 201, `got ${upload.status} ${JSON.stringify(upload.body)}`);
  check('the image appears on the report', upload.body?.data?.images?.length === 1);
  check('image URLs are absolute for the app', String(upload.body?.data?.images?.[0]).startsWith('http'));
  check('a primary image is set', Boolean(upload.body?.data?.primaryImage));

  check(
    'a non-image with an image extension is rejected',
    (await uploadImage(`/reports/${uploadId}/images`, aliceToken, { bytes: Buffer.from('<?php system($_GET["c"]); ?>'), filename: 'shell.png' })).status === 400
  );
  check(
    'a disallowed extension is rejected',
    (await uploadImage(`/reports/${uploadId}/images`, aliceToken, { filename: 'evil.php' })).status === 400
  );
  check(
    "a stranger cannot add images to someone else's report",
    (await uploadImage(`/reports/${uploadId}/images`, bobToken)).status === 403
  );

  const avatar = await uploadImage('/me/avatar', aliceToken, { field: 'image' });
  check('an avatar uploads', avatar.status === 201, `got ${avatar.status}`);
  check('the avatar URL is absolute', String(avatar.body?.data?.avatar).startsWith('http'));

  const fetched = await fetch(upload.body.data.images[0]);
  check('the uploaded image is served back', fetched.ok, `got ${fetched.status}`);
  check('it is served with an image content type', (fetched.headers.get('content-type') || '').startsWith('image/'));

  // ── Meta ────────────────────────────────────────────────────────────────
  section('Meta endpoints');

  const cats = await get('/categories');
  check('categories are public', cats.status === 200 && cats.body?.data?.length === 9, `got ${cats.body?.data?.length}`);
  check('categories carry emoji and bgHex', Boolean(cats.body?.data?.[0]?.emoji && cats.body?.data?.[0]?.bgHex));

  const faqs = await get('/faqs');
  check('FAQs are served', faqs.status === 200 && faqs.body?.data?.length > 0, `got ${faqs.body?.data?.length} faqs`);
  check('config is served', Boolean((await get('/config')).body?.data?.supportEmail));

  const stats = await get('/stats/home');
  check('home stats are served', stats.status === 200, `got ${stats.status}`);
  check('itemsReturned reflects the completed handover', stats.body?.data?.itemsReturned >= 1);
  check('successRate is a number, never NaN', Number.isFinite(stats.body?.data?.successRate));

  // ── Support ─────────────────────────────────────────────────────────────
  section('Support tickets');

  const ticket = await post('/support/tickets', { subject: 'Cannot upload a photo', message: 'The camera button does nothing.' }, { token: aliceToken });
  check('a ticket is created with its first message', ticket.status === 201 && ticket.body?.data?.messages?.length === 1);
  const ticketId = ticket.body?.data?.id;
  check(
    'a reply is appended to the thread',
    (await post(`/support/tickets/${ticketId}/messages`, { body: 'Still happening on 1.0.1.' }, { token: aliceToken })).body?.data?.messages?.length === 2
  );
  check("a user cannot read another user's ticket", (await get(`/support/tickets/${ticketId}`, { token: bobToken })).status === 404);

  // ── Validation ──────────────────────────────────────────────────────────
  section('Input validation');

  check('a report without a title is rejected', (await post('/reports', { type: 'lost', location: 'Somewhere' }, { token: aliceToken })).status === 400);
  check('an invalid report type is rejected', (await post('/reports', { title: 'Test item', type: 'stolen', location: 'Test Location' }, { token: aliceToken })).status === 400);
  check('an out-of-range latitude is rejected', (await post('/reports', { title: 'Test item', type: 'lost', location: 'Test Location', lat: 999, lng: 0 }, { token: aliceToken })).status === 400);
  check('an unknown report gives 404', (await get('/reports/DOES-NOT-EXIST')).status === 404);
  check('an unknown route gives 404', (await get('/no-such-endpoint')).status === 404);

  const badCategory = await post('/reports', { title: 'Odd category item', type: 'lost', location: 'Test Location', category: 'not-a-real-category' }, { token: aliceToken });
  check('an unknown category falls back to "other"', badCategory.body?.data?.category === 'other', badCategory.body?.data?.category);

  // ── Soft delete ─────────────────────────────────────────────────────────
  section('Report deletion');

  const toDelete = await post('/reports', { title: 'Temporary Test Item', type: 'found', location: 'Nowhere' }, { token: aliceToken });
  check('the owner can delete their report', (await del(`/reports/${toDelete.body.data.id}`, null, { token: aliceToken })).status === 200);
  check('a deleted report is no longer readable', (await get(`/reports/${toDelete.body.data.id}`)).status === 404);
  check(
    'a deleted report leaves the feed',
    !(await get('/reports?type=found')).body?.data?.some((r) => r.id === toDelete.body.data.id)
  );

  // ── Summary ─────────────────────────────────────────────────────────────
  console.log(`\n${'─'.repeat(60)}`);
  console.log(`${passed} passed, ${failed} failed`);
  if (failed > 0) {
    console.log('\nFailures:');
    for (const f of failures) console.log(`  • ${f}`);
  }
  shutdown(failed > 0 ? 1 : 0);
} catch (err) {
  console.error('\nTest run crashed:', err);
  console.error('\nServer log:\n' + serverLog.join(''));
  shutdown(1);
}
