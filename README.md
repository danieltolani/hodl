# Hodl Automation

Polls Gmail every 30 minutes for Globus Bank debit alerts and writes each
transaction into the Hodl Notion expense database automatically.

---

## Folder layout

```
automation/
  index.js        — main pipeline (Gmail → Notion, runs every 30 min)
  parser.js       — extracts amount / narration / date from email body
  notion.js       — writes a new row to the Notion database
  auth.js         — one-time OAuth2 setup helper
  processed.json  — IDs of emails already added (prevents duplicates)
```

---

## One-time setup

### 1. Install dependencies

```bash
npm install
```

### 2. Create a Google Cloud project and enable Gmail API

1. Go to https://console.cloud.google.com
2. Create a project (or pick an existing one)
3. Enable the **Gmail API**
4. Go to **Credentials → Create Credentials → OAuth 2.0 Client ID**
5. Application type: **Desktop app**
6. Add `http://localhost:3000/callback` as an authorised redirect URI
7. Download the client JSON — copy `client_id` and `client_secret` into `.env`

### 3. Get a Gmail refresh token

```bash
npm run auth
```

Open the printed URL, sign in with tolanidaniel02@gmail.com, approve access.
The script captures the callback and prints your `GMAIL_REFRESH_TOKEN`.
Paste it into `.env`.

### 4. Create a Notion integration

1. Go to https://www.notion.so/my-integrations → **+ New integration**
2. Name it *Hodl Automation*, enable **Read & Write content**
3. Copy the **Internal Integration Secret** into `.env` as `NOTION_TOKEN`
4. Open the *APRIL FIGURES (NGN)* database in Notion → **… → Add connections**
   → select *Hodl Automation*

### 5. Fill in `.env`

```
GMAIL_CLIENT_ID=...
GMAIL_CLIENT_SECRET=...
GMAIL_REFRESH_TOKEN=...
NOTION_TOKEN=secret_...
NOTION_DATABASE_ID=2dda8549-9429-81f1-99c6-000b3044eaf9
```

---

## Running

```bash
npm start
```

The process runs indefinitely, checking every 30 minutes. Each new debit alert
is added to Notion under **Payment Category: Basic Needs** — retag as needed.

To keep it running in the background:

```bash
nohup npm start > automation/hodl.log 2>&1 &
```

---

## Each month

Update `NOTION_DATABASE_ID` in `.env` when you create the new month's database
in Notion, then restart the process.
