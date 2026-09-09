import { ApiError } from '../utils/ApiError.js';

// Zod schemas run as middleware, before the controller — controllers then work with parsed,
// typed data and never re-validate.
export function validate({ body, query, params }) {
  return (req, res, next) => {
    try {
      if (body) req.body = body.parse(req.body ?? {});
      if (params) req.params = params.parse(req.params ?? {});
      if (query) {
        // Express 5 makes req.query a getter-only property, so the parsed result is stashed
        // alongside rather than assigned back.
        req.validatedQuery = query.parse(req.query ?? {});
      }
      next();
    } catch (err) {
      if (err?.issues) {
        const details = err.issues.map((i) => ({ path: i.path.join('.'), message: i.message }));
        return next(
          new ApiError(400, details[0] ? `${details[0].path}: ${details[0].message}` : 'Invalid request', details)
        );
      }
      next(err);
    }
  };
}

// Controllers read query params through this so they work with or without a schema attached.
export const q = (req) => req.validatedQuery ?? req.query ?? {};
