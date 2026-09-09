import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';

// Every token this backend issues carries `aud: app`. Nothing else should be accepted here, so a
// token minted by another service (the admin dashboard backend, say) cannot authenticate a user.
export const AUDIENCE = 'app';

export function signAccessToken(payload) {
  return jwt.sign(payload, env.jwtSecret, {
    expiresIn: env.accessTokenExpiresIn,
    audience: AUDIENCE,
  });
}

export function verifyToken(token) {
  return jwt.verify(token, env.jwtSecret, { audience: AUDIENCE });
}
