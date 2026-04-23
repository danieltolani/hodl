/**
 * One-time OAuth2 setup helper.
 * Run with: npm run auth
 *
 * Prerequisites:
 *   1. Create a Google Cloud project → enable Gmail API
 *   2. Create OAuth 2.0 credentials (Desktop app type)
 *   3. Download client.json and place it at the project root (next to package.json)
 *   4. Run this script — browser opens, you approve, refresh token is printed.
 */

import { google } from 'googleapis';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import http from 'http';
import { URL } from 'url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

let clientJson;
try {
  clientJson = JSON.parse(readFileSync(join(root, 'client.json'), 'utf8'));
} catch {
  console.error('client.json not found. Download it from Google Cloud Console and place it in the project root.');
  process.exit(1);
}

const { client_id, client_secret } = clientJson.installed ?? clientJson.web;
const REDIRECT = 'http://localhost:3000/callback';

const oauth2 = new google.auth.OAuth2(client_id, client_secret, REDIRECT);

const authUrl = oauth2.generateAuthUrl({
  access_type: 'offline',
  prompt: 'consent', // forces refresh_token to be returned every time
  scope: ['https://www.googleapis.com/auth/gmail.readonly'],
});

console.log('\nOpen this URL in your browser:\n');
console.log(authUrl);
console.log('\nWaiting for Google to redirect back...\n');

const server = http.createServer(async (req, res) => {
  const { pathname, searchParams } = new URL(req.url, 'http://localhost:3000');
  if (pathname !== '/callback') return;

  const code = searchParams.get('code');
  const error = searchParams.get('error');

  if (error) {
    res.end(`<h1>Authorization failed: ${error}</h1>`);
    server.close();
    console.error('Authorization denied:', error);
    return;
  }

  res.end('<h1>Authorization complete — you can close this tab.</h1>');
  server.close();

  try {
    const { tokens } = await oauth2.getToken(code);
    console.log('\n✓ Success! Add this line to your .env file:\n');
    console.log(`GMAIL_REFRESH_TOKEN=${tokens.refresh_token}`);
    console.log('');
  } catch (err) {
    console.error('Token exchange failed:', err.message);
  }
});

server.listen(3000, () => {
  console.log('Listening on http://localhost:3000 ...');
});
