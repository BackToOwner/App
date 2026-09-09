import { db, withTransaction } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';
import { asyncHandler } from '../utils/asyncHandler.js';
import { newId } from '../utils/id.js';
import { nowSql, toIso } from '../utils/time.js';

function serializeTicket(row, messages = null) {
  return {
    id: row.id,
    subject: row.subject,
    category: row.category,
    status: row.status,
    createdAt: toIso(row.created_at),
    updatedAt: toIso(row.updated_at),
    ...(messages
      ? {
          messages: messages.map((m) => ({
            id: m.id,
            senderType: m.sender_type,
            body: m.body,
            createdAt: toIso(m.created_at),
          })),
        }
      : {}),
  };
}

const threadOf = (ticketId) =>
  db.prepare('SELECT * FROM support_messages WHERE ticket_id = ? ORDER BY created_at ASC').all(ticketId);

// GET /api/v1/support/tickets
export const listTickets = asyncHandler(async (req, res) => {
  const rows = db.prepare('SELECT * FROM support_tickets WHERE user_id = ? ORDER BY created_at DESC').all(req.user.id);
  res.json({ success: true, data: rows.map((r) => serializeTicket(r)) });
});

// GET /api/v1/support/tickets/:id
export const getTicket = asyncHandler(async (req, res) => {
  const ticket = db.prepare('SELECT * FROM support_tickets WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
  if (!ticket) throw new ApiError(404, 'Ticket not found');
  res.json({ success: true, data: serializeTicket(ticket, threadOf(ticket.id)) });
});

// POST /api/v1/support/tickets
export const createTicket = asyncHandler(async (req, res) => {
  const { subject, category, message } = req.body;
  const id = newId('TKT');

  const tx = withTransaction(() => {
    db.prepare(
      'INSERT INTO support_tickets (id, user_id, subject, category, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(id, req.user.id, subject, category, nowSql(), nowSql());
    db.prepare(
      'INSERT INTO support_messages (id, ticket_id, sender_type, sender_id, body, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(newId('SMSG'), id, 'user', req.user.id, message, nowSql());
  });
  tx();

  res.status(201).json({
    success: true,
    data: serializeTicket(db.prepare('SELECT * FROM support_tickets WHERE id = ?').get(id), threadOf(id)),
  });
});

// POST /api/v1/support/tickets/:id/messages
export const addTicketMessage = asyncHandler(async (req, res) => {
  const ticket = db.prepare('SELECT * FROM support_tickets WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
  if (!ticket) throw new ApiError(404, 'Ticket not found');
  if (['resolved', 'closed'].includes(ticket.status)) {
    throw new ApiError(409, `This ticket is ${ticket.status} — open a new one to continue`);
  }

  const tx = withTransaction(() => {
    db.prepare(
      'INSERT INTO support_messages (id, ticket_id, sender_type, sender_id, body, created_at) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(newId('SMSG'), ticket.id, 'user', req.user.id, req.body.body, nowSql());
    // A user reply reopens a ticket that support had put on hold.
    db.prepare("UPDATE support_tickets SET status = 'open', updated_at = ? WHERE id = ?").run(nowSql(), ticket.id);
  });
  tx();

  res.status(201).json({
    success: true,
    data: serializeTicket(db.prepare('SELECT * FROM support_tickets WHERE id = ?').get(ticket.id), threadOf(ticket.id)),
  });
});
