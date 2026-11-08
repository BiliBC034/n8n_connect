# Directrices del Proyecto

## 1. Flujo de Control de Versiones Local (Git)
- **Al iniciar una nueva petición**: Antes de modificar cualquier archivo, verificar si existen cambios pendientes no guardados en el repositorio local (`git status`). Si los hay, registrarlos con un commit previo (`git add . && git commit -m "chore: checkpoint previo"`).
- **Al finalizar los cambios solicitados**: Inmediatamente después de aplicar las modificaciones solicitadas por el usuario, agregarlas al staging y hacer commit (`git add . && git commit -m "<tipo>: <descripción concisa>"`) para que el usuario pueda auditar el diff de forma inmediata en su repositorio local.

## 2. Ahorro de Tokens y Respuestas Ultraconcisas
- Al implementar o modificar código/documentación, la respuesta final en el chat debe ser **mínima y directa** (máximo 1-2 líneas confirmando los archivos modificados y el commit).
- No incluir resúmenes extensos, no repetir fragmentos de código modificados ni dar explicaciones innecesarias a menos que el usuario lo solicite expresamente.

## 3. Qué es este repo

**n8n Connect** es una app Flutter (solo Android de momento) que muestra y ejecuta *apps* definidas en flujos de n8n. La APK es fija: las apps se crean en n8n. La app no tiene lógica de negocio: dibuja una spec JSON, guarda estado local y ejecuta las acciones del móvil que le pide n8n.

El protocolo completo está en [docs/PROTOCOL.md](docs/PROTOCOL.md). Si este archivo contradice al protocolo o al código, manda el código y corrige el documento.

Mapa del repositorio:

| Ruta | Contenido |
|---|---|
| `lib/core/` | Constantes del protocolo (`app_config.dart`), router, plantillas `{{…}}`, utilidades JSON y log |
| `lib/features/actions/` | Tipos de acción (`action_spec.dart`), ejecutor (`action_executor.dart`) y acciones de dispositivo |
| `lib/features/alarms/` | Alarmas propias de la app (`schedule_alarm`): motor, pantalla de aviso y listado |
| `lib/features/apps/` | Catálogo, runner de apps, render de componentes (`spec_view.dart`), iconos (`app_style.dart`) y caché sin conexión |
| `lib/features/auth/` | Inicio de sesión con Firebase (email y contraseña, o Google) y verificación de email |
| `lib/features/automation/` | Permiso de automatizaciones por app y ejecución de pushes con la app cerrada |
| `lib/features/device_context/` | Datos del móvil (zona horaria, ubicación) y permisos del sistema |
| `lib/features/onboarding/` | Tutorial de primer inicio (`onboarding_page.dart`) y `OnboardingService` (`onboarding_service.dart`), que guarda si ya se completó u omitió |
| `lib/features/push/` | FCM: recepción de pushes `nc`, eventos y bandeja de n8n |
| `lib/features/server/` | Cliente HTTP de n8n (`n8n_api.dart`), sesión JWT, URL del servidor y almacenamiento seguro |
| `lib/features/settings/` | Configuración, idioma y tema |
| `lib/features/share/` | Recibir texto o enlaces de "Compartir" y enviarlos a n8n |
| `lib/features/startup/` | Arranque, pantalla de inicio y marca `BrandMark` (`brand.dart`) |
| `lib/l10n/` | Textos de la app en ARB: `intl_es.arb` e `intl_en.arb` |
| `lib/generated/` | Código generado por intl_utils. No editar a mano |
| `lib/main.dart`, `lib/app.dart` | Entrada de la app |
| `test/` | Tests unitarios y de widgets (`*_test.dart`) |
| `docs/` | `PROTOCOL.md`: protocolo n8n Connect v1. `RELEASING.md`: firma y publicación de versiones |
| `n8n/` | `workflows/` (plantillas importables) y `data-tables.json` (esquema de las tablas) |
| `tools/` | `send_push.py`: envía un push de prueba sin pasar por n8n. `build_release.sh`: compila la release en `dist/`. `changelog_section.sh`: imprime las notas de una versión de `CHANGELOG.md`. `release_secrets.sh`: muestra o sube los secretos de GitHub Actions. `verify_apk_signature.sh`: comprueba con apksigner que una APK no lleva la clave debug |
| `assets/branding/` | Logo c8c: `logo.svg` (completo), `logo-mark.svg` (solo el texto) y `logo-512.png` |
| `android/` | Única plataforma configurada. `applicationId`: `me.bilibc.n8n_connect` |
| `ios/` | Sin configurar |

