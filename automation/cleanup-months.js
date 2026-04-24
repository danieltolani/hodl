/**
 * Archives Notion rows whose Date is outside the current month/year.
 * Run once with: npm run cleanup-months
 */

import 'dotenv/config';
import { Client } from '@notionhq/client';

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const DATABASE_ID = process.env.NOTION_DATABASE_ID;

const now = new Date();
const currentYearMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

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

async function run() {
  console.log(`Current month: ${currentYearMonth}`);
  console.log('Fetching all rows...');
  const pages = await fetchAllPages();
  console.log(`  ${pages.length} rows found.\n`);

  const bad = pages.filter(p => {
    const date = p.properties?.Date?.date?.start ?? '';
    return date && !date.startsWith(currentYearMonth);
  });

  if (!bad.length) {
    console.log('No out-of-month rows found.');
    return;
  }

  console.log(`Archiving ${bad.length} rows from other months/years...\n`);

  for (const page of bad) {
    const date = page.properties?.Date?.date?.start ?? '?';
    const title = page.properties?.Item?.title?.[0]?.plain_text ?? '(no title)';
    const amount = page.properties?.Expenses?.number ?? '?';
    await notion.pages.update({ page_id: page.id, archived: true });
    console.log(`  ✓ Archived [${date}] ₦${Number(amount).toLocaleString()} — "${title}"`);
  }

  console.log(`\nDone — ${bad.length} rows removed.`);
}

run().catch(err => {
  console.error('Failed:', err.message);
  process.exit(1);
});
