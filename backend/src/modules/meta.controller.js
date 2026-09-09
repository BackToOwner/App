import { db } from '../db/index.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { serializeCategory } from '../serializers/index.js';

// GET /api/v1/categories   — card emoji and swatch colours come from here, not from Dart
export const listCategories = asyncHandler(async (req, res) => {
  const rows = db.prepare('SELECT * FROM categories WHERE active = 1 ORDER BY sort_order, label').all();
  res.json({ success: true, data: rows.map(serializeCategory) });
});

// GET /api/v1/faqs   — backs help_support_screen.dart
export const listFaqs = asyncHandler(async (req, res) => {
  const rows = db.prepare('SELECT * FROM faqs WHERE active = 1 ORDER BY sort_order, question').all();
  res.json({ success: true, data: rows.map((r) => ({ id: r.id, question: r.question, answer: r.answer })) });
});

// GET /api/v1/config   — hotline, support email, social links, minimum app version
export const getConfig = asyncHandler(async (req, res) => {
  const rows = db.prepare('SELECT key, value FROM app_config').all();
  res.json({ success: true, data: Object.fromEntries(rows.map((r) => [r.key, r.value])) });
});

/**
 * GET /api/v1/stats/home
 *
 * The three KPI cards on dashboard_screen.dart. Success rate is returned to one decimal place and
 * is 0 when there is nothing to divide by, rather than NaN.
 */
export const homeStats = asyncHandler(async (req, res) => {
  const totals = db
    .prepare(
      `SELECT
         COUNT(*) AS total,
         SUM(CASE WHEN status = 'returned' THEN 1 ELSE 0 END) AS returned,
         SUM(CASE WHEN status IN ('open','in_review','matched') THEN 1 ELSE 0 END) AS active
       FROM reports WHERE deleted_at IS NULL`
    )
    .get();

  const total = totals.total || 0;
  const returned = totals.returned || 0;

  res.json({
    success: true,
    data: {
      itemsReturned: returned,
      activeCases: totals.active || 0,
      totalReports: total,
      successRate: total > 0 ? Number(((returned / total) * 100).toFixed(1)) : 0,
    },
  });
});