## 4. Comandos

Ejecutar desde la raíz del repositorio. El CI (`.github/workflows/ci.yml`) usa Flutter 3.35.x, canal stable.

Configuración local de Firebase (primera vez). Los archivos reales están en `.gitignore`: no los subas nunca.

```bash
cp lib/firebase_options.example.dart lib/firebase_options.dart
cp lib/firebase_web_client.example.dart lib/firebase_web_client.dart
cp android/app/google-services.example.json android/app/google-services.json
```

- Alternativa: `flutterfire configure` genera `lib/firebase_options.dart`. El `google-services.json` se descarga de la consola de Firebase.
- `lib/firebase_web_client.dart` define `firebaseWebClientId`: el client ID de tipo web (`client_type` 3 en `google-services.json`). Vacío oculta el botón de Google.
- Google Sign-In en Android necesita registrar la huella SHA-1 de la clave de firma en la app Android de Firebase (`me.bilibc.n8n_connect`). Con la clave debug: `cd android && ./gradlew signingReport` y copia el SHA-1 de la variante debug. Hazlo antes de descargar `google-services.json`.

Comandos habituales:

```bash
flutter pub get
flutter analyze
flutter test
dart format lib test
dart run intl_utils:generate    # tras editar lib/l10n/*.arb
flutter build apk --release
```

- `dart run intl_utils:generate` lee la sección `flutter_intl` de `pubspec.yaml` (`arb_dir: lib/l10n`, `output_dir: lib/generated`). Edita siempre los dos ARB (`es` y `en`).
- `flutter build apk --release` firma con la clave de `android/key.properties` (local, ignorado por git) si existe; si no, con la clave debug. Publicar versiones: [docs/RELEASING.md](docs/RELEASING.md) (etiqueta `vX.Y.Z` → workflow Release).
- El CI copia los `.example`, luego ejecuta `flutter analyze` y `flutter test`. Antes de dar un cambio por bueno, pasa esos dos comandos y `dart format`.
- `tools/send_push.py` necesita el paquete Python `firebase_admin` y la cuenta de servicio (`--service-account` o la variable `GOOGLE_APPLICATION_CREDENTIALS`).

## 5. Inicializar el servidor n8n

La guía completa (credenciales, placeholders, pruebas y problemas frecuentes) está en [n8n/README.md](n8n/README.md). Resumen:

1. **Firebase.** Anota el ID del proyecto y la clave de API web (Configuración del proyecto → General). Descarga `google-services.json` para la app Android `me.bilibc.n8n_connect`. Crea una cuenta de servicio para los push.
2. **Credenciales en n8n** (las crea una persona; son secretos):
   - `n8n Connect JWT`: tipo "JWT Auth", con passphrase HS256 y un secreto aleatorio largo (por ejemplo `openssl rand -base64 48`).
   - `n8n Connect FCM`: tipo "Google Service Account API", con la cuenta de servicio de Firebase y el scope `https://www.googleapis.com/auth/firebase.messaging`.
