# Protocolo n8n Connect (v1)

Referencia para quien crea flows en n8n que usan la app. Describe lo que la app lee, lo que envía y lo que hace con cada respuesta. La fuente de verdad es el código: `lib/core/app_config.dart`, `lib/features/server/`, `lib/features/apps/`, `lib/features/actions/`, `lib/features/push/`, `lib/features/share/`, `lib/features/automation/`, `lib/features/alarms/` y `lib/features/device_context/`.

1. [Visión general](#1-visión-general)
2. [Seguridad](#2-seguridad)
3. [Endpoints del Core](#3-endpoints-del-core)
4. [Tablas](#4-tablas)
5. [Cómo crear una app](#5-cómo-crear-una-app)
6. [Spec de UI (schema 1)](#6-spec-de-ui-schema-1)
7. [Acciones](#7-acciones)
8. [Respuesta de submit](#8-respuesta-de-submit)
9. [Push n8n → móvil](#9-push-n8n--móvil)
10. [Paneles en vivo (refreshSeconds)](#10-paneles-en-vivo-refreshseconds)
11. [Modo sin conexión](#11-modo-sin-conexión)
12. [Bandeja de n8n](#12-bandeja-de-n8n)
13. [Compartir con n8n](#13-compartir-con-n8n)
14. [Automatizaciones](#14-automatizaciones)
15. [Ejemplos](#15-ejemplos)

---

## 1. Visión general

La app no tiene lógica de negocio. Dibuja una pantalla a partir de un JSON (la *spec*), guarda un estado local y ejecuta acciones del móvil cuando se lo pide n8n. Toda la decisión la toma n8n.

```
 App Android (Flutter)                              n8n (https://tu-servidor)
 ─────────────────────                              ─────────────────────────
 1. Login Firebase ── ID token ──────────────────►  n8n-connect/auth
                   ◄──────────── JWT (12 h) ─────
 2. Catálogo ─────── GET (JWT) ──────────────────►  n8n-connect/apps
 3. Spec de la app ── GET app.path (JWT) ────────►  webhook de la app
 4. Botón submit ─── POST/GET + state (JWT) ─────►  webhook de la app
                   ◄── {state, screen, message, actions, spec}

 Push (n8n → móvil)
 n8n flow ──► Execute Sub-workflow "Enviar al móvil"
           ──► FCM (mensaje de datos, prioridad alta) ──► la app
                                                      muestra diálogo o notificación
                                                      y ejecuta las acciones si procede
```

Piezas:

- **Core**: workflow "n8n Connect · Core" (`n8n-connect/info`, `auth`, `apps`, `logout`). Plantilla: [n8n/workflows/core.json](../n8n/workflows/core.json).
- **Apps**: un par de webhooks por app (una spec GET y uno o más submit POST/GET).
- **Push**: sub-workflow "n8n Connect · Enviar al móvil", que envía el mensaje FCM a los dispositivos del usuario. Plantilla: [n8n/workflows/send-to-phone.json](../n8n/workflows/send-to-phone.json).
- **Compartir**: workflow "n8n Connect · Compartir" (`n8n-connect/share`), que recibe texto o enlaces de otras apps ([§13](#13-compartir-con-n8n)). Plantilla: [n8n/workflows/share.json](../n8n/workflows/share.json).

---

## 2. Seguridad

**Transporte**
- Solo HTTPS. `normalizeServerUrl` rechaza `http://`, y `AndroidManifest.xml` tiene `usesCleartextTraffic="false"`.
- En una spec, las imágenes (`image`) solo se cargan si la URL es `https`.

**Sesión**
1. La app obtiene un ID token de Firebase (email/contraseña o Google).
2. `POST n8n-connect/auth` con ese token. El Core lo verifica con Google, comprueba `emailVerified` y que el email esté habilitado en `nc_users`.
3. El Core responde con un JWT HS256 de 12 h. Claims: `sub`, `email`, `name`, `role`, `did`, `aud="n8n-connect"`, `iss="n8n-connect"`, `iat`, `exp`.
4. Todos los demás webhooks exigen ese JWT (ver abajo).

**Webhooks protegidos**
- En cada webhook de app, el nodo Webhook tiene *Authentication = "JWT Auth"* con la credencial de JWT. Dentro del flow, los claims verificados están en `$json.jwtPayload` (email, role, did…).
- Sin token o con token inválido, n8n responde 401/403. La app lo trata como `session_invalid` si el 401 no trae `error.code` o si el 403 no tiene un cuerpo JSON de tipo objeto ([§3.6](#36-formato-de-error)).

**Almacenamiento en el móvil**
- La sesión (URL, JWT, expiración, uid, usuario) va en `FlutterSecureStorage` con `encryptedSharedPreferences` (almacén respaldado por Android Keystore).
- La última URL del servidor va en SharedPreferences (no es secreta).
- El id del dispositivo es aleatorio y también va en almacenamiento seguro.
- La copia offline (`nc.cache.*`, [§11](#11-modo-sin-conexión)) y la bandeja (`nc.push.history`, [§12](#12-bandeja-de-n8n)) van en SharedPreferences, **sin cifrar**. Guardan specs, catálogo y contenido de los pushes; nunca el JWT ni el ID token de Firebase. Los permisos de automatización (`nc.auto.*`, [§14.1](#141-permiso-por-app)) también van sin cifrar; solo guardan qué apps están permitidas.

**Renovación**
- Antes de cada petición, si al JWT le quedan menos de 2 min (`sessionRefreshMargin`), la app pide uno nuevo.
- Si el servidor responde `session_invalid` (401 sin `error.code`, o 403 cuyo cuerpo no es un objeto JSON), la app renueva la sesión y repite la petición una vez.
- Al cambiar el token FCM, la app también renueva la sesión para registrar el token nuevo.
- Renovar usa el ID token de Firebase, así que la app reintenta una vez forzando un ID token nuevo si el servidor responde `invalid_token` o `email_not_verified`.

**URL de submit (mismo origen)**
- Las rutas relativas (`n8n-connect/apps/x/y`) se resuelven bajo `{servidor}/webhook/`. No pueden contener `.` ni `..`.
- Una URL absoluta solo se acepta si es `https` con el mismo host y puerto que el servidor. Si no, la app devuelve `foreignOrigin` y no envía nada. Así una spec no puede llevarse el JWT a otro dominio.

**Logout**
- Desconectar desde Configuración o Conectar, cambiar de servidor y borrar la cuenta llaman a `POST n8n-connect/logout` (timeout 6 s, errores ignorados). El servidor borra el `fcm_token` del dispositivo y deja de enviarle push.
- Si la sesión de Firebase desaparece por otra vía (p. ej. cambio de usuario detectado por la app), la app borra la sesión local, llama a `logout` y borra los permisos de automatización y el token FCM del móvil ([§14.1](#141-permiso-por-app)).
- Cuando la sesión con el servidor se cierra (desconectar, o acceso revocado con `not_allowed`, `account_disabled`, `email_not_verified` o `no_email`), también se borran la copia offline ([§11](#11-modo-sin-conexión)) y los permisos de automatización ([§14.1](#141-permiso-por-app)). La bandeja no se borra al desconectar.

**Cómo revocar acceso**

| Quieres… | Haz esto | Efecto |
|---|---|---|
| Cortar el acceso de una persona a todo el servidor | `nc_users.enabled = false` | La app no renueva la sesión: al renovarla, el Core responde `not_allowed` (403) y la app borra la sesión. El JWT ya emitido sigue valiendo hasta 12 h. |
| Quitar acceso a una sola app | Quitar su email de `allowed_emails` en `nc_apps` (vacío = todos) | Solo tiene efecto inmediato (403 `app_forbidden`) si la app usa «Acceso a app» ([§5](#5-cómo-crear-una-app)). Si no lo usa, la app solo deja de aparecer en el catálogo. |
| Cortar todas las sesiones JWT ya emitidas (p. ej. una sesión robada) | Rotar el secreto de la credencial JWT | Todos los JWT dejan de valer de inmediato. Las apps piden una sesión nueva con Firebase automáticamente, así que esto **no bloquea** a nadie. Para bloquear a una persona, usa la primera fila. |
| Dejar de enviar push a un dispositivo | Borrar su fila de `nc_devices` | Deja de recibir push. No invalida su JWT. |

**Validación**
- Los `required` de la spec son solo para la experiencia de usuario. El servidor debe validar siempre lo que recibe.
- Cada webhook de app debe comprobar además el acceso con el sub-workflow «n8n Connect · Acceso a app» (ver [§5](#5-cómo-crear-una-app)). El JWT prueba quién llama, no que pueda usar esa app.

**Credenciales**: las que hacen falta para los nodos JWT y cómo crearlas están en [n8n/README.md](../n8n/README.md).

---

## 3. Endpoints del Core

Todas las rutas son relativas a `{servidor}/webhook/`. Las constantes están en `lib/core/app_config.dart`.

| Ruta | Método | Auth | Uso en la app |
|---|---|---|---|
| `n8n-connect/info` | GET | pública | Comprobar que el servidor es n8n Connect |
| `n8n-connect/auth` | POST | Firebase ID token | Abrir sesión (y renovarla) |
| `n8n-connect/apps` | GET | JWT | Catálogo de apps |
| `n8n-connect/logout` | POST | JWT | Borrar el token push del dispositivo |
| `n8n-connect/share` | POST | JWT | Enviar texto o un enlace compartido desde otra app (workflow "n8n Connect · Compartir", [§13](#13-compartir-con-n8n)) |

Cada app tiene además su propio `path` (ver [§3.4](#34-spec-de-una-app-y-submit)).

### 3.1 GET `n8n-connect/info`

Respuesta:
```json
{"service": "n8n-connect", "protocol": 1, "name": "Mi n8n", "firebaseProjectId": "mi-proyecto-firebase"}
```

Validación en la app:
- `service` distinto de `"n8n-connect"` → `not_n8n_connect`.
- `protocol` mayor que 1 (`AppConfig.protocolVersion`) → `unsupported_protocol`.
- `firebaseProjectId` distinto del proyecto Firebase de la app → `wrong_firebase_project`.

### 3.2 POST `n8n-connect/auth`

Cabeceras: `Authorization: Bearer <Firebase ID token>`, `Content-Type: application/json`.

Cuerpo:
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
`fcmToken` va vacío (`""`) si el móvil no tiene token FCM.

Respuesta 200:
```json
{
  "token": "eyJhbGciOi…",
  "expiresAt": "2026-11-03T00:00:00Z",
  "user": {"email": "tu@email.com", "name": "Tu nombre", "role": "admin"},
  "server": {"name": "Mi n8n"}
}
```
`token` y `expiresAt` (ISO 8601) son obligatorios; si faltan, la app devuelve `bad_response`.

Errores (cuerpo `{"error": {"code", "message"}}`):

| Código | HTTP | Significado |
|---|---|---|
| `invalid_token` | 401 | ID token de Firebase inválido o caducado |
| `account_disabled` | 403 | La cuenta de Firebase está deshabilitada |
| `no_email` | 403 | La cuenta de Firebase no tiene email |
| `email_not_verified` | 403 | El email no está verificado |
| `not_allowed` | 403 | La cuenta no está autorizada: no tiene fila en `nc_users` o tiene `enabled = false` |
| `invalid_device` | 400 | `device.id` ausente o con formato no válido (16-64 caracteres `[A-Za-z0-9_-]`) |
| `upstream_error` | 424 | «No se pudo verificar la sesión con Google. Inténtalo de nuevo en unos segundos.» Google no responde o falla por causa distinta de un token inválido (red, 429, 5xx) |

### 3.3 GET `n8n-connect/apps`

Cabecera: `Authorization: Bearer <JWT>`.

Respuesta:
```json
{
  "apps": [
    {
      "id": "tools",
      "name": "Herramientas",
      "description": "Alarma, panel en vivo, formulario y acciones del móvil",
      "icon": "bolt",
      "color": "#0EA5E9",
      "path": "n8n-connect/apps/tools"
    }
  ]
}
```
- Las entradas sin `id` o sin `path` se ignoran.
- `icon`: nombre de la tabla de iconos de la app (ver [§6](#6-spec-de-ui-schema-1)). Por defecto `apps`.
- `color`: `#RRGGBB` o `#AARRGGBB`. Si no es válido, se usa el color primario.
- `path`: ruta del webhook que devuelve la spec de la app.

El catálogo se cachea en memoria. Se refresca al arrastrar la lista hacia abajo, y también si la app no encuentra un `id` (p. ej. al abrirla desde un push). Además se guarda una copia en el móvil para el modo sin conexión ([§11](#11-modo-sin-conexión)).

### 3.4 Spec de una app y submit

- **GET `{path}`** (JWT): devuelve la spec ([§6](#6-spec-de-ui-schema-1)). Si trae `refreshSeconds`, se vuelve a pedir cada cierto tiempo ([§10](#10-paneles-en-vivo-refreshseconds)).
- **POST/GET/PUT/PATCH/DELETE `{ruta del submit}`** (JWT): devuelve la respuesta de submit ([§8](#8-respuesta-de-submit)).

### 3.5 POST `n8n-connect/logout`

Cabecera JWT. Cuerpo vacío. Respuesta: `{"ok": true}`. El Core borra el `fcm_token` del dispositivo de la sesión.

### 3.6 Formato de error

Cualquier error de n8n puede traer:
```json
{"error": {"code": "algo_ha_fallado", "message": "Texto para el usuario"}}
```
Si el `message` existe y el código **no** es uno de los códigos de cliente de la tabla siguiente, la app muestra ese texto tal cual. Si no, muestra un mensaje localizado según el código.

Códigos de cliente (los genera la propia app, no el servidor):

| Código | Cuándo |
|---|---|
| `network` / `timeout` | Sin red o sin respuesta (20 s, o 150 s en submit) |
| `session_invalid` | 401 sin `error.code`, o 403 cuyo cuerpo no es un objeto JSON (JWT rechazado). Un 401 con `error.code` conserva ese código |
| `not_found` | 404: el webhook no existe. Suele ser un workflow no publicado o una ruta mal escrita |
| `bad_response` | Respuesta 2xx que no es JSON, o auth sin `token` |
| `http_<status>` | Otro error HTTP sin código |
| `not_connected` / `signed_out` | No hay sesión del servidor / no hay sesión de Firebase |
| `app_not_found` | El `id` de la app no está en el catálogo |
| `unsupported_spec` | `schema` mayor que 1 |
| `bad_spec` | La spec no tiene pantallas válidas |

---

## 4. Tablas

Las tablas de datos de n8n que usa el Core.

**`nc_users`**: quién puede entrar.

| Campo | Tipo | Notas |
|---|---|---|
| `email` | texto | Email de la cuenta de Firebase, **en minúsculas**. Clave de búsqueda (el Core compara el email en minúsculas) |
| `enabled` | booleano | `false` bloquea el acceso con `not_allowed` (ver [§2](#2-seguridad)) |
| `role` | texto | Se devuelve en `user.role` |
| `name` | texto | Se devuelve en `user.name` |

**`nc_devices`**: dispositivos con sesión. Se hace *upsert* por `device_id` + `email`.

| Campo | Tipo | Notas |
|---|---|---|
| `device_id` | texto | `device.id` |
| `email` | texto | Dueño del dispositivo |
| `uid` | texto | uid de Firebase |
| `name` | texto | `device.name` (p. ej. "Pixel 8") |
| `platform` | texto | `device.platform` (`android`) |
| `fcm_token` | texto | Token FCM. Vacío tras logout. Es el destino de los push |
| `app_version` | texto | `device.appVersion` |
| `last_seen` | fecha | Última vez que el dispositivo renovó la sesión |

**`nc_apps`**: catálogo de apps.

| Campo | Tipo | Notas |
|---|---|---|
| `app_id` | texto | Sale como `id` en `GET n8n-connect/apps` |
| `name` | texto | |
| `description` | texto | |
| `icon` | texto | Nombre de icono ([§6](#6-spec-de-ui-schema-1)) |
| `color` | texto | `#RRGGBB` |
| `path` | texto | Ruta de la spec, p. ej. `n8n-connect/apps/tools` |
| `enabled` | booleano | Solo las `true` aparecen |
| `allowed_emails` | texto | Emails separados por coma. Vacío = todos los usuarios habilitados. Filtra el catálogo; para que también bloquee la app, esta debe usar «Acceso a app» ([§5](#5-cómo-crear-una-app)) |
| `sort` | número | Orden ascendente en el catálogo |

**`nc_inbox`**: textos enviados desde otras apps con "Compartir" ([§13](#13-compartir-con-n8n)). El workflow guarda una fila por envío.

| Campo | Notas |
|---|---|
| `email` | Usuario que comparte |
| `text` | Texto o enlace compartido |
| `subject` | Asunto de la app de origen. Vacío si no lo tenía |
| `note` | Nota escrita en la app. Vacía si no se escribió |
| `received_at` | Momento de recepción |

---

## 5. Cómo crear una app

1. **Diseña la spec** (JSON, [§6](#6-spec-de-ui-schema-1)) y decide qué hace cada botón ([§7](#7-acciones)).
2. **Crea el webhook de la spec** en n8n:
   - Nodo Webhook, método GET, path `n8n-connect/apps/<id>`.
   - Authentication = "JWT Auth", con la credencial JWT (ver [n8n/README.md](../n8n/README.md)).
   - Responde con el JSON de la spec.
3. **Crea los webhooks de submit**, uno por acción de servidor, con la misma autenticación. Por ejemplo POST `n8n-connect/apps/<id>/saludar`. Responden con el JSON de [§8](#8-respuesta-de-submit).
4. **Comprueba el acceso en cada webhook** (la spec y cada submit). Justo después del Webhook, llama al sub-workflow «n8n Connect · Acceso a app» (plantilla [n8n/workflows/app-access.json](../n8n/workflows/app-access.json)), como hace [app-tools.json](../n8n/workflows/app-tools.json):
   - Nodo Execute Sub-workflow con `app_id` = id de la app y `email` = `{{ $json.jwtPayload.email }}`.
   - Nodo IF sobre `allowed`: si es `true`, el flow sigue. Si no, responde 403 con `{{ { error: $json.error } }}`, que da `{"error": {"code": "app_forbidden", "message": "…"}}`.

   El sub-workflow da `allowed: true` solo si la app está activa en `nc_apps` y el email está en `allowed_emails` (o la lista está vacía). Sin esta comprobación, `allowed_emails` solo filtra el catálogo ([§2](#2-seguridad)).

5. **Registra la app** en `nc_apps`:

   | app_id | name | description | icon | color | path | enabled | allowed_emails | sort |
   |---|---|---|---|---|---|---|---|---|
   | hola | Hola | Saluda desde n8n | notifications | #EA4B71 | n8n-connect/apps/hola | true | (vacío) | 10 |

6. **Abre la app** y arrastra hacia abajo en la lista de apps para refrescarla.

Spec mínima con un formulario y un botón que envía datos:

```json
{
  "schema": 1,
  "title": "Hola",
  "start": "inicio",
  "state": {"nombre": ""},
  "screens": [
    {
      "id": "inicio",
      "title": "Hola",
      "components": [
        {"type": "input", "key": "nombre", "label": "Tu nombre", "required": true},
        {"type": "text", "text": "Escribe tu nombre y pulsa enviar", "style": "caption"},
        {
          "type": "button",
          "label": "Enviar",
          "icon": "send",
          "action": {"type": "submit", "path": "n8n-connect/apps/hola/saludar", "loading": "Enviando…"}
        }
      ]
    }
  ]
}
```

Respuesta del webhook `saludar` (el cuerpo que envió la app es `{"nombre": "Ana"}`):

```json
{"message": "Hola, Ana"}
```

---

## 6. Spec de UI (schema 1)

Respuesta del GET de la app:

| Campo | Obligatorio | Descripción |
|---|---|---|
| `schema` | no (por defecto 1) | Versión del formato. Si es mayor que 1, la app devuelve `unsupported_spec` |
| `title` | no | Título por defecto de las pantallas |
| `start` | no | `id` de la pantalla inicial. Si no existe o falta, se usa la primera |
| `state` | no | Valores iniciales (objeto) |
| `screens` | sí | Lista de pantallas, o mapa `id → pantalla`. Sin pantallas válidas: `bad_spec` |
| `refreshSeconds` | no | Segundos entre recargas silenciosas. Número o texto numérico; mínimo 10 (menos se ignora). Ver [§10](#10-paneles-en-vivo-refreshseconds) |

**Pantallas**
- Como lista: `[{"id": "inicio", "title": "…", "components": [ … ]}]`. Las entradas sin `id` se ignoran.
- Como mapa: `{"inicio": {"title": "…", "components": [ … ]}}`. La clave es el `id`.
- `title` de la pantalla es el título de la barra. Si falta, se usa el `title` de la spec y, si tampoco, el nombre de la app.

**Estado**
- El estado empieza en `state` y se rellena con los controles (`input`, `switch`, `select`, `date`, `time`).
- Cada control escribe su valor en `state[key]`. `input` guarda texto; `switch` guarda booleano; `select` guarda el `value` elegido; `date` guarda `yyyy-MM-dd`; `time` guarda `HH:mm`.
- Las claves que empiezan por `_` son solo locales: no se envían en submit ([§8](#8-respuesta-de-submit)).

**Plantillas `{{…}}`**
- `{{clave}}` se sustituye por el valor del estado. Puede ser una ruta con puntos (`{{user.name}}`) o con índices de lista (`{{items.0.title}}`).
- Caracteres permitidos en la clave: letras, números, `_`, `.`, `$` y `-`.
- Clave inexistente: en texto se muestra vacío.
- **Regla del valor crudo**: si la cadena es solo un placeholder (`"{{hour}}"`), se usa el valor original (número, booleano, objeto). Aplica a los parámetros de las acciones y a `visible`. En los textos de los componentes el resultado siempre es texto.

**`visible`**: cualquier componente puede tener `visible`. Se evalúa con plantilla y es falso si vale `null`, `false`, `0`, `""`, `"false"`, `"0"`, `"no"`, una lista vacía o un objeto vacío. Cualquier otro valor lo muestra. Sin `visible`, el componente se muestra.

**Validación de `required`**: al enviar un `submit`, la app revisa solo los componentes de primer nivel de la pantalla actual (no los que van dentro de una `card`). Si un `input` con `required: true` está vacío, no envía nada y muestra `Rellena "<label>"`.

**Iconos**: nombres de la tabla de `lib/features/apps/app_style.dart`. Los que no estén en esa tabla se ignoran. Lista completa: `add`, `alarm`, `alarm_add`, `apps`, `arrow_back`, `arrow_forward`, `bolt`, `calendar_today`, `camera`, `check`, `check_circle`, `close`, `cloud`, `delete`, `directions_car`, `edit`, `email`, `error`, `event`, `event_available`, `favorite`, `fitness_center`, `home`, `info`, `lightbulb`, `link`, `list`, `local_cafe`, `location_on`, `lock`, `music_note`, `notifications`, `person`, `phone`, `play_arrow`, `power`, `refresh`, `restaurant`, `schedule`, `search`, `send`, `settings`, `shopping_cart`, `star`, `stop`, `thermostat`, `timer`, `warning`, `wb_sunny`, `work`.

**Componentes** (los campos son exactamente los que lee `lib/features/apps/spec_view.dart`):

| `type` | Campos | Notas |
|---|---|---|
| `text` | `text`, `style` (`title`, `subtitle`, `caption`; por defecto cuerpo), `align` (`start`, `center`, `end`) | Texto seleccionable. `text` admite plantillas |
| `banner` | `text`, `tone` (`info` por defecto, `success`, `warning`, `error`), `icon` | Aviso con color. `tone` admite plantillas |
| `card` | `title`, `subtitle`, `icon`, `components` (lista) | Contenedor. Sus componentes siguen las mismas reglas |
| `image` | `url`, `height` | Solo `https`. Si falla la carga no muestra nada |
| `divider` | — | Línea separadora |
| `spacer` | `height` (px, 16 por defecto) | Espacio vertical |
| `input` | `key` (obligatorio), `label`, `hint`, `keyboard` (`text`, `number`, `email`, `phone`, `url`, `multiline`), `obscure` (booleano), `required` (booleano) | Sin `key` no se muestra. `number` solo admite dígitos, `.`, `,` y `-` |
| `switch` | `key` (obligatorio), `label`, `description` | Guarda booleano |
| `select` | `key` (obligatorio), `label`, `style` (`chips`, `radio`; por defecto desplegable), `options`: `[{value, label, description, disabled}]` | `value` es obligatorio en cada opción; las que no lo tengan se ignoran. `label` por defecto es el `value` |
| `date` | `key` (obligatorio), `label` | Abre el selector de fecha. Guarda `yyyy-MM-dd` |
| `time` | `key` (obligatorio), `label` | Abre el selector de hora. Guarda `HH:mm` |
| `button` | `label`, `icon`, `style` (por defecto relleno; `tonal`, `outlined`, `text`), `action` y/o `actions` | Sin acciones, el botón queda deshabilitado |
| `list` | `items`: `[{title, subtitle, trailing, icon, action / actions}]` | Tocar un elemento ejecuta sus acciones. `trailing` sustituye a la flecha |
| `details` | `items`: `[{label, value}]` | Pares clave/valor |
| `slider` | `key` (obligatorio), `label`, `min` (0), `max` (100), `step`, `unit` | Barra deslizante con el valor y `unit` pegado al número (sin espacio). Sin `step` es continua; con `step` muestra marcas, y si `step` da más de 1000 divisiones es continua. Si `max` ≤ `min`, `max` pasa a `min` + 1. Guarda entero si `min` y `step` (o `min` y `max`, sin `step`) son enteros; si no, decimal de 2 cifras. Sin valor empieza en `min` |
| `checkbox` | `key` (obligatorio), `label`, `description` | Casilla con descripción opcional. Guarda booleano |
| `multiselect` | `key` (obligatorio), `label`, `options`: `[{value, label, disabled}]` | Chips de selección múltiple. Guarda la lista de `value` en el orden de `options`; los valores que no estén en `options` se conservan al final. Las opciones sin `value` se ignoran. `label` por defecto es `value` |
| `stepper` | `key` (obligatorio), `label`, `min`, `max`, `step` (1) | Botones − y + con el valor entre ambos. Sin `min` o `max`, no hay límite por ese lado. El botón se desactiva en el límite. Guarda entero si el paso y el valor son enteros; si no, decimal de 2 cifras. Sin valor empieza en `min` (o en 0) |
| `progress` | `value`, `max`, `label` | Barra de progreso con porcentaje. Sin `max` vale 100 si `value` es mayor que 1, y 1 si no. Se acota entre 0 % y 100 % |
| `metric` | `label`, `value`, `unit`, `icon`, `tone`, `caption` | Tarjeta de indicador: etiqueta, valor grande, unidad y pie opcional. `tone` `success` (verde), `warning` (ámbar) o `error` colorea el valor; otro valor usa el color normal |
| `grid` | `columns` (2; se acota a 1–4), `components` | Filas de columnas iguales separadas 12 px. Los hijos con `visible` falso se quitan antes de repartir, así que el resto se reordena. Cada hijo se dibuja como cualquier componente |
| `table` | `columns` (cabeceras), `rows` (listas de celdas) | Tabla de solo lectura con desplazamiento horizontal. Las filas cortas se rellenan con celdas vacías, las largas se recortan al número de cabeceras y las que no son listas se omiten. Sin `columns` no muestra nada |

En los componentes nuevos, `min`, `max`, `step`, `value` y `columns` admiten plantillas; se leen como número después de resolverlas. Los campos de texto también admiten plantillas.

Un `type` desconocido se muestra como "Componente no soportado: <type>". No rompe la pantalla.

Ejemplo de `select` con estilo chips y `visible`:

```json
{
  "type": "select",
  "key": "dia",
  "label": "Día",
  "style": "chips",
  "options": [
    {"value": "lun", "label": "Lunes"},
    {"value": "mar", "label": "Martes", "disabled": true, "description": "Cerrado"}
  ],
  "visible": "{{modo}}"
}
```

---

## 7. Acciones

Una acción es un objeto con `type`, sus parámetros y, opcionalmente, `confirm`:

```json
{"type": "set_alarm", "hour": 7, "minute": 30, "label": "Gym", "confirm": "¿Poner alarma a las 7:30?"}
```

**Dónde aparecen**: en `action` / `actions` de `button` y de los elementos de `list`; en la clave `actions` de una respuesta de submit; en `actions` de un push; y en la respuesta de un `report` ([§14.4](#144-acciones-de-automatización)).

**Ejecución**
- Los parámetros se resuelven con plantillas (regla del valor crudo) justo antes de ejecutar.
- Se ejecutan en orden. La lista se detiene en el primer error o si el usuario cancela una confirmación.
- Los errores se muestran en un aviso.
- Un `type` desconocido produce un error de "acción no soportada" y detiene la lista.

**`confirm`**
- Texto: `"confirm": "¿Seguro?"`.
- Objeto: `{"title", "message", "confirmLabel"}`. Las tres son plantillas.
- Sin `message` no hay confirmación, aunque exista el objeto.

**Tipos**

| `type` | Parámetros | Necesita pantalla de app | Efecto |
|---|---|---|---|
| `submit` | `path` o `url` (obligatorio), `method` (`GET`, `POST`, `PUT`, `PATCH`, `DELETE`; por defecto `POST`), `body` (objeto), `keys` (lista de claves del estado), `loading` (texto del overlay) | Sí | Envía datos y aplica la respuesta ([§8](#8-respuesta-de-submit)) |
| `navigate` | `screen` (id) | Sí | Abre una pantalla. Si ya está en la pila, vuelve a ella |
| `back` | — | Sí | Vuelve atrás. En la primera pantalla sale de la app |
| `reload` | — | Sí | Vuelve a pedir la spec. Reinicia el estado y la pila |
| `set_state` | `values` (o `state`, objeto) | Sí | Mezcla valores en el estado |
| `open_app` | `app` (id de la app) | No | Abre otra app del catálogo |
| `toast` | `message` | No | Aviso breve |
| `dialog` | `title` (opcional), `message` | No | Diálogo con Aceptar |
| `notify` | `title` (por defecto el nombre de la app), `body` | No | Notificación local |
| `set_alarm` | `hour` y `minute`, o `time` (`"HH:mm"`); `label`; `days` (1 = domingo … 7 = sábado); `vibrate` (booleano); `skipUi` (por defecto `true`) | No | Crea una alarma en la app Reloj. `hour` 0–23, `minute` 0–59 |
| `set_timer` | `seconds`, o `minutes`; `label`; `skipUi` (por defecto `true`) | No | Temporizador de 1 s a 24 h |
| `calendar_event` | `title` y `start` (obligatorios, ISO 8601); `end`; `location`; `description`; `allDay` (booleano) | No | Abre el formulario de evento del calendario prellenado. `end` por defecto es `start` + 1 h |
| `open_url` | `url` | No | Abre el enlace. Esquemas permitidos: `https`, `http`, `mailto`, `tel`, `geo` |
| `copy` | `text` | No | Copia al portapapeles |
| `share` | `text` (obligatorio), `subject` | No | Abre el selector de compartir de Android con el texto |
| `dial` | `number` (obligatorio) | No | Abre el marcador con el número. No llama |
| `sms` | `number` (obligatorio), `body` | No | Abre la app de mensajes con el destinatario y el texto (`body` solo si no está vacío) |
| `email` | `to` (obligatorio), `subject`, `body` | No | Abre un correo nuevo. Los espacios se codifican como `%20` |
| `maps` | `query`, o `lat` y `lng` (número o texto numérico), `label`, `navigate` (booleano, por defecto `false`) | No | Abre Mapas en un lugar, o inicia la navegación con `navigate: true`. Si hay `query`, las coordenadas se ignoran; `label` solo se usa con coordenadas. Sin `query` ni coordenadas, o con lat/lng fuera de −90…90 y −180…180, da error |
| `vibrate` | `style`: `light`, `medium`, `heavy` o `vibrate` (por defecto) | No | Vibración háptica. Otro valor da error |
| `show_alarms` | — | No | Abre la lista de alarmas del reloj |
| `open_settings` | `panel` (obligatorio; no distingue mayúsculas) | No | Abre un ajuste del sistema: `wifi`, `bluetooth`, `location`, `display`, `sound`, `battery`, `date`, `notifications` (de esta app) o `app` (información de esta app). Otro panel da error |
| `launch_app` | `package` (obligatorio, p. ej. `com.whatsapp`) | No | Abre una app por su nombre de paquete. Si el formato no es válido (al menos dos segmentos separados por puntos, cada uno empezando por letra), da error |
| `read_clipboard` | `key` (obligatorio) | Sí | Copia el texto del portapapeles a `state[key]` (vacío si no hay texto) |
| `schedule_alarm` | `id` (por defecto `default`), `at` (obligatorio, ISO 8601), `label`, `body` | No | Programa una alarma propia de la app que suena aunque la app esté cerrada. Con el mismo `id`, reemplaza la anterior. Automática ([§14.4](#144-acciones-de-automatización)) |
| `cancel_alarm` | `id` (por defecto `default`) | No | Cancela la alarma propia de esa app con ese `id`. Automática |
| `report` | `path` (obligatorio), `include` (por defecto `["location"]`), `data` (objeto) | No | Envía datos del móvil por `POST` a `path` y ejecuta las `actions` de la respuesta. Automática ([§14.4](#144-acciones-de-automatización)) |
| `request_permission` | `permission` (obligatorio): `location`, `location_always` o `notifications` | No | Pide un permiso del sistema. No es automática |

Notas de las acciones de dispositivo:
- `share`, `dial`, `sms`, `email`, `maps`, `show_alarms`, `open_settings` y `launch_app` abren apps del sistema con un intent: solo funcionan en Android.
- `dial` y `sms` codifican el número en la URI. `+34 600 123 123` llega como `%2B34%20600%20123%20123`. No se ha probado en todos los marcadores.
- `launch_app` no necesita `<queries>` en el manifiesto: la app lanza el intent directamente con `startActivity`, al que no le afecta la visibilidad de paquetes de Android 11+. Si la app no está instalada, se muestra un error.
- `set_alarm` abre la app Reloj y no sirve en automatizaciones. `schedule_alarm` es una alarma propia de la app: ver [§14.6](#146-alarma-del-reloj-y-alarma-propia).

Ejemplo de respuesta con dos acciones:

```json
{
  "actions": [
    {"type": "set_alarm", "time": "06:30", "label": "Gym"},
    {"type": "toast", "message": "Alarma puesta"}
  ]
}
```

---

## 8. Respuesta de submit

**Petición**
- El método es el de la acción (`method`, `POST` por defecto).
- Con `POST`, `PUT`, `PATCH` o `DELETE`, el contenido va como JSON en el cuerpo.
- Con `GET`, el contenido va en la query string. Los valores se convierten a texto; `null` pasa a cadena vacía.
- Contenido, en este orden de prioridad:
  1. `body`, si la acción lo tiene (objeto).
  2. `keys`, solo esas claves del estado.
  3. Todo el estado, salvo las claves que empiezan por `_`.
- La cabecera `Authorization: Bearer <JWT>` la añade la app.
- Timeout de 150 s en la app. Un proxy con un límite de tiempo menor corta antes (ver Recomendaciones más abajo). Mientras espera, aparece un overlay con el texto `loading` y los controles quedan deshabilitados. No se puede salir con el gesto atrás.

**Respuesta**: un objeto JSON con estos campos, todos opcionales. La app los aplica en este orden:

| Orden | Campo | Efecto |
|---|---|---|
| 1 | `spec` | Reemplaza la spec completa (schema 1). El estado vuelve al `state` del nuevo spec y la pila a `start` |
| 2 | `state` | Mezcla valores en el estado (sobrescribe claves) |
| 3 | `screen` | Navega a esa pantalla (id) |
| 4 | `message` | Muestra un aviso |
| 5 | `actions` | Ejecuta las acciones ([§7](#7-acciones)). Acepta una lista o un solo objeto |

- Una respuesta 2xx vacía no hace nada.
- Una respuesta 2xx que no es JSON produce `bad_response`.
- Una respuesta 2xx que es una lista JSON se ignora.

**Errores**: ver [§3.6](#36-formato-de-error). Un 404 significa que el webhook no existe o que el workflow no está publicado.

**Recomendaciones para los flows**
- Si pones un proxy como Cloudflare delante de n8n, sustituye el cuerpo de las respuestas 502/504 y corta las peticiones a los 100 s (error 524): responde con 4xx o 424 y mantén cada petición por debajo de ese límite.
- Si una dependencia falla, usa 424 con `error.code` y `error.message`.
- Responde siempre con JSON.

Ejemplo de respuesta completa:

```json
{
  "message": "Reserva confirmada",
  "state": {"reservada": true},
  "screen": "resumen",
  "actions": [
    {"type": "set_alarm", "time": "06:30", "label": "Gym"}
  ]
}
```

---

## 9. Push n8n → móvil

**Quién envía**: el sub-workflow "n8n Connect · Enviar al móvil" (plantilla [n8n/workflows/send-to-phone.json](../n8n/workflows/send-to-phone.json)), llamado desde otro flow con **Execute Sub-workflow**.

Entradas:

| Campo | Descripción |
|---|---|
| `email` | Usuario destino. Se envía a todos sus dispositivos con `fcm_token` |
| `title` | Título de la notificación |
| `body` | Cuerpo |
| `actions` | Array de acciones ([§7](#7-acciones)). Vacío si solo es un aviso |
| `app` | Id de app asociada (opcional). Al tocar la notificación sin acciones, abre esa app |

Salida: `{"sent": n, "failed": n, "unregistered": ["device_id", …]}`, o `{"sent": 0, "failed": 0, "reason": "no_devices"}` si el usuario no tiene dispositivos con token. `unregistered` lista los `device_id` cuyo token FCM ya no es válido (FCM responde 404 o `UNREGISTERED`). La plantilla solo informa: no borra esas filas.

Envío: mensaje FCM v1 de **datos**, prioridad alta, `ttl` 3600 s.

**Formato del mensaje** (datos, todos son cadenas):

```json
{
  "nc": "1",
  "id": "5f0c…",
  "title": "Gym",
  "body": "07:30",
  "actions": "[{\"type\":\"set_alarm\",\"hour\":7,\"minute\":30,\"label\":\"Gym\"}]",
  "app": "tools",
  "to": "usuario@ejemplo.com"
}
```

- `nc` debe ser `"1"`. Sin ese campo, la app no lo trata como comando de n8n Connect.
- `actions` llega como JSON en texto. La app también acepta una lista JSON directamente.
- `id` evita duplicados: si llega dos veces el mismo `id` en la misma sesión de la app, la segunda se ignora.
- `to` es el email en minúsculas del destinatario (el `email` de entrada del sub-workflow). Si no coincide con la cuenta conectada, la app descarta el push, tanto en primer plano como en segundo plano ([§14.2](#142-qué-puede-ejecutarse-sin-preguntar)). Sin `to`, no hay esa comprobación.

**Comportamiento en el móvil**

| Estado de la app | Sin `actions` | Con `actions` |
|---|---|---|
| Abierta (primer plano) | Notificación normal | Diálogo "n8n quiere ejecutar acciones" con *Ejecutar* / *Ignorar*. Si el ajuste "Ejecutar acciones de n8n automáticamente" está activo, ejecuta sin preguntar (se muestra un aviso con el `title`). La confirmación de cada acción (`confirm`) se respeta igualmente |
| En segundo plano o cerrada | Notificación en el canal "n8n". Tocarla abre la app (si hay `app`) | Notificación con el botón **Ejecutar**. Pulsar *Ejecutar* ejecuta las acciones sin diálogo y luego manda la app a segundo plano. Tocar el cuerpo abre el diálogo de confirmación |

Motivo del botón: Android bloquea abrir actividades (alarma, calendario) desde segundo plano. Por eso las acciones solo se ejecutan cuando el usuario pulsa el botón o abre la app.

Excepción: si la app tiene permiso de automatización y todas sus acciones son automáticas, el push se ejecuta solo, también con la app cerrada, sin diálogo ni botón ([§14](#14-automatizaciones)).

Mensajes FCM con bloque `notification` (sin `nc`): en segundo plano los muestra el sistema; en primer plano la app los muestra como notificación local.

Cada push que la app recibe en primer plano o que el usuario abre queda registrado en la bandeja ([§12](#12-bandeja-de-n8n)), y también las automatizaciones ejecutadas con la app cerrada ([§14.3](#143-cómo-se-ejecuta)).

**Probar sin n8n**: `tools/send_push.py`, ver [README](../README.md#probar-un-push-con-toolssend_pushpy).

---

## 10. Paneles en vivo (refreshSeconds)

Una spec puede pedir que la app la vuelva a leer sola cada cierto tiempo:

```json
{"schema": 1, "title": "Pedidos", "refreshSeconds": 60, "start": "inicio", "state": {"pendientes": 0}, "screens": [{"id": "inicio", "components": [{"type": "metric", "label": "Pendientes", "value": "{{pendientes}}"}]}]}
```

- `refreshSeconds`: segundos entre recargas. Acepta número o texto numérico. Valores menores de 10 (`AppSpec.minRefreshSeconds`) o no válidos se ignoran: la spec no se recarga sola.
- En cada recarga la app vuelve a pedir la spec (`GET {path}`) y:
  - Sustituye la spec entera por la nueva.
  - Mezcla el `state` de la spec nueva sobre el estado actual: cada clave que trae la spec se actualiza **solo si el usuario no la ha cambiado** desde la última carga (un formulario a medio rellenar conserva lo escrito); el resto del estado se conserva.
  - Mantiene la pila de pantallas si todas sus pantallas existen en la spec nueva. Si alguna ya no existe, vuelve a `start`.
- La recarga se omite si hay un submit en curso, otra carga en curso, la app está en segundo plano o la pantalla está tapada por otra ruta.
- Un error en una recarga no se muestra: la pantalla se queda como estaba. Si el fallo es de red y hay copia guardada, se muestra la copia ([§11](#11-modo-sin-conexión)).
- El temporizador empieza de nuevo cada vez que se aplica una spec.
- La recarga manual (icono de refrescar o arrastrar hacia abajo) no es silenciosa: reinicia el estado y la pila, como antes.
- La barra superior muestra "Actualizado HH:mm" tras cada carga correcta, también en apps sin `refreshSeconds`.

> Los valores que vienen del servidor (métricas, horas, contadores) se refrescan solos; los que el usuario ha editado se respetan. Una recarga manual (botón ⟳ o acción `reload`) sí reinicia estado y pantalla.

---

## 11. Modo sin conexión

La app guarda una copia de lo que recibe del servidor para mostrarla cuando no hay red.

- **Qué se guarda**: el catálogo (`GET n8n-connect/apps`) y la spec de cada app (`GET {path}`), tal como llegaron (JSON volvido a serializar), con la hora en que se guardaron. No se guardan submits ni sus respuestas.
- **Dónde**: SharedPreferences, con las claves `nc.cache.apps|{servidor}` y `nc.cache.spec|{servidor}|{id de app}`. Hay una copia por servidor, sin cifrar.
- **Cuándo se usa**: solo si la petición falla con `network` o `timeout` ([§3.6](#36-formato-de-error)). Otros errores (401, 404, 5xx…) se muestran tal cual. Sin copia, se muestra el error.
- **Qué ve el usuario**: un aviso "Sin conexión. Mostrando datos guardados (HH:mm)." sobre el catálogo o sobre la app. La hora es `HH:mm` si la copia es de hoy y `dd/MM HH:mm` si no. Una respuesta correcta del servidor quita el aviso.
- **Qué no funciona sin red**: `submit` nunca usa la copia y falla con `network`. Las acciones que solo usan el móvil (`toast`, `dialog`, `open_url`, alarmas…) sí funcionan.
- **Borrado**: al desconectar, o cuando el servidor revoca el acceso (`not_allowed`, `account_disabled`, `email_not_verified`, `no_email`), se borran todas las claves `nc.cache.*`. Cambiar de servidor no las borra: cada servidor tiene sus propias claves.

---

## 12. Bandeja de n8n

La bandeja guarda los pushes de n8n y el resultado de cada uno. Se abre con el icono de bandeja de la pantalla de apps (ruta `/inbox`).

**Qué entra**: cada push con `nc: "1"` ([§9](#9-push-n8n--móvil)) que llega con la app abierta, o que el usuario abre desde una notificación (tocándola o con el botón *Ejecutar*). Un push que llega con la app cerrada o en segundo plano y que el usuario no abre no entra en la bandeja, salvo que se ejecute como automatización ([§14.3](#143-cómo-se-ejecuta)).

**Estados**

| Estado | Cuándo |
|---|---|
| Pendiente | En cuanto llega el push, mientras la app decide qué hacer con él |
| Ejecutado | No traía `actions` (aviso), o todas sus acciones se ejecutaron |
| Ignorado | El usuario no aceptó el diálogo de confirmación (Cancelar o tocar fuera) |
| Fallido | Alguna acción falló, o se canceló la confirmación `confirm` de una acción |

**Ejecutar desde la bandeja**: el botón *Ejecutar* aparece solo si el push tiene `actions`. Ejecuta la lista sin el diálogo general (las acciones con `confirm` siguen pidiendo confirmación) y guarda el resultado: Ejecutado o Fallido. Mientras corre, el botón está desactivado. Las acciones que necesitan una pantalla de app abierta ([§7](#7-acciones)) fallan aquí.

**Qué muestra cada entrada**: icono de estado (su nombre aparece al mantenerlo pulsado), título o "Mensaje de n8n" si está vacío, cuerpo, una línea por cada acción y fecha y hora de recepción.

**Almacenamiento**
- Clave `nc.push.history`: lista JSON, la más reciente primero, con un máximo de 50 entradas.
- Un push con el mismo `id` que una entrada existente actualiza su estado y su contenido. Conserva su posición y su fecha de recepción.
- Los datos corruptos se descartan sin romper la bandeja.
- El botón *Vaciar bandeja* (con confirmación) borra todas las entradas.

---

## 13. Compartir con n8n

Desde cualquier app, el menú Compartir de Android (texto o enlace, `text/plain`) incluye **n8n Connect**.

**En el móvil**
1. La app recibe el texto y el asunto de la app de origen (`EXTRA_TEXT` y `EXTRA_SUBJECT`).
2. Si la app ya estaba abierta, lo recoge al momento; si no, lo espera. Hasta que haya sesión con el servidor, el contenido solo vive en memoria: si la app se cierra antes, se pierde.
3. Se abre la pantalla **Compartir con n8n**, con el asunto (solo si lo hay), el texto seleccionable (altura máxima de 320 px, con desplazamiento), el campo *Nota (opcional)* y el botón *Enviar a n8n*.
4. Al enviar, el botón muestra un indicador de carga y el campo de nota se bloquea. La petición es:

```
POST n8n-connect/share      (JWT)
{"text": "https://ejemplo.com/articulo", "subject": "Artículo", "note": "Leer el domingo"}
```

`subject` va como cadena vacía si no hay asunto. `note` se envía sin espacios al principio ni al final.

5. Respuesta: la app muestra `message` (o "Enviado a n8n." si viene vacío), ejecuta `actions` si las hay y cierra la pantalla. Las acciones se ejecutan aunque el usuario haya salido mientras esperaba. Como no hay pantalla de app abierta, las que la necesitan fallan ([§7](#7-acciones)).
6. Si el envío falla, aparece una tarjeta de error en la pantalla. El texto y la nota se conservan para reintentar.

Si llega otro contenido con la pantalla ya abierta, se abre otra pantalla encima.

**En n8n** (workflow "n8n Connect · Compartir")
- Nodo Webhook POST `n8n-connect/share`, con *Authentication = "JWT Auth"*, como el resto de webhooks ([§2](#2-seguridad)).
- Recibe `{text, subject, note}`.
- Guarda una fila en la tabla `nc_inbox` ([§4](#4-tablas)).
- Responde con JSON `{"message": "…"}`. Puede añadir `actions` ([§7](#7-acciones)), que la app ejecuta.

---

## 14. Automatizaciones

Una automatización es un push de n8n cuyas acciones se ejecutan solas en el móvil: sin diálogo y, con la app cerrada, sin notificación si todo va bien. Para que pase, el usuario tiene que permitirlo en cada app y el push tiene que cumplir una regla fija.

### 14.1 Permiso por app

- Lo concede el usuario en la pantalla de la app, con el componente `automation` ([§14.7](#147-componentes-automation-y-permission)). En **Configuración → Automatizaciones** aparecen las apps permitidas del servidor conectado; un interruptor quita cada permiso.
- Se guarda en SharedPreferences, sin cifrar, con la clave `nc.auto.{servidor}|{appId}`. Es por servidor: cambiar de servidor no borra el permiso del anterior, pero no se aplica al nuevo.
- Se borran **todos** los permisos y el token FCM del móvil (`push.deleteToken`) cuando se cierra la sesión con el servidor (`onSessionClosed` en `lib/main.dart`): al desconectar (también desde Configuración, al cerrar sesión o al borrar la cuenta), al cambiar de cuenta de Firebase y cuando el servidor revoca el acceso. Desconectar y cambiar de cuenta llaman además a `logout`; la revocación no.

### 14.2 Qué puede ejecutarse sin preguntar

Las acciones automáticas (`automaticActionTypes` en `lib/features/actions/action_spec.dart`) son `schedule_alarm`, `cancel_alarm`, `report` y `notify`.

Un push se decide con `decide()` en `lib/features/automation/background_automation.dart`, en este orden:

| Resultado | Cuándo |
|---|---|
| Descartar (`drop`) | No hay sesión con el servidor. O el push trae `to` y no coincide con el email de la sesión (sin distinguir mayúsculas) |
| Preguntar (`ask`) | Falta `app`, no hay acciones, alguna acción no es automática o tiene `confirm`, o la app no tiene permiso |
| Ejecutar (`run`) | Hay `app`, todas las acciones son automáticas sin `confirm` y la app tiene permiso |

- Sin `to` no hay comprobación de destinatario. La plantilla `send-to-phone` siempre lo envía ([§9](#9-push-n8n--móvil)).
- Con `automaticOnly` el ejecutor rechaza cualquier acción fuera de la lista. Lo mismo vale para las acciones de la respuesta de un `report`: si una no es automática, el `report` falla entero.

### 14.3 Cómo se ejecuta

| Caso | `run` | `drop` | `ask` |
|---|---|---|---|
| App abierta | Ejecuta sin diálogo, aunque el ajuste "Ejecutar acciones de n8n automáticamente" esté apagado. Si falla, muestra el error en un aviso. En la bandeja pasa de Pendiente a Ejecutado o Fallido | Se ignora. Queda en la bandeja como Pendiente | Diálogo normal ([§9](#9-push-n8n--móvil)) |
| App cerrada o en segundo plano | Se ejecuta en el isolate de FCM (`firebaseMessagingBackgroundHandler`), sin notificación si va bien. Se guarda en la bandeja como Ejecutado o Fallido. Si falla, muestra una notificación de error con el título del push | Se ignora sin notificación y no entra en la bandeja | Notificación normal con el botón *Ejecutar* |

- Si la automatización lanza una excepción antes de ejecutar, el push se muestra como notificación normal ([§9](#9-push-n8n--móvil)).
- Las entradas de segundo plano se guardan aparte y pasan a la bandeja al abrir la app ([§12](#12-bandeja-de-n8n)).

### 14.4 Acciones de automatización

**`schedule_alarm`** `{id, at, label, body}`
- `at`: ISO 8601. Con desfase (`2026-11-03T06:45:00+01:00`) es el instante exacto; sin desfase se toma como hora local del móvil. Debe estar en el futuro; si no, la acción falla.
- `id` (por defecto `default`) identifica la alarma dentro de la app. Programar otra con el mismo `id` en la misma app la reemplaza.
- `label` (por defecto `n8n`) es el título y `body` (por defecto la hora `HH:mm`) el texto.
- Es una alarma propia (plugin `alarm`): suena con la app cerrada, con el tono por defecto del móvil, vibra, abre la pantalla completa y sobrevive a reinicios. En primer plano muestra un aviso con la hora.

**`cancel_alarm`** `{id}`: cancela la alarma de esa app con ese `id`.

**`report`** `{path, include, data}`
- Hace `POST {path}` con el JWT (renueva la sesión si hace falta; timeout 60 s). Cuerpo: `timezoneOffsetMinutes`, `timezone`, `collectedAt`, `location` (según `include`), `app` (id de la app del push) y `data` (objeto tal cual).
- `include` por defecto es `["location"]`; vacío o ausente equivale a ese valor. Los nombres que no reconoce se ignoran; la zona horaria va siempre ([§14.5](#145-datos-del-móvil)).
- Si la respuesta trae `actions`, las ejecuta a continuación. En primer plano, las que tengan `confirm` piden confirmación. En segundo plano solo se ejecutan las automáticas ([§14.2](#142-qué-puede-ejecutarse-sin-preguntar)).
- Sin red falla. En segundo plano la ubicación requiere el permiso *siempre* (`location_always`); sin él, Android no da la posición.

**`request_permission`** `{permission}`: `location`, `location_always` o `notifications`. Muestra el diálogo del sistema. Para `location_always`, si la ubicación está solo "mientras se usa", abre los ajustes de la app. Si los servicios de ubicación están apagados, abre sus ajustes. No es automática: un push que la incluya siempre pregunta.

### 14.5 Datos del móvil

`DeviceContext.collect(include)` (`lib/features/device_context/device_context.dart`) produce, por ejemplo:

```json
{
  "timezoneOffsetMinutes": 60,
  "timezone": "CET",
  "collectedAt": "2026-11-02T20:30:00.000Z",
  "location": {"lat": 40.4168, "lng": -3.7038, "accuracy": 18.5, "timestamp": "2026-11-02T20:29:58.000Z"}
}
```

- `location` es una posición (`lat`, `lng`, `accuracy`, `timestamp`) o `{"error": "disabled" | "permission_denied" | "timeout"}`. `disabled`: los servicios de ubicación están apagados. `timeout`: no hay posición reciente en 15 s ni última posición conocida. `permission_denied`: falta el permiso o hubo un fallo.
- Un `submit` con `include: ["location"]` añade el mismo contenido como `_device` en el cuerpo ([§7](#7-acciones)). Sin `include` no se envía nada de esto.

### 14.6 Alarma del reloj y alarma propia

| | `set_alarm` | `schedule_alarm` |
|---|---|---|
| Dónde suena | App Reloj del sistema | La propia app (plugin `alarm`) |
| Con la app cerrada | No: Android bloquea abrir la app Reloj desde segundo plano | Sí |
| En automatizaciones | No | Sí |
| Cancelar | Desde la app Reloj | `cancel_alarm` |
| Dónde se ve | En la app Reloj (`show_alarms`) | Pantalla **Alarmas de n8n** (`/alarms`) |
| Reinicio del móvil | Lo gestiona el reloj | Sobrevive |

- **Alarmas de n8n** (Configuración → Automatizaciones): lista las alarmas propias con hora, fecha, etiqueta y app. Las que ya pasaron aparecen atenuadas con "Ya pasó". Cancelar pide confirmación y cancela esa alarma, igual que `cancel_alarm`.
- **Pantalla de aviso**: con la app abierta, al sonar una alarma propia se abre a pantalla completa con la hora, la etiqueta y dos botones, **Parar** y **Posponer 5 min** (vuelve a sonar 5 minutos después con la misma etiqueta). Con la app cerrada, el aviso lo da el plugin con una notificación a pantalla completa que tiene el botón *Stop*.
- **Limitación conocida**: con la app abierta, si la alarma que vuelve a sonar es la misma que acaba de parar o posponer, no se abre la pantalla de aviso (`AlarmEngine.ringing` usa `distinct`, que compara solo con el evento anterior). El sonido lo gestiona el plugin `alarm`.

### 14.7 Componentes automation y permission

| `type` | Campos | Qué muestra |
|---|---|---|
| `automation` | `label`, `description` | Interruptor para dejar que n8n ejecute acciones de esta app sin preguntar. Guarda el permiso de [§14.1](#141-permiso-por-app). Sin textos, usa "Acciones automáticas" y una descripción por defecto |
| `permission` | `permission` (`location`, `location_always` o `notifications`), `label`, `description` | Estado del permiso y el botón adecuado (ver abajo). Sin textos, usa los títulos por defecto del permiso |

Estados de `permission`:
- **Concedido**: check verde con "Concedido".
- **Denegado**: botón **Conceder**, que pide el permiso.
- **Denegado para siempre**: botón **Abrir ajustes**. En `notifications` el botón vuelve a pedir el permiso, y Android puede no mostrar nada.
- **No disponible**: solo el texto, sin botón.

El estado se vuelve a leer al mostrarse el componente y cada vez que la app vuelve a primer plano.

## 15. Ejemplos

### 15.1 Alarma

Es una pantalla de la app Herramientas (flow "n8n Connect · App · Herramientas", pantalla `alarma`): POST `n8n-connect/apps/tools/alarm`.

La app muestra una hora y una etiqueta. Al pulsar el botón envía el estado y el flow responde con una acción `set_alarm`. Forma resumida de la spec (la real está en el flow):

```json
{
  "schema": 1,
  "title": "Alarma",
  "start": "inicio",
  "state": {"alarma_hora": "07:30", "alarma_etiqueta": "Gym"},
  "screens": [
    {
      "id": "inicio",
      "components": [
        {"type": "time", "key": "alarma_hora", "label": "Hora"},
        {"type": "input", "key": "alarma_etiqueta", "label": "Etiqueta"},
        {
          "type": "button",
          "label": "Poner alarma",
          "icon": "alarm_add",
          "action": {"type": "submit", "path": "n8n-connect/apps/tools/alarm", "loading": "Programando…"}
        }
      ]
    }
  ]
}
```

Respuesta de `alarm` (la app pone la alarma y muestra un aviso):

```json
{"actions": [{"type": "set_alarm", "hour": 7, "minute": 30, "label": "Gym"}]}
```

La misma alarma sin abrir la app, desde un flow programado, con un push (ver `tools/send_push.py` en el README):

```bash
python3 tools/send_push.py --service-account /ruta/cuenta-servicio.json --token TOKEN_FCM \
  --title "Gym" --body "07:30" \
  --actions '[{"type":"set_alarm","hour":7,"minute":30,"label":"Gym"}]' --app tools
```

Con ese comando, en primer plano aparece el diálogo de confirmación; en segundo plano aparece la notificación con el botón *Ejecutar*.

### 15.2 Herramientas

La plantilla importable está en [n8n/workflows/app-tools.json](../n8n/workflows/app-tools.json) y la puesta en marcha del servidor en [n8n/README.md](../n8n/README.md).

Flows: "n8n Connect · App · Herramientas" (path `n8n-connect/apps/tools`). Es la app de demostración de los componentes nuevos y de las acciones de dispositivo. Forma ilustrativa, no copia del flow:

```json
{
  "schema": 1,
  "title": "Herramientas",
  "refreshSeconds": 30,
  "state": {"pasos": 3, "volumen": 40, "modo": true},
  "screens": [
    {
      "id": "inicio",
      "components": [
        {"type": "slider", "key": "volumen", "label": "Volumen", "min": 0, "max": 100, "step": 5, "unit": "%"},
        {"type": "stepper", "key": "pasos", "label": "Pasos", "min": 0, "max": 10},
        {"type": "checkbox", "key": "modo", "label": "Modo compacto"},
        {
          "type": "grid",
          "columns": 2,
          "components": [
            {"type": "metric", "label": "Pasos", "value": "{{pasos}}", "unit": "/ 10", "icon": "bolt", "tone": "success"},
            {"type": "progress", "label": "Objetivo", "value": "{{pasos}}", "max": 10}
          ]
        },
        {"type": "table", "columns": ["Acción", "Estado"], "rows": [["Compartir", "{{pasos}} pasos"], ["Mapa", "Madrid"]]},
        {"type": "button", "label": "Compartir", "icon": "send", "action": {"type": "share", "text": "Llevo {{pasos}} pasos"}},
        {"type": "button", "label": "Mapa", "icon": "location_on", "style": "outlined", "action": {"type": "maps", "lat": 40.4168, "lng": -3.7038, "label": "Madrid"}},
        {"type": "button", "label": "Vibrar", "icon": "bolt", "style": "tonal", "action": {"type": "vibrate", "style": "medium"}}
      ]
    }
  ]
}
```

### 15.3 Ejemplo de diseño: despertador según la agenda

No es un flow real, sino un diseño: cada noche calcula la hora de despertar de mañana según la agenda, la ubicación del móvil y el tiempo de viaje.

> No hay plantilla en `n8n/workflows/`. Depende de datos personales (agenda, ubicación y preferencias del usuario) y de credenciales propias. Úsalo como referencia de diseño, no como flow para importar.

- **Preferencias por usuario**: una tabla de datos propia con el modo de transporte (`driving` coche, `transit` transporte público, `bicycling` bici o `walking` a pie), los minutos de preparación, los minutos de margen, la hora de respaldo y el calendario.
- **Cada noche a una hora fija**, n8n manda un push a los móviles de los usuarios que han permitido las automatizaciones de la app ([§14.1](#141-permiso-por-app)). El push lleva una acción que el móvil ejecuta sola:

  ```json
  [{"type": "report", "path": "…", "include": ["location"], "data": {}}]
  ```

- **El móvil responde** con su ubicación y su zona horaria ([§14.5](#145-datos-del-móvil)). Si la app está cerrada, la ubicación requiere el permiso *siempre*.
- **n8n** lee el primer evento de mañana que tenga ubicación en el calendario del usuario. Pide a un servicio de rutas (por ejemplo, Google Maps Distance Matrix) el tiempo de viaje desde la ubicación del móvil, con el modo elegido y con la llegada a la hora de inicio del evento.
- **Hora de despertar** = inicio del evento − viaje − preparación − margen. n8n responde con:

  ```json
  {"actions": [{"type": "schedule_alarm", "id": "wakeup", "at": "2026-11-03T06:45:00+01:00", "label": "Despertador"}]}
  ```

  Con el mismo `id`, cada noche reemplaza la alarma de la noche anterior.
- **Botón *Recalcular ahora***: un submit con `include: ["location"]` que repite el cálculo con la ubicación actual.

Notas:
- Sin credencial del servicio de rutas en n8n, el flow usa los minutos de viaje de respaldo.
- La hora de respaldo del usuario sirve como alternativa cuando no hay un evento con ubicación.
- Si la hora calculada ya ha pasado, `schedule_alarm` falla ([§14.4](#144-acciones-de-automatización)).
