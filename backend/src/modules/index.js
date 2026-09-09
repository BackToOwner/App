import { Router } from 'express';
import { requireAuth, optionalAuth } from '../middleware/auth.js';
import { validate } from '../middleware/validate.js';
import { apiLimiter, authLimiter, identifierLimiter, writeLimiter } from '../middleware/rateLimit.js';
import { uploadSingleImage, uploadReportImages, verifyUploadedImages, handleUploadErrors } from './uploads.js';
import * as schema from './schemas.js';

import * as auth from './auth.controller.js';
import * as profile from './profile.controller.js';
import * as reports from './reports.controller.js';
import * as comments from './comments.controller.js';
import * as claims from './claims.controller.js';
import * as notifications from './notifications.controller.js';
import * as meta from './meta.controller.js';
import * as support from './support.controller.js';

const router = Router();

router.use(apiLimiter);

// ── Auth ──────────────────────────────────────────────────────────────────
// Credential endpoints are limited per IP and per identifier (see middleware/rateLimit.js).
const credentialGuards = [authLimiter, identifierLimiter];

router.post('/auth/register', ...credentialGuards, validate({ body: schema.registerSchema }), auth.register);
router.post('/auth/login', ...credentialGuards, validate({ body: schema.loginSchema }), auth.login);
router.post('/auth/google', authLimiter, validate({ body: schema.googleSchema }), auth.googleAuth);
router.post('/auth/refresh', validate({ body: schema.refreshSchema }), auth.refresh);
router.post('/auth/logout', optionalAuth, validate({ body: schema.logoutSchema }), auth.logout);
router.post('/auth/forgot-password', ...credentialGuards, validate({ body: schema.forgotPasswordSchema }), auth.forgotPassword);
router.post('/auth/reset-password', ...credentialGuards, validate({ body: schema.resetPasswordSchema }), auth.resetPassword);
router.post('/auth/request-email-verification', requireAuth, authLimiter, auth.requestEmailVerification);
router.post('/auth/verify-email', requireAuth, validate({ body: schema.verifyEmailSchema }), auth.verifyEmail);
router.get('/auth/me', requireAuth, auth.me);

// ── Profile ───────────────────────────────────────────────────────────────
router.get('/me', requireAuth, profile.getProfile);
router.patch('/me', requireAuth, validate({ body: schema.updateProfileSchema }), profile.updateProfile);
router.post(
  '/me/avatar',
  requireAuth,
  writeLimiter,
  uploadSingleImage,
  handleUploadErrors,
  verifyUploadedImages,
  profile.uploadAvatar
);
router.patch('/me/password', requireAuth, authLimiter, validate({ body: schema.changePasswordSchema }), profile.changePassword);
router.get('/me/settings', requireAuth, profile.getSettings);
router.patch('/me/settings', requireAuth, validate({ body: schema.settingsSchema }), profile.updateSettings);
router.get('/me/reports', requireAuth, validate({ query: schema.listQuerySchema }), profile.myReports);
router.get('/me/saved', requireAuth, validate({ query: schema.listQuerySchema }), profile.savedReports);
router.get('/me/claims', requireAuth, validate({ query: schema.listQuerySchema }), claims.myClaims);
router.get('/me/matches', requireAuth, reports.myMatches);
router.delete('/me', requireAuth, profile.deleteAccount);

// ── Reports ───────────────────────────────────────────────────────────────
// The feed and detail views are readable signed out, but richer signed in (isMine, isSaved).
router.get('/reports', optionalAuth, validate({ query: schema.feedQuerySchema }), reports.listReports);
router.get('/reports/:id', optionalAuth, reports.getReport);
router.post('/reports', requireAuth, writeLimiter, validate({ body: schema.createReportSchema }), reports.createReport);
router.patch('/reports/:id', requireAuth, validate({ body: schema.updateReportSchema }), reports.updateReport);
router.delete('/reports/:id', requireAuth, reports.deleteReport);

router.post(
  '/reports/:id/images',
  requireAuth,
  writeLimiter,
  uploadReportImages,
  handleUploadErrors,
  verifyUploadedImages,
  reports.addImages
);
router.delete('/reports/:id/images/:imageId', requireAuth, reports.deleteImage);

router.post('/reports/:id/view', optionalAuth, reports.recordView);
router.put('/reports/:id/save', requireAuth, reports.saveReport);
router.delete('/reports/:id/save', requireAuth, reports.unsaveReport);

// ── Matches ───────────────────────────────────────────────────────────────
// Approval lives in the admin dashboard (shared database); the app can only dismiss its own.
router.post('/matches/:id/dismiss', requireAuth, reports.dismissMatch);

// ── Comments ──────────────────────────────────────────────────────────────
router.get('/reports/:id/comments', optionalAuth, validate({ query: schema.listQuerySchema }), comments.listComments);
router.post('/reports/:id/comments', requireAuth, writeLimiter, validate({ body: schema.commentSchema }), comments.createComment);
router.delete('/comments/:id', requireAuth, comments.deleteComment);

// ── Claims ────────────────────────────────────────────────────────────────
router.get('/reports/:id/claims', requireAuth, claims.listReportClaims);
router.post('/reports/:id/claims', requireAuth, writeLimiter, validate({ body: schema.createClaimSchema }), claims.createClaim);
router.post('/claims/:id/accept', requireAuth, validate({ body: schema.decideClaimSchema }), claims.acceptClaim);
router.post('/claims/:id/reject', requireAuth, validate({ body: schema.decideClaimSchema }), claims.rejectClaim);
router.post('/claims/:id/withdraw', requireAuth, claims.withdrawClaim);
router.post('/claims/:id/confirm-return', requireAuth, claims.confirmReturn);

// ── Notifications & devices ───────────────────────────────────────────────
router.get('/notifications', requireAuth, validate({ query: schema.listQuerySchema }), notifications.listNotifications);
router.get('/notifications/unread-count', requireAuth, notifications.getUnreadCount);
router.patch('/notifications/:id/read', requireAuth, notifications.markRead);
router.post('/notifications/read-all', requireAuth, notifications.markAllRead);
router.delete('/notifications/:id', requireAuth, notifications.deleteNotification);

router.post('/devices', requireAuth, validate({ body: schema.deviceSchema }), notifications.registerDevice);
router.delete('/devices', requireAuth, validate({ body: schema.deviceSchema.pick({ fcmToken: true }) }), notifications.unregisterDevice);

// ── Meta (public) ─────────────────────────────────────────────────────────
router.get('/categories', meta.listCategories);
router.get('/faqs', meta.listFaqs);
router.get('/config', meta.getConfig);
router.get('/stats/home', meta.homeStats);

// ── Support ───────────────────────────────────────────────────────────────
router.get('/support/tickets', requireAuth, support.listTickets);
router.get('/support/tickets/:id', requireAuth, support.getTicket);
router.post('/support/tickets', requireAuth, writeLimiter, validate({ body: schema.ticketSchema }), support.createTicket);
router.post('/support/tickets/:id/messages', requireAuth, writeLimiter, validate({ body: schema.ticketMessageSchema }), support.addTicketMessage);

export default router;
