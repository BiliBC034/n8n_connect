# Política de seguridad

## Versiones soportadas

Solo se mantiene la rama `main`. Las correcciones de seguridad se publican ahí; no hay ramas de mantenimiento para versiones anteriores.

## Cómo informar de una vulnerabilidad

**No abras un issue público** para reportar una vulnerabilidad.

Usa el aviso privado de GitHub:

1. Ve a la pestaña **Security** del repositorio.
2. Pulsa **Report a vulnerability**.
3. Describe el problema, los pasos para reproducirlo y el impacto que tendría.

Si el botón **Report a vulnerability** no aparece, abre un issue **sin detalles** de la vulnerabilidad, solo para pedir un canal privado de contacto.

Intentaremos responder en un plazo razonable y coordinar la corrección antes de hacer pública la información.

## Alcance

Se consideran en alcance, entre otras cosas:

- **Sesión y JWT**: emisión, validación, caducidad y renovación de la sesión con el servidor.
- **Ejecución de acciones recibidas por push**: cualquier forma en que un mensaje de n8n pueda provocar acciones en el móvil sin la confirmación o el permiso adecuados.
- **Almacenamiento de credenciales en el móvil**: la sesión se guarda en almacenamiento cifrado; cualquier fuga de tokens o secretos fuera de él es un problema.
- **Plantillas de n8n**: flows de ejemplo o plantillas que expongan datos o acciones de forma insegura.

Quedan fuera los problemas que dependen de un servidor n8n mal configurado por su propietario (por ejemplo, un webhook sin autenticación que el propio usuario ha desactivado) y los fallos en software de terceros, que deben reportarse a sus autores.

## Modelo de seguridad (resumen)

El modelo completo está en [docs/PROTOCOL.md, sección 2](docs/PROTOCOL.md#2-seguridad). En resumen:

- **Solo HTTPS**: la app no acepta servidores `http://` y no permite tráfico en claro.
- **Intercambio de sesión**: la app obtiene un token de Firebase y el servidor lo cambia por un JWT de corta duración (12 h). Los webhooks de las apps deben exigir ese JWT (las plantillas lo hacen).
- **Renovación automática**: la app pide un JWT nuevo antes de que caduque y, si el servidor rechaza la sesión, la renueva una vez.
- **Almacenamiento**: la sesión va en almacenamiento cifrado respaldado por el Keystore de Android. La copia offline, la bandeja y los permisos de automatización van sin cifrar y nunca contienen el JWT ni el token de Firebase.
- **Mismo origen**: una spec no puede enviar el JWT a otro dominio; las URL absolutas de envío deben ser HTTPS y tener el mismo host y puerto que el servidor.
- **Revocación**: el acceso se quita deshabilitando al usuario en el servidor, y los JWT ya emitidos se invalidan rotando el secreto de la credencial JWT.
- **Validación en el servidor**: los campos obligatorios de una spec solo sirven para la interfaz; el servidor debe validar siempre lo que recibe.

## Buenas prácticas para contribuir

- No subas claves, tokens, `google-services.json`, claves de firma (`*.jks`, `*.keystore`) ni datos personales.
- Si un secreto llega a subirse por error, revócalo primero y después limpia el historial.
