/**
 * Scans the Notion database for duplicate rows.
 * Duplicate = same Amount + Date + Narration (case-insensitive, trimmed).
 * Keeps the oldest entry (by Notion createdTime), archives the rest.
 *
 * Run with: npm run dedup
 */

import 'dotenv/config';
import { Client } from '@notionhq/client';

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const DATABASE_ID = process.env.NOTION_DATABASE_ID;

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

function pageKey(page) {
  const narration = (page.properties?.Item?.title?.[0]?.plain_text ?? '').toLowerCase().trim();
  const amount    = page.properties?.Expenses?.number ?? '';
  const date      = page.properties?.Date?.date?.start ?? '';
  return `${amount}|${date}|${narration}`;
}

async function run() {
  console.log('Fetching all rows from Notion...');
  const pages = await fetchAllPages();
  console.log(`  ${pages.length} rows found.\n`);

  // Group pages by composite key
  const groups = new Map();
  for (const page of pages) {
    const key = pageKey(page);
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(page);
  }

  // Find groups with more than one entry
  const dupes = [...groups.values()].filter(g => g.length > 1);

  if (!dupes.length) {
    console.log('No duplicates found.');
    return;
  }

  let totalArchived = 0;

  for (const group of dupes) {
    // Sort oldest first — keep [0], archive the rest
    group.sort((a, b) => new Date(a.created_time) - new Date(b.created_time));

    const keeper  = group[0];
    const victims = group.slice(1);

    const label = keeper.properties?.Item?.title?.[0]?.plain_text ?? '(no title)';
    const amount = keeper.properties?.Expenses?.number ?? '?';
    const date   = keeper.properties?.Date?.date?.start ?? '?';

    console.log(`Duplicate: ₦${Number(amount).toLocaleString()} — "${label}" (${date})`);
    console.log(`  Keeping  : ${keeper.id} (created ${keeper.created_time.slice(0, 19)})`);

    for (const page of victims) {
      await notion.pages.update({ page_id: page.id, archived: true });
      console.log(`  Archived : ${page.id} (created ${page.created_time.slice(0, 19)})`);
      totalArchived++;
    }
    console.log('');
  }

  console.log(`Done — ${totalArchived} duplicate(s) removed, ${dupes.length} group(s) resolved.`);
}

run().catch(err => {
  console.error('Dedup failed:', err.message);
  process.exit(1);
});
