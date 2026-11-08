# Publicar una versión de n8n Connect

Esta guía explica, paso a paso, cómo firmar la APK, guardar la clave a salvo, publicar una versión en GitHub Releases y instalarla en el móvil. No hace falta saber de firma de apps Android: se explica todo lo necesario.

Los comandos se ejecutan desde la raíz del repositorio, salvo que se indique otra cosa.

## Índice

- [a) Qué es la clave de firma](#a-qué-es-la-clave-de-firma)
- [b) Crear la clave](#b-crear-la-clave)
- [c) Copia de seguridad](#c-copia-de-seguridad)
- [d) Registrar la huella en Firebase](#d-registrar-la-huella-en-firebase)
- [e) Guardar los secretos en GitHub](#e-guardar-los-secretos-en-github)
- [f) Publicar una versión (automático)](#f-publicar-una-versión-automático)
- [g) Publicar a mano](#g-publicar-a-mano)
- [h) Instalar en el móvil](#h-instalar-en-el-móvil)
- [i) Problemas frecuentes](#i-problemas-frecuentes)

## a) Qué es la clave de firma

Toda APK de Android va firmada con una clave privada. La clave identifica a quien publica la app: Android comprueba que cada actualización esté firmada con la misma clave que la versión instalada.

Por eso importa:

- **Android solo instala una actualización** si va firmada con la misma clave que la versión que ya hay en el móvil. Si firmas con otra clave, Android rechaza la instalación.
- **Si pierdes la clave, no puedes publicar actualizaciones** que se instalen encima de las anteriores. La única salida es cambiar el identificador de la app, lo que equivale a una app nueva: los usuarios tendrían que desinstalar la anterior y perderían sesión y datos locales.
- **La clave nunca va al repositorio.** Vive en tu PC (y en una copia de seguridad) y se usa para firmar. En GitHub solo se guardan copias cifradas para el workflow de release.

La clave de depuración (debug) que usan Android Studio y `flutter run` no sirve para publicar: se genera sola en cada equipo (`~/.android/debug.keystore`), cambia si cambias de PC o la borras, y su contraseña es pública (`android`). Por eso `flutter build apk --release` usa la clave debug solo si no existe `android/key.properties`.

## b) Crear la clave

> El autor del proyecto ya tiene la clave creada. Esta sección documenta cómo se hizo, para repetirlo si hace falta en otro equipo o para otro proyecto.

1. Crea la carpeta en la que guardarás la clave (fuera del repositorio):

   ```bash
   mkdir -p ~/.android
   ```

2. Genera una contraseña fuerte con OpenSSL y guárdala en tu gestor de contraseñas en cuanto la veas:

   ```bash
   openssl rand -base64 32
   ```

   No la pegues en chats, issues ni capturas de pantalla.

3. Genera la clave con `keytool` (viene con el JDK que usa Flutter/Android Studio). Sustituye `Tu nombre` por tu nombre:

   ```bash
   keytool -genkeypair -v \
     -storetype PKCS12 \
     -keystore ~/.android/n8n-connect-release.jks \
     -alias n8n-connect \
     -keyalg RSA -keysize 4096 -validity 10000 \
     -dname "CN=Tu nombre"
   ```

   `keytool` pide la contraseña del almacén: usa la del paso anterior. Con PKCS12, la contraseña de la clave es la misma que la del almacén.

4. Crea el archivo `android/key.properties` con este formato. Está en `.gitignore`, así que git nunca lo sube. Sustituye los valores por los tuyos, sin comillas:

   ```properties
   storeFile=/ruta/absoluta/a/.android/n8n-connect-release.jks
   storePassword=CONTRASEÑA_DEL_ALMACÉN
   keyAlias=n8n-connect
   keyPassword=CONTRASEÑA_DE_LA_CLAVE
   ```

   - `storeFile` necesita la ruta **absoluta** (por ejemplo `/home/tu-usuario/.android/n8n-connect-release.jks`); Gradle no expande `~`.
   - Con PKCS12, `keyPassword` es igual que `storePassword`.

5. Restringe los permisos del archivo para que solo tu usuario pueda leerlo:

   ```bash
   chmod 600 android/key.properties
   ```

Comprueba que el archivo existe sin mostrar su contenido con `ls -l android/key.properties` (debe verse `-rw-------`). **No ejecutes `cat android/key.properties`** en una terminal compartida ni en una grabación.

## c) Copia de seguridad

Si pierdes el archivo `.jks` o su contraseña, pierdes la capacidad de actualizar la app (ver [a)](#a-qué-es-la-clave-de-firma)). Guarda copias en **dos sitios distintos**:

- **La contraseña**: en un gestor de contraseñas (Bitwarden, KeePass, 1Password o similar).
- **El archivo `~/.android/n8n-connect-release.jks`**: en un almacenamiento cifrado (disco o USB con cifrado, o un contenedor cifrado) y, si quieres, en un segundo lugar cifrado.

No guardes el `.jks` en la nube sin cifrar, ni por correo, ni en el repositorio.

**Los secretos de GitHub no sirven como copia de seguridad**: GitHub no permite leer un secreto una vez guardado. Solo puedes sobrescribirlo.

## d) Registrar la huella en Firebase

Firebase solo permite el inicio de sesión con Google desde apps cuya huella de firma esté registrada. Sin esto, el inicio de sesión con Google falla con el error 10 (`DEVELOPER_ERROR`).

1. Obtén las huellas de la clave de release:

   ```bash
   keytool -list -v -keystore ~/.android/n8n-connect-release.jks -alias n8n-connect
   ```

   Introduce la contraseña del almacén. Copia las líneas **SHA1** y **SHA256** (son dos cadenas de pares hexadecimales separados por `:`).

2. En la [consola de Firebase](https://console.firebase.google.com/), abre tu proyecto y ve a **Configuración del proyecto** (el engranaje) → pestaña **General** → sección **Tus apps**.

3. Selecciona la app Android `me.bilibc.n8n_connect` → **Añadir huella digital**. Añade **las dos** huellas (SHA-1 y SHA-256), una a una.

4. En la misma app, descarga de nuevo **google-services.json** y sustituye `android/app/google-services.json` por el nuevo. El archivo contiene la lista de huellas, así que hay que volver a descargarlo después de añadirlas.

5. Si además compilas en local con la clave debug (`flutter run`), su huella SHA-1 también debe estar registrada. Puedes verla con `cd android && ./gradlew signingReport`.

Si cambias `google-services.json`, actualiza también el secreto `GOOGLE_SERVICES_JSON_BASE64` ([e)](#e-guardar-los-secretos-en-github)).

## e) Guardar los secretos en GitHub

El workflow de release (`.github/workflows/release.yml`) necesita siete secretos para compilar y firmar la APK en GitHub. Se añaden en el repositorio:

**GitHub → repositorio → Settings → Secrets and variables → Actions → New repository secret.** Crea uno por cada nombre de la tabla, con el nombre exacto.

| Nombre del secreto | Qué contiene | Cómo obtenerlo |
|---|---|---|
| `ANDROID_KEYSTORE_BASE64` | El archivo `.jks` completo, codificado en base64 | `base64 -w0 ~/.android/n8n-connect-release.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña del almacén | `storePassword` de `android/key.properties` (o tu gestor de contraseñas) |
| `ANDROID_KEY_ALIAS` | Alias de la clave | `n8n-connect` |
| `ANDROID_KEY_PASSWORD` | Contraseña de la clave | `keyPassword` de `android/key.properties` (igual que la del almacén con PKCS12) |
| `GOOGLE_SERVICES_JSON_BASE64` | `android/app/google-services.json` en base64 | `base64 -w0 android/app/google-services.json` |
| `FIREBASE_OPTIONS_DART_BASE64` | `lib/firebase_options.dart` en base64 | `base64 -w0 lib/firebase_options.dart` |
| `FIREBASE_WEB_CLIENT_DART_BASE64` | `lib/firebase_web_client.dart` en base64 | `base64 -w0 lib/firebase_web_client.dart` |

La forma más cómoda es ejecutar el script del repositorio, que lee los archivos locales y muestra el nombre y el valor de cada secreto:

```bash
tools/release_secrets.sh
```

> **Advertencia: la salida de `tools/release_secrets.sh` contiene secretos** (la clave en base64 y las contraseñas). Cópialos directamente a GitHub, no los pegues en chats, issues ni capturas, y cierra la terminal cuando termines. Si la sesión se graba o se comparte, no la uses.

Con la [GitHub CLI](https://cli.github.com/) instalada y autenticada (`gh auth login`), el script puede subir los secretos por ti:

```bash
tools/release_secrets.sh --gh BiliBC034/n8n_connect
```

Indica siempre el repositorio (`OWNER/REPO`): si el clon tiene varios remotes, `gh` no sabe a cuál subirlos (o fija uno antes con `gh repo set-default`).

Comprueba después que aparecen los siete nombres en la lista de secretos del repositorio. Los valores no se pueden ver otra vez en GitHub, solo sobrescribir.

## f) Publicar una versión (automático)

Es el camino normal. Al subir una etiqueta `vX.Y.Z`, el workflow **Release** compila, firma y crea la release con la APK y su `.sha256`.

1. **Sube la versión** en `pubspec.yaml`. El formato es `version: X.Y.Z+N`:
   - `X.Y.Z` es la versión que ve la persona usuaria (la del nombre de la APK y la etiqueta).
   - `N` es el número de compilación. **Debe ser mayor que el de la versión anterior**: Android rechaza instalar una versión con un número igual o menor.

   ```yaml
   version: 1.0.1+4
   ```

2. **Añade la sección** en `CHANGELOG.md`, con el encabezado `## [X.Y.Z] - AAAA-MM-DD` y las notas en español. Las notas de la release son las líneas entre ese encabezado y el siguiente `## [`.

3. **Haz el commit** de los cambios:

   ```bash
   git add . && git commit -m "chore: publica la versión X.Y.Z"
   ```

4. **Etiqueta y sube** el commit y la etiqueta:

   ```bash
   git tag vX.Y.Z
   git push origin main
   git push origin vX.Y.Z
   ```

   La etiqueta debe ser exactamente `vX.Y.Z` y coincidir con `version` de `pubspec.yaml`. Si no coincide, el workflow falla (ver [i)](#i-problemas-frecuentes)).

5. **Sigue el proceso** en la pestaña **Actions** del repositorio, en el workflow **Release**. Si termina bien, la release aparece en **Releases** con la APK `n8n-connect-vX.Y.Z.apk` y su `n8n-connect-vX.Y.Z.apk.sha256`. Si falla, el log indica la causa (por ejemplo, secretos que faltan). El workflow comprueba los secretos y la etiqueta, ejecuta `flutter test` y solo compila si todo pasa.

## g) Publicar a mano

Úsalo si el workflow no funciona o si quieres compilar y revisar la APK antes de publicarla.

1. Asegúrate de tener `android/key.properties` y los archivos de Firebase locales (`lib/firebase_options.dart`, `lib/firebase_web_client.dart`, `android/app/google-services.json`).

2. Compila la release:

   ```bash
   tools/build_release.sh
   ```

   El script exige `android/key.properties` y deja en `dist/` (carpeta ignorada por git) la APK, su `.sha256` y `RELEASE_NOTES-vX.Y.Z.md`. Después comprueba que la APK no esté firmada con la clave debug: si el script termina con el error «firmada con la clave de DEPURACIÓN», **no publiques esa APK**, porque no podrá actualizar a las versiones firmadas con la clave de release. Revisa `android/key.properties` (ver [b)](#b-crear-la-clave)) y vuelve a compilar.

3. En GitHub, ve a **Releases → Draft a new release**:
   - **Choose a tag**: escribe `vX.Y.Z`. Si la etiqueta aún no existe, GitHub la crea sobre la rama principal, así que sube antes el commit. Ojo: si ya configuraste los secretos de [e)](#e-guardar-los-secretos-en-github), crear la etiqueta puede lanzar también el workflow **Release**, que publicaría su propia APK en esa release. Usa una vía u otra, no las dos.
   - **Release title**: `n8n Connect vX.Y.Z`.
   - **Description**: pega el contenido de `dist/RELEASE_NOTES-vX.Y.Z.md`.
   - **Attach binaries**: arrastra `dist/n8n-connect-vX.Y.Z.apk` y `dist/n8n-connect-vX.Y.Z.apk.sha256`.

4. Pulsa **Publish release**.

## h) Instalar en el móvil

1. En un PC, abre la [última release](https://github.com/BiliBC034/n8n_connect/releases/latest) y descarga `n8n-connect-vX.Y.Z.apk` y su `.sha256` en la misma carpeta.

2. Comprueba que la APK no está dañada:

   ```bash
   sha256sum -c n8n-connect-vX.Y.Z.apk.sha256
   ```

   Debe responder `n8n-connect-vX.Y.Z.apk: OK`. En Windows, PowerShell tiene `Get-FileHash -Algorithm SHA256`; compara el valor con el del archivo `.sha256`. (Si prefieres descargarla directamente en el móvil, puedes saltarte este paso.)

3. Pasa la APK al móvil (cable USB, nube, etc.) y permite instalar apps desconocidas para el gestor de archivos o el navegador que uses. Los menús cambian según la versión de Android; busca **Instalar apps desconocidas** en los ajustes de esa app o en **Ajustes → Apps → Acceso especial**.

4. Abre el archivo APK y pulsa **Instalar**.

> **Aviso:** si tenías instalada una versión firmada con **otra clave** (por ejemplo, una build de pruebas con la clave debug), Android no la actualiza. Desinstálala antes. Se pierden la sesión y los datos locales de la app (caché sin conexión, bandeja y permisos de automatización); el servidor y tus apps no cambian.

## i) Problemas frecuentes

- **"App no instalada", "el paquete parece no ser compatible" o conflicto de paquete.** La versión instalada está firmada con otra clave o tiene un número de compilación mayor. Desinstala la app actual (se pierden sesión y datos locales) e instala la nueva. Para evitarlo en el futuro, firma siempre con la misma clave.

- **Error 10 o `DEVELOPER_ERROR` al iniciar sesión con Google.** Falta la huella SHA-1 (y SHA-256) de la clave con la que se firmó la APK en la app Android de Firebase. Sigue [d)](#d-registrar-la-huella-en-firebase), descarga de nuevo `google-services.json` y actualiza el secreto `GOOGLE_SERVICES_JSON_BASE64`.

- **El workflow falla por secretos.** El paso de comprobación indica qué secretos faltan. Añádelos en **Settings → Secrets and variables → Actions** con el nombre exacto de la tabla de [e)](#e-guardar-los-secretos-en-github). Luego vuelve a ejecutar el workflow desde la pestaña **Actions**.

- **El workflow falla porque la etiqueta no coincide con `pubspec.yaml`.** La etiqueta `vX.Y.Z` debe ser igual que `X.Y.Z` de `version:`. Para corregirlo:
  1. Borra la etiqueta equivocada, en local y en GitHub:

     ```bash
     git tag -d vA.B.C
     git push origin :refs/tags/vA.B.C
     ```

  2. Si lo que estaba mal era `pubspec.yaml`, corrígelo y haz commit y push. Si lo que estaba mal era la etiqueta, no cambies nada.
  3. Crea la etiqueta correcta sobre el último commit y súbela:

     ```bash
     git tag vX.Y.Z
     git push origin vX.Y.Z
     ```

  Si ya se había publicado una release con la etiqueta equivocada, bórrala en GitHub (**Releases → Edit → Delete**).

- **"Keystore was tampered with, or password was incorrect" en el workflow.** El secreto `ANDROID_KEYSTORE_PASSWORD` no es la contraseña del almacén, o `ANDROID_KEYSTORE_BASE64` está incompleto (cópialo entero, es una sola línea larga). Sobrescribe los dos secretos.

- **"Cannot recover key" en el workflow.** El alias (`ANDROID_KEY_ALIAS`, debe ser `n8n-connect`) o `ANDROID_KEY_PASSWORD` son incorrectos. Con PKCS12, `ANDROID_KEY_PASSWORD` es la misma contraseña que la del almacén.

- **"key.properties no encontrado" en el aviso de compilación.** No has creado `android/key.properties`, así que la APK se firma con la clave debug. Crea el archivo ([b)](#b-crear-la-clave)) antes de publicar.

- **La compilación falla porque faltan archivos de Firebase.** Copia los `.example` a sus nombres reales o usa tu `google-services.json` y tus opciones de Firebase, como se explica en el [README](../README.md#puesta-en-marcha).
