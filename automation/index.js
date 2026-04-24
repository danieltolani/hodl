import 'dotenv/config';
import { google } from 'googleapis';
import { readFileSync, writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import { parseGlobusEmail } from './parser.js';
import { addExpenseRow } from './notion.js';

const __root = join(dirname(fileURLToPath(import.meta.url)), '..');

let clientJson;
try {
  clientJson = JSON.parse(readFileSync(join(__root, 'client.json'), 'utf8'));
} catch {
  console.error('client.json not found. Download it from Google Cloud Console and place it in the project root.');
  process.exit(1);
}
const { client_id, client_secret } = clientJson.installed ?? clientJson.web;

const __dirname = dirname(fileURLToPath(import.meta.url));
const PROCESSED_FILE = join(__dirname, 'processed.json');
const POLL_INTERVAL_MS = 1 * 60 * 1000; // 1 minute

function currentMonthQuery() {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, '0');
  return `from:globusbank subject:debit after:${year}/${month}/01`;
}

// ─── Persistence ─────────────────────────────────────────────────────────────

function loadProcessed() {
  try {
    return new Set(JSON.parse(readFileSync(PROCESSED_FILE, 'utf8')));
  } catch {
    return new Set();
  }
}

function saveProcessed(set) {
  writeFileSync(PROCESSED_FILE, JSON.stringify([...set], null, 2));
}

// ─── Gmail helpers ────────────────────────────────────────────────────────────

function buildGmailClient() {
  const auth = new google.auth.OAuth2(client_id, client_secret);
  auth.setCredentials({ refresh_token: process.env.GMAIL_REFRESH_TOKEN });
  return google.gmail({ version: 'v1', auth });
}

/** Recursively decode body, preferring plain text over HTML. */
function decodePayload(payload) {
  if (!payload) return '';

  const parts = payload.parts ?? [];

  // Prefer plain text part
  for (const mimeType of ['text/plain', 'text/html']) {
    const part = parts.find(p => p.mimeType === mimeType);
    if (part?.body?.data) {
      const decoded = Buffer.from(part.body.data, 'base64url').toString('utf-8');
      return mimeType === 'text/html' ? stripHtml(decoded) : decoded;
    }
  }

  // Recurse into nested multipart
  for (const part of parts) {
    const text = decodePayload(part);
    if (text) return text;
  }

  // Single-part message (no nested parts)
  if (payload.body?.data) {
    const decoded = Buffer.from(payload.body.data, 'base64url').toString('utf-8');
    return (payload.mimeType ?? '').includes('html') ? stripHtml(decoded) : decoded;
  }

  return '';
}

function stripHtml(html) {
  return html
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<!--[\s\S]*?-->/g, '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/\s{2,}/g, ' ')
    .trim();
}

async function listMessages(gmail) {
  const res = await gmail.users.messages.list({
    userId: 'me',
    q: currentMonthQuery(),
    maxResults: 500,
  });
  return res.data.messages ?? [];
}

async function getMessage(gmail, id) {
  const res = await gmail.users.messages.get({ userId: 'me', id, format: 'full' });
  const { payload } = res.data;
  const header = name => payload.headers.find(h => h.name === name)?.value ?? '';
  return {
    id,
    subject: header('Subject'),
    date: header('Date'),
    body: decodePayload(payload),
  };
}

// ─── Main pipeline ────────────────────────────────────────────────────────────

async function run() {
  const timestamp = new Date().toISOString();
  console.log(`\n[${timestamp}] Checking Globus Bank debit emails...`);

  const processed = loadProcessed();
  let gmail;

  try {
    gmail = buildGmailClient();
  } catch (err) {
    console.error('Failed to build Gmail client:', err.message);
    return;
  }

  let messages;
  try {
    messages = await listMessages(gmail);
  } catch (err) {
    console.error('Gmail list error:', err.message);
    return;
  }

  if (!messages.length) {
    console.log('No matching emails found.');
    return;
  }

  let added = 0;
  let skipped = 0;

  for (const { id } of messages) {
    if (processed.has(id)) {
      skipped++;
      continue;
    }

    try {
      const emailData = await getMessage(gmail, id);
      const parsed = parseGlobusEmail(emailData);

      if (!parsed.amount) {
        console.warn(`  [SKIP] ${id} — could not extract amount`);
        processed.add(id);
        continue;
      }

      // Skip if not in the current month/year
      const now = new Date();
      const currentYearMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;
      if (!parsed.date.startsWith(currentYearMonth)) {
        processed.add(id);
        continue;
      }

      await addExpenseRow(parsed);
      processed.add(id);
      saveProcessed(processed); // Save after each success so a crash doesn't re-process
      added++;
      console.log(`  [+] ₦${parsed.amount.toLocaleString()} — "${parsed.narration}" (${parsed.date})`);
    } catch (err) {
      console.error(`  [ERR] ${id}:`, err.message);
    }
  }

  saveProcessed(processed);
  console.log(`Done: ${added} added, ${skipped} already processed.`);
}

// ─── Entry point ──────────────────────────────────────────────────────────────

const REQUIRED_ENV = [
  'GMAIL_REFRESH_TOKEN',
  'NOTION_TOKEN',
  'NOTION_DATABASE_ID',
];

const missing = REQUIRED_ENV.filter(k => !process.env[k]);
if (missing.length) {
  console.error(`Missing required env vars: ${missing.join(', ')}`);
  console.error('Copy .env.example to .env and fill in the values.');
  process.exit(1);
}

run();
setInterval(run, POLL_INTERVAL_MS);
