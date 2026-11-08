# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato sigue [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el proyecto usa [Versionado Semántico](https://semver.org/lang/es/). Cada versión se publica como release de GitHub; el proceso está en [docs/RELEASING.md](docs/RELEASING.md).

## [1.0.0] - 2026-11-08

Primera versión pública.

> **Firebase del autor:** la APK publicada está compilada con el proyecto Firebase del autor y solo se conecta a servidores n8n configurados con ese mismo proyecto (con otro, la app rechaza la conexión con `wrong_firebase_project`). Para tu propio servidor, compila la app con tu propio Firebase (ver el [README](https://github.com/BiliBC034/n8n_connect#puesta-en-marcha)).

> **Requisitos:** Android 7.0 o superior (minSdk 24).

### Añadido

- **Apps definidas en n8n**: cada app es una spec JSON que la app dibuja en el móvil, con 24 tipos de componente (textos, formularios, selectores, deslizadores, tarjetas, listas, tablas, cuadrículas, indicadores, permisos y automatizaciones) y 28 acciones (de pantalla, del dispositivo y automáticas).
- **Sesión segura**: inicio de sesión con Firebase (email y contraseña con verificación, o Google). La app cambia el token de Firebase por una sesión JWT de 12 h emitida por tu servidor n8n y la renueva sola.
- **Conexión con n8n**: URL del servidor (solo HTTPS) y comprobación de que el servidor es un n8n Connect.
- **Catálogo de apps** en la pantalla principal, con plantillas `{{clave}}` y valores crudos.
- **Push con acciones**: avisos de n8n que piden confirmación o, si lo activas, se ejecutan sin preguntar. Bandeja con el historial de pushes y botón para volver a ejecutarlos.
- **Paneles en vivo**: las apps con `refreshSeconds` se recargan solas mientras están en pantalla.
- **Modo sin conexión**: sin red, el catálogo y las apps muestran la última copia guardada.
- **Automatizaciones con permiso por app**: cada app puede ejecutar sus acciones automáticas sin preguntar; el permiso se revoca en Configuración.
- **Alarmas propias de n8n**: suenan con la app cerrada, sobreviven a reinicios y se pueden posponer 5 minutos.
- **Datos del móvil para n8n**: ubicación y zona horaria, solo con permiso.
- **Permisos desde las apps**: un componente para ver y pedir ubicación o notificaciones.
- **Compartir con n8n**: envía texto o enlaces desde cualquier app a n8n, con una nota opcional.
- **Tutorial de primer inicio**, que se puede repetir desde Configuración.
- **Idioma español o inglés**, y tema claro u oscuro.
- **Plantillas de n8n importables**: Core, Enviar al móvil, Acceso a app, Compartir y la app de ejemplo Herramientas.
