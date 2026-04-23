/**
 * Removes Notion rows that have garbled narrations (leftover from before the
 * parser fix), then clears processed.json so the main script re-imports them
 * cleanly on the next run.
 *
 * Run once with: npm run cleanup
 */

import 'dotenv/config';
import { Client } from '@notionhq/client';
import { writeFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const notion = new Client({ auth: process.env.NOTION_TOKEN });
const DATABASE_ID = process.env.NOTION_DATABASE_ID;

// Any Item that contains these strings is a garbled row
const JUNK_MARKERS = ['Transaction Type', 'colorSchemeQueryList', '-->'];

async function fetchAllPages() {
  const pages = [];
  let cursor;
  do {
    const res = await notion.databases.query({
      database_id: DATABASE_ID,
      start_cursor: cursor,
      page_size: 100,
    });
    pages.push(...res.results);
    cursor = res.has_more ? res.next_cursor : undefined;
  } while (cursor);
  return pages;
}

function isGarbled(page) {
  const text = page.properties?.Item?.title?.[0]?.plain_text ?? '';
  return JUNK_MARKERS.some(m => text.includes(m));
}

async function run() {
  console.log('Fetching all rows from Notion...');
  const pages = await fetchAllPages();
  const bad = pages.filter(isGarbled);

  if (!bad.length) {
    console.log('No garbled rows found — nothing to clean up.');
    return;
  }

  console.log(`Found ${bad.length} garbled rows out of ${pages.length} total. Archiving...\n`);

  for (const page of bad) {
    const preview = (page.properties?.Item?.title?.[0]?.plain_text ?? '').slice(0, 60);
    await notion.pages.update({ page_id: page.id, archived: true });
    console.log(`  ✓ Archived: "${preview}..."`);
  }

  writeFileSync(join(__dirname, 'processed.json'), '[]');

  console.log(`\nDone — ${bad.length} rows removed, processed.json cleared.`);
  console.log('Run `npm start` to re-import all emails with clean narrations.');
}

run().catch(err => {
  console.error('Cleanup failed:', err.message);
  process.exit(1);
});
