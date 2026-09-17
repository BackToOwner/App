import rateLimit from 'express-rate-limit';
import { env } from '../config/env.js';
import { ApiError } from '../utils/ApiError.js';

const handler = (req, res, next) => next(new ApiError(429, 'Too many requests — please try again shortly'));

// The API smoke test issues far more requests than any real client. env.rateLimitDisabled is
// hard-wired to false in production (see config/env.js), so this cannot be flipped on a live server.
const skipWhenDisabled = () => env.rateLimitDisabled;

// General API budget.
export const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 120,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
  skip: skipWhenDisabled,
});

// Credential endpoints are limited per IP *and* per identifier below, so one attacker cannot
// spray many accounts from one IP, and a botnet cannot brute-force one account from many IPs.
export const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
  skip: skipWhenDisabled,
});

export const identifierLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 5,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
  keyGenerator: (req) => `id:${String(req.body?.email || req.body?.phone || '').toLowerCase().trim()}`,
  // Requests with no identifier fall through to the per-IP limiter above.
  skip: (req) => skipWhenDisabled() || !(req.body?.email || req.body?.phone),
});

// Writes that create content — keeps a runaway client from flooding the feed.
export const writeLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
  skip: skipWhenDisabled,
});