3. **Tablas.** Crea `nc_users`, `nc_devices`, `nc_apps` y `nc_inbox` según [n8n/data-tables.json](n8n/data-tables.json) y la [§4 del protocolo](docs/PROTOCOL.md#4-tablas). Anota sus IDs.
4. **Importar** en este orden: `app-access` y `send-to-phone` (sub-workflows, para conocer sus IDs), luego `core`, `share` y `app-tools`. Sustituye los placeholders de la tabla siguiente.
5. **Publicar** cada workflow (botón Publish en n8n 2.x). Un webhook sin publicar responde 404.
6. **Probar** con `GET https://TU-SERVIDOR/webhook/n8n-connect/info`: debe devolver `service: "n8n-connect"`, `protocol: 1`, el nombre del servidor y el ID del proyecto Firebase.
7. **Dar acceso**: añade en `nc_users` una fila con el email de la cuenta en minúsculas, `enabled` a `true`, `role` y `name`. Sin fila, `auth` responde `not_allowed`.
8. **Apps**: cada app necesita su fila en `nc_apps` (ver la sección 6).

| Placeholder | Sustituir por | Usado en |
|---|---|---|
| `REPLACE_CREDENTIAL_ID:n8n Connect JWT` | ID de la credencial JWT Auth | `core`, `share`, `app-tools` |
| `REPLACE_CREDENTIAL_ID:n8n Connect FCM` | ID de la credencial Google Service Account | `send-to-phone` |
| `REPLACE_DATA_TABLE_ID:<tabla>` | ID de cada tabla de datos | `nc_users`: `core`. `nc_devices`: `core`, `send-to-phone`. `nc_apps`: `core`, `app-access`. `nc_inbox`: `share`, `app-tools` |
| `REPLACE_WORKFLOW_ID:app-access` | ID del workflow "n8n Connect · Acceso a app" | `app-tools` |
| `REPLACE_WORKFLOW_ID:send-to-phone` | ID del workflow "n8n Connect · Enviar al móvil" | `app-tools` |
| `REPLACE_FIREBASE_WEB_API_KEY` | Clave de API web de Firebase | `core` (verificación del ID token) |
| `REPLACE_FIREBASE_PROJECT_ID` | ID del proyecto Firebase | `core` (info), `send-to-phone` (URL de FCM) |
| `REPLACE_SERVER_NAME` | Nombre visible del servidor | `core` (info y sesión) |

**Un agente de IA** puede, con la API pública o el MCP de n8n: importar las plantillas (`POST /api/v1/workflows`; el JSON solo trae `name`, `nodes`, `connections` y `settings`), crear tablas y filas, consultar IDs, publicar y probar los webhooks. En el MCP de n8n, los nombres son `create_data_table`, `add_data_table_rows`, `search_data_tables`, `list_credentials` y `publish_workflow`. Crear credenciales no aparece entre sus herramientas: lo hace una persona.

**Necesita de una persona**: los secretos (secreto JWT, cuenta de servicio, clave de API web), el ID del proyecto Firebase, el email que se autoriza en `nc_users` y la confirmación antes de publicar. Nunca escribas esos valores en el repositorio ni en un chat.

## 6. Crear una app de n8n Connect

Resumen operativo. Detalle en el protocolo: [§5 Cómo crear una app](docs/PROTOCOL.md#5-cómo-crear-una-app), [§6 spec](docs/PROTOCOL.md#6-spec-de-ui-schema-1), [§7 acciones](docs/PROTOCOL.md#7-acciones), [§8 respuesta de submit](docs/PROTOCOL.md#8-respuesta-de-submit), [§10 refreshSeconds](docs/PROTOCOL.md#10-paneles-en-vivo-refreshseconds) y [§14 automatizaciones](docs/PROTOCOL.md#14-automatizaciones).

### 6.1 Piezas

1. **Fila en `nc_apps`**: `app_id`, `name`, `description`, `icon` (de la lista de la sección 6.5), `color` (`#RRGGBB`), `path` (`n8n-connect/apps/<id>`), `enabled`, `allowed_emails` (vacío = todos los usuarios habilitados) y `sort`. Ver [§4](docs/PROTOCOL.md#4-tablas).
2. **Webhook GET `n8n-connect/apps/<id>`**: devuelve la spec JSON.
3. **Webhooks de submit**, uno por acción de servidor, por ejemplo `POST n8n-connect/apps/<id>/saludar`.
4. **Autenticación**: todos con *Authentication = "JWT Auth"* y la credencial `n8n Connect JWT`. Los claims verificados llegan en `$json.jwtPayload` (`email`, `did`, `role`…).
5. **Control de acceso**: justo después de cada Webhook, llama al sub-workflow `n8n Connect · Acceso a app` con `app_id` y `email` (`jwtPayload.email`). Si devuelve `allowed: false`, responde 403 con `{error: {code: "app_forbidden", message}}` (el `error` del sub-workflow), como en la plantilla. Sin esta comprobación, `allowed_emails` solo filtra el catálogo y no bloquea los webhooks.
6. **Punto de partida**: duplica `n8n/workflows/app-tools.json`, la app de demostración que usa casi todos los componentes y acciones. Cambia su path y su `app_id` (en la plantilla, los nodos de acceso tienen `app_id: "tools"` fijado).

### 6.2 Spec de UI (schema 1)

Campos de primer nivel: `schema` (1 por defecto; mayor que 1 da `unsupported_spec`), `title` (título por defecto), `start` (id de la pantalla inicial), `state` (valores iniciales), `refreshSeconds` (mínimo 10) y `screens` (lista de `{id, title, components}` o mapa `id → pantalla`). Sin pantallas válidas da `bad_spec`.

```json
{"schema": 1, "title": "Hola", "start": "inicio", "state": {"nombre": ""},
 "screens": [{"id": "inicio", "components": [
   {"type": "input", "key": "nombre", "label": "Tu nombre", "required": true},
   {"type": "button", "label": "Enviar", "action": {"type": "submit", "path": "n8n-connect/apps/hola/saludar"}}
 ]}]}
```

- Los controles guardan su valor en `state[key]`. Las claves que empiezan por `_` son locales y no se envían.
- **Plantillas `{{clave}}`**: admiten rutas (`{{user.name}}`, `{{items.0.title}}`). Una clave inexistente se muestra vacía en texto.
- **Regla del valor crudo**: si una cadena es solo `"{{x}}"`, se usa el tipo original (número, booleano, objeto). Aplica a los parámetros de acciones y a `visible`.
- **`visible`** es falso si vale `null`, `false`, `0`, `""`, `"false"`, `"0"`, `"no"`, una lista vacía o un objeto vacío. Sin `visible`, el componente se muestra.
- **`required`** solo se valida en el móvil, sobre los componentes de primer nivel de la pantalla (no dentro de `card`). Es ayuda de interfaz: el servidor debe validar siempre.

### 6.3 Componentes

Los 24 `type` que dibuja la app (`lib/features/apps/spec_view.dart`). Un `type` desconocido muestra "Componente no soportado" y no rompe la pantalla.

- `text`: texto (`text`, `style` `title`/`subtitle`/`caption`, `align`). Admite plantillas.
- `banner`: aviso con `tone` `info`, `success`, `warning` o `error`.
- `card`: contenedor con `title`, `subtitle`, `icon` y `components`.
- `image`: imagen `url` solo `https` y `height`. Si falla la carga, no muestra nada.
- `divider`: línea separadora.
- `spacer`: espacio vertical (`height`, 16 por defecto).
- `input`: campo de texto (`key`, `label`, `hint`, `keyboard`, `obscure`, `required`).
- `switch`: interruptor booleano (`key`, `label`, `description`).
- `checkbox`: casilla booleana (`key`, `label`, `description`).
- `select`: lista de `options` `{value, label, description, disabled}`; `style` `chips`, `radio` o desplegable.
- `multiselect`: chips de selección múltiple; guarda la lista de `value`.
- `date`: selector de fecha; guarda `yyyy-MM-dd`.
- `time`: selector de hora; guarda `HH:mm`.
- `slider`: barra deslizante (`min`, `max`, `step`, `unit`).
- `stepper`: botones − y + (`min`, `max`, `step`).
- `button`: botón (`label`, `icon`, `style` `tonal`/`outlined`/`text`, `action` y/o `actions`). Sin acciones queda deshabilitado.
- `list`: elementos tocables `items` `{title, subtitle, trailing, icon, action / actions}`.
- `details`: pares `{label, value}`.
- `progress`: barra de progreso (`value`, `max`, `label`).
- `metric`: indicador (`label`, `value`, `unit`, `icon`, `tone` `success`/`warning`/`error`, `caption`).
- `grid`: filas de columnas iguales (`columns`, de 1 a 4) con `components` hijos.
- `table`: tabla de solo lectura (`columns`, `rows`).
- `automation` ([§14.7](docs/PROTOCOL.md#147-componentes-automation-y-permission)): interruptor del permiso de automatizaciones de la app.
- `permission` ([§14.7](docs/PROTOCOL.md#147-componentes-automation-y-permission)): estado y botón de un permiso (`location`, `location_always`, `notifications`).

En los componentes nuevos, `min`, `max`, `step`, `value` y `columns` admiten plantillas.

### 6.4 Acciones

Una acción es un objeto `{"type": ..., ...parámetros, "confirm": ...}`. Se ejecutan en orden y la lista se detiene en el primer error o si el usuario cancela una confirmación. `confirm` acepta un texto o `{title, message, confirmLabel}`. Las 28 acciones de `lib/features/actions/action_spec.dart`:

Necesitan una pantalla de app abierta:
- `submit`: envía datos a `path` o `url` (`method`, `body`, `keys`, `loading`) y aplica la respuesta.
- `navigate`: abre una pantalla (`screen`). Si ya está en la pila, vuelve a ella.
- `back`: vuelve atrás; en la primera pantalla cierra la app.
- `reload`: vuelve a pedir la spec y reinicia estado y pila.
- `set_state`: mezcla valores en el estado (`values`).
- `read_clipboard`: copia el portapapeles en `state[key]`.

Sin pantalla de app:
- `open_app`: abre otra app del catálogo (`app`).
- `toast`: aviso breve (`message`).
- `dialog`: diálogo con Aceptar (`title`, `message`).
- `set_alarm`: alarma en la app Reloj (`hour` y `minute` o `time`, `label`, `days`, `vibrate`, `skipUi`).
- `set_timer`: temporizador de 1 s a 24 h (`seconds` o `minutes`, `label`, `skipUi`).
- `calendar_event`: formulario de evento prellenado (`title`, `start`, `end`, `location`, `description`, `allDay`).
- `open_url`: abre un enlace `https`, `http`, `mailto`, `tel` o `geo` (`url`).
- `copy`: copia texto (`text`).
- `share`: selector de compartir de Android (`text`, `subject`).
- `dial`: abre el marcador con el número sin llamar (`number`).
- `sms`: abre mensajes con destinatario y texto (`number`, `body`).
- `email`: abre un correo nuevo (`to`, `subject`, `body`).
- `maps`: abre un lugar (`query`, o `lat` y `lng`) o inicia la navegación (`navigate`).
- `vibrate`: vibración háptica (`style`: `light`, `medium`, `heavy` o `vibrate`).
- `show_alarms`: abre la lista de alarmas del reloj.
- `open_settings`: abre un ajuste del sistema (`panel`: `wifi`, `bluetooth`, `location`, `display`, `sound`, `battery`, `date`, `notifications` o `app`).
- `launch_app`: abre una app por nombre de paquete (`package`).
- `request_permission`: pide un permiso (`location`, `location_always`, `notifications`). No es automática.

Automáticas (las únicas que pueden ejecutarse sin preguntar; `automaticActionTypes`):
- `notify`: notificación local (`title`, `body`).
- `schedule_alarm`: alarma propia de la app que suena aunque la app esté cerrada (`id`, `at` en ISO 8601, `label`, `body`). Con el mismo `id`, reemplaza la anterior.
- `cancel_alarm`: cancela la alarma propia con ese `id`.
- `report`: envía datos del móvil por POST a `path` (`include`, `data`) y ejecuta las `actions` de la respuesta.

Las acciones de intent (`share`, `dial`, `sms`, `email`, `maps`, `show_alarms`, `open_settings`, `launch_app`) solo funcionan en Android. Los parámetros admiten plantillas.

### 6.5 Iconos

Solo estos nombres son válidos en `icon` (de la app o de un componente); los demás se ignoran. Tabla de `lib/features/apps/app_style.dart`:

`add`, `alarm`, `alarm_add`, `apps`, `arrow_back`, `arrow_forward`, `bolt`, `calendar_today`, `camera`, `check`, `check_circle`, `close`, `cloud`, `delete`, `directions_car`, `edit`, `email`, `error`, `event`, `event_available`, `favorite`, `fitness_center`, `home`, `info`, `lightbulb`, `link`, `list`, `local_cafe`, `location_on`, `lock`, `music_note`, `notifications`, `person`, `phone`, `play_arrow`, `power`, `refresh`, `restaurant`, `schedule`, `search`, `send`, `settings`, `shopping_cart`, `star`, `stop`, `thermostat`, `timer`, `warning`, `wb_sunny`, `work`

### 6.6 Respuesta de submit y errores

**Petición**: el método es el de la acción (`POST` por defecto). `POST`, `PUT`, `PATCH` y `DELETE` envían JSON; `GET` lo envía en la query string. El contenido es, por prioridad: `body`, luego `keys`, y si no hay ninguno, todo el estado salvo las claves con `_`. La app añade `Authorization: Bearer <JWT>`. Timeout de 150 s, con un overlay de `loading`.

**Respuesta**: un objeto JSON cuyos campos son opcionales. La app los aplica en este orden: `spec` (reemplaza la spec), `state` (mezcla valores), `screen` (navega), `message` (aviso) y `actions` (acciones, lista u objeto). Una 2xx vacía no hace nada; una 2xx que no es JSON da `bad_response`; una lista JSON se ignora.

**Errores**: `{"error": {"code": "…", "message": "…"}}`. Si el `code` no es uno de los que genera la app, se muestra el `message` tal cual. Códigos de la app: `network`, `timeout`, `session_invalid`, `not_found` (404: el webhook no existe o no está publicado), `bad_response`, `http_<status>`, `not_connected`, `signed_out`, `app_not_found`, `unsupported_spec` y `bad_spec` ([§3.6](docs/PROTOCOL.md#36-formato-de-error)).

### 6.7 Push, automatizaciones y permisos

- **Push n8n → móvil**: llama al sub-workflow `n8n Connect · Enviar al móvil` con Execute Sub-workflow y las entradas `email`, `title`, `body`, `actions` y `app` ([§9](docs/PROTOCOL.md#9-push-n8n--móvil)). Sin `actions` es un aviso; con `actions`, la app pide confirmación en primer plano y muestra un botón *Ejecutar* en segundo plano.
- **Automatización**: un push se ejecuta sin preguntar solo si la app tiene permiso, hay `app`, todas las acciones son automáticas y ninguna tiene `confirm` ([§14.2](docs/PROTOCOL.md#142-qué-puede-ejecutarse-sin-preguntar)). El permiso lo concede el usuario en la app, con el componente `automation` ([§14.1](docs/PROTOCOL.md#141-permiso-por-app)).
- **Alarmas**: para automatizaciones usa `schedule_alarm`; `set_alarm` abre la app Reloj y no sirve ([§14.6](docs/PROTOCOL.md#146-alarma-del-reloj-y-alarma-propia)).
- **Datos del móvil**: `report` y `include: ["location"]` añaden ubicación y zona horaria ([§14.5](docs/PROTOCOL.md#145-datos-del-móvil)).

### 6.8 Trampas conocidas

- **Títulos de pantalla**: el título de una pantalla (y el `title` de la spec, usado en la barra) es texto literal; no resuelve `{{…}}`. Los textos de los componentes sí.
- **`refreshSeconds`**: los valores menores de 10 se ignoran y la spec no se recarga sola ([§10](docs/PROTOCOL.md#10-paneles-en-vivo-refreshseconds)).
- **`reload`** reinicia el estado y la pila a `start`. Además, el `screen` de la respuesta se aplica antes que las `actions`, así que el reload lo deshace. Para volver a una subpantalla con datos frescos, responde `"actions": [{"type": "reload"}, {"type": "navigate", "screen": "…"}]`.
- **Proxy delante de n8n**: si pones un proxy como Cloudflare delante de n8n, sustituye el cuerpo de las respuestas 502/504 y corta las peticiones a los 100 s (error 524): responde con 4xx o 424 y mantén cada petición por debajo de ese límite. Si una dependencia falla, usa 424 con `error.code` y `error.message` ([§8](docs/PROTOCOL.md#8-respuesta-de-submit)).
- **Sesión**: la app trata como `session_invalid` un 401 sin `error.code` y un 403 cuyo cuerpo no es un objeto JSON, y renueva la sesión ([§3.6](docs/PROTOCOL.md#36-formato-de-error)). Un 401 con `{error: {code}}` conserva su código. Los errores de negocio van en 403 con JSON `{error: {code, message}}`.
- **Submit sin conexión**: `submit` nunca usa la copia offline; falla con `network` ([§11](docs/PROTOCOL.md#11-modo-sin-conexión)).
- **`required`** es solo ayuda de interfaz: valida también en el servidor ([§2](docs/PROTOCOL.md#2-seguridad)).

### 6.9 Checklist antes de dar una app por terminada

1. Un `GET n8n-connect/apps/<id>` con un JWT válido devuelve la spec. Para obtener el JWT: `POST n8n-connect/auth` con un ID token de Firebase ([§3.2](docs/PROTOCOL.md#32-post-n8n-connectauth)).
2. Sin acceso (email fuera de `allowed_emails` o app deshabilitada) responde 403 con JSON `{error: {code: "app_forbidden", message}}`. Un 401 sin `error.code`, o un 403 cuyo cuerpo no es un objeto JSON, hace que la app crea que la sesión caducó.
3. Cada submit responde JSON válido con las claves esperadas.
4. Los workflows de la app están publicados (sin publicar, 404).
5. El `app_id` de los nodos "Acceso" coincide con el `id` de la app.
6. Existe la fila en `nc_apps` con `enabled` a `true`, `path` igual a la ruta del GET, `icon` de la lista y `color` en `#RRGGBB`.
7. La app muestra la entrada tras refrescar el catálogo (arrastrar hacia abajo).

## 7. Cambiar la app Flutter

- **Idioma del código**: comentarios en inglés. Los textos visibles van en `lib/l10n/intl_es.arb` e `intl_en.arb`, ambos, y se regeneran con `dart run intl_utils:generate`. No edites `lib/generated/` a mano.
- **Protocolo**: cualquier cambio de protocolo actualiza `docs/PROTOCOL.md` y, si corresponde, las constantes `AppConfig.protocolVersion` y `AppConfig.specSchemaVersion` de `lib/core/app_config.dart`. La app rechaza `protocol` o `schema` mayores que esas constantes.
- **Tests**: cada parser, acción o regla nueva lleva test en `test/`. Pasa `flutter analyze` y `flutter test` antes de cerrar.
- **Sin secretos**: no subas claves, IDs de proyecto Firebase, emails reales, IPs ni URLs de servidores propios. Los archivos de Firebase reales son locales y están en `.gitignore`; en el repo solo van los `*.example`.
- **Git**: sigue la sección 1.
