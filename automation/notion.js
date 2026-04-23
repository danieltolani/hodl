import { Client } from '@notionhq/client';

const notion = new Client({ auth: process.env.NOTION_TOKEN });
const DATABASE_ID = process.env.NOTION_DATABASE_ID;

/**
 * Creates a new row in the Hodl expenses database.
 * @param {{ narration: string, amount: number, date: string }} expense
 */
export async function addExpenseRow({ narration, amount, date }) {
  await notion.pages.create({
    parent: { database_id: DATABASE_ID },
    properties: {
      Item: {
        title: [{ type: 'text', text: { content: narration } }],
      },
      Expenses: {
        number: amount,
      },
      Date: {
        date: { start: date },
      },
      'Payment Category': {
        select: { name: 'Basic Needs' },
      },
    },
  });
}
