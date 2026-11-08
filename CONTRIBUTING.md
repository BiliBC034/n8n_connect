# Cómo contribuir a n8n Connect

¡Gracias por tu interés! Esta guía explica cómo preparar el entorno, qué comandos usar y qué esperamos de los cambios.

## Requisitos

- **Flutter 3.35** (canal stable) con **Dart 3.9**.
- **Android SDK** (la app es solo Android por ahora).

## Puesta en marcha

1. Clona el repositorio y entra en la carpeta.
2. Configura Firebase con una de estas opciones:
   - **Opción rápida (sin Firebase real)**: copia los archivos de ejemplo:
     - `lib/firebase_options.example.dart` → `lib/firebase_options.dart`
     - `lib/firebase_web_client.example.dart` → `lib/firebase_web_client.dart`
     - `android/app/google-services.example.json` → `android/app/google-services.json`: es **obligatorio** para compilar, porque el plugin `com.google.gms.google-services` lo exige. Con valores de ejemplo la app compila, pero el inicio de sesión no funciona.
   - **Opción completa**: ejecuta `flutterfire configure` con tu propio proyecto de Firebase. Esto genera `lib/firebase_options.dart`. Copia también `lib/firebase_web_client.example.dart` a `lib/firebase_web_client.dart` y rellénalo para Google Sign-In.
3. Para el inicio de sesión real, coloca el `google-services.json` de tu proyecto en `android/app/`. Antes de descargarlo, registra en la app Android de Firebase la huella SHA-1 de tu clave de firma (debug: `cd android && ./gradlew signingReport`), necesaria para Google Sign-In.
4. Instala las dependencias: `flutter pub get`.

Los archivos reales de Firebase están en `.gitignore`: no los subas nunca al repositorio.

## Comandos habituales

```bash
flutter pub get        # Instalar dependencias
flutter analyze        # Análisis estático (no debe haber avisos)
flutter test           # Tests
flutter build apk      # Generar el APK de Android
```

## Estilo de código

- Formatea con `dart format` antes de enviar cambios.
- `flutter analyze` no debe mostrar avisos.
- Los comentarios del código van en **inglés**.
- Los textos que ve la persona usuaria (interfaz, documentación y mensajes de commit) van en **español**.

## Commits

Usa el formato `<tipo>: <descripción>`, con la descripción en español y concisa:

| Tipo | Uso |
|---|---|
| `feat` | Nueva funcionalidad |
| `fix` | Corrección de un error |
| `perf` | Mejora de rendimiento |
| `refactor` | Cambio interno sin cambiar el comportamiento |
| `docs` | Documentación |
| `test` | Tests |
| `chore` | Mantenimiento (dependencias, configuración, etc.) |

Ejemplo: `fix: la alarma no se programa si la hora ya ha pasado`.

## Cambios en el protocolo

Si cambias el protocolo entre la app y n8n:

- Actualiza [`docs/PROTOCOL.md`](docs/PROTOCOL.md) en el mismo cambio.
- Si el cambio rompe la compatibilidad, incrementa `AppConfig.protocolVersion` y/o `AppConfig.specSchemaVersion` (en `lib/core/app_config.dart`) y explícalo en la descripción del PR.

## Secretos y datos personales

**Nunca subas secretos ni datos personales**: claves de API, tokens, `google-services.json`, claves de firma (`*.jks`, `*.keystore`, `android/key.properties`), correos, IPs o IDs reales de workflows o credenciales de n8n. Usa siempre datos de ejemplo en código, tests y documentación.

## Publicar una versión

Las versiones se publican como releases de GitHub con la APK firmada. Sigue [docs/RELEASING.md](docs/RELEASING.md) y actualiza `CHANGELOG.md` y la versión de `pubspec.yaml` en el mismo cambio.

## Pull requests

Rellena la plantilla de PR y asegúrate de que `flutter analyze` y `flutter test` pasan antes de pedir revisión.
