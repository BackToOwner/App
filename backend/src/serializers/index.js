import { db } from '../db/index.js';
import { env } from '../config/env.js';
import { parseJsonSafe } from '../utils/parseJson.js';
import { toIso } from '../utils/time.js';
import { canSeeContacts, isOwner } from '../services/reports.service.js';

// Uploads are stored as site-relative paths ('/uploads/x.jpg'); the app needs absolute URLs.
export function absoluteUrl(url) {
  if (!url) return null;
  if (/^https?:\/\//i.test(url)) return url;
  return `${env.publicUrl}${url.startsWith('/') ? '' : '/'}${url}`;
}

export function serializeUserSummary(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    avatar: absoluteUrl(row.avatar),
    trustScore: row.trust_score,
  };
}

// Never emits id_verification_no, password_hash or google_id.
export function serializeUserProfile(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name,
    firstName: row.first_name,
    lastName: row.last_name,
    email: row.email,
    phone: row.phone,
    role: row.role,
    avatar: absoluteUrl(row.avatar),
    itemsReported: row.items_reported,
    itemsFound: row.items_found,
    itemsReturned: row.items_returned,
    trustScore: row.trust_score,
    status: row.status,
    emailVerified: Boolean(row.email_verified),
    phoneVerified: Boolean(row.phone_verified),
    idVerified: Boolean(row.id_verified),
    joinedAt: toIso(row.joined_at),
    lastLoginAt: toIso(row.last_login_at),
  };
}

export function serializeCategory(row) {
  return {
    id: row.id,
    label: row.label,
    icon: row.icon,
    color: row.color,
    emoji: row.emoji,
    bgHex: row.bg_hex,
    description: row.description,
    sortOrder: row.sort_order,
  };
}

const categoryVisualsCache = new Map();
function categoryVisuals(categoryId) {
  if (!categoryVisualsCache.has(categoryId)) {
    const row = db.prepare('SELECT emoji, bg_hex FROM categories WHERE id = ?').get(categoryId);
    categoryVisualsCache.set(categoryId, row || { emoji: '📦', bg_hex: 'F1F5F9' });
  }
  return categoryVisualsCache.get(categoryId);
}
export function clearCategoryVisualsCache() {
  categoryVisualsCache.clear();
}

/**
 * The report shape the Flutter client consumes.
 *
 * Contact details are gated behind canSeeContacts() — owner, or a claimant with an accepted
 * claim — so phone numbers and emails never reach the public feed. `contacts` is absent rather
 * than null when withheld, so the app can tell "not allowed to see" from "not provided".
 *
 * @param viewerId  id of the signed-in user, or null for anonymous requests
 */
export function serializeReport(row, viewerId = null, { images } = {}) {
  if (!row) return null;

  const visuals = categoryVisuals(row.category);
  const owner = row.owner_user_id
    ? db.prepare('SELECT id, name, avatar, trust_score FROM users WHERE id = ?').get(row.owner_user_id)
    : null;

  const imageRows =
    images ??
    db.prepare('SELECT url FROM report_images WHERE report_id = ? ORDER BY sort_order, created_at').all(row.id);
  const imageUrls = imageRows.length
    ? imageRows.map((i) => absoluteUrl(i.url))
    : parseJsonSafe(row.images, []).map(absoluteUrl);

  const showContacts = canSeeContacts(row, viewerId);

  return {
    id: row.id,
    title: row.title,
    type: row.type,
    category: row.category,
    status: row.status,
    description: row.description,
    location: row.location,
    coordinates: row.lat != null && row.lng != null ? { lat: row.lat, lng: row.lng } : null,
    distanceKm: row.distance_km,
    occurredAt: toIso(row.occurred_at),
    reward: row.reward,
    rewardCurrency: row.reward_currency,
    emoji: row.emoji || visuals.emoji,
    iconBgHex: visuals.bg_hex,
    images: imageUrls,
    primaryImage: imageUrls[0] ?? null,
    matched: Boolean(row.matched),
    matchedWithId: row.matched_with_id,
    matchScore: row.match_score,
    owner: serializeUserSummary(owner),
    isMine: isOwner(row, viewerId),
    viewCount: row.view_count,
    commentCount: row.comment_count,
    claimCount: row.claim_count,
    ...(showContacts
      ? {
          contacts: {
            reporter: row.reporter_name ? { name: row.reporter_name, contact: row.reporter_contact } : null,
            finder: row.finder_name ? { name: row.finder_name, contact: row.finder_contact } : null,
          },
        }
      : {}),
    contactsVisible: showContacts,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    resolvedAt: toIso(row.resolved_at),
  };
}

export function serializeComment(row) {
  return {
    id: row.id,
    reportId: row.report_id,
    parentId: row.parent_id,
    body: row.body,
    author: serializeUserSummary({
      id: row.user_id,
      name: row.author_name,
      avatar: row.author_avatar,
      trust_score: row.author_trust_score,
    }),
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
  };
}

export function serializeClaim(row, { includeContacts = false } = {}) {
  const contactsUnlocked = includeContacts && ['accepted', 'completed'].includes(row.status);
  return {
    id: row.id,
    reportId: row.report_id,
    reportTitle: row.report_title,
    status: row.status,
    message: row.message,
    proof: parseJsonSafe(row.proof, {}),
    meetingPlace: row.meeting_place,
    meetingAt: toIso(row.meeting_at),
    ownerConfirmed: Boolean(row.owner_confirmed_at),
    claimantConfirmed: Boolean(row.claimant_confirmed_at),
    claimant: serializeUserSummary({
      id: row.claimant_user_id,
      name: row.claimant_name,
      avatar: row.claimant_avatar,
      trust_score: row.claimant_trust_score,
    }),
    ...(contactsUnlocked ? { claimantContact: { email: row.claimant_email, phone: row.claimant_phone } } : {}),
    createdAt: toIso(row.created_at),
    decidedAt: toIso(row.decided_at),
  };
}

export function serializeNotification(row) {
  return {
    id: row.id,
    type: row.type,
    title: row.title,
    body: row.body,
    reportId: row.report_id,
    matchId: row.match_id,
    commentId: row.comment_id,
    claimId: row.claim_id,
    data: parseJsonSafe(row.data, {}),
    isRead: row.read_at != null,
    readAt: toIso(row.read_at),
    createdAt: toIso(row.created_at),
  };
}
