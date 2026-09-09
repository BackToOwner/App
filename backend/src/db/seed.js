import bcrypt from 'bcryptjs';
import { db, withTransaction, dbPath } from './index.js';
import { newId } from '../utils/id.js';
import { nowSql } from '../utils/time.js';

// The same nine categories the admin dashboard backend seeds. Because the database is shared,
// these rows usually already exist — the upsert then only fills in the emoji and swatch colour the
// Flutter cards need, leaving the admin's label/icon/colour untouched.
const CATEGORIES = [
  { id: 'electronics', label: 'Electronics & Phones', icon: 'Smartphone', color: '#0284C7', emoji: '📱', bg: 'F0F7FF', order: 10 },
  { id: 'wallets', label: 'Wallets & IDs', icon: 'Wallet', color: '#8B5CF6', emoji: '👛', bg: 'FFF0F5', order: 20 },
  { id: 'pets', label: 'Lost Pets', icon: 'Dog', color: '#F59E0B', emoji: '🐕', bg: 'FFF9EB', order: 30 },
  { id: 'keys', label: 'Keys & Keyfobs', icon: 'Key', color: '#10B981', emoji: '🔑', bg: 'F0FDF4', order: 40 },
  { id: 'bags', label: 'Bags & Luggage', icon: 'Briefcase', color: '#EC4899', emoji: '🎒', bg: 'EFF6FF', order: 50 },
  { id: 'documents', label: 'Passports & Cards', icon: 'FileText', color: '#6366F1', emoji: '📄', bg: 'EEF2FF', order: 60 },
  { id: 'jewelry', label: 'Jewelry & Watches', icon: 'Watch', color: '#F43F5E', emoji: '⌚', bg: 'FEF2F2', order: 70 },
  { id: 'clothing', label: 'Apparel & Wearables', icon: 'Shirt', color: '#14B8A6', emoji: '👕', bg: 'F0FDFA', order: 80 },
  { id: 'other', label: 'Other', icon: 'Package', color: '#64748B', emoji: '📦', bg: 'F1F5F9', order: 999 },
];

// Lifted from App/lib/screens/help_support_screen.dart so the app can drop its hard-coded list.
const FAQS = [
  {
    id: 'faq_report_lost',
    question: 'How do I report a lost item?',
    answer:
      'Go to the Home tab, tap "Report Lost", fill in the item details including title, location, and an optional photo, then submit.',
    order: 10,
  },
  {
    id: 'faq_report_found',
    question: 'How do I report a found item?',
    answer:
      'Go to the Home tab, tap "Report Found", describe the item you found with its location and a photo to help the owner identify it.',
    order: 20,
  },
  {
    id: 'faq_reward',
    question: 'Is there a reward for returning items?',
    answer: 'Some owners may offer a reward when reporting lost items. This is optional and shown on the report card.',
    order: 30,
  },
  {
    id: 'faq_profile',
    question: 'How do I update my profile?',
    answer: 'Go to Profile → Edit Profile. You can update your name, email, mobile number, and profile photo.',
    order: 40,
  },
  {
    id: 'faq_password',
    question: 'How do I change my password?',
    answer: 'Go to Profile → Privacy & Security. Enter your current password and set a new one.',
    order: 50,
  },
  {
    id: 'faq_delete',
    question: 'Can I delete a report?',
    answer: 'Yes, you can delete your reports from the Lost or Found items list.',
    order: 60,
  },
  {
    id: 'faq_matching',
    question: 'How does matching work?',
    answer:
      'Every new report is automatically compared against reports of the opposite type on category, description, location and timing. Strong candidates are sent to both people as a suggestion, which either of you can confirm or dismiss.',
    order: 70,
  },
  {
    id: 'faq_contact_privacy',
    question: 'Who can see my contact details?',
    answer:
      'Nobody by default. Your phone number and email are only shared with someone after you accept their claim on your report.',
    order: 80,
  },
];

const CONFIG = {
  hotline: '+94 11 234 5678',
  hotlineHours: 'Available 24/7',
  supportEmail: 'support@backtoowner.com',
  supportReplyTime: 'Reply within 24h',
  emergencyNumber: '119',
  facebookUrl: 'https://facebook.com/backtoowner',
  instagramUrl: 'https://instagram.com/backtoowner',
  twitterUrl: 'https://twitter.com/backtoowner',
  websiteUrl: 'https://backtoowner.com',
  minSupportedAppVersion: '1.0.0',
  defaultCurrency: 'LKR',
};

const DEMO_USERS = [
  {
    id: 'USR-DEMO-AHMED',
    firstName: 'Ahmed',
    lastName: 'Khalid',
    email: 'ahmed.khalid@example.com',
    phone: '+94 71 234 5678',
    password: 'Test@12345',
  },
  {
    id: 'USR-DEMO-SARA',
    firstName: 'Sara',
    lastName: 'Fernando',
    email: 'sara.fernando@example.com',
    phone: '+94 77 987 6543',
    password: 'Test@12345',
  },
];

