import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import { env } from './config/env.js';
import { uploadsDir } from './config/paths.js';
import { notFoundHandler, errorHandler } from './middleware/errorHandler.js';
import apiRoutes from './modules/index.js';

export const app = express();

// Trust the reverse proxy so req.ip is the real client, not the proxy — rate limiting keys on it.
app.set('trust proxy', 1);

app.use(
  helmet({
    // Images are served cross-origin to the mobile client.
    crossOriginResourcePolicy: { policy: 'cross-origin' },
  })
);
app.use(
  cors({
    // The mobile client sends no Origin header and is unaffected by this list; it only
    // constrains browser callers.
    origin: env.corsOrigin.includes('*') ? true : env.corsOrigin,
  })
);
app.use(express.json({ limit: '5mb' }));
app.use(morgan(env.nodeEnv === 'production' ? 'combined' : 'dev'));
app.use('/uploads', express.static(uploadsDir));

app.get('/health', (req, res) =>
  res.json({ success: true, service: 'backtoowner-app-backend', status: 'ok' })
);

app.use('/api/v1', apiRoutes);

app.use(notFoundHandler);
app.use(errorHandler);
