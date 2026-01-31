# Remote Focus Push Notifications – Supabase Setup

For remote focus commands to trigger silent APNs pushes to the iPhone, you need to finish configuring Supabase and Apple.

## 0. Link the repo to your Supabase project (required for `db push`)

`supabase db push` only works after the CLI knows which remote project to use.

1. **Log in** (if needed):  
   `supabase login`

2. **Link this repo** to your project:  
   `supabase link --project-ref YOUR_PROJECT_REF`

   **Where to get the project ref**
   - Supabase Dashboard → your project → **Settings** → **General** → “Reference ID”, or  
   - From your project URL: `https://YOUR_PROJECT_REF.supabase.co` → the subdomain is the ref.

3. Then run:  
   `supabase db push`

**If you see “Remote migration versions not found in local migrations directory”:**  
The remote DB has a migration version that no longer matches a local file (e.g. after renaming a migration). Repair it, then push again:

```bash
supabase migration repair --status reverted 20260112
supabase db push
```

Use the version the CLI printed (e.g. `20260112`). If it lists several, run `repair --status reverted <version>` for each, then `db push`.

## 1. Database

- Migrations are in place: `user_devices`, `remote_focus_commands`, and the trigger that calls the Edge Function.
- Apply them (after linking):  
  `supabase db push`

## 2. Apple (APNs)

1. In [Apple Developer](https://developer.apple.com/account/resources/authkeys/list):
   - Create an **APNs Auth Key** (Keys → + → Apple Push Notifications service).
   - Download the `.p8` file once (you can’t download it again).
   - Note: **Key ID**, **Team ID**, and your app’s **Bundle ID** (e.g. `com.yourcompany.winFlutter`).

2. For **development** (Xcode / TestFlight): use the **sandbox** APNs environment.  
   For **production** (App Store): use **production**.

## 3. Supabase Edge Function secrets

The `remote_focus_push` Edge Function needs these **secrets** (Supabase Dashboard → Project Settings → Edge Functions → Secrets, or `supabase secrets set`):

| Secret | Description |
|--------|-------------|
| `SUPABASE_URL` | Your project URL (e.g. `https://xxx.supabase.co`) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key from Project Settings → API |
| `APNS_TEAM_ID` | Apple Team ID (10-character) |
| `APNS_KEY_ID` | APNs key ID (from the key you created) |
| `APNS_PRIVATE_KEY_P8` | **Full contents** of the `.p8` file (including `-----BEGIN PRIVATE KEY-----` / `-----END PRIVATE KEY-----`) |
| `APNS_BUNDLE_ID` | Your iOS app bundle ID (used as APNs topic) |
| `APNS_USE_SANDBOX` | `true` for development, `false` for production |

Example (CLI):

```bash
supabase secrets set APNS_TEAM_ID=XXXXXXXXXX
supabase secrets set APNS_KEY_ID=YYYYYYYYYY
supabase secrets set APNS_PRIVATE_KEY_P8="$(cat AuthKey_XXXXX.p8)"
supabase secrets set APNS_BUNDLE_ID=com.yourcompany.winFlutter
supabase secrets set APNS_USE_SANDBOX=true
```

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are often already set; if not, add them the same way.

## 4. Database trigger → Edge Function (Vault)

The trigger that runs when a `remote_focus_commands` row is inserted calls the Edge Function via **pg_net**. It reads two values from **Supabase Vault** (`vault.decrypted_secrets`), **not** from Edge Function secrets:

- **Name:** `SUPABASE_URL` → value: your project URL
- **Name:** `SUPABASE_SERVICE_ROLE_KEY` → value: your service role key

If these are not in Vault, the trigger does nothing (inserts still succeed; no push is sent).

### Step 1: Get the two values

1. **SUPABASE_URL**
   - Open [Supabase Dashboard](https://supabase.com/dashboard) → your project.
   - Go to **Project Settings** (gear icon in the left sidebar) → **API**.
   - Under **Project URL**, copy the URL (e.g. `https://mytllkdpadrwapwxytca.supabase.co`). No trailing slash.

2. **SUPABASE_SERVICE_ROLE_KEY**
   - Same page: **Project Settings** → **API**.
   - Under **Project API keys**, find **service_role** (labeled “secret”).
   - Click **Reveal** and copy the key. Treat it as a password; it bypasses RLS.

### Step 2: Add them to Vault

You can use either the **Dashboard** or **SQL**.

#### Option A: Dashboard

1. In the left sidebar, open **Database** → **Vault** (or **Integrations** → **Vault**, depending on your dashboard).
2. Click **Create new secret** (or **Add secret**).
3. **First secret:**
   - **Name:** `SUPABASE_URL` (exactly, no spaces).
   - **Secret value:** paste your Project URL (e.g. `https://xxxx.supabase.co`).
   - Save.
4. **Second secret:**
   - **Name:** `SUPABASE_SERVICE_ROLE_KEY` (exactly).
   - **Secret value:** paste your service_role key.
   - Save.

If the UI has a “Description” field, you can use it (e.g. “URL for remote_focus_push trigger”) but the **Name** must be exactly as above.

#### Option B: SQL (if Vault UI is hard to find)

1. Go to **SQL Editor** in the dashboard.
2. Run two statements (replace the placeholder values with your real URL and service_role key):

```sql
-- Replace the first argument with your Project URL, e.g. https://mytllkdpadrwapwxytca.supabase.co
select vault.create_secret(
  'https://YOUR_PROJECT_REF.supabase.co',
  'SUPABASE_URL',
  'Project URL for remote_focus_push trigger'
);

-- Replace the first argument with your service_role key (the long JWT)
select vault.create_secret(
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',  -- your full service_role key
  'SUPABASE_SERVICE_ROLE_KEY',
  'Service role key for remote_focus_push trigger'
);
```

3. Run each `select vault.create_secret(...);` once. You should see a result row with an `id` or `create_secret` UUID.

### Step 3: Confirm

In **SQL Editor**, run:

```sql
select name, description from vault.decrypted_secrets where name in ('SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY');
```

You should see two rows with names `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`. (Do not paste the query result anywhere; it may expose the key.)

After that, when you insert a row into `remote_focus_commands`, the trigger will POST to `/functions/v1/remote_focus_push`, which will send the silent push to the user’s iOS devices.

## 5. App side (already implemented)

- The app registers for remote notifications and gets the APNs device token.
- It upserts the token into `user_devices` (via `PushNotificationService`).
- So once the app has run on a **real device** with a **signed-in user**, that device’s token should be in `user_devices`. The Edge Function looks up tokens there to send the push.

## Quick checklist

- [ ] Migrations applied: `supabase db push`
- [ ] APNs key created in Apple Developer; Key ID, Team ID, Bundle ID noted
- [ ] Edge Function secrets set for `remote_focus_push` (all `APNS_*` and Supabase URL/key)
- [ ] Vault secrets `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` set (so the DB trigger can call the Edge Function)
- [ ] App run on a real device and user signed in (so `user_devices` has a row with `push_token`)

Once all of the above are done, inserting a `remote_focus_commands` row for that user will cause a silent push to be sent to their iPhone.
