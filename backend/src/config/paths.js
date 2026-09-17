import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { env } from './env.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
export const projectRoot = path.resolve(__dirname, '../..');

export const uploadsDir = path.isAbsolute(env.uploadsDir)
  ? env.uploadsDir
  : path.resolve(projectRoot, env.uploadsDir);

fs.mkdirSync(uploadsDir, { recursive: true });
