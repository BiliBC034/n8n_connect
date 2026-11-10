# n8n Connect protocol (v1)

Reference for anyone who creates n8n workflows that the app uses. It describes what the app reads, what it sends and what it does with each response. The source of truth is the code: `lib/core/app_config.dart`, `lib/features/server/`, `lib/features/apps/`, `lib/features/actions/`, `lib/features/push/`, `lib/features/share/`, `lib/features/automation/`, `lib/features/alarms/` and `lib/features/device_context/`.

1. [Overview](#1-overview)
2. [Security](#2-security)
3. [Core endpoints](#3-core-endpoints)
4. [Tables](#4-tables)
5. [How to create an app](#5-how-to-create-an-app)
6. [UI spec (schema 1)](#6-ui-spec-schema-1)
7. [Actions](#7-actions)
8. [Submit response](#8-submit-response)
9. [Push n8n → phone](#9-push-n8n--phone)
10. [Live dashboards (refreshSeconds)](#10-live-dashboards-refreshseconds)
11. [Offline mode](#11-offline-mode)
12. [n8n inbox](#12-n8n-inbox)
13. [Sharing with n8n](#13-sharing-with-n8n)
14. [Automations](#14-automations)
15. [Examples](#15-examples)

---

## 1. Overview

The app has no business logic. It draws a screen from a JSON document (the *spec*), keeps a local state and runs phone actions when n8n asks for them. n8n makes every decision.

```
 Android app (Flutter)                              n8n (https://your-server)
 ─────────────────────                              ─────────────────────────
 1. Firebase login ── ID token ──────────────────►  n8n-connect/auth
                   ◄──────────── JWT (12 h) ─────
 2. Catalog ──────── GET (JWT) ──────────────────►  n8n-connect/apps
 3. App spec ─────── GET app.path (JWT) ─────────►  app webhook
 4. Submit button ── POST/GET + state (JWT) ─────►  app webhook
                   ◄── {state, screen, message, actions, spec}

 Push (n8n → phone)
 n8n workflow ──► Execute Sub-workflow "Send to phone"
              ──► FCM (data message, high priority) ──► the app
                                                        shows a dialog or notification
                                                        and runs the actions if appropriate
```

Parts:

- **Core**: the "n8n Connect · Core" workflow (`n8n-connect/info`, `auth`, `apps`, `logout`). Template: [n8n/workflows/core.json](../n8n/workflows/core.json).
- **Apps**: a pair of webhooks per app (a GET spec and one or more POST/GET submits).
- **Push**: the "n8n Connect · Send to phone" sub-workflow, which sends the FCM message to the user's devices. Template: [n8n/workflows/send-to-phone.json](../n8n/workflows/send-to-phone.json).
- **Share**: the "n8n Connect · Share" workflow (`n8n-connect/share`), which receives text or links from other apps ([§13](#13-sharing-with-n8n)). Template: [n8n/workflows/share.json](../n8n/workflows/share.json).

---

## 2. Security

**Transport**
- HTTPS only. `normalizeServerUrl` rejects `http://`, and `AndroidManifest.xml` sets `usesCleartextTraffic="false"`.
- In a spec, images (`image`) load only if the URL is `https`.

**Session**
1. The app gets a Firebase ID token (email/password or Google).
2. `POST n8n-connect/auth` with that token. The Core verifies it with Google, checks `emailVerified` and that the email is enabled in `nc_users`.
3. The Core replies with a JWT (HS256) valid for 12 h. Claims: `sub`, `email`, `name`, `role`, `did`, `aud="n8n-connect"`, `iss="n8n-connect"`, `iat`, `exp`.
4. All other webhooks require that JWT (see below).

**Protected webhooks**
- In each app webhook, the Webhook node has *Authentication = "JWT Auth"* with the JWT credential. Inside the workflow, the verified claims are in `$json.jwtPayload` (email, role, did…).
- Without a token or with an invalid one, n8n responds 401/403. The app treats it as `session_invalid` if the 401 has no `error.code` or if the 403 has no JSON object body ([§3.6](#36-error-format)).

**Storage on the phone**
- The session (URL, JWT, expiry, uid, user) is kept in `FlutterSecureStorage` with `encryptedSharedPreferences` (a store backed by the Android Keystore).
- The last server URL is kept in SharedPreferences (it is not secret).
- The device ID is random and is also kept in secure storage.
- The offline copy (`nc.cache.*`, [§11](#11-offline-mode)) and the inbox (`nc.push.history`, [§12](#12-n8n-inbox)) are kept in SharedPreferences, **unencrypted**. They hold specs, the catalog and push content; never the JWT or the Firebase ID token. The automation permissions (`nc.auto.*`, [§14.1](#141-per-app-permission)) are also unencrypted; they only store which apps are allowed.

**Renewal**
- Before each request, if the JWT has less than 2 min left (`sessionRefreshMargin`), the app asks for a new one.
- If the server responds `session_invalid` (401 without `error.code`, or 403 whose body is not a JSON object), the app renews the session and repeats the request once.
- When the FCM token changes, the app also renews the session to register the new token.
- Renewing uses the Firebase ID token, so the app retries once, forcing a new ID token, if the server responds `invalid_token` or `email_not_verified`.

**Submit URL (same origin)**
- Relative paths (`n8n-connect/apps/x/y`) resolve under `{server}/webhook/`. They cannot contain `.` or `..`.
- An absolute URL is accepted only if it is `https` with the same host and port as the server. Otherwise the app returns `foreignOrigin` and sends nothing. This way a spec cannot take the JWT to another domain.

**Logout**
- Disconnecting from Settings or Connect, changing the server and deleting the account call `POST n8n-connect/logout` (6 s timeout, errors ignored). The server deletes the device's `fcm_token` and stops sending it push messages.
- If the Firebase session disappears another way (for example, a user change detected by the app), the app deletes the local session, calls `logout`, and deletes the automation permissions and the phone's FCM token ([§14.1](#141-per-app-permission)).
- When the server session closes (disconnecting, or access revoked with `not_allowed`, `account_disabled`, `email_not_verified` or `no_email`), the offline copy ([§11](#11-offline-mode)) and the automation permissions ([§14.1](#141-per-app-permission)) are also deleted. The inbox is not deleted when you disconnect.

**How to revoke access**

| You want to… | Do this | Effect |
|---|---|---|
| Cut one person's access to the whole server | `nc_users.enabled = false` | The app does not renew the session: when it does, the Core responds `not_allowed` (403) and the app deletes the session. A JWT already issued stays valid for up to 12 h. |
| Remove access to a single app | Remove their email from `allowed_emails` in `nc_apps` (empty = everyone) | Takes effect immediately (403 `app_forbidden`) only if the app uses "App access" ([§5](#5-how-to-create-an-app)). If it does not, the app only stops appearing in the catalog. |
| Cut all JWT sessions already issued (for example, a stolen session) | Rotate the secret of the JWT credential | All JWTs stop working immediately. Apps request a new session with Firebase automatically, so this **does not block** anyone. To block a person, use the first row. |
| Stop sending push to a device | Delete its row in `nc_devices` | It stops receiving push. It does not invalidate its JWT. |

**Validation**
- The `required` fields of the spec are for user experience only. The server must always validate what it receives.
- Each app webhook must also check access with the "n8n Connect · App access" sub-workflow (see [§5](#5-how-to-create-an-app)). The JWT proves who is calling, not that they may use that app.

**Credentials**: the ones needed for the JWT nodes and how to create them are in [n8n/README.md](../n8n/README.md).

---

## 3. Core endpoints

All routes are relative to `{server}/webhook/`. The constants are in `lib/core/app_config.dart`.

| Route | Method | Auth | Use in the app |
|---|---|---|---|
| `n8n-connect/info` | GET | public | Check that the server is n8n Connect |
| `n8n-connect/auth` | POST | Firebase ID token | Open a session (and renew it) |
| `n8n-connect/apps` | GET | JWT | App catalog |
| `n8n-connect/logout` | POST | JWT | Delete the device's push token |
| `n8n-connect/share` | POST | JWT | Send text or a shared link from another app (workflow "n8n Connect · Share", [§13](#13-sharing-with-n8n)) |

Each app also has its own `path` (see [§3.4](#34-app-spec-and-submit)).

### 3.1 GET `n8n-connect/info`

Response:
```json
{"service": "n8n-connect", "protocol": 1, "name": "My n8n", "firebaseProjectId": "my-firebase-project"}
```

Validation in the app:
- `service` other than `"n8n-connect"` → `not_n8n_connect`.
- `protocol` greater than 1 (`AppConfig.protocolVersion`) → `unsupported_protocol`.
- `firebaseProjectId` different from the app's Firebase project → `wrong_firebase_project`.

### 3.2 POST `n8n-connect/auth`

Headers: `Authorization: Bearer <Firebase ID token>`, `Content-Type: application/json`.

Body:
```json
{
  "device": {
    "id": "k3J9…",
    "name": "Pixel 8",
    "platform": "android",
    "appVersion": "1.0.0+3",
    "fcmToken": "dXy…"
  }
}
```
`fcmToken` is empty (`""`) if the phone has no FCM token.

Response 200:
```json
{
  "token": "eyJhbGciOi…",
  "expiresAt": "2026-11-03T00:00:00Z",
  "user": {"email": "you@email.com", "name": "Your name", "role": "admin"},
  "server": {"name": "My n8n"}
}
```
`token` and `expiresAt` (ISO 8601) are required; if either is missing, the app returns `bad_response`.

Errors (body `{"error": {"code", "message"}}`):

| Code | HTTP | Meaning |
|---|---|---|
| `invalid_token` | 401 | Firebase ID token is invalid or expired |
| `account_disabled` | 403 | The Firebase account is disabled |
| `no_email` | 403 | The Firebase account has no email |
| `email_not_verified` | 403 | The email is not verified |
| `not_allowed` | 403 | The account is not authorized: it has no row in `nc_users` or has `enabled = false` |
| `invalid_device` | 400 | `device.id` is missing or has an invalid format (16–64 characters `[A-Za-z0-9_-]`) |
| `upstream_error` | 424 | "The session could not be verified with Google. Try again in a few seconds." Google does not respond or fails for a reason other than an invalid token (network, 429, 5xx) |

### 3.3 GET `n8n-connect/apps`

Header: `Authorization: Bearer <JWT>`.

Response:
```json
{
  "apps": [
    {
      "id": "tools",
      "name": "Tools",
      "description": "Alarm, live panel, form and phone actions",
      "icon": "bolt",
      "color": "#0EA5E9",
      "path": "n8n-connect/apps/tools"
    }
  ]
}
```
- Entries without `id` or `path` are ignored.
- `icon`: name from the app's icon table ([§6](#6-ui-spec-schema-1)). Default `apps`.
- `color`: `#RRGGBB` or `#AARRGGBB`. If it is not valid, the primary color is used.
- `path`: path of the webhook that returns the app's spec.

The catalog is cached in memory. It refreshes when the list is pulled down, and also if the app cannot find an `id` (for example, when opening it from a push). A copy is also saved on the phone for offline mode ([§11](#11-offline-mode)).

### 3.4 App spec and submit

- **GET `{path}`** (JWT): returns the spec ([§6](#6-ui-spec-schema-1)). If it includes `refreshSeconds`, it is requested again at intervals ([§10](#10-live-dashboards-refreshseconds)).
- **POST/GET/PUT/PATCH/DELETE `{submit path}`** (JWT): returns the submit response ([§8](#8-submit-response)).

### 3.5 POST `n8n-connect/logout`

JWT header. Empty body. Response: `{"ok": true}`. The Core deletes the fcm_token of the session's device.

### 3.6 Error format

Any n8n error may include:
```json
{"error": {"code": "something_failed", "message": "Text for the user"}}
```
If `message` exists and the code is **not** one of the client codes in the table below, the app shows that text as is. Otherwise, it shows a message localized for the code.

Client codes (generated by the app itself, not by the server):

| Code | When |
|---|---|
| `network` / `timeout` | No network or no response (20 s, or 150 s for submit) |
| `session_invalid` | 401 without `error.code`, or 403 whose body is not a JSON object (JWT rejected). A 401 with `error.code` keeps that code |
| `not_found` | 404: the webhook does not exist. Usually an unpublished workflow or a mistyped path |
| `bad_response` | 2xx response that is not JSON, or auth without `token` |
| `http_<status>` | Another HTTP error without a code |
| `not_connected` / `signed_out` | No server session / no Firebase session |
| `app_not_found` | The app `id` is not in the catalog |
| `unsupported_spec` | `schema` greater than 1 |
| `bad_spec` | The spec has no valid screens |

---

## 4. Tables

The n8n data tables that the Core uses.

**`nc_users`**: who can sign in.

| Field | Type | Notes |
|---|---|---|
| `email` | text | Email of the Firebase account, **in lowercase**. Lookup key (the Core compares the email in lowercase) |
| `enabled` | boolean | `false` blocks access with `not_allowed` (see [§2](#2-security)) |
| `role` | text | Returned in `user.role` |
| `name` | text | Returned in `user.name` |

**`nc_devices`**: devices with a session. Upserted by `device_id` + `email`.

| Field | Type | Notes |
|---|---|---|
| `device_id` | text | `device.id` |
| `email` | text | Device owner |
| `uid` | text | Firebase uid |
| `name` | text | `device.name` (e.g. "Pixel 8") |
| `platform` | text | `device.platform` (`android`) |
| `fcm_token` | text | FCM token. Empty after logout. It is the target of push messages |
| `app_version` | text | `device.appVersion` |
| `last_seen` | date | Last time the device renewed its session |

**`nc_apps`**: app catalog.

| Field | Type | Notes |
|---|---|---|
| `app_id` | text | Returned as `id` in `GET n8n-connect/apps` |
| `name` | text | |
| `description` | text | |
| `icon` | text | Icon name ([§6](#6-ui-spec-schema-1)) |
| `color` | text | `#RRGGBB` |
| `path` | text | Spec path, e.g. `n8n-connect/apps/tools` |
| `enabled` | boolean | Only the `true` ones appear |
| `allowed_emails` | text | Comma-separated emails. Empty = all enabled users. Filters the catalog; for it to also block the app, the app must use "App access" ([§5](#5-how-to-create-an-app)) |
| `sort` | number | Ascending order in the catalog |

**`nc_inbox`**: texts sent from other apps with "Share" ([§13](#13-sharing-with-n8n)). The workflow saves one row per submission.

| Field | Notes |
|---|---|
| `email` | User who shares |
| `text` | Shared text or link |
| `subject` | Subject of the source app. Empty if it had none |
| `note` | Note entered in the app. Empty if none was written |
| `received_at` | Time of receipt |

---

## 5. How to create an app

1. **Design the spec** (JSON, [§6](#6-ui-spec-schema-1)) and decide what each button does ([§7](#7-actions)).
2. **Create the spec webhook** in n8n:
   - Webhook node, GET method, path `n8n-connect/apps/<id>`.
   - Authentication = "JWT Auth", with the JWT credential (see [n8n/README.md](../n8n/README.md)).
   - Respond with the spec JSON.
3. **Create the submit webhooks**, one per server action, with the same authentication. For example, POST `n8n-connect/apps/<id>/greet`. They respond with the JSON in [§8](#8-submit-response).
4. **Check access in each webhook** (the spec and each submit). Right after the Webhook, call the "n8n Connect · App access" sub-workflow (template [n8n/workflows/app-access.json](../n8n/workflows/app-access.json)), as [app-tools.json](../n8n/workflows/app-tools.json) does:
   - Execute Sub-workflow node with `app_id` = the app's id and `email` = `{{ $json.jwtPayload.email }}`.
   - IF node on `allowed`: if it is `true`, the workflow continues. Otherwise, respond 403 with `{{ { error: $json.error } }}`, which gives `{"error": {"code": "app_forbidden", "message": "…"}}`.

   The sub-workflow gives `allowed: true` only if the app is enabled in `nc_apps` and the email is in `allowed_emails` (or the list is empty). Without this check, `allowed_emails` only filters the catalog ([§2](#2-security)).

5. **Register the app** in `nc_apps`:

   | app_id | name | description | icon | color | path | enabled | allowed_emails | sort |
   |---|---|---|---|---|---|---|---|---|
   | hello | Hello | Says hello from n8n | notifications | #EA4B71 | n8n-connect/apps/hello | true | (empty) | 10 |

6. **Open the app** and pull down the app list to refresh it.

Minimal spec with a form and a button that sends data:

```json
{
  "schema": 1,
  "title": "Hello",
  "start": "home",
  "state": {"name": ""},
  "screens": [
    {
      "id": "home",
      "title": "Hello",
      "components": [
        {"type": "input", "key": "name", "label": "Your name", "required": true},
        {"type": "text", "text": "Type your name and tap Send", "style": "caption"},
        {
          "type": "button",
          "label": "Send",
          "icon": "send",
          "action": {"type": "submit", "path": "n8n-connect/apps/hello/greet", "loading": "Sending…"}
        }
      ]
    }
  ]
}
```

Response of the `greet` webhook (the body the app sent is `{"name": "Ana"}`):

```json
{"message": "Hello, Ana"}
```

---

## 6. UI spec (schema 1)

Response of the app's GET:

| Field | Required | Description |
|---|---|---|
| `schema` | no (default 1) | Format version. If greater than 1, the app returns `unsupported_spec` |
| `title` | no | Default title for the screens |
| `start` | no | `id` of the first screen. If it does not exist or is missing, the first screen is used |
| `state` | no | Initial values (object) |
| `screens` | yes | List of screens, or map `id → screen`. Without valid screens: `bad_spec` |
| `refreshSeconds` | no | Seconds between silent reloads. Number or numeric text; minimum 10 (smaller values are ignored). See [§10](#10-live-dashboards-refreshseconds) |

**Screens**
- As a list: `[{"id": "home", "title": "…", "components": [ … ]}]`. Entries without `id` are ignored.
- As a map: `{"home": {"title": "…", "components": [ … ]}}`. The key is the `id`.
- The screen's `title` is the title in the bar. If it is missing, the spec's `title` is used and, if that is missing too, the app name.

**State**
- The state starts from `state` and is filled in by the controls (`input`, `switch`, `select`, `date`, `time`).
- Each control writes its value to `state[key]`. `input` stores text; `switch` stores a boolean; `select` stores the chosen `value`; `date` stores `yyyy-MM-dd`; `time` stores `HH:mm`.
- Keys starting with `_` are local only: they are not sent on submit ([§8](#8-submit-response)).

**`{{…}}` templates**
- `{{key}}` is replaced by the state value. It can be a dotted path (`{{user.name}}`) or use list indexes (`{{items.0.title}}`).
- Characters allowed in the key: letters, digits, `_`, `.`, `$` and `-`.
- Missing key: shown as empty in text.
- **Raw value rule**: if the string is only a placeholder (`"{{hour}}"`), the original value is used (number, boolean, object). This applies to action parameters and to `visible`. In component text, the result is always text.

**`visible`**: any component can have `visible`. It is evaluated with the template and is false if it is `null`, `false`, `0`, `""`, `"false"`, `"0"`, `"no"`, an empty list or an empty object. Any other value shows the component. Without `visible`, the component is shown.

**`required` validation**: when a `submit` is sent, the app checks only the top-level components of the current screen (not those inside a `card`). If an `input` with `required: true` is empty, it sends nothing and shows `Fill in "<label>"`.

**Icons**: names from the table in `lib/features/apps/app_style.dart`. Names that are not in that table are ignored. Full list: `add`, `alarm`, `alarm_add`, `apps`, `arrow_back`, `arrow_forward`, `bolt`, `calendar_today`, `camera`, `check`, `check_circle`, `close`, `cloud`, `delete`, `directions_car`, `edit`, `email`, `error`, `event`, `event_available`, `favorite`, `fitness_center`, `home`, `info`, `lightbulb`, `link`, `list`, `local_cafe`, `location_on`, `lock`, `music_note`, `notifications`, `person`, `phone`, `play_arrow`, `power`, `refresh`, `restaurant`, `schedule`, `search`, `send`, `settings`, `shopping_cart`, `star`, `stop`, `thermostat`, `timer`, `warning`, `wb_sunny`, `work`.

**Components** (the fields are exactly the ones read by `lib/features/apps/spec_view.dart`):

| `type` | Fields | Notes |
|---|---|---|
| `text` | `text`, `style` (`title`, `subtitle`, `caption`; default body), `align` (`start`, `center`, `end`) | Selectable text. `text` supports templates |
| `banner` | `text`, `tone` (`info` by default, `success`, `warning`, `error`), `icon` | Colored notice. `tone` supports templates |
| `card` | `title`, `subtitle`, `icon`, `components` (list) | Container. Its components follow the same rules |
| `image` | `url`, `height` | `https` only. If loading fails, nothing is shown |
| `divider` | — | Separator line |
| `spacer` | `height` (px, 16 by default) | Vertical space |
| `input` | `key` (required), `label`, `hint`, `keyboard` (`text`, `number`, `email`, `phone`, `url`, `multiline`), `obscure` (boolean), `required` (boolean) | Not shown without `key`. `number` only accepts digits, `.`, `,` and `-` |
| `switch` | `key` (required), `label`, `description` | Stores a boolean |
| `select` | `key` (required), `label`, `style` (`chips`, `radio`; default dropdown), `options`: `[{value, label, description, disabled}]` | `value` is required on each option; options without it are ignored. `label` defaults to `value` |
| `date` | `key` (required), `label` | Opens the date picker. Stores `yyyy-MM-dd` |
| `time` | `key` (required), `label` | Opens the time picker. Stores `HH:mm` |
| `button` | `label`, `icon`, `style` (default filled; `tonal`, `outlined`, `text`), `action` and/or `actions` | Without actions, the button is disabled |
| `list` | `items`: `[{title, subtitle, trailing, icon, action / actions}]` | Tapping an item runs its actions. `trailing` replaces the arrow |
| `details` | `items`: `[{label, value}]` | Label/value pairs |
| `slider` | `key` (required), `label`, `min` (0), `max` (100), `step`, `unit` | Slider with the value and `unit` attached to the number (no space). Without `step` it is continuous; with `step` it shows tick marks, and if `step` gives more than 1000 divisions it is continuous. If `max` ≤ `min`, `max` becomes `min` + 1. Stores an integer if `min` and `step` (or `min` and `max`, without `step`) are integers; otherwise a decimal with 2 places. Without a value it starts at `min` |
| `checkbox` | `key` (required), `label`, `description` | Checkbox with an optional description. Stores a boolean |
| `multiselect` | `key` (required), `label`, `options`: `[{value, label, disabled}]` | Multiple-selection chips. Stores the list of `value`s in the order of `options`; values not in `options` are kept at the end. Options without `value` are ignored. `label` defaults to `value` |
| `stepper` | `key` (required), `label`, `min`, `max`, `step` (1) | − and + buttons with the value between them. Without `min` or `max`, there is no limit on that side. The button is disabled at the limit. Stores an integer if the step and the value are integers; otherwise a decimal with 2 places. Without a value it starts at `min` (or 0) |
| `progress` | `value`, `max`, `label` | Progress bar with a percentage. Without `max` it is 100 if `value` is greater than 1, and 1 otherwise. Clamped between 0 % and 100 % |
| `metric` | `label`, `value`, `unit`, `icon`, `tone`, `caption` | Indicator card: label, large value, unit and optional footer. `tone` `success` (green), `warning` (amber) or `error` colors the value; any other value uses the normal color |
| `grid` | `columns` (2; clamped to 1–4), `components` | Rows of equal columns separated by 12 px. Children with `visible` false are removed before laying out, so the rest is reflowed. Each child is drawn like any other component |
| `table` | `columns` (headers), `rows` (lists of cells) | Read-only table with horizontal scrolling. Short rows are padded with empty cells, long rows are cut to the number of headers, and rows that are not lists are skipped. Without `columns` nothing is shown |
| `graph` | `nodes`: `[{id, label, subtitle, icon, tone, badge, action / actions}]`; `edges`: `[{from, to, label, dashed}]` | Vertical node map, top to bottom, with as many columns as the width allows. `id` is required and must be unique; `label` defaults to `id`. `tone` `success` (green), `warning` (amber), `error` (red) or `muted` (half opacity). `label`, `subtitle`, `badge`, `tone` and the edge `label` support templates. Nodes with actions are tappable (not while a submit runs). Edges with unknown ids are ignored; a repeated edge is drawn once. Each independent flow (nodes joined by edges) is drawn as its own block, in the order of its first node, and nodes without edges go together in a last block. Edges leave from the bottom of a node and enter at the top; several outputs or inputs of one node are spread along its side and the edge `label` is shown next to the output. An edge that would cross other nodes goes down the left side, and an edge into a node that is already on the path (a loop) goes up the right side. `dashed` edges have no arrowhead |

In the newer components, `min`, `max`, `step`, `value` and `columns` accept templates; they are read as numbers after resolution. Text fields also accept templates.

Example of a `graph` (the `icon` names are the ones in the table above):

```json
{
  "type": "graph",
  "nodes": [
    {"id": "Webhook", "label": "Webhook", "subtitle": "webhook", "icon": "bolt", "tone": "success", "badge": "3 items"},
    {"id": "Code", "label": "Code", "subtitle": "transform"},
    {"id": "Notify", "label": "Notify", "tone": "error", "action": {"type": "toast", "message": "Failed"}}
  ],
  "edges": [
    {"from": "Webhook", "to": "Code"},
    {"from": "Code", "to": "Notify", "label": "false", "dashed": true}
  ]
}
```

An unknown `type` is shown as "Unsupported component: <type>". It does not break the screen.

Example of a `select` in chips style with `visible`:

```json
{
  "type": "select",
  "key": "day",
  "label": "Day",
  "style": "chips",
  "options": [
    {"value": "mon", "label": "Monday"},
    {"value": "tue", "label": "Tuesday", "disabled": true, "description": "Closed"}
  ],
  "visible": "{{mode}}"
}
```

---

## 7. Actions

An action is an object with a `type`, its parameters and, optionally, `confirm`:

```json
{"type": "set_alarm", "hour": 7, "minute": 30, "label": "Gym", "confirm": "Set an alarm for 7:30?"}
```

**Where they appear**: in `action` / `actions` of `button` and of `list` items; in the `actions` key of a submit response; in `actions` of a push; and in the response of a `report` ([§14.4](#144-automation-actions)).

**Execution**
- Parameters are resolved with templates (raw value rule) right before running.
- They run in order. The list stops at the first error or if the user cancels a confirmation.
- Errors are shown in a notice.
- An unknown `type` produces an error saying the action is not supported, and the list stops.

**`confirm`**
- Text: `"confirm": "Are you sure?"`.
- Object: `{"title", "message", "confirmLabel"}`. All three are templates.
- Without `message` there is no confirmation, even if the object exists.

**Types**

| `type` | Parameters | Needs an open app screen | Effect |
|---|---|---|---|
| `submit` | `path` or `url` (required), `method` (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`; default `POST`), `body` (object), `keys` (list of state keys), `loading` (overlay text) | Yes | Sends data and applies the response ([§8](#8-submit-response)) |
| `navigate` | `screen` (id) | Yes | Opens a screen. If it is already on the stack, goes back to it |
| `back` | — | Yes | Goes back. On the first screen, it closes the app |
| `reload` | — | Yes | Requests the spec again. Resets the state and the stack |
| `set_state` | `values` (or `state`, object) | Yes | Merges values into the state |
| `open_app` | `app` (app id) | No | Opens another app from the catalog |
| `toast` | `message` | No | Brief notice |
| `dialog` | `title` (optional), `message` | No | Dialog with an OK button |
| `notify` | `title` (default is the app name), `body` | No | Local notification |
| `set_alarm` | `hour` and `minute`, or `time` (`"HH:mm"`); `label`; `days` (1 = Sunday … 7 = Saturday); `vibrate` (boolean); `skipUi` (default `true`) | No | Creates an alarm in the Clock app. `hour` 0–23, `minute` 0–59 |
| `set_timer` | `seconds`, or `minutes`; `label`; `skipUi` (default `true`) | No | Timer from 1 s to 24 h |
| `calendar_event` | `title` and `start` (required, ISO 8601); `end`; `location`; `description`; `allDay` (boolean) | No | Opens the calendar event form, pre-filled. `end` defaults to `start` + 1 h |
| `open_url` | `url` | No | Opens the link. Allowed schemes: `https`, `http`, `mailto`, `tel`, `geo` |
| `copy` | `text` | No | Copies to the clipboard |
| `share` | `text` (required), `subject` | No | Opens the Android share sheet with the text |
| `dial` | `number` (required) | No | Opens the dialer with the number. It does not call |
| `sms` | `number` (required), `body` | No | Opens the messaging app with the recipient and the text (`body` only if it is not empty) |
| `email` | `to` (required), `subject`, `body` | No | Opens a new email. Spaces are encoded as `%20` |
| `maps` | `query`, or `lat` and `lng` (number or numeric text), `label`, `navigate` (boolean, default `false`) | No | Opens Maps at a place, or starts navigation with `navigate: true`. If there is a `query`, the coordinates are ignored; `label` is only used with coordinates. Without `query` or coordinates, or with lat/lng outside −90…90 and −180…180, it fails with an error |
| `vibrate` | `style`: `light`, `medium`, `heavy` or `vibrate` (default) | No | Haptic vibration. Any other value is an error |
| `show_alarms` | — | No | Opens the list of alarms in the Clock app |
| `open_settings` | `panel` (required; not case-sensitive) | No | Opens a system setting: `wifi`, `bluetooth`, `location`, `display`, `sound`, `battery`, `date`, `notifications` (of this app) or `app` (information about this app). Any other panel is an error |
| `launch_app` | `package` (required, e.g. `com.whatsapp`) | No | Opens an app by its package name. If the format is not valid (at least two segments separated by dots, each starting with a letter), it is an error |
| `read_clipboard` | `key` (required) | Yes | Copies the clipboard text to `state[key]` (empty if there is no text) |
| `schedule_alarm` | `id` (default `default`), `at` (required, ISO 8601), `label`, `body` | No | Schedules an alarm of the app itself that rings even when the app is closed. With the same `id`, it replaces the previous one. Automatic ([§14.4](#144-automation-actions)) |
| `cancel_alarm` | `id` (default `default`) | No | Cancels that app's own alarm with that `id`. Automatic |
| `report` | `path` (required), `include` (default `["location"]`), `data` (object) | No | Sends phone data by `POST` to `path` and runs the `actions` of the response. Automatic ([§14.4](#144-automation-actions)) |
| `request_permission` | `permission` (required): `location`, `location_always` or `notifications` | No | Asks for a system permission. Not automatic |

Notes on device actions:
- `share`, `dial`, `sms`, `email`, `maps`, `show_alarms`, `open_settings` and `launch_app` open system apps with an intent: they only work on Android.
- `dial` and `sms` encode the number in the URI. `+34 600 123 123` arrives as `%2B34%20600%20123%20123`. It has not been tested on every dialer.
- `launch_app` does not need `<queries>` in the manifest: the app launches the intent directly with `startActivity`, which is not affected by Android 11+ package visibility. If the app is not installed, an error is shown.
- `set_alarm` opens the Clock app and does not work in automations. `schedule_alarm` is the app's own alarm: see [§14.6](#146-clock-alarm-and-app-alarm).

Example response with two actions:

```json
{
  "actions": [
    {"type": "set_alarm", "time": "06:30", "label": "Gym"},
    {"type": "toast", "message": "Alarm set"}
  ]
}
```

---

## 8. Submit response

**Request**
- The method is the action's (`method`, `POST` by default).
- With `POST`, `PUT`, `PATCH` or `DELETE`, the content is sent as JSON in the body.
- With `GET`, the content goes in the query string. Values are converted to text; `null` becomes an empty string.
- Content, in this priority order:
  1. `body`, if the action has it (object).
  2. `keys`, only those state keys.
  3. The whole state, except the keys that start with `_`.
- The `Authorization: Bearer <JWT>` header is added by the app.
- The app's timeout is 150 s. A proxy with a shorter time limit cuts the request off earlier (see Recommendations below). While waiting, an overlay with the `loading` text appears and the controls are disabled. The back gesture does not leave it.

**Response**: a JSON object with these fields, all optional. The app applies them in this order:

| Order | Field | Effect |
|---|---|---|
| 1 | `spec` | Replaces the whole spec (schema 1). The state goes back to the new spec's `state` and the stack to `start` |
| 2 | `state` | Merges values into the state (overwrites keys) |
| 3 | `screen` | Navigates to that screen (id) |
| 4 | `message` | Shows a notice |
| 5 | `actions` | Runs the actions ([§7](#7-actions)). Accepts a list or a single object |

- An empty 2xx response does nothing.
- A 2xx response that is not JSON produces `bad_response`.
- A 2xx response that is a JSON list is ignored.

**Errors**: see [§3.6](#36-error-format). A 404 means the webhook does not exist or the workflow is not published.

**Recommendations for workflows**
- If you put a proxy such as Cloudflare in front of n8n, it replaces the body of 502/504 responses and cuts requests off at 100 s (error 524): respond with 4xx or 424 and keep each request below that limit.
- If a dependency fails, use 424 with `error.code` and `error.message`.
- Always respond with JSON.

Full response example:

```json
{
  "message": "Booking confirmed",
  "state": {"booked": true},
  "screen": "summary",
  "actions": [
    {"type": "set_alarm", "time": "06:30", "label": "Gym"}
  ]
}
```

---

## 9. Push n8n → phone

**Who sends it**: the "n8n Connect · Send to phone" sub-workflow (template [n8n/workflows/send-to-phone.json](../n8n/workflows/send-to-phone.json)), called from another workflow with **Execute Sub-workflow**.

Inputs:

| Field | Description |
|---|---|
| `email` | Target user. It is sent to all their devices that have an `fcm_token` |
| `title` | Notification title |
| `body` | Body |
| `actions` | Array of actions ([§7](#7-actions)). Empty if it is only a notice |
| `app` | Associated app id (optional). Tapping the notification without actions opens that app |

Output: `{"sent": n, "failed": n, "unregistered": ["device_id", …]}`, or `{"sent": 0, "failed": 0, "reason": "no_devices"}` if the user has no devices with a token. `unregistered` lists the `device_id`s whose FCM token is no longer valid (FCM responds 404 or `UNREGISTERED`). The template only reports them: it does not delete those rows.

Delivery: FCM v1 **data** message, high priority, `ttl` 3600 s.

**Message format** (data; all values are strings):

```json
{
  "nc": "1",
  "id": "5f0c…",
  "title": "Gym",
  "body": "07:30",
  "actions": "[{\"type\":\"set_alarm\",\"hour\":7,\"minute\":30,\"label\":\"Gym\"}]",
  "app": "tools",
  "to": "user@example.com"
}
```

- `nc` must be `"1"`. Without that field, the app does not treat the message as an n8n Connect command.
- `actions` arrives as JSON text. The app also accepts a JSON list directly.
- `id` avoids duplicates: if the same `id` arrives twice in the same app session, the second one is ignored.
- `to` is the recipient's email in lowercase (the `email` input of the sub-workflow). If it does not match the connected account, the app discards the push, both in the foreground and in the background ([§14.2](#142-what-can-run-without-asking)). Without `to`, there is no such check.

**Behavior on the phone**

| App state | Without `actions` | With `actions` |
|---|---|---|
| Open (foreground) | Normal notification | "n8n wants to run actions" dialog with *Run* / *Ignore*. If the "Run n8n actions automatically" setting is on, it runs without asking (a notice with the `title` is shown). The confirmation of each action (`confirm`) is still respected |
| Background or closed | Notification in the "n8n" channel. Tapping it opens the app (if there is an `app`) | Notification with a **Run** button. Tapping *Run* runs the actions without a dialog and then sends the app to the background. Tapping the body opens the confirmation dialog |

The reason for the button: Android blocks opening activities (alarm, calendar) from the background. That is why actions only run when the user taps the button or opens the app.

Exception: if the app has automation permission and all its actions are automatic, the push runs by itself, even with the app closed, with no dialog or button ([§14](#14-automations)).

FCM messages with a `notification` block (without `nc`): in the background the system shows them; in the foreground the app shows them as a local notification.

Each push that the app receives in the foreground or that the user opens is recorded in the inbox ([§12](#12-n8n-inbox)), and so are the automations run with the app closed ([§14.3](#143-how-it-runs)).

**Testing without n8n**: `tools/send_push.py`, see the [README](../README.md#testing-a-push-with-toolssend_pushpy).

---

## 10. Live dashboards (refreshSeconds)

A spec can ask the app to read it again on its own at intervals:

```json
{"schema": 1, "title": "Orders", "refreshSeconds": 60, "start": "home", "state": {"pending": 0}, "screens": [{"id": "home", "components": [{"type": "metric", "label": "Pending", "value": "{{pending}}"}]}]}
```

- `refreshSeconds`: seconds between reloads. Accepts a number or numeric text. Values less than 10 (`AppSpec.minRefreshSeconds`) or invalid values are ignored: the spec does not reload on its own.
- On each reload, the app requests the spec again (`GET {path}`) and:
  - Replaces the whole spec with the new one.
  - Merges the `state` of the new spec over the current state: each key that the spec includes is updated **only if the user has not changed it** since the last load (a half-filled form keeps what was typed); the rest of the state is kept.
  - Keeps the screen stack if all its screens exist in the new spec. If any of them no longer exists, it goes back to `start`.
- The reload is skipped if a submit is in progress, another load is in progress, the app is in the background, or the screen is covered by another route.
- An error in a reload is not shown: the screen stays as it was. If the failure is a network one and a saved copy exists, the copy is shown ([§11](#11-offline-mode)).
- The timer starts again each time a spec is applied.
- A manual reload (refresh icon or pull down) is not silent: it resets the state and the stack, as before.
- The top bar shows "Updated HH:mm" after each successful load, also in apps without `refreshSeconds`.

> Values that come from the server (metrics, times, counters) refresh on their own; values the user has edited are kept. A manual reload (⟳ button or `reload` action) does reset the state and the screen.

---

## 11. Offline mode

The app keeps a copy of what it receives from the server so it can show it when there is no network.

- **What is saved**: the catalog (`GET n8n-connect/apps`) and each app's spec (`GET {path}`), as received (JSON re-serialized), together with the time they were saved. Submits and their responses are not saved.
- **Where**: SharedPreferences, with the keys `nc.cache.apps|{server}` and `nc.cache.spec|{server}|{app id}`. There is one copy per server, unencrypted.
- **When it is used**: only if the request fails with `network` or `timeout` ([§3.6](#36-error-format)). Other errors (401, 404, 5xx…) are shown as they are. Without a copy, the error is shown.
- **What the user sees**: a notice "Offline. Showing data saved at HH:mm." over the catalog or over the app. The time is `HH:mm` if the copy is from today and `dd/MM HH:mm` if it is not. A successful response from the server removes the notice.
- **What does not work offline**: `submit` never uses the copy and fails with `network`. Actions that only use the phone (`toast`, `dialog`, `open_url`, alarms…) do work.
- **Deletion**: when disconnecting, or when the server revokes access (`not_allowed`, `account_disabled`, `email_not_verified`, `no_email`), all `nc.cache.*` keys are deleted. Changing the server does not delete them: each server has its own keys.

---

## 12. n8n inbox

The inbox stores the n8n pushes and the result of each one. It opens with the inbox icon on the app list screen (route `/inbox`).

**What gets in**: each push with `nc: "1"` ([§9](#9-push-n8n--phone)) that arrives while the app is open, or that the user opens from a notification (by tapping it or with the *Run* button). A push that arrives while the app is closed or in the background, and that the user does not open, does not enter the inbox, unless it runs as an automation ([§14.3](#143-how-it-runs)).

**Statuses**

| Status | When |
|---|---|
| Pending | As soon as the push arrives, while the app decides what to do with it |
| Executed | It had no `actions` (it was a notice), or all its actions ran |
| Ignored | The user did not accept the confirmation dialog (Cancel or tapping outside it) |
| Failed | An action failed, or the confirmation (`confirm`) of an action was cancelled |

**Run from the inbox**: the *Run* button appears only if the push has `actions`. It runs the list without the general dialog (actions with `confirm` still ask for confirmation) and saves the result: Executed or Failed. While it runs, the button is disabled. Actions that need an open app screen ([§7](#7-actions)) fail here.

**What each entry shows**: a status icon (its name appears when you long-press it), the title or "n8n message" if it is empty, the body, one line per action, and the date and time received.

**Storage**
- Key `nc.push.history`: JSON list, most recent first, with a maximum of 50 entries.
- A push with the same `id` as an existing entry updates that entry's status and content. It keeps its position and its received date.
- Corrupt data is discarded without breaking the inbox.
- The *Clear inbox* button (with confirmation) deletes all the entries.

---

## 13. Sharing with n8n

From any app, the Android Share menu (text or link, `text/plain`) includes **n8n Connect**.

**On the phone**
1. The app receives the text and the subject from the source app (`EXTRA_TEXT` and `EXTRA_SUBJECT`).
2. If the app was already open, it picks the content up immediately; if not, it waits. Until there is a server session, the content lives only in memory: if the app closes first, it is lost.
3. The **Share to n8n** screen opens, with the subject (only if there is one), the selectable text (maximum height 320 px, scrollable), the *Note (optional)* field and the *Send to n8n* button.
4. When you send, the button shows a loading indicator and the note field is locked. The request is:

```
POST n8n-connect/share      (JWT)
{"text": "https://example.com/article", "subject": "Article", "note": "Read on Sunday"}
```

`subject` is sent as an empty string if there is no subject. `note` is sent without leading or trailing spaces.

5. Response: the app shows `message` (or "Sent to n8n." if it is empty), runs `actions` if there are any, and closes the screen. The actions run even if the user left while waiting. Since no app screen is open, those that need one fail ([§7](#7-actions)).
6. If sending fails, an error card appears on the screen. The text and the note are kept so you can retry.

If other content arrives while the screen is already open, another screen opens on top of it.

**In n8n** (workflow "n8n Connect · Share")
- POST Webhook node `n8n-connect/share`, with *Authentication = "JWT Auth"*, like the other webhooks ([§2](#2-security)).
- Receives `{text, subject, note}`.
- Saves a row in the `nc_inbox` table ([§4](#4-tables)).
- Responds with JSON `{"message": "…"}`. It can add `actions` ([§7](#7-actions)), which the app runs.

---

## 14. Automations

An automation is an n8n push whose actions run by themselves on the phone: with no dialog and, with the app closed, with no notification if everything goes well. For that to happen, the user must allow it for each app, and the push must meet a fixed rule.

### 14.1 Per-app permission

- The user grants it on the app's screen, with the `automation` component ([§14.7](#147-automation-and-permission-components)). In **Settings → Automations**, the allowed apps of the connected server are listed; a switch removes each permission.
- It is stored in SharedPreferences, unencrypted, with the key `nc.auto.{server}|{appId}`. It is per server: changing the server does not delete the permission of the previous server, but it does not apply to the new one.
- **All** permissions and the phone's FCM token (`push.deleteToken`) are deleted when the server session closes (`onSessionClosed` in `lib/main.dart`): when disconnecting (also from Settings, when signing out or deleting the account), when switching Firebase accounts, and when the server revokes access. Disconnecting and switching accounts also call `logout`; revocation does not.

### 14.2 What can run without asking

The automatic actions (`automaticActionTypes` in `lib/features/actions/action_spec.dart`) are `schedule_alarm`, `cancel_alarm`, `report` and `notify`.

A push is decided by `decide()` in `lib/features/automation/background_automation.dart`, in this order:

| Result | When |
|---|---|
| Discard (`drop`) | There is no server session. Or the push includes `to` and it does not match the session's email (case-insensitive) |
| Ask (`ask`) | `app` is missing, there are no actions, some action is not automatic or has `confirm`, or the app does not have permission |
| Run (`run`) | There is an `app`, all the actions are automatic and have no `confirm`, and the app has permission |

- Without `to` there is no recipient check. The `send-to-phone` template always sends it ([§9](#9-push-n8n--phone)).
- With `automaticOnly`, the executor rejects any action outside the list. The same applies to the actions in a `report` response: if one of them is not automatic, the whole `report` fails.

### 14.3 How it runs

| Case | `run` | `drop` | `ask` |
|---|---|---|---|
| App open | Runs without a dialog, even if the "Run n8n actions automatically" setting is off. If it fails, the error is shown in a notice. In the inbox, it changes from Pending to Executed or Failed | Ignored. It stays in the inbox as Pending | Normal dialog ([§9](#9-push-n8n--phone)) |
| App closed or in the background | Runs in the FCM isolate (`firebaseMessagingBackgroundHandler`), with no notification if it succeeds. Saved to the inbox as Executed or Failed. If it fails, an error notification with the push's title is shown | Ignored with no notification, and does not enter the inbox | Normal notification with the *Run* button |

- If the automation throws an exception before running, the push is shown as a normal notification ([§9](#9-push-n8n--phone)).
- Background entries are saved separately and move into the inbox when the app opens ([§12](#12-n8n-inbox)).

### 14.4 Automation actions

**`schedule_alarm`** `{id, at, label, body}`
- `at`: ISO 8601. With an offset (`2026-11-03T06:45:00+01:00`) it is the exact instant; without an offset it is taken as the phone's local time. It must be in the future; otherwise the action fails.
- `id` (default `default`) identifies the alarm within the app. Scheduling another alarm with the same `id` in the same app replaces it.
- `label` (default `n8n`) is the title and `body` (default the time `HH:mm`) is the text.
- It is the app's own alarm (`alarm` plugin): it rings with the app closed, with the phone's default tone, vibrates, opens a full-screen screen and survives reboots. In the foreground it shows a notice with the time.

**`cancel_alarm`** `{id}`: cancels the app's alarm with that `id`.

**`report`** `{path, include, data}`
- Makes `POST {path}` with the JWT (renews the session if needed; 60 s timeout). Body: `timezoneOffsetMinutes`, `timezone`, `collectedAt`, `location` (according to `include`), `app` (the push's app id) and `data` (the object, as is).
- `include` defaults to `["location"]`; empty or absent means that same value. Names it does not recognize are ignored; the time zone is always sent ([§14.5](#145-phone-data)).
- If the response has `actions`, they run next. In the foreground, those with `confirm` ask for confirmation. In the background, only the automatic ones run ([§14.2](#142-what-can-run-without-asking)).
- Without network it fails. In the background, location requires the *always* permission (`location_always`); without it, Android does not provide the position.

**`request_permission`** `{permission}`: `location`, `location_always` or `notifications`. It shows the system dialog. For `location_always`, if location is only allowed "while using the app", it opens the app's settings. If location services are off, it opens their settings. It is not automatic: a push that includes it always asks.

### 14.5 Phone data

`DeviceContext.collect(include)` (`lib/features/device_context/device_context.dart`) produces, for example:

```json
{
  "timezoneOffsetMinutes": 60,
  "timezone": "CET",
  "collectedAt": "2026-11-02T20:30:00.000Z",
  "location": {"lat": 40.4168, "lng": -3.7038, "accuracy": 18.5, "timestamp": "2026-11-02T20:29:58.000Z"}
}
```

- `location` is a position (`lat`, `lng`, `accuracy`, `timestamp`) or `{"error": "disabled" | "permission_denied" | "timeout"}`. `disabled`: location services are off. `timeout`: there is no recent position within 15 s and no last known position. `permission_denied`: the permission is missing or there was a failure.
- A `submit` with `include: ["location"]` adds the same content as `_device` in the body ([§7](#7-actions)). Without `include`, none of this is sent.

### 14.6 Clock alarm and app alarm

| | `set_alarm` | `schedule_alarm` |
|---|---|---|
| Where it rings | The system Clock app | The app itself (`alarm` plugin) |
| With the app closed | No: Android blocks opening the Clock app from the background | Yes |
| In automations | No | Yes |
| Cancel | From the Clock app | `cancel_alarm` |
| Where it is shown | In the Clock app (`show_alarms`) | **n8n alarms** screen (`/alarms`) |
| Phone restart | Handled by the clock app | Survives |

- **n8n alarms** (Settings → Automations): lists the app's own alarms with time, date, label and app. Those that have already passed appear dimmed and marked "Passed". Cancelling asks for confirmation and cancels that alarm, the same as `cancel_alarm`.
- **Alarm screen**: with the app open, when an app alarm rings, it opens full screen with the time, the label and two buttons, **Stop** and **Snooze 5 min** (it rings again 5 minutes later with the same label). With the app closed, the plugin gives the alert with a full-screen notification that has a *Stop* button.
- **Known limitation**: with the app open, if the alarm that rings again is the same one that was just stopped or snoozed, the alarm screen does not open (`AlarmEngine.ringing` uses `distinct`, which only compares against the previous event). Sound is handled by the `alarm` plugin.

### 14.7 automation and permission components

| `type` | Fields | What it shows |
|---|---|---|
| `automation` | `label`, `description` | Switch to let n8n run this app's actions without asking. Stores the permission from [§14.1](#141-per-app-permission). Without texts, it uses "Automatic actions" and a default description |
| `permission` | `permission` (`location`, `location_always` or `notifications`), `label`, `description` | The permission's status and the right button (see below). Without texts, it uses the permission's default titles |

`permission` states:
- **Granted**: green check with "Granted".
- **Denied**: **Grant** button, which asks for the permission.
- **Permanently denied**: **Open settings** button. For `notifications`, the button asks for the permission again, and Android may show nothing.
- **Unavailable**: text only, no button.

The status is read again when the component is shown and each time the app returns to the foreground.

## 15. Examples

### 15.1 Alarm

It is a screen of the Tools app (workflow "n8n Connect · App · Tools", `alarm` screen): POST `n8n-connect/apps/tools/alarm`.

The app shows a time and a label. When the button is tapped, it sends the state and the workflow responds with a `set_alarm` action. Abbreviated form of the spec (the real one is in the workflow):

```json
{
  "schema": 1,
  "title": "Alarm",
  "start": "home",
  "state": {"alarm_time": "07:30", "alarm_label": "Gym"},
  "screens": [
    {
      "id": "home",
      "components": [
        {"type": "time", "key": "alarm_time", "label": "Time"},
        {"type": "input", "key": "alarm_label", "label": "Label"},
        {
          "type": "button",
          "label": "Set alarm",
          "icon": "alarm_add",
          "action": {"type": "submit", "path": "n8n-connect/apps/tools/alarm", "loading": "Scheduling…"}
        }
      ]
    }
  ]
}
```

Response of `alarm` (the app sets the alarm and shows a notice):

```json
{"actions": [{"type": "set_alarm", "hour": 7, "minute": 30, "label": "Gym"}]}
```

The same alarm, without opening the app, from a scheduled workflow, sent as a push (see `tools/send_push.py` in the README):

```bash
python3 tools/send_push.py --service-account /path/to/service-account.json --token FCM_TOKEN \
  --title "Gym" --body "07:30" \
  --actions '[{"type":"set_alarm","hour":7,"minute":30,"label":"Gym"}]' --app tools
```

With that command, in the foreground the confirmation dialog appears; in the background, the notification with the *Run* button appears.

### 15.2 Tools

The importable template is in [n8n/workflows/app-tools.json](../n8n/workflows/app-tools.json), and the server setup is in [n8n/README.md](../n8n/README.md).

Workflow: "n8n Connect · App · Tools" (path `n8n-connect/apps/tools`). It is the demo app for the new components and the device actions. Illustrative form, not a copy of the workflow:

```json
{
  "schema": 1,
  "title": "Tools",
  "refreshSeconds": 30,
  "state": {"steps": 3, "volume": 40, "mode": true},
  "screens": [
    {
      "id": "home",
      "components": [
        {"type": "slider", "key": "volume", "label": "Volume", "min": 0, "max": 100, "step": 5, "unit": "%"},
        {"type": "stepper", "key": "steps", "label": "Steps", "min": 0, "max": 10},
        {"type": "checkbox", "key": "mode", "label": "Compact mode"},
        {
          "type": "grid",
          "columns": 2,
          "components": [
            {"type": "metric", "label": "Steps", "value": "{{steps}}", "unit": "/ 10", "icon": "bolt", "tone": "success"},
            {"type": "progress", "label": "Goal", "value": "{{steps}}", "max": 10}
          ]
        },
        {"type": "table", "columns": ["Action", "Status"], "rows": [["Share", "{{steps}} steps"], ["Map", "Madrid"]]},
        {"type": "button", "label": "Share", "icon": "send", "action": {"type": "share", "text": "I've walked {{steps}} steps"}},
        {"type": "button", "label": "Map", "icon": "location_on", "style": "outlined", "action": {"type": "maps", "lat": 40.4168, "lng": -3.7038, "label": "Madrid"}},
        {"type": "button", "label": "Vibrate", "icon": "bolt", "style": "tonal", "action": {"type": "vibrate", "style": "medium"}}
      ]
    }
  ]
}
```

### 15.3 Design example: agenda-based wake-up alarm

This is not a real workflow but a design: every night it calculates tomorrow's wake-up time from the agenda, the phone's location and the travel time.

> There is no template in `n8n/workflows/`. It depends on personal data (agenda, location and the user's preferences) and on the user's own credentials. Use it as a design reference, not as a workflow to import.

- **Per-user preferences**: a custom data table with the travel mode (`driving` car, `transit` public transport, `bicycling` bike or `walking` on foot), the preparation minutes, the margin minutes, the fallback wake-up time and the calendar.
- **Every night at a fixed time**, n8n sends a push to the phones of the users who have allowed the app's automations ([§14.1](#141-per-app-permission)). The push carries an action that the phone runs by itself:

  ```json
  [{"type": "report", "path": "…", "include": ["location"], "data": {}}]
  ```

- **The phone responds** with its location and time zone ([§14.5](#145-phone-data)). If the app is closed, the location requires the *always* permission.
- **n8n** reads the first event tomorrow that has a location in the user's calendar. It asks a routing service (for example, Google Maps Distance Matrix) for the travel time from the phone's location, using the chosen mode and arriving at the event's start time.
- **Wake-up time** = event start − travel − preparation − margin. n8n responds with:

  ```json
  {"actions": [{"type": "schedule_alarm", "id": "wakeup", "at": "2026-11-03T06:45:00+01:00", "label": "Wake up"}]}
  ```

  With the same `id`, each night replaces the previous night's alarm.
- **"Recalculate now" button**: a submit with `include: ["location"]` that repeats the calculation with the current location.

Notes:
- Without a routing-service credential in n8n, the workflow uses the fallback travel minutes.
- The user's fallback wake-up time is used when there is no event with a location.
- If the calculated time has already passed, `schedule_alarm` fails ([§14.4](#144-automation-actions)).

### 15.4 n8n admin app

An example app that manages the n8n server itself: its workflows, executions, errors, credentials and users. It calls the n8n public REST API from n8n, so it needs no extra server. The importable templates are [n8n/workflows/app-n8n.json](../n8n/workflows/app-n8n.json) (the app) and [n8n/workflows/app-n8n-alerts.json](../n8n/workflows/app-n8n-alerts.json) (error alerts). The server setup, including the `n8n API` credential, is in [n8n/README.md](../n8n/README.md).

- **Access**: only users with `role` = `admin` in `nc_users`, plus the usual per-app check with `allowed_emails` ([§4](#4-tables)). App id `n8n`, path `n8n-connect/apps/n8n`.
- **Endpoints** (JWT):
  - `GET n8n-connect/apps/n8n`: the initial spec (the panel).
  - `POST n8n-connect/apps/n8n/view`: body `{"view", "op", "id", "wf", "status", "nav"}`. `view` chooses the screen to build and `op` the operation to run. The other fields are used only by the screens and operations that need them.
- **Screens**:
  - *Panel*: metrics (workflows and how many are published, running executions, errors in the last 24 h, and executions in the last 7 days when the API key can read insights), latest errors, sections, and an *Error alerts* card with a button to turn the alerts on or off.
  - *Workflows*, grouped by folder (folder names are cached in the workflow's static data).
  - *Workflow*: status, folder, nodes, triggers, error workflow, tags, latest executions and the node map (`graph` component).
  - *Executions*, filtered by all, error, running, waiting, success or canceled. *Execution*: the failing node with its error message, the node map with the run status of each node (ran, failed or did not run, and the items each one returned) and a summary of each node's run.
  - *Credentials*: names and types only; the API never returns secrets.
  - *Users and tags*, and *security audit* (`POST /audit`).
- **Operations** (all of them ask for confirmation except turning error alerts on or off):
  - Publish or unpublish a workflow (`POST /workflows/{id}/activate` or `/deactivate`). The app itself and the *n8n Connect · Core* and *n8n Connect · App access* workflows cannot be unpublished from the phone.
  - Run now: Execute Workflow by id. Only for workflows that start with *When executed by another workflow* (Execute Workflow Trigger) or a Manual Trigger, and the target must be published.
  - Retry an execution, with the original or the current version of the workflow; stop it; delete it.
  - Turn error alerts on or off.
- **Navigation**: a POST response returns the whole `spec` plus `screen` and `actions` (`navigate`) to rebuild the navigation stack. A spec alone in a submit response resets the stack to `start` ([§8](#8-submit-response)).
- **Error alerts** (*n8n Connect · App · n8n · Alerts*): every 5 minutes it reads the latest failed executions (`GET /executions?status=error&limit=20`) and keeps the IDs it has already seen in its static data. The first run only records the existing errors, so the phone is not flooded. Each new error is read with its data and sent through the [Send to phone](#9-push-n8n--phone) sub-workflow to every enabled `nc_users` row with `role` = `admin`: one push per error, or one summary when more than 3 fail at once. The app turns it on and off by publishing and unpublishing the workflow, which it finds by its exact name. The push needs the `n8n Connect FCM` credential set up for HTTP Request nodes ([n8n/README.md §6](../n8n/README.md#6-troubleshooting)).
- **Scopes**: the key of the `n8n API` credential needs these scopes: `workflow:list`, `workflow:read`, `workflow:activate`, `workflow:deactivate`, `execution:list`, `execution:read`, `execution:delete`, `execution:retry`, `execution:stop`, `credential:list`, `insights:read`, `securityAudit:generate`, `user:list` and `tag:list`. If a scope is missing, its section shows a banner instead of failing. Projects, folders and variables need an Enterprise license and are not used. The API address `http://127.0.0.1:5678/api/v1` is hard-coded in five places (the `API` constant of the Code nodes *Plan op*, *Plan fetch* and *Plan folders*, and the URLs of the HTTP Request nodes *Recent errors* and *Error details*); the Base URL of the `n8n API` credential only affects its connection test.
- **Saving and time zone**: both workflows set `saveDataSuccessExecution` to `none` (the app is called often and the alerts run every 5 minutes); errors are kept. The time zone is the constant `TZ` (default `UTC`) at the top of the *Build spec* Code node.
