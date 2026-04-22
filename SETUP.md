# Finance Widget – Setup Guide

## Files overview

```
FinanceWidget/
  KeychainHelper.swift        – Keychain read/write (shared)
  FinanceSummary.swift        – Data model (shared)
  NotionFinanceService.swift  – Notion REST API client (shared)
  FinanceWidgetIntent.swift   – AppIntent: configurable spend limit
  FinanceWidget.swift         – TimelineProvider + @main Widget
  FinanceWidgetView.swift     – SwiftUI views (small + medium)
```

**What lives where**

| Value | Storage |
|---|---|
| Notion integration secret | Keychain (`notionToken`) |
| Notion database ID | Keychain (`notionDatabaseId`) |
| Monthly spend limit | Widget configuration (AppIntent) — set by long-pressing the widget |

The spend limit is **not** stored in Notion or Keychain. It is entered directly
in the widget's edit sheet (long-press → Edit Widget → *Monthly Spend Limit*).

---

## Platform requirements

| Feature | Minimum OS |
|---|---|
| Widget display | iOS 16.0 / macOS 13.0 |
| Editable spend limit (AppIntentConfiguration) | **iOS 17.0 / macOS 14.0** |

If your deployment target is iOS 16, the widget will compile and run, but the
spend limit edit sheet will not appear. Set the Widget Extension deployment
target to iOS 17.0 to unlock configuration.

---

## Step 1 – Create a Notion Internal Integration

1. Open <https://www.notion.so/my-integrations> → **+ New integration**.
2. Name it (e.g. *Hodl Finance*), select your workspace.
3. Under **Capabilities**, enable **Read content** only (write is not needed).
4. Click **Submit**, then copy the **Internal Integration Secret** —
   it looks like `secret_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX`.

---

## Step 2 – Share the database with the integration

1. Open the `{MONTH} FIGURES (NGN)` database page in Notion.
2. Click **…** (top-right) → **Add connections** → select your integration.
3. Repeat at the start of every new month when you create the next database.

---

## Step 3 – Find the database ID

Open the database in a browser. The URL looks like:

```
https://www.notion.so/{workspace}/{DATABASE_ID}?v={view_id}
```

The `DATABASE_ID` is the 32-character hex string between the last `/` and `?`.

> **Monthly reminder**: because each month has its own database, update the
> stored database ID at the start of each new month (see Step 5).

---

## Step 4 – Add the Widget Extension target in Xcode

1. **File → New → Target → Widget Extension**.
2. Name it `FinanceWidgetExtension`.
3. **Uncheck** *Include Configuration Intent* — we provide our own AppIntent.
4. Set the extension's **Minimum Deployment Target** to **iOS 17.0 / macOS 14.0**.
5. Add all six Swift files to the extension target
   (select file → File Inspector → Target Membership).
6. Add `KeychainHelper.swift`, `FinanceSummary.swift`, and
   `NotionFinanceService.swift` to the **host app target** as well.

### App Group for shared Keychain

The widget extension cannot read Keychain items saved by the host app unless
both targets share an access group.

1. Host app → **Signing & Capabilities → + Capability → App Groups**.  
   Add `group.com.yourcompany.hodl` (use your own reverse-DNS identifier).
2. Repeat for the **Widget Extension** target using the **same group ID**.
3. Enable **Keychain Sharing** on both targets and add the same group.
4. Pass the group to every `KeychainHelper` call:

```swift
let appGroup = "group.com.yourcompany.hodl"

KeychainHelper.save(key: KeychainHelper.notionTokenKey, value: secret,     accessGroup: appGroup)
KeychainHelper.save(key: KeychainHelper.databaseIdKey,  value: databaseId, accessGroup: appGroup)

// Reading (from the extension):
let token = KeychainHelper.load(key: KeychainHelper.notionTokenKey, accessGroup: appGroup)
```

If you save credentials only from within the extension (no host app), omit
`accessGroup` entirely.

---

## Step 5 – Inject credentials at first launch

Call the following from your host app's onboarding or settings screen:

```swift
let appGroup = "group.com.yourcompany.hodl"  // or nil

// Notion integration secret
KeychainHelper.save(
    key:         KeychainHelper.notionTokenKey,
    value:       "secret_XXXX…",
    accessGroup: appGroup
)

// Current month's database ID (32-char hex, no hyphens)
KeychainHelper.save(
    key:         KeychainHelper.databaseIdKey,
    value:       "abcdef1234567890abcdef1234567890",
    accessGroup: appGroup
)
```

These values persist until you explicitly delete them or uninstall the app.  
**Update `databaseIdKey` at the start of each new month.**

---

## Step 6 – Verify Notion property names

Open your database and confirm the exact column names match the constants in
`NotionFinanceService.swift`:

| Constant in code | Default value | Your column name |
|---|---|---|
| `amountProperty` | `"Amount"` | ? |
| `typeProperty` | `"Type"` | ? |
| `dateProperty` | `"Date"` | ? |

If any differ, change the constant — nothing else needs to change.

The Type values must contain `#income` or `#expense` as a substring
(case-insensitive), so values like `"#income – salary"` also work.

---

## Step 7 – Set the monthly spend limit on the widget

1. Add the widget to your Home Screen or Notification Center.
2. **Long-press → Edit Widget**.
3. Tap the **Monthly Spend Limit** field and enter your limit in Naira
   (e.g. `250000` for ₦250,000).
4. Tap outside to dismiss — the widget refreshes immediately with the new limit.

You can change this value at any time without touching the app or Keychain.

---

## Step 8 – Test in the Xcode widget simulator

1. Select the **FinanceWidgetExtension** scheme and press **Run (⌘R)**.
2. Xcode opens the widget host on the simulator — your widget appears on screen.
3. To force a refresh: call `WidgetCenter.shared.reloadAllTimelines()` from the
   host app, or use **Debug → Simulate Background Fetch** in the simulator.
4. To test **stale / offline**: enable Network Link Conditioner (100 % loss).
   The widget shows cached values with the orange *Cached data* indicator.
5. To test **over-budget**: set the spend limit lower than your current spend total.
6. To test **empty database**: use a database ID for a month with no entries —
   all values show ₦0 with no crash.

---

## Edge cases handled automatically

| Scenario | Behaviour |
|---|---|
| No transactions this month | ₦0 for all three values; no crash |
| Network unavailable | Last cached `FinanceSummary` shown with orange *Cached data* badge |
| First launch (no cache + no network) | Zeroed `FinanceSummary.empty`; no crash |
| Spend > monthly limit | Remaining shown negative with ⚠️ icon and orange colour |
| Missing Keychain credentials | `NotionError.missingCredentials`; widget shows cached or zeroed data |
| Notion 429 rate-limit | `NotionError.rateLimited`; retry scheduled in 15 min |
| Paginated results (>100 rows) | All pages fetched before totals are computed |
| Spend limit changed mid-month | Cache rebased to new limit immediately on next render |