const DEMO_REPORTS = [
  {
    id: 'LST-DEMO-WALLET',
    owner: 'USR-DEMO-AHMED',
    title: 'Black Leather Wallet',
    type: 'lost',
    category: 'wallets',
    description: 'Black bifold leather wallet with a bank card and my ID inside. Lost near the fountain.',
    location: 'Viharamahadevi Park, Colombo',
    lat: 6.9149,
    lng: 79.8615,
    reward: 5000,
  },
  {
    id: 'FND-DEMO-IPHONE',
    owner: 'USR-DEMO-SARA',
    title: 'iPhone 15 Pro Max',
    type: 'found',
    category: 'electronics',
    description: 'Found a black iPhone 15 Pro Max on a bench. Screen is cracked in one corner.',
    location: 'Fort Railway Station, Colombo',
    lat: 6.9337,
    lng: 79.8501,
    reward: null,
  },
  {
    id: 'LST-DEMO-KEYS',
    owner: 'USR-DEMO-AHMED',
    title: 'Toyota Smart Key Fob',
    type: 'lost',
    category: 'keys',
    description: 'Toyota smart key with a small blue carabiner attached.',
    location: 'Keells Super, Bambalapitiya',
    lat: 6.8905,
    lng: 79.8565,
    reward: 2500,
  },
];

const seed = withTransaction(() => {
  const now = nowSql();

  const upsertCategory = db.prepare(
    `INSERT INTO categories (id, label, icon, color, emoji, bg_hex, sort_order, active, created_at)
     VALUES (@id, @label, @icon, @color, @emoji, @bg, @order, 1, @now)
     ON CONFLICT(id) DO UPDATE SET label = @label, icon = @icon, color = @color,
                                   emoji = @emoji, bg_hex = @bg, sort_order = @order`
  );
  for (const c of CATEGORIES) upsertCategory.run({ ...c, now });

  const upsertFaq = db.prepare(
    `INSERT INTO faqs (id, question, answer, sort_order, active, updated_at)
     VALUES (@id, @question, @answer, @order, 1, @now)
     ON CONFLICT(id) DO UPDATE SET question = @question, answer = @answer,
                                   sort_order = @order, updated_at = @now`
  );
  for (const f of FAQS) upsertFaq.run({ ...f, now });

  const upsertConfig = db.prepare(
    `INSERT INTO app_config (key, value, updated_at) VALUES (?, ?, ?)
     ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`
  );
  for (const [key, value] of Object.entries(CONFIG)) upsertConfig.run(key, value, now);

  // Demo accounts exist so the Flutter app has something to sign in to before real users do.
  // Skipped if they already exist, so re-running never clobbers edited data.
  for (const user of DEMO_USERS) {
    if (db.prepare('SELECT id FROM users WHERE id = ? OR lower(email) = ?').get(user.id, user.email)) continue;

    db.prepare(
      `INSERT INTO users (id, name, first_name, last_name, email, phone, password_hash, role, status,
                          email_verified, joined_at, updated_at)
       VALUES (@id, @name, @firstName, @lastName, @email, @phone, @passwordHash, 'Verified Citizen', 'active',
               1, @now, @now)`
    ).run({
      id: user.id,
      name: `${user.firstName} ${user.lastName}`,
      firstName: user.firstName,
      lastName: user.lastName,
      email: user.email,
      phone: user.phone,
      passwordHash: bcrypt.hashSync(user.password, 12),
      now,
    });
    db.prepare('INSERT OR IGNORE INTO user_settings (user_id, updated_at) VALUES (?, ?)').run(user.id, now);
  }

  for (const report of DEMO_REPORTS) {
    if (db.prepare('SELECT id FROM reports WHERE id = ?').get(report.id)) continue;

    const owner = db.prepare('SELECT name, email FROM users WHERE id = ?').get(report.owner);
    if (!owner) continue;

    db.prepare(
      `INSERT INTO reports (id, title, type, category, status, location, lat, lng, occurred_at, reward,
                            reward_currency, description, images, owner_user_id, source,
                            reporter_name, reporter_contact, finder_name, finder_contact, created_at, updated_at)
       VALUES (@id, @title, @type, @category, 'open', @location, @lat, @lng, @now, @reward,
               'LKR', @description, '[]', @owner, 'mobile',
               @reporterName, @reporterContact, @finderName, @finderContact, @now, @now)`
    ).run({
      id: report.id,
      title: report.title,
      type: report.type,
      category: report.category,
      location: report.location,
      lat: report.lat,
      lng: report.lng,
      reward: report.reward,
      description: report.description,
      owner: report.owner,
      reporterName: report.type === 'lost' ? owner.name : null,
      reporterContact: report.type === 'lost' ? owner.email : null,
      finderName: report.type === 'found' ? owner.name : null,
      finderContact: report.type === 'found' ? owner.email : null,
      now,
    });

    const column = report.type === 'lost' ? 'items_reported' : 'items_found';
    db.prepare(`UPDATE users SET ${column} = ${column} + 1 WHERE id = ?`).run(report.owner);
  }
});

seed();

const counts = {
  categories: db.prepare('SELECT COUNT(*) AS c FROM categories').get().c,
  faqs: db.prepare('SELECT COUNT(*) AS c FROM faqs').get().c,
  config: db.prepare('SELECT COUNT(*) AS c FROM app_config').get().c,
  users: db.prepare('SELECT COUNT(*) AS c FROM users').get().c,
  reports: db.prepare('SELECT COUNT(*) AS c FROM reports').get().c,
};

console.log(`[seed] ${counts.categories} categories, ${counts.faqs} FAQs, ${counts.config} config keys`);
console.log(`[seed] ${counts.users} users, ${counts.reports} reports`);
console.log(`[seed] demo login: ${DEMO_USERS.map((u) => u.email).join(', ')} — password Test@12345`);
console.log(`[seed] database: ${dbPath}`);
console.log(`[seed] Done.`);
