# Servidor n8n para n8n Connect

Esta carpeta contiene las plantillas de workflows y el esquema de tablas que necesita tu servidor de n8n para que la app Android muestre tus apps y ejecute acciones. Sirve igual para una persona que para un agente de IA con acceso a shell y, si lo tiene, al MCP de n8n.

El protocolo completo está en [docs/PROTOCOL.md](../docs/PROTOCOL.md). Las plantillas no contienen secretos ni IDs reales: usan placeholders `REPLACE_...` que tienes que sustituir (ver [§4](#4-referencia-de-placeholders)).

## 1. Contenido de esta carpeta

| Archivo | Workflow en n8n | Qué hace | Endpoints |
|---|---|---|---|
| `workflows/core.json` | n8n Connect · Core | Información del servidor, inicio de sesión con Firebase, catálogo de apps y logout de dispositivo | `GET n8n-connect/info` (pública), `POST n8n-connect/auth` (ID token de Firebase), `GET n8n-connect/apps` (JWT), `POST n8n-connect/logout` (JWT) |
| `workflows/share.json` | n8n Connect · Compartir | Recibe texto o enlaces de «Compartir → n8n Connect» y los guarda en `nc_inbox` | `POST n8n-connect/share` (JWT) |
| `workflows/app-tools.json` | n8n Connect · App · Herramientas | App de demo: panel en vivo, alarma, formulario y acciones del móvil | `GET n8n-connect/apps/tools`, `POST n8n-connect/apps/tools/echo`, `POST n8n-connect/apps/tools/alarm` (JWT) |
| `workflows/app-access.json` | n8n Connect · Acceso a app | Sub-workflow: decide si un email puede usar una app (según `nc_apps`). Lo llama `app-tools` | Ninguno (se llama desde otro workflow) |
| `workflows/send-to-phone.json` | n8n Connect · Enviar al móvil | Sub-workflow: envía un mensaje FCM de datos a los dispositivos del usuario. Lo llama `app-tools` | Ninguno (se llama desde otro workflow) |
| `data-tables.json` | No es un workflow | Esquema de las cuatro tablas (`nc_users`, `nc_devices`, `nc_apps`, `nc_inbox`) y filas de ejemplo | Ninguno |

Las plantillas de `workflows/` tienen solo las claves `name`, `nodes`, `connections` y `settings`. Sirven para «Import from File» en la UI y para `POST /api/v1/workflows` de la API pública.

## 2. Requisitos

- **n8n 2.x con Data tables** (las plantillas se hicieron con esa versión).
- **URL pública HTTPS** del servidor. La app rechaza `http://`.
- **Proyecto de Firebase** con:
  - Una app Android con el package name `me.bilibc.n8n_connect`.
  - Authentication con el proveedor Email/contraseña (y, si quieres, Google).
  - Cloud Messaging, para los push.
  - Una cuenta de servicio del proyecto con acceso a FCM.
- **Acceso a la API de n8n** (una API key), si vas a usar la vía por API o el agente.

## 3. Puesta en marcha

Ten a mano estos valores antes de empezar. Ninguno debe acabar en el repositorio.

### a. Firebase

Datos que necesitas (en la consola de Firebase, Configuración del proyecto; los nombres de pantalla pueden variar según el idioma y la versión de la consola):

| Dato | Dónde sale | Va en |
|---|---|---|
| Clave de API web | Configuración del proyecto → General | `REPLACE_FIREBASE_WEB_API_KEY` |
| ID del proyecto | Configuración del proyecto → General | `REPLACE_FIREBASE_PROJECT_ID` |
| JSON de la cuenta de servicio (email y clave privada) | Configuración del proyecto → Cuentas de servicio → Generar nueva clave privada | Credencial `n8n Connect FCM` |

**Cómo comprobarlo:** el ID del proyecto tiene que ser exactamente el que usa la app. Si no coincide, la app muestra `wrong_firebase_project` (ver [§6](#6-problemas-frecuentes)). El JSON de la cuenta de servicio es un secreto: guárdalo fuera del repo y no lo pegues en un chat.

### b. Credenciales en n8n

Crea dos credenciales con estos nombres exactos.

**`n8n Connect JWT`** (tipo *JWT Auth*, `jwtAuth`):
- Key Type: *Passphrase*.
- Secret: un secreto aleatorio largo. Genéralo con `openssl rand -base64 48`.
- Algorithm: `HS256`.

**`n8n Connect FCM`** (tipo *Google Service Account API*, `googleApi`):
- Email y clave privada de la cuenta de servicio (del JSON del paso a).
- Scope: `https://www.googleapis.com/auth/firebase.messaging`.
- Se usa en el nodo HTTP Request de `send-to-phone` (la plantilla ya lo tiene configurado).

Los nombres exactos de los campos dependen de tu versión de n8n. Consúltalos con la API:

```bash
curl -sS "$N8N_URL/api/v1/credentials/schema/jwtAuth" -H "X-N8N-API-KEY: $N8N_API_KEY"
curl -sS "$N8N_URL/api/v1/credentials/schema/googleApi" -H "X-N8N-API-KEY: $N8N_API_KEY"
```

Para crearlas por API: `POST /api/v1/credentials` con `{"name": "...", "type": "jwtAuth", "data": {...}}`. Para crearlas en la UI: *Credentials → Create credential*.

**Cómo comprobarlo:** aparecen con esos nombres en *Credentials* (o en `list_credentials` si usas el MCP). El secreto JWT no aparece en ningún archivo del repo.

### c. Tablas de datos

Crea cuatro Data tables con estas columnas (tomadas de `data-tables.json`):

| Tabla | Columnas (tipo) |
|---|---|
| `nc_users` | `email` (string), `enabled` (boolean), `role` (string), `name` (string) |
| `nc_devices` | `device_id` (string), `email` (string), `uid` (string), `name` (string), `platform` (string), `fcm_token` (string), `app_version` (string), `last_seen` (date) |
| `nc_apps` | `app_id` (string), `name` (string), `description` (string), `icon` (string), `color` (string), `path` (string), `enabled` (boolean), `allowed_emails` (string), `sort` (number) |
| `nc_inbox` | `email` (string), `text` (string), `subject` (string), `note` (string), `received_at` (date) |

Dónde: en la UI, *Data tables*. Con el MCP de n8n, `create_data_table`. Este README no documenta crear tablas por API.

Filas de ejemplo (seeds de `data-tables.json`):

- **`nc_users`**: una fila con `email` = tu email de Firebase **en minúsculas**, `enabled` = `true`, `role` = `admin`, `name` = tu nombre. Sin esta fila, el servidor rechaza tu cuenta.
- **`nc_apps`**: una fila para la app de demo, con `app_id` = `tools`, `name` = `Herramientas`, `description` = `Alarma, panel en vivo, formulario y acciones del móvil`, `icon` = `bolt`, `color` = `#0EA5E9`, `path` = `n8n-connect/apps/tools`, `enabled` = `true`, `allowed_emails` = vacío (todos los usuarios habilitados), `sort` = `30`.
- `nc_devices` y `nc_inbox` empiezan vacías. Las rellena el servidor.

**Cómo comprobarlo:** las cuatro tablas existen con todas sus columnas y tipos; `nc_users` tiene tu fila; `nc_apps` tiene la fila `tools` con `enabled` = `true`.

### d. Importar los workflows

Orden obligatorio, por tandas: **tanda 1** `app-access` y `send-to-phone` (sub-workflows); **tanda 2** `core` y `share`; **tanda 3** `app-tools`. Los sub-workflows van primero porque `app-tools` necesita sus IDs.

Hay dos vías.

**Vía 1: UI.**
1. *Import from File* con `workflows/app-access.json`. Repite con `send-to-phone.json`, `core.json`, `share.json` y `app-tools.json`, en ese orden.
2. En cada workflow, abre los nodos marcados y elige:
   - Credencial `n8n Connect JWT` en *Firmar sesión*, *Apps* y *Logout* (core); *Compartido desde el móvil* (share); *Pantalla*, *Formulario* y *Poner alarma* (app-tools).
   - Credencial `n8n Connect FCM` en *Enviar FCM* (send-to-phone).
   - Tabla por nombre: en core, *Buscar usuario* (`nc_users`), *Registrar dispositivo*, *Olvidar token push* y *Liberar token de otras cuentas* (`nc_devices`), *Leer apps* (`nc_apps`); en app-access, *Leer app* (`nc_apps`); en send-to-phone, *Dispositivos con push* (`nc_devices`); en share, *Guardar en nc_inbox* (`nc_inbox`); en app-tools, *Mis compartidos* (`nc_inbox`).
   - Sub-workflow: en app-tools, *Acceso (Pantalla)*, *Acceso (Formulario)* y *Acceso (Alarma)* → `n8n Connect · Acceso a app`; *Enviar al móvil* → `n8n Connect · Enviar al móvil`.
3. Los placeholders de texto no se eligen en un desplegable: edítalos a mano. Son `REPLACE_SERVER_NAME` (*Responder info* y *Responder sesión* de core), `REPLACE_FIREBASE_PROJECT_ID` (*Responder info* de core y la URL de *Enviar FCM* en send-to-phone) y `REPLACE_FIREBASE_WEB_API_KEY` (la URL de *Verificar ID token en Firebase* en core).

**Vía 2: API.** Copia las plantillas fuera del repo, rellena los placeholders y importa con `POST /api/v1/workflows`. Importa en tres tandas, porque `app-tools` necesita los IDs de los dos sub-workflows.

1. Guarda este script como `fill.py` **fuera del repo** (por ejemplo en `$HOME/n8n-connect-build/`). Solo sustituye los placeholders cuyas variables de entorno estén definidas:

   ```python
   import json, os, sys
   from pathlib import Path

   src, out = Path(sys.argv[1]), Path(sys.argv[2])  # carpeta workflows del repo; carpeta de salida (fuera del repo)
   out.mkdir(parents=True, exist_ok=True)

   names = {  # placeholder -> variable de entorno con el valor
       "REPLACE_CREDENTIAL_ID:n8n Connect JWT": "JWT_CRED_ID",
       "REPLACE_CREDENTIAL_ID:n8n Connect FCM": "FCM_CRED_ID",
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

2. Exporta las variables (los valores reales solo en la shell, nunca en un archivo del repo). `SERVER_NAME` no debe llevar comillas dobles ni barras invertidas.

3. Define la función `import_wf`. Imprime el `id` del workflow. Si la respuesta no trae `id`, imprime el error y sale con código 1: ese error no es un ID y no debes usarlo. Está escrita como subshell, así que el `exit` no cierra tu terminal:

   ```bash
   import_wf() ( # $1 = copia rellenada
     resp=$(curl -sS -X POST "$N8N_URL/api/v1/workflows" \
       -H "X-N8N-API-KEY: $N8N_API_KEY" \
       -H "Content-Type: application/json" \
       --data-binary "@$1") || exit 1
     printf '%s' "$resp" | python3 -c 'import json,sys; d=json.load(sys.stdin); sys.exit("Error al importar: " + json.dumps(d, ensure_ascii=False)) if "id" not in d else print(d["id"])' || exit 1
   )
   ```

4. **Tanda 1: sub-workflows.** Desde la raíz del repo, rellena las copias y comprueba **el archivo que vas a importar** con `grep REPLACE_ <archivo>` (no sobre toda la carpeta). Debe salir **vacío**; si imprime algo, no importes ese archivo. `app-access.json` solo necesita `DT_APPS`; `send-to-phone.json` necesita `FCM_CRED_ID`, `DT_DEVICES` y `FIREBASE_PROJECT_ID`.

   ```bash
   python3 -I "$HOME/n8n-connect-build/fill.py" n8n/workflows "$HOME/n8n-connect-build/out"
   grep REPLACE_ "$HOME/n8n-connect-build/out/app-access.json"      # debe no imprimir nada
   import_wf "$HOME/n8n-connect-build/out/app-access.json"          # anota el id impreso
   grep REPLACE_ "$HOME/n8n-connect-build/out/send-to-phone.json"   # debe no imprimir nada
   import_wf "$HOME/n8n-connect-build/out/send-to-phone.json"       # anota el id impreso
   ```

5. **Tanda 2: core y share.** Mismo control: `grep REPLACE_` sobre cada archivo antes de importarlo.

   ```bash
   grep REPLACE_ "$HOME/n8n-connect-build/out/core.json"    # debe no imprimir nada
   import_wf "$HOME/n8n-connect-build/out/core.json"        # ningún otro workflow usa su id
   grep REPLACE_ "$HOME/n8n-connect-build/out/share.json"   # debe no imprimir nada
   import_wf "$HOME/n8n-connect-build/out/share.json"       # ningún otro workflow usa su id
   ```

6. **Tanda 3: app-tools.** Exporta los IDs anotados en la tanda 1 (con tus valores reales, solo en la shell). Vuelve a ejecutar `fill.py`: solo `app-tools.json` cambia, porque es el único que usa `WF_*`. Comprueba ese archivo e impórtalo:

   ```bash
   export WF_APP_ACCESS=id-anotado-en-la-tanda-1
   export WF_SEND_TO_PHONE=id-anotado-en-la-tanda-1
   python3 -I "$HOME/n8n-connect-build/fill.py" n8n/workflows "$HOME/n8n-connect-build/out"
   grep REPLACE_ "$HOME/n8n-connect-build/out/app-tools.json"   # debe no imprimir nada
   import_wf "$HOME/n8n-connect-build/out/app-tools.json"
   ```

**Cómo comprobarlo:** en *Workflows* aparecen los cinco con los nombres de la tabla de arriba. No importes dos veces el mismo archivo: crea duplicados.

### e. Publicar

Publica o activa **core**, **share** y **app-tools**. Según tu versión, también puede hacer falta publicar **app-access** y **send-to-phone**.

- UI (n8n 2.x): botón **Publish** de cada workflow.
- API: `POST /api/v1/workflows/{id}/activate`. Esta ruta no está verificada para tu versión de n8n; si devuelve 404 o 405, publica desde la UI.
- MCP: `publish_workflow`.

**Cómo comprobarlo:** los webhooks de producción responden (`/webhook/...`, no `/webhook-test/...`). Un 404 significa que el workflow no está publicado o que la ruta no coincide.

### f. Probar

1. Información del servidor (pública):

   ```bash
   curl -sS https://n8n.example.com/webhook/n8n-connect/info
   ```

   Debe devolver JSON con cuatro campos:
   - `service`: `"n8n-connect"`.
   - `protocol`: `1`.
   - `name`: el valor que pusiste en `REPLACE_SERVER_NAME`.
   - `firebaseProjectId`: el ID del proyecto de Firebase (`REPLACE_FIREBASE_PROJECT_ID`).

2. Rutas protegidas sin token:

   ```bash
   curl -i https://n8n.example.com/webhook/n8n-connect/apps
   ```

   Debe responder 401 o 403 sin JWT (PROTOCOL §2: n8n responde 401/403 en texto plano).

3. En el móvil: instala la app, escribe la URL de tu servidor (`https://n8n.example.com`; la app quita rutas como `/webhook`), inicia sesión con la cuenta de `nc_users` y comprueba que **Herramientas** aparece en el catálogo. Ábrela: debe mostrar el panel en vivo, y el formulario debe responder «n8n recibió el formulario».

Comprobación extra de la sesión: `curl -i -X POST https://n8n.example.com/webhook/n8n-connect/auth` sin token. Según el código de *Validar identidad*, debe responder 401 con `error.code` = `invalid_token`. Esto no está probado en tu despliegue.

## 4. Referencia de placeholders

| Placeholder | Qué poner | De dónde sale | Archivo y nodos |
|---|---|---|---|
| `REPLACE_CREDENTIAL_ID:n8n Connect JWT` | ID de la credencial JWT | Lo asigna n8n al crear `n8n Connect JWT` (o `list_credentials`) | `core.json`: Firmar sesión, Apps, Logout. `share.json`: Compartido desde el móvil. `app-tools.json`: Pantalla, Formulario, Poner alarma |
| `REPLACE_CREDENTIAL_ID:n8n Connect FCM` | ID de la credencial Google Service Account | Lo asigna n8n al crear `n8n Connect FCM` | `send-to-phone.json`: Enviar FCM |
| `REPLACE_DATA_TABLE_ID:nc_users` | ID de la tabla `nc_users` | Data tables (`search_data_tables` con MCP) | `core.json`: Buscar usuario |
| `REPLACE_DATA_TABLE_ID:nc_devices` | ID de la tabla `nc_devices` | Igual | `core.json`: Registrar dispositivo, Olvidar token push, Liberar token de otras cuentas. `send-to-phone.json`: Dispositivos con push |
| `REPLACE_DATA_TABLE_ID:nc_apps` | ID de la tabla `nc_apps` | Igual | `core.json`: Leer apps. `app-access.json`: Leer app |
| `REPLACE_DATA_TABLE_ID:nc_inbox` | ID de la tabla `nc_inbox` | Igual | `share.json`: Guardar en nc_inbox. `app-tools.json`: Mis compartidos |
| `REPLACE_WORKFLOW_ID:app-access` | ID del workflow «n8n Connect · Acceso a app» | Su id al importarlo (UI: el de la URL; API: el `id` de la respuesta) | `app-tools.json`: Acceso (Pantalla), Acceso (Formulario), Acceso (Alarma) |
| `REPLACE_WORKFLOW_ID:send-to-phone` | ID del workflow «n8n Connect · Enviar al móvil» | Igual | `app-tools.json`: Enviar al móvil |
| `REPLACE_FIREBASE_WEB_API_KEY` | Clave de API web de Firebase | Configuración del proyecto → General | `core.json`: URL de Verificar ID token en Firebase (`identitytoolkit.../accounts:lookup?key=...`) |
| `REPLACE_FIREBASE_PROJECT_ID` | ID del proyecto de Firebase | Configuración del proyecto → General | `core.json`: Responder info (`firebaseProjectId`). `send-to-phone.json`: URL de Enviar FCM (`fcm.googleapis.com/v1/projects/...`) |
| `REPLACE_SERVER_NAME` | Nombre visible del servidor (sin comillas dobles ni barras invertidas) | Lo eliges tú | `core.json`: Responder info (`name`) y Responder sesión (`server.name`) |

## 5. Para agentes de IA

Checklist verificable. Si no puedes cumplir un punto, detente y pregunta al usuario.

1. **Variables.** Necesitas `N8N_URL` (sin barra final, p. ej. `https://n8n.example.com`) y `N8N_API_KEY`. Si no existen en el entorno, pídelas. No inventes valores.
2. **Acceso.** `curl -sS -o /dev/null -w "%{http_code}" "$N8N_URL/api/v1/workflows" -H "X-N8N-API-KEY: $N8N_API_KEY"` debe devolver `200`.
3. **Datos de Firebase.** Pide al usuario la clave de API web, el ID del proyecto y la ruta local al JSON de la cuenta de servicio. Usa la ruta solo para crear la credencial; no la copies al repo.
4. **Orden.** Credenciales (`n8n Connect JWT`, `n8n Connect FCM`) → tablas y filas seed → sub-workflows (`app-access`, `send-to-phone`) → `core`, `share` → `app-tools` → publicar → probar.
5. **Por cada workflow.** Rellena la copia con `fill.py` en un directorio fuera del repo. Comprueba `grep REPLACE_ <copia>/<archivo>.json` sobre el archivo que vas a importar: debe estar vacío. Importa con `POST /api/v1/workflows` y guarda el `id` devuelto (función `import_wf` de la §3.d).
6. **Comprobaciones finales.** `GET $N8N_URL/webhook/n8n-connect/info` devuelve `service`, `protocol`, `name` y `firebaseProjectId` con los valores correctos. `GET $N8N_URL/webhook/n8n-connect/apps` sin token devuelve 401 o 403.
7. **Con MCP de n8n.** Antes de crear nada, llama a `get_instance_context`. Para IDs usa `search_data_tables` y `list_credentials`. Para tablas, `create_data_table` y `add_data_table_rows`. Para publicar, `publish_workflow`.

**No hagas esto:**
- No escribas secretos ni valores reales (API keys, secreto JWT, clave privada de Firebase, IDs reales, emails reales o URLs de producción) en `n8n/` ni en ningún otro archivo del repo.
- No subas copias rellenadas de los JSON. Las copias van fuera del repo.
- No sustituyas los placeholders en las plantillas del repo: se rellenan solo en copias.
- No pegues el secreto JWT ni la clave privada en un chat o un log.
- No importes dos veces el mismo workflow (se duplica). Si ocurre, borra el duplicado.
- No publiques un workflow mientras quede algún `REPLACE_`.
- No uses `/webhook-test/` para probar la app: la app usa `/webhook/`.

## 6. Problemas frecuentes

Los códigos vienen de [docs/PROTOCOL.md](../docs/PROTOCOL.md) y del código de los nodos.

- **`not_allowed` (403): «La cuenta … no está autorizada en este servidor».** El email no tiene fila habilitada en `nc_users`. Añade la fila con el email en minúsculas y `enabled` = `true`.
- **`account_disabled`, `email_not_verified` o `no_email` (403).** Los pone el servidor según la cuenta de Firebase. `email_not_verified` se resuelve verificando el email en Firebase.
- **`wrong_firebase_project`.** El `firebaseProjectId` de `info` no coincide con el proyecto de la app. Corrige `REPLACE_FIREBASE_PROJECT_ID` y republica `core`.
- **`app_forbidden` o «Esta app no está registrada en el servidor».** Falta la fila `tools` en `nc_apps` (o su `app_id` no coincide). Si la fila existe pero la app no aparece en el catálogo, revisa que `enabled` sea `true` y que tu email esté en `allowed_emails` (vacío = todos).
- **El push no llega.** Comprueba, en este orden:
  1. Que la credencial `n8n Connect FCM` existe y tiene el scope `https://www.googleapis.com/auth/firebase.messaging`.
  2. Que `REPLACE_FIREBASE_PROJECT_ID` de la URL de Enviar FCM es el del proyecto.
  3. Que tu fila de `nc_devices` tiene `fcm_token` y el email correcto. Sin token no hay envío. La respuesta `{"sent": 0, "reason": "no_devices"}` indica que el usuario no tiene dispositivos con token (PROTOCOL §9).
  4. Que no has cerrado sesión en el móvil (el logout borra el `fcm_token`).
- **Errores que no son JSON o que la app interpreta como sesión caducada.** La app trata como `session_invalid` un 401 sin `error.code` y un 403 cuyo cuerpo no es un objeto JSON (PROTOCOL §3.6). Un 401 con `{"error": {"code": "..."}}` conserva su código. Para tus propios rechazos usa 403 (o 400/404) con `{"error": {"code": "...", "message": "..."}}`, y nunca un 401 para un permiso de app.
- **502, 504 o peticiones cortadas.** Si pones un proxy como Cloudflare delante de n8n, sustituye el cuerpo de las respuestas 502/504 y corta las peticiones a los 100 s (error 524): responde con 4xx o 424 y mantén cada petición por debajo de ese límite. Si una dependencia falla, responde 424 con `error.code` y `error.message` (PROTOCOL §8). La app espera hasta 150 s en submit (`AppConfig.submitTimeout`).
- **`not_found` (404).** El webhook no existe o el workflow no está publicado. Revisa la ruta (`n8n-connect/...`, sin `/webhook/` duplicado) y publica el workflow.
- **`invalid_token` (401) en `auth`.** Firebase rechazó el ID token: sesión caducada o de otro proyecto. Cierra sesión en la app e inicia de nuevo.
- **`upstream_error` (424) en `auth`.** El servidor no pudo verificar el ID token con Google (Google respondió algo distinto de 400, o hubo un fallo de red). La app muestra el mensaje de *Validar identidad*. Vuelve a intentarlo en unos segundos.
- **La app rechaza la URL.** Solo acepta `https://`. Un servidor local sin HTTPS no funciona con la app.
