import { app } from './app.js';
import { env } from './config/env.js';
import { dbPath } from './db/index.js';
import { startMatchNotifier } from './services/matchNotifier.service.js';

// An admin approving a match happens in the dashboard's process, so there is nothing to hook.
// This sweep spots newly-approved matches and notifies their owners.
startMatchNotifier(env.matchSweepIntervalMs);

app.listen(env.port, () => {
  console.log(`[backtoowner-app-backend] listening on http://localhost:${env.port}`);
  console.log(`[backtoowner-app-backend] database (shared with the admin dashboard): ${dbPath}`);
  if (env.publicUrl.includes('localhost')) {
    console.log('[backtoowner-app-backend] PUBLIC_URL is localhost — a phone cannot reach that.');
    console.log('  Set PUBLIC_URL to this machine\'s LAN IP, or http://10.0.2.2:' + env.port + ' for the Android emulator.');
  }
});
