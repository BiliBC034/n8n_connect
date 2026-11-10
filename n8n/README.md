# n8n server for n8n Connect

This folder contains the workflow templates and the table schema that your n8n server needs so the Android app can show your apps and run actions. It works equally well for a person or for an AI agent with shell access and, if it has one, access to the n8n MCP.

The full protocol is in [docs/PROTOCOL.md](../docs/PROTOCOL.md). The templates contain no secrets or real IDs: they use `REPLACE_...` placeholders that you must replace (see [§4](#4-placeholder-reference)).

## 1. What's in this folder

| File | Workflow in n8n | What it does | Endpoints |
|---|---|---|---|
| `workflows/core.json` | n8n Connect · Core | Server information, Firebase sign-in, app catalog and device logout | `GET n8n-connect/info` (public), `POST n8n-connect/auth` (Firebase ID token), `GET n8n-connect/apps` (JWT), `POST n8n-connect/logout` (JWT) |
| `workflows/share.json` | n8n Connect · Share | Receives text or links from "Share → n8n Connect" and saves them to `nc_inbox` | `POST n8n-connect/share` (JWT) |
| `workflows/app-tools.json` | n8n Connect · App · Tools | Demo app: live panel, alarm, form and phone actions | `GET n8n-connect/apps/tools`, `POST n8n-connect/apps/tools/echo`, `POST n8n-connect/apps/tools/alarm` (JWT) |
| `workflows/app-n8n.json` | n8n Connect · App · n8n | Optional admin panel of this n8n server (workflows, executions, errors, credentials, users and security audit), through the n8n API. Admins only | `GET n8n-connect/apps/n8n`, `POST n8n-connect/apps/n8n/view` (JWT) |
| `workflows/app-n8n-alerts.json` | n8n Connect · App · n8n · Alerts | Optional: every 5 minutes, sends a push to the admins for each new failed execution. The n8n app turns it on and off | None (runs on a schedule) |
| `workflows/app-access.json` | n8n Connect · App access | Sub-workflow: decides whether an email can use an app (based on `nc_apps`). Called by `app-tools` and `app-n8n` | None (called from another workflow) |
| `workflows/send-to-phone.json` | n8n Connect · Send to phone | Sub-workflow: sends a FCM data message to the user's devices. Called by `app-tools` and `app-n8n-alerts` | None (called from another workflow) |
| `data-tables.json` | Not a workflow | Schema of the four tables (`nc_users`, `nc_devices`, `nc_apps`, `nc_inbox`) and sample rows | None |

The templates in `workflows/` only have the keys `name`, `nodes`, `connections` and `settings`. They are used for "Import from File" in the UI and for `POST /api/v1/workflows` in the public API.

## 2. Requirements

- **n8n 2.x with Data tables** (the templates were built with that version).
- **Public HTTPS URL** for the server. The app rejects `http://`.
- **Firebase project** with:
  - An Android app with the package name `me.bilibc.n8n_connect`.
  - Authentication with the Email/Password provider (and, if you want, Google).
  - Cloud Messaging, for push notifications.
  - A service account for the project with access to FCM.
- **Access to the n8n API** (an API key), if you are going to use the API route or the agent. The optional n8n app also needs one, through the `n8n API` credential (see [§3.b](#b-credentials-in-n8n)).

## 3. Setup

Have these values at hand before you start. None of them should end up in the repository.

### a. Firebase

Data you need (in the Firebase console, Project settings; the labels on screen may vary by language and console version):

| Item | Where to find it | Goes in |
|---|---|---|
| Web API key | Project settings → General | `REPLACE_FIREBASE_WEB_API_KEY` |
| Project ID | Project settings → General | `REPLACE_FIREBASE_PROJECT_ID` |
| Service account JSON (email and private key) | Project settings → Service accounts → Generate new private key | Credential `n8n Connect FCM` |

**How to check:** the project ID must be exactly the one the app uses. If it does not match, the app shows `wrong_firebase_project` (see [§6](#6-troubleshooting)). The service account JSON is a secret: store it outside the repo and do not paste it into a chat.

### b. Credentials in n8n

Create three credentials with these exact names. The third one (`n8n API`) is only needed for the optional n8n app.

**`n8n Connect JWT`** (type *JWT Auth*, `jwtAuth`):
- Key Type: *Passphrase*.
- Secret: a long random secret. Generate it with `openssl rand -base64 48`.
- Algorithm: `HS256`.

**`n8n Connect FCM`** (type *Google Service Account API*, `googleApi`):
- Email and private key of the service account (from the JSON in step a).
- Scope: `https://www.googleapis.com/auth/firebase.messaging`.
- Turn on *Set up for use in HTTP Request node*. Without it, FCM answers `401` with `CREDENTIALS_MISSING` ([§6](#6-troubleshooting)).
- It is used by the HTTP Request node in `send-to-phone` (the template already has it configured).

**`n8n API`** (type *n8n API*, `n8nApi`). Only for the n8n admin app and its alerts (optional). Used by the HTTP Request nodes of `app-n8n` and `app-n8n-alerts`:
- API key: create a new key in *Settings → n8n API* with all the scopes listed below. Older keys may lack some of them, so do not reuse one. The key is a secret.
- Base URL: `http://127.0.0.1:5678/api/v1`. Use `127.0.0.1`, not `localhost` (it may resolve to IPv6). If n8n is not reachable at `http://127.0.0.1:5678` (another `N8N_PORT`, `N8N_LISTEN_ADDRESS`, HTTPS…), edit the address in the 5 places where it is hard-coded: the constant `API` at the top of the Code nodes *Plan op*, *Plan fetch* and *Plan folders* (`app-n8n.json`), and the URLs of the HTTP Request nodes *Recent errors* and *Error details* (`app-n8n-alerts.json`). The Base URL only affects the credential's connection test: set it to the same address so that the test passes.
- Scopes: `workflow:list`, `workflow:read`, `workflow:activate`, `workflow:deactivate`, `execution:list`, `execution:read`, `execution:delete`, `execution:retry`, `execution:stop`, `credential:list`, `insights:read`, `securityAudit:generate`, `user:list` and `tag:list`. Projects, folders and variables need an Enterprise license and are not used.

The exact field names depend on your n8n version. Check them with the API:

```bash
curl -sS "$N8N_URL/api/v1/credentials/schema/jwtAuth" -H "X-N8N-API-KEY: $N8N_API_KEY"
curl -sS "$N8N_URL/api/v1/credentials/schema/googleApi" -H "X-N8N-API-KEY: $N8N_API_KEY"
```

To create them through the API: `POST /api/v1/credentials` with `{"name": "...", "type": "jwtAuth", "data": {...}}`. To create them in the UI: *Credentials → Create credential*.

**How to check:** they appear with those names under *Credentials* (or in `list_credentials` if you use the MCP). The JWT secret does not appear in any file in the repo. `n8n API` appears the same way, if you created it.

### c. Data tables

Create four Data tables with these columns (taken from `data-tables.json`):

| Table | Columns (type) |
|---|---|
| `nc_users` | `email` (string), `enabled` (boolean), `role` (string), `name` (string) |
| `nc_devices` | `device_id` (string), `email` (string), `uid` (string), `name` (string), `platform` (string), `fcm_token` (string), `app_version` (string), `last_seen` (date) |
| `nc_apps` | `app_id` (string), `name` (string), `description` (string), `icon` (string), `color` (string), `path` (string), `enabled` (boolean), `allowed_emails` (string), `sort` (number) |
| `nc_inbox` | `email` (string), `text` (string), `subject` (string), `note` (string), `received_at` (date) |

Where: in the UI, *Data tables*. With the n8n MCP, `create_data_table`. This README does not document creating tables through the API.

Seed rows (from `data-tables.json`):

- **`nc_users`**: one row with `email` = your Firebase email **in lowercase**, `enabled` = `true`, `role` = `admin`, `name` = your name. Without this row, the server rejects your account.
- **`nc_apps`**: one row for the demo app, with `app_id` = `tools`, `name` = `Tools`, `description` = `Alarm, live panel, form and phone actions`, `icon` = `bolt`, `color` = `#0EA5E9`, `path` = `n8n-connect/apps/tools`, `enabled` = `true`, `allowed_emails` = empty (all enabled users), `sort` = `30`.
- **`nc_apps`** (optional, for the n8n admin app): one row with `app_id` = `n8n`, `name` = `n8n`, `description` = `Workflows, executions, errors and alerts of this server`, `icon` = `settings`, `color` = `#EA4B71`, `path` = `n8n-connect/apps/n8n`, `enabled` = `false`, `allowed_emails` = empty (or the admins' emails), `sort` = `50`. Set `enabled` to `true` once the app is imported. The app is only for users with `role` = `admin` in `nc_users`, so only admins can use it.
- `nc_devices` and `nc_inbox` start empty. The server fills them.

**How to check:** the four tables exist with all their columns and types; `nc_users` has your row; `nc_apps` has the `tools` row with `enabled` = `true`.

### d. Importing the workflows

Required order, in batches: **batch 1** `app-access` and `send-to-phone` (sub-workflows); **batch 2** `core` and `share`; **batch 3** `app-tools`; **batch 4** (optional) `app-n8n` and `app-n8n-alerts`. The sub-workflows go first because `app-tools` needs their IDs; batch 4 needs them too, plus the `n8n API` credential and the `nc_users` table.

There are two options.

**Option 1: UI.**
1. *Import from File* with `workflows/app-access.json`. Repeat with `send-to-phone.json`, `core.json`, `share.json` and `app-tools.json`, in that order. Then, if you want the n8n app, `app-n8n.json` and `app-n8n-alerts.json`.
2. In each workflow, open the marked nodes and choose:
   - Credential `n8n Connect JWT` in *Sign session*, *Apps* and *Logout* (core); *Shared from phone* (share); *Screen*, *Form* and *Set alarm* (app-tools); *Screen* and *View* (app-n8n).
   - Credential `n8n Connect FCM` in *Send FCM* (send-to-phone).
   - Credential `n8n API` in *Call op*, *Fetch* and *Fetch folders* (app-n8n); in *Recent errors* and *Error details* (app-n8n-alerts).
   - Table by name: in core, *Find user* (`nc_users`), *Register device*, *Forget push token* and *Release token from other accounts* (`nc_devices`), *Read apps* (`nc_apps`); in app-access, *Read app* (`nc_apps`); in send-to-phone, *Devices with push* (`nc_devices`); in share, *Save to nc_inbox* (`nc_inbox`); in app-tools, *My shared items* (`nc_inbox`); in app-n8n-alerts, *Admins* (`nc_users`).
   - Sub-workflow: in app-tools, *Access (Screen)*, *Access (Form)* and *Access (Alarm)* → `n8n Connect · App access`; *Send to phone* → `n8n Connect · Send to phone`. In app-n8n, *Access* → `n8n Connect · App access`; in app-n8n-alerts, *Send to phone* → `n8n Connect · Send to phone`.
3. Text placeholders are not picked from a dropdown: edit them by hand. They are `REPLACE_SERVER_NAME` (*Respond info* and *Respond session* in core), `REPLACE_FIREBASE_PROJECT_ID` (*Respond info* in core and the URL of *Send FCM* in send-to-phone) and `REPLACE_FIREBASE_WEB_API_KEY` (the URL of *Verify ID token with Firebase* in core).

**Option 2: API.** Copy the templates outside the repo, fill in the placeholders and import with `POST /api/v1/workflows`. Import in three batches (plus an optional fourth for the n8n app), because `app-tools` needs the IDs of the two sub-workflows.

1. Save this script as `fill.py` **outside the repo** (for example in `$HOME/n8n-connect-build/`). It only replaces the placeholders whose environment variables are set:

   ```python
   import json, os, sys
   from pathlib import Path

   src, out = Path(sys.argv[1]), Path(sys.argv[2])  # repo workflows folder; output folder (outside the repo)
   out.mkdir(parents=True, exist_ok=True)

   names = {  # placeholder -> environment variable holding the value
       "REPLACE_CREDENTIAL_ID:n8n Connect JWT": "JWT_CRED_ID",
       "REPLACE_CREDENTIAL_ID:n8n Connect FCM": "FCM_CRED_ID",
       "REPLACE_CREDENTIAL_ID:n8n API": "N8N_API_CRED_ID",
       "REPLACE_DATA_TABLE_ID:nc_users": "DT_USERS",
       "REPLACE_DATA_TABLE_ID:nc_devices": "DT_DEVICES",
       "REPLACE_DATA_TABLE_ID:nc_apps": "DT_APPS",
       "REPLACE_DATA_TABLE_ID:nc_inbox": "DT_INBOX",
       "REPLACE_WORKFLOW_ID:app-access": "WF_APP_ACCESS",
       "REPLACE_WORKFLOW_ID:send-to-phone": "WF_SEND_TO_PHONE",
       "REPLACE_FIREBASE_WEB_API_KEY": "FIREBASE_WEB_API_KEY",
       "REPLACE_FIREBASE_PROJECT_ID": "FIREBASE_PROJECT_ID",
       "REPLACE_SERVER_NAME": "SERVER_NAME",
   }
   vals = {k: os.environ[v] for k, v in names.items() if os.environ.get(v)}

   def fill(node):
       if isinstance(node, dict):
           return {k: fill(v) for k, v in node.items()}
       if isinstance(node, list):
           return [fill(v) for v in node]
       if isinstance(node, str):
           for k, v in vals.items():
               node = node.replace(k, v)
       return node

   for f in sorted(src.glob("*.json")):
       data = fill(json.loads(f.read_text(encoding="utf-8")))
       (out / f.name).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
   ```

2. Export the variables (real values only in the shell, never in a file in the repo). `SERVER_NAME` must not contain double quotes or backslashes.

3. Define the `import_wf` function. It prints the workflow's `id`. If the response has no `id`, it prints the error and exits with code 1: that error is not an ID and you must not use it. It is written as a subshell, so the `exit` does not close your terminal:

   ```bash
   import_wf() ( # $1 = filled copy
     resp=$(curl -sS -X POST "$N8N_URL/api/v1/workflows" \
       -H "X-N8N-API-KEY: $N8N_API_KEY" \
       -H "Content-Type: application/json" \
       --data-binary "@$1") || exit 1
     printf '%s' "$resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit("Import error: " + json.dumps(d, ensure_ascii=False)) if "id" not in d else print(d["id"])' || exit 1
   )
   ```

4. **Batch 1: sub-workflows.** From the repo root, fill in the copies and check **the file you are going to import** with `grep REPLACE_ <file>` (not the whole folder). The output must be **empty**; if it prints anything, do not import that file. `app-access.json` only needs `DT_APPS`; `send-to-phone.json` needs `FCM_CRED_ID`, `DT_DEVICES` and `FIREBASE_PROJECT_ID`.

   ```bash
   python3 -I "$HOME/n8n-connect-build/fill.py" n8n/workflows "$HOME/n8n-connect-build/out"
   grep REPLACE_ "$HOME/n8n-connect-build/out/app-access.json"      # should print nothing
   import_wf "$HOME/n8n-connect-build/out/app-access.json"          # note the printed id
   grep REPLACE_ "$HOME/n8n-connect-build/out/send-to-phone.json"   # should print nothing
   import_wf "$HOME/n8n-connect-build/out/send-to-phone.json"       # note the printed id
   ```

5. **Batch 2: core and share.** Same check: `grep REPLACE_` on each file before importing it.

   ```bash
   grep REPLACE_ "$HOME/n8n-connect-build/out/core.json"    # should print nothing
   import_wf "$HOME/n8n-connect-build/out/core.json"        # no other workflow uses its id
   grep REPLACE_ "$HOME/n8n-connect-build/out/share.json"   # should print nothing
   import_wf "$HOME/n8n-connect-build/out/share.json"       # no other workflow uses its id
   ```

6. **Batch 3: app-tools.** Export the IDs noted in batch 1 (with your real values, only in the shell). Run `fill.py` again: `app-tools.json` changes, and so do `app-n8n.json` and `app-n8n-alerts.json` (they also use `WF_*`; batch 4 imports them). Check that file and import it:

   ```bash
   export WF_APP_ACCESS=id-noted-in-batch-1
   export WF_SEND_TO_PHONE=id-noted-in-batch-1
   python3 -I "$HOME/n8n-connect-build/fill.py" n8n/workflows "$HOME/n8n-connect-build/out"
   grep REPLACE_ "$HOME/n8n-connect-build/out/app-tools.json"   # should print nothing
   import_wf "$HOME/n8n-connect-build/out/app-tools.json"
   ```

7. **Batch 4 (optional): n8n app.** Export `N8N_API_CRED_ID` (the `n8n API` credential ID) and `DT_USERS` (the `nc_users` table ID). `JWT_CRED_ID`, `WF_APP_ACCESS` and `WF_SEND_TO_PHONE` must still be set from the earlier steps. Run `fill.py` again and check each file before importing it:

   ```bash
   export N8N_API_CRED_ID=id-noted-for-n8n-API
   export DT_USERS=id-noted-for-nc_users
   python3 -I "$HOME/n8n-connect-build/fill.py" n8n/workflows "$HOME/n8n-connect-build/out"
   grep REPLACE_ "$HOME/n8n-connect-build/out/app-n8n.json"          # should print nothing
   import_wf "$HOME/n8n-connect-build/out/app-n8n.json"
   grep REPLACE_ "$HOME/n8n-connect-build/out/app-n8n-alerts.json"   # should print nothing
   import_wf "$HOME/n8n-connect-build/out/app-n8n-alerts.json"       # optional
   ```

**How to check:** in *Workflows*, all the imported workflows appear with the names from the table above (seven with the n8n app and its alerts). Do not import the same file twice: it creates duplicates.

### e. Publishing

Publish or activate **core**, **share** and **app-tools**. Depending on your version, you may also need to publish **app-access** and **send-to-phone**. If you imported the n8n app, publish **app-n8n** too. Leave **app-n8n-alerts** unpublished if you do not want alerts yet: the n8n app turns them on and off by publishing and unpublishing that workflow.

- UI (n8n 2.x): the **Publish** button of each workflow.
- API: `POST /api/v1/workflows/{id}/activate`. This route is not verified for your n8n version; if it returns 404 or 405, publish from the UI.
- MCP: `publish_workflow`.

**How to check:** production webhooks respond (`/webhook/...`, not `/webhook-test/...`). A 404 means the workflow is not published or the path does not match.

### f. Testing

1. Server information (public):

   ```bash
   curl -sS https://n8n.example.com/webhook/n8n-connect/info
   ```

   It must return JSON with four fields:
   - `service`: `"n8n-connect"`.
   - `protocol`: `1`.
   - `name`: the value you set in `REPLACE_SERVER_NAME`.
   - `firebaseProjectId`: the Firebase project ID (`REPLACE_FIREBASE_PROJECT_ID`).

2. Protected paths without a token:

   ```bash
   curl -i https://n8n.example.com/webhook/n8n-connect/apps
   ```

   It must respond with 401 or 403 without a JWT (PROTOCOL §2: n8n responds 401/403 as plain text).

3. On the phone: install the app, enter your server URL (`https://n8n.example.com`; the app strips paths such as `/webhook`), sign in with the account in `nc_users` and check that **Tools** appears in the catalog. Open it: it must show the live panel, and the form must respond "n8n received the form". The n8n app is only for users with `role` = `admin`: check it with an admin account.

Extra session check: `curl -i -X POST https://n8n.example.com/webhook/n8n-connect/auth` without a token. According to the code in *Validate identity*, it must respond 401 with `error.code` = `invalid_token`. This has not been tested in your deployment.

## 4. Placeholder reference

| Placeholder | What to put | Where it comes from | File and nodes |
|---|---|---|---|
| `REPLACE_CREDENTIAL_ID:n8n Connect JWT` | JWT credential ID | Assigned by n8n when you create `n8n Connect JWT` (or `list_credentials`) | `core.json`: Sign session, Apps, Logout. `share.json`: Shared from phone. `app-tools.json`: Screen, Form, Set alarm. `app-n8n.json`: Screen, View |
| `REPLACE_CREDENTIAL_ID:n8n Connect FCM` | ID of the Google Service Account credential | Assigned by n8n when you create `n8n Connect FCM` | `send-to-phone.json`: Send FCM |
| `REPLACE_CREDENTIAL_ID:n8n API` | ID of the n8n API credential | Assigned by n8n when you create `n8n API` | `app-n8n.json`: Call op, Fetch, Fetch folders. `app-n8n-alerts.json`: Recent errors, Error details |
| `REPLACE_DATA_TABLE_ID:nc_users` | ID of the `nc_users` table | Data tables (`search_data_tables` with MCP) | `core.json`: Find user. `app-n8n-alerts.json`: Admins |
| `REPLACE_DATA_TABLE_ID:nc_devices` | ID of the `nc_devices` table | Same | `core.json`: Register device, Forget push token, Release token from other accounts. `send-to-phone.json`: Devices with push |
| `REPLACE_DATA_TABLE_ID:nc_apps` | ID of the `nc_apps` table | Same | `core.json`: Read apps. `app-access.json`: Read app |
| `REPLACE_DATA_TABLE_ID:nc_inbox` | ID of the `nc_inbox` table | Same | `share.json`: Save to nc_inbox. `app-tools.json`: My shared items |
| `REPLACE_WORKFLOW_ID:app-access` | ID of the workflow "n8n Connect · App access" | Its ID when imported (UI: the one in the URL; API: the `id` in the response) | `app-tools.json`: Access (Screen), Access (Form), Access (Alarm). `app-n8n.json`: Access |
| `REPLACE_WORKFLOW_ID:send-to-phone` | ID of the workflow "n8n Connect · Send to phone" | Same | `app-tools.json`: Send to phone. `app-n8n-alerts.json`: Send to phone |
| `REPLACE_FIREBASE_WEB_API_KEY` | Firebase web API key | Project settings → General | `core.json`: URL of Verify ID token with Firebase (`identitytoolkit.../accounts:lookup?key=...`) |
| `REPLACE_FIREBASE_PROJECT_ID` | Firebase project ID | Project settings → General | `core.json`: Respond info (`firebaseProjectId`). `send-to-phone.json`: URL of Send FCM (`fcm.googleapis.com/v1/projects/...`) |
| `REPLACE_SERVER_NAME` | Visible server name (no double quotes or backslashes) | You choose it | `core.json`: Respond info (`name`) and Respond session (`server.name`) |

## 5. For AI agents

Verifiable checklist. If you cannot meet a point, stop and ask the user.

1. **Variables.** You need `N8N_URL` (no trailing slash, e.g. `https://n8n.example.com`) and `N8N_API_KEY`. If they do not exist in the environment, ask for them. Do not invent values.
2. **Access.** `curl -sS -o /dev/null -w "%{http_code}" "$N8N_URL/api/v1/workflows" -H "X-N8N-API-KEY: $N8N_API_KEY"` must return `200`.
3. **Firebase data.** Ask the user for the web API key, the project ID and the local path to the service account JSON. Use the path only to create the credential; do not copy it into the repo.
4. **Order.** Credentials (`n8n Connect JWT`, `n8n Connect FCM` and, for the n8n app, `n8n API`) → tables and seed rows → sub-workflows (`app-access`, `send-to-phone`) → `core`, `share` → `app-tools` → publish → test → optional, last: import `app-n8n` and `app-n8n-alerts` (batch 4 in [§3.d](#d-importing-the-workflows)), then publish `app-n8n`.
5. **For each workflow.** Fill the copy with `fill.py` in a directory outside the repo. Check `grep REPLACE_ <copy>/<file>.json` on the file you are going to import: it must be empty. Import with `POST /api/v1/workflows` and save the returned `id` (`import_wf` function in §3.d).
6. **Final checks.** `GET $N8N_URL/webhook/n8n-connect/info` returns `service`, `protocol`, `name` and `firebaseProjectId` with the correct values. `GET $N8N_URL/webhook/n8n-connect/apps` without a token returns 401 or 403.
7. **With the n8n MCP.** Before creating anything, call `get_instance_context`. For IDs use `search_data_tables` and `list_credentials`. For tables, `create_data_table` and `add_data_table_rows`. To publish, `publish_workflow`.

**Do not do this:**
- Do not write secrets or real values (API keys, JWT secret, Firebase private key, real IDs, real emails or production URLs) in `n8n/` or in any other file in the repo.
- Do not push filled copies of the JSON files to the repo. The copies go outside the repo.
- Do not replace the placeholders in the repo templates: fill them only in copies.
- Do not paste the JWT secret or the private key into a chat or a log.
- Do not import the same workflow twice (it gets duplicated). If it happens, delete the duplicate.
- Do not publish a workflow while any `REPLACE_` remains.
- Do not use `/webhook-test/` to test the app: the app uses `/webhook/`.

## 6. Troubleshooting

The codes come from [docs/PROTOCOL.md](../docs/PROTOCOL.md) and from the node code.

- **`not_allowed` (403): "The account … is not authorized on this server."** The email has no enabled row in `nc_users`. Add the row with the email in lowercase and `enabled` = `true`.
- **`account_disabled`, `email_not_verified` or `no_email` (403).** The server sets these based on the Firebase account. `email_not_verified` is resolved by verifying the email in Firebase.
- **`wrong_firebase_project`.** The `firebaseProjectId` from `info` does not match the app's project. Fix `REPLACE_FIREBASE_PROJECT_ID` and republish `core`.
- **`app_forbidden` or "This app is not registered on the server."** The `tools` row is missing from `nc_apps` (or its `app_id` does not match). If the row exists but the app does not appear in the catalog, check that `enabled` is `true` and that your email is in `allowed_emails` (empty = all).
- **The push does not arrive.** Check, in this order:
  1. That the `n8n Connect FCM` credential exists and has the scope `https://www.googleapis.com/auth/firebase.messaging`.
  2. That `REPLACE_FIREBASE_PROJECT_ID` in the Send FCM URL is the project's ID.
  3. That your `nc_devices` row has `fcm_token` and the correct email. Without a token nothing is sent. The response `{"sent": 0, "reason": "no_devices"}` means the user has no devices with a token (PROTOCOL §9).
  4. That you have not signed out on the phone (logout deletes the `fcm_token`).
- **FCM answers `401` with `CREDENTIALS_MISSING`.** The Google credential does not reach the HTTP Request node of *Send FCM*. Open `n8n Connect FCM`, turn on *Set up for use in HTTP Request node* and check the scope `https://www.googleapis.com/auth/firebase.messaging`.
- **Errors that are not JSON, or that the app reads as an expired session.** The app treats a 401 without `error.code` and a 403 whose body is not a JSON object as `session_invalid` (PROTOCOL §3.6). A 401 with `{"error": {"code": "..."}}` keeps its code. For your own rejections use 403 (or 400/404) with `{"error": {"code": "...", "message": "..."}}`, and never a 401 for an app permission.
- **502, 504 or cut-off requests.** If you put a proxy such as Cloudflare in front of n8n, it replaces the body of 502/504 responses and cuts requests at 100 s (error 524): respond with 4xx or 424 and keep each request under that limit. If a dependency fails, respond 424 with `error.code` and `error.message` (PROTOCOL §8). The app waits up to 150 s on submit (`AppConfig.submitTimeout`).
- **`not_found` (404).** The webhook does not exist or the workflow is not published. Check the path (`n8n-connect/...`, without a duplicated `/webhook/`) and publish the workflow.
- **`invalid_token` (401) on `auth`.** Firebase rejected the ID token: expired session or from another project. Sign out in the app and sign in again.
- **`upstream_error` (424) on `auth`.** The server could not verify the ID token with Google (Google responded with something other than 400, or there was a network failure). The app shows the message from *Validate identity*. Try again in a few seconds.
- **The app rejects the URL.** It only accepts `https://`. A local server without HTTPS does not work with the app.
- **A section of the n8n app shows a 403 banner.** The key of the `n8n API` credential lacks the scope that section needs. Older keys may lack `credential:list`, `insights:read`, `execution:retry` or `execution:stop`. Create a new key with all the scopes listed in [§3.b](#b-credentials-in-n8n), then update the credential.
