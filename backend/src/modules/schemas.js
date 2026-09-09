import { z } from 'zod';

const trimmed = (min, max) => z.string().trim().min(min).max(max);

export const passwordSchema = z.string().min(8, 'password must be at least 8 characters').max(128);

export const registerSchema = z.object({
  email: z.email().trim().toLowerCase(),
  password: passwordSchema,
  firstName: trimmed(1, 60).optional(),
  lastName: z.string().trim().max(60).optional(),
  name: z.string().trim().max(120).optional(),
  phone: z.string().trim().max(30).optional(),
  idVerificationNo: z.string().trim().max(40).optional(),
});

export const loginSchema = z.object({
  email: z.string().trim().toLowerCase().optional(),
  phone: z.string().trim().optional(),
  password: z.string().min(1, 'password is required'),
});

export const googleSchema = z.object({
  idToken: z.string().min(10, 'idToken is required'),
});

export const refreshSchema = z.object({
  refreshToken: z.string().min(10, 'refreshToken is required'),
});

export const logoutSchema = z.object({
  refreshToken: z.string().min(10).optional(),
});

export const forgotPasswordSchema = z.object({
  email: z.email().trim().toLowerCase(),
});

export const resetPasswordSchema = z.object({
  email: z.email().trim().toLowerCase(),
  code: z.string().trim().min(4).max(10),
  newPassword: passwordSchema,
});

export const verifyEmailSchema = z.object({
  code: z.string().trim().min(4).max(10),
});

export const updateProfileSchema = z
  .object({
    firstName: trimmed(1, 60).optional(),
    lastName: z.string().trim().max(60).optional(),
    email: z.email().trim().toLowerCase().optional(),
    phone: z.string().trim().max(30).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'no fields to update' });

export const changePasswordSchema = z.object({
  currentPassword: z.string().min(1, 'currentPassword is required'),
  newPassword: passwordSchema,
  // Optional: send this device's refresh token to stay signed in here while every other session
  // is revoked. Without it, all sessions including this one are revoked.
  refreshToken: z.string().min(10).optional(),
});

export const settingsSchema = z
  .object({
    pushMatches: z.boolean().optional(),
    pushComments: z.boolean().optional(),
    pushClaims: z.boolean().optional(),
    emailDigest: z.boolean().optional(),
    searchRadiusKm: z.number().min(1).max(500).optional(),
    language: z.string().trim().min(2).max(8).optional(),
  })
  .refine((v) => Object.keys(v).length > 0, { message: 'no fields to update' });

export const createReportSchema = z.object({
  title: trimmed(3, 140),
  type: z.enum(['lost', 'found']),
  category: z.string().trim().max(40).default('other'),
  description: z.string().trim().max(4000).default(''),
  location: trimmed(2, 200),
  lat: z.number().min(-90).max(90).nullish(),
  lng: z.number().min(-180).max(180).nullish(),
  occurredAt: z.string().trim().max(40).nullish(),
  reward: z.number().min(0).max(10_000_000).nullish(),
  rewardCurrency: z.string().trim().length(3).optional(),
  emoji: z.string().trim().max(8).nullish(),
  images: z.array(z.string().trim().max(500)).max(5).optional(),
});

export const updateReportSchema = createReportSchema
  .partial()
  .extend({ status: z.enum(['open', 'in_review', 'closed']).optional() })
  .refine((v) => Object.keys(v).length > 0, { message: 'no fields to update' });

export const feedQuerySchema = z.object({
  type: z.enum(['all', 'lost', 'found']).default('all'),
  category: z.string().trim().default('all'),
  status: z.string().trim().default('open'),
  q: z.string().trim().max(120).default(''),
  lat: z.coerce.number().min(-90).max(90).optional(),
  lng: z.coerce.number().min(-180).max(180).optional(),
  radiusKm: z.coerce.number().min(0.1).max(500).optional(),
  sort: z.enum(['recent', 'nearest']).default('recent'),
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

export const listQuerySchema = z.object({
  page: z.coerce.number().int().min(1).default(1),
  pageSize: z.coerce.number().int().min(1).max(50).default(20),
});

export const commentSchema = z.object({
  body: trimmed(1, 1000),
  parentId: z.string().trim().max(64).nullish(),
});

export const createClaimSchema = z.object({
  message: z.string().trim().max(1000).default(''),
  proof: z.record(z.string(), z.string().max(500)).default({}),
});

export const decideClaimSchema = z.object({
  meetingPlace: z.string().trim().max(200).nullish(),
  meetingAt: z.string().trim().max(40).nullish(),
  reason: z.string().trim().max(500).nullish(),
});

export const deviceSchema = z.object({
  fcmToken: trimmed(10, 500),
  platform: z.enum(['android', 'ios', 'web']),
  appVersion: z.string().trim().max(20).optional(),
});

export const ticketSchema = z.object({
  subject: trimmed(3, 140),
  category: z.string().trim().max(40).default('general'),
  message: trimmed(1, 4000),
});

export const ticketMessageSchema = z.object({
  body: trimmed(1, 4000),
});
