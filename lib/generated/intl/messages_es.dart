// DO NOT EDIT. This is code generated via package:intl/generate_localized.dart
// This is a library that provides messages for a es locale. All the
// messages from the main program should be duplicated here with the same
// function name.

// Ignore issues from commonly used lints in this file.
// ignore_for_file:unnecessary_brace_in_string_interps, unnecessary_new
// ignore_for_file:prefer_single_quotes,comment_references, directives_ordering
// ignore_for_file:annotate_overrides,prefer_generic_function_type_aliases
// ignore_for_file:unused_import, file_names, avoid_escaping_inner_quotes
// ignore_for_file:unnecessary_string_interpolations, unnecessary_string_escapes

import 'package:intl/intl.dart';
import 'package:intl/message_lookup_by_library.dart';

final messages = new MessageLookup();

typedef String MessageIfAbsent(String messageStr, List<dynamic> args);

class MessageLookup extends MessageLookupByLibrary {
  String get localeName => 'es';

  static String m0(number) => "Abrir el marcador con ${number}";

  static String m1(to) => "Escribir un correo a ${to}";

  static String m2(app) => "Abrir la app ${app}";

  static String m3(place) => "Abrir ${place} en Mapas";

  static String m4(place) => "Navegar hasta ${place}";

  static String m5(panel) => "Abrir ajustes de ${panel}";

  static String m6(key) => "Leer el portapapeles en ${key}";

  static String m7(text) => "Compartir texto: ${text}";

  static String m8(number) => "Escribir un SMS a ${number}";

  static String m9(time) => "Alarma puesta a las ${time}";

  static String m10(time) => "Alarma programada para las ${time}";

  static String m11(time, label) => "${time} · ${label} no sonará.";

  static String m12(app) => "App: ${app}";

  static String m13(email) => "Sesión iniciada como ${email}";

  static String m14(time) => "Poner una alarma a las ${time}";

  static String m15(title) => "Añadir evento al calendario: ${title}";

  static String m16(title) => "Mostrar notificación: ${title}";

  static String m17(app) => "Abrir la app ${app}";

  static String m18(url) => "Abrir ${url}";

  static String m19(permission) => "Pedir el permiso de ${permission}";

  static String m20(time) => "Programar una alarma a las ${time}";

  static String m21(duration) => "Iniciar un temporizador de ${duration}";

  static String m22(id) => "Dispositivo ${id}…";

  static String m23(type) =>
      "La acción \'${type}\' solo funciona dentro de una app.";

  static String m24(message) => "Fallo de inicio de sesión: ${message}";

  static String m25(error) => "Página no encontrada: ${error}";

  static String m26(message) => "Fallo de re-autenticación: ${message}";

  static String m27(code) => "Error del servidor (${code}).";

  static String m28(message) => "Fallo de registro: ${message}";

  static String m29(field) => "Rellena \"${field}\".";

  static String m30(current, total) => "Página ${current} de ${total}";

  static String m31(time) =>
      "Sin conexión. Mostrando datos guardados (${time}).";

  static String m32(time) => "Actualizado ${time}";

  static String m33(role) => "Rol: ${role}";

  static String m34(type) => "Componente no soportado: ${type}";

  final messages = _notInlinedMessages(_notInlinedMessages);
  static Map<String, Function> _notInlinedMessages(_) => <String, Function>{
    "actDescribeDial": m0,
    "actDescribeEmail": m1,
    "actDescribeLaunchApp": m2,
    "actDescribeMap": m3,
    "actDescribeNavigate": m4,
    "actDescribeOpenSettings": m5,
    "actDescribeReadClipboard": m6,
    "actDescribeShare": m7,
    "actDescribeShowAlarms": MessageLookupByLibrary.simpleMessage(
      "Ver las alarmas en la app Reloj",
    ),
    "actDescribeSms": m8,
    "actDescribeVibrate": MessageLookupByLibrary.simpleMessage(
      "Hacer vibrar el teléfono",
    ),
    "actShareChooser": MessageLookupByLibrary.simpleMessage("Compartir con"),
    "actionAlarmDone": m9,
    "actionCopied": MessageLookupByLibrary.simpleMessage(
      "Copiado al portapapeles",
    ),
    "actionScheduledAlarm": m10,
    "alarmsCancelConfirm": MessageLookupByLibrary.simpleMessage(
      "Cancelar alarma",
    ),
    "alarmsCancelFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudo cancelar la alarma.",
    ),
    "alarmsCancelMessage": m11,
    "alarmsCancelTitle": MessageLookupByLibrary.simpleMessage(
      "¿Cancelar esta alarma?",
    ),
    "alarmsCancelTooltip": MessageLookupByLibrary.simpleMessage(
      "Cancelar alarma",
    ),
    "alarmsCancelled": MessageLookupByLibrary.simpleMessage("Alarma cancelada"),
    "alarmsDefaultLabel": MessageLookupByLibrary.simpleMessage("Alarma"),
    "alarmsEmpty": MessageLookupByLibrary.simpleMessage(
      "Aún no hay alarmas. Las apps con acciones automáticas pueden poner alarmas desde n8n y aparecerán aquí.",
    ),
    "alarmsFromApp": m12,
    "alarmsLoadFailed": MessageLookupByLibrary.simpleMessage(
      "No se pudieron cargar las alarmas.",
    ),
    "alarmsPassed": MessageLookupByLibrary.simpleMessage("Ya pasó"),
    "alarmsRetry": MessageLookupByLibrary.simpleMessage("Reintentar"),
    "alarmsSnooze": MessageLookupByLibrary.simpleMessage("Posponer 5 min"),
    "alarmsStop": MessageLookupByLibrary.simpleMessage("Parar"),
    "alarmsTitle": MessageLookupByLibrary.simpleMessage("Alarmas de n8n"),
    "alreadyHaveAccount": MessageLookupByLibrary.simpleMessage(
      "¿Ya tienes una cuenta?",
    ),
    "appTitle": MessageLookupByLibrary.simpleMessage("n8n Connect"),
    "appsEmpty": MessageLookupByLibrary.simpleMessage(
      "Aún no hay apps. Añade una fila a la tabla nc_apps de tu servidor n8n.",
    ),
    "appsTitle": MessageLookupByLibrary.simpleMessage("Mis apps"),
    "automationDescription": MessageLookupByLibrary.simpleMessage(
      "Deja que esta app ponga alarmas y lea tu ubicación sin preguntar, incluso con la app cerrada.",
    ),
    "automationFailedTitle": MessageLookupByLibrary.simpleMessage(
      "Falló una automatización de n8n",
    ),
    "automationRanTitle": MessageLookupByLibrary.simpleMessage(
      "n8n ejecutó una automatización",
    ),
    "automationTitle": MessageLookupByLibrary.simpleMessage(
      "Acciones automáticas",
    ),
    "backToHomeTooltip": MessageLookupByLibrary.simpleMessage(
      "Volver a Inicio",
    ),
    "cancelButton": MessageLookupByLibrary.simpleMessage("Cancelar"),
    "compDecrease": MessageLookupByLibrary.simpleMessage("Disminuir"),
    "compIncrease": MessageLookupByLibrary.simpleMessage("Aumentar"),
    "confirmActionTitle": MessageLookupByLibrary.simpleMessage("¿Continuar?"),
    "confirmPasswordLabel": MessageLookupByLibrary.simpleMessage(
      "Confirmar Contraseña",
    ),
    "confirmReadClipboard": MessageLookupByLibrary.simpleMessage(
      "¿Dejar que esta app lea tu portapapeles y lo use en n8n?",
    ),
    "connectAllowListHint": MessageLookupByLibrary.simpleMessage(
      "Este email debe estar activado en la tabla nc_users del servidor.",
    ),
    "connectButton": MessageLookupByLibrary.simpleMessage("Conectar"),
    "connectSignedInAs": m13,
    "connectSubtitle": MessageLookupByLibrary.simpleMessage(
      "Introduce la dirección de tu servidor n8n. Debe usar HTTPS y tener publicado el workflow \'n8n Connect · Core\'.",
    ),
    "connectTitle": MessageLookupByLibrary.simpleMessage("Conecta tu n8n"),
    "connectUrlLabel": MessageLookupByLibrary.simpleMessage("URL del servidor"),
    "darkTheme": MessageLookupByLibrary.simpleMessage("Oscuro"),
    "deleteAccountButton": MessageLookupByLibrary.simpleMessage(
      "Eliminar Cuenta",
    ),
    "deleteButton": MessageLookupByLibrary.simpleMessage("Eliminar"),
    "describeAlarm": m14,
    "describeCalendarEvent": m15,
    "describeCancelAlarm": MessageLookupByLibrary.simpleMessage(
      "Cancelar una alarma",
    ),
    "describeCopy": MessageLookupByLibrary.simpleMessage(
      "Copiar texto al portapapeles",
    ),
    "describeNotify": m16,
    "describeOpenApp": m17,
    "describeOpenUrl": m18,
    "describeReport": MessageLookupByLibrary.simpleMessage(
      "Enviar datos del móvil (ubicación) a n8n",
    ),
    "describeRequestPermission": m19,
    "describeScheduleAlarm": m20,
    "describeTimer": m21,
    "deviceIdLabel": m22,
    "dialogActionCancel": MessageLookupByLibrary.simpleMessage("Cancelar"),
    "dialogActionConfirm": MessageLookupByLibrary.simpleMessage("Confirmar"),
    "disconnectButton": MessageLookupByLibrary.simpleMessage(
      "Desconectar del servidor",
    ),
    "dontHaveAccount": MessageLookupByLibrary.simpleMessage(
      "¿No tienes una cuenta?",
    ),
    "emailLabel": MessageLookupByLibrary.simpleMessage("Correo Electrónico"),
    "englishLanguage": MessageLookupByLibrary.simpleMessage("Inglés"),
    "errorActionChainFailed": MessageLookupByLibrary.simpleMessage(
      "n8n respondió con acciones que no se pudieron ejecutar.",
    ),
    "errorActionNeedsScreen": m23,
    "errorAppNotFound": MessageLookupByLibrary.simpleMessage(
      "Esa app ya no está disponible en el servidor.",
    ),
    "errorBadResponse": MessageLookupByLibrary.simpleMessage(
      "Respuesta inesperada del servidor.",
    ),
    "errorBadSpec": MessageLookupByLibrary.simpleMessage(
      "La app enviada por n8n no tiene pantallas o está mal formada.",
    ),
    "errorDeleteAccount": MessageLookupByLibrary.simpleMessage(
      "Fallo al eliminar la cuenta.",
    ),
    "errorDeviceAction": MessageLookupByLibrary.simpleMessage(
      "El móvil no pudo ejecutar esta acción (¿hay una app para ello?).",
    ),
    "errorEmailNotVerified": MessageLookupByLibrary.simpleMessage(
      "Verifica tu email antes de conectar.",
    ),
    "errorGeneric": MessageLookupByLibrary.simpleMessage(
      "Ocurrió un error inesperado.",
    ),
    "errorInvalidAction": MessageLookupByLibrary.simpleMessage(
      "La acción enviada por n8n tiene parámetros no válidos.",
    ),
    "errorLoginFailed": m24,
    "errorNetwork": MessageLookupByLibrary.simpleMessage(
      "No se pudo contactar con el servidor. Revisa la conexión.",
    ),
    "errorNotAllowed": MessageLookupByLibrary.simpleMessage(
      "Tu cuenta no está autorizada en este servidor.",
    ),
    "errorNotConnected": MessageLookupByLibrary.simpleMessage(
      "No hay ningún servidor conectado.",
    ),
    "errorNotN8nConnect": MessageLookupByLibrary.simpleMessage(
      "Esta URL no es un servidor n8n Connect (publica el workflow \'n8n Connect · Core\').",
    ),
    "errorPageNotFound": m25,
    "errorPasswordTooShort": MessageLookupByLibrary.simpleMessage(
      "La contraseña debe tener al menos 6 caracteres.",
    ),
    "errorPasswordsDoNotMatch": MessageLookupByLibrary.simpleMessage(
      "Las contraseñas no coinciden.",
    ),
    "errorReauthenticationFailed": m26,
    "errorRequiredField": MessageLookupByLibrary.simpleMessage(
      "Por favor, rellena todos los campos obligatorios.",
    ),
    "errorRequiresRecentLogin": MessageLookupByLibrary.simpleMessage(
      "Esta operación requiere que hayas iniciado sesión recientemente. Por favor, cierra sesión y vuelve a iniciarla, luego inténtalo de nuevo.",
    ),
    "errorServer": m27,
    "errorSessionInvalid": MessageLookupByLibrary.simpleMessage(
      "La sesión con el servidor ha caducado. Vuelve a conectar.",
    ),
    "errorSignedOut": MessageLookupByLibrary.simpleMessage(
      "Inicia sesión primero.",
    ),
    "errorSignupFailed": m28,
    "errorTimeout": MessageLookupByLibrary.simpleMessage(
      "El servidor tardó demasiado en responder.",
    ),
    "errorTitle": MessageLookupByLibrary.simpleMessage("Error"),
    "errorUnsupportedAction": MessageLookupByLibrary.simpleMessage(
      "Esta versión de la app no admite esa acción.",
    ),
    "errorUnsupportedProtocol": MessageLookupByLibrary.simpleMessage(
      "El servidor usa una versión más nueva del protocolo. Actualiza la app.",
    ),
    "errorUnsupportedSpec": MessageLookupByLibrary.simpleMessage(
      "Esta app necesita una versión más nueva de n8n Connect.",
    ),
    "errorUpdateDisplayName": MessageLookupByLibrary.simpleMessage(
      "Fallo al actualizar el nombre de usuario.",
    ),
    "errorUpdatePassword": MessageLookupByLibrary.simpleMessage(
      "Fallo al actualizar la contraseña.",
    ),
    "errorUrlEmpty": MessageLookupByLibrary.simpleMessage(
      "Introduce la URL de tu servidor n8n.",
    ),
    "errorUrlForeignOrigin": MessageLookupByLibrary.simpleMessage(
      "Las apps solo pueden llamar a tu propio servidor n8n.",
    ),
    "errorUrlInsecure": MessageLookupByLibrary.simpleMessage(
      "Solo se admiten servidores HTTPS: tu sesión viajaría sin cifrar.",
    ),
    "errorUrlInvalid": MessageLookupByLibrary.simpleMessage(
      "Esa URL no es válida.",
    ),
    "errorUserNotLoggedIn": MessageLookupByLibrary.simpleMessage(
      "Error: Usuario no ha iniciado sesión.",
    ),
    "errorWebhookNotFound": MessageLookupByLibrary.simpleMessage(
      "Ese webhook no existe. ¿Está publicado el workflow en n8n?",
    ),
    "errorWrongFirebaseProject": MessageLookupByLibrary.simpleMessage(
      "Este servidor está configurado para otra app (otro proyecto de Firebase).",
    ),
    "fieldRequired": m29,
    "homePageTitle": MessageLookupByLibrary.simpleMessage("Inicio"),
    "inboxClearConfirm": MessageLookupByLibrary.simpleMessage("Vaciar"),
    "inboxClearMessage": MessageLookupByLibrary.simpleMessage(
      "Se eliminarán de esta lista todos los avisos recibidos.",
    ),
    "inboxClearTitle": MessageLookupByLibrary.simpleMessage(
      "¿Vaciar la bandeja?",
    ),
    "inboxClearTooltip": MessageLookupByLibrary.simpleMessage("Vaciar bandeja"),
    "inboxEmpty": MessageLookupByLibrary.simpleMessage("Todavía no hay avisos"),
    "inboxEmptyHint": MessageLookupByLibrary.simpleMessage(
      "Aquí aparecerán los mensajes enviados desde n8n.",
    ),
    "inboxRun": MessageLookupByLibrary.simpleMessage("Ejecutar"),
    "inboxStatusExecuted": MessageLookupByLibrary.simpleMessage("Ejecutado"),
    "inboxStatusFailed": MessageLookupByLibrary.simpleMessage("Fallido"),
    "inboxStatusIgnored": MessageLookupByLibrary.simpleMessage("Ignorado"),
    "inboxStatusPending": MessageLookupByLibrary.simpleMessage("Pendiente"),
    "inboxTitle": MessageLookupByLibrary.simpleMessage("Bandeja de n8n"),
    "inboxTooltip": MessageLookupByLibrary.simpleMessage("Bandeja de n8n"),
    "inboxUntitled": MessageLookupByLibrary.simpleMessage("Mensaje de n8n"),
    "languageName": MessageLookupByLibrary.simpleMessage("Español"),
    "languageSettings": MessageLookupByLibrary.simpleMessage("Idioma"),
    "languageTitle": MessageLookupByLibrary.simpleMessage("Seleccionar Idioma"),
    "lightTheme": MessageLookupByLibrary.simpleMessage("Claro"),
    "loginButton": MessageLookupByLibrary.simpleMessage("Iniciar Sesión"),
    "loginFooter": MessageLookupByLibrary.simpleMessage(
      "Tu servidor n8n decide qué cuentas pueden conectarse.",
    ),
    "loginPageTitle": MessageLookupByLibrary.simpleMessage("Iniciar Sesión"),
    "loginSubtitle": MessageLookupByLibrary.simpleMessage(
      "Inicia sesión para conectar tu móvil con tus workflows de n8n.",
    ),
    "logoutButton": MessageLookupByLibrary.simpleMessage("Cerrar Sesión"),
    "onboardingActionsBody": MessageLookupByLibrary.simpleMessage(
      "Los flujos pueden poner alarmas, crear eventos, abrir mapas, avisarte o compartir contenido. Solo se ejecutan sin preguntarte si lo permites en Configuración o en cada app.",
    ),
    "onboardingActionsTitle": MessageLookupByLibrary.simpleMessage(
      "Acciones en el móvil",
    ),
    "onboardingAppsBody": MessageLookupByLibrary.simpleMessage(
      "Cada app es un flujo que dibuja pantallas con formularios, listas y paneles en vivo. Al pulsar un botón, el flujo recibe los datos y responde.",
    ),
    "onboardingAppsTitle": MessageLookupByLibrary.simpleMessage(
      "Tus apps, hechas en n8n",
    ),
    "onboardingDone": MessageLookupByLibrary.simpleMessage("Empezar"),
    "onboardingNext": MessageLookupByLibrary.simpleMessage("Siguiente"),
    "onboardingPageLabel": m30,
    "onboardingPermissionsBody": MessageLookupByLibrary.simpleMessage(
      "n8n puede avisarte aunque la app esté cerrada. La ubicación solo se pide cuando una app la necesita, y puedes cambiar los permisos en los ajustes del móvil.",
    ),
    "onboardingPermissionsTitle": MessageLookupByLibrary.simpleMessage(
      "Notificaciones y permisos",
    ),
    "onboardingServerBody": MessageLookupByLibrary.simpleMessage(
      "Inicia sesión con tu cuenta y escribe la dirección de tu n8n. Solo entran las cuentas autorizadas en tu servidor, y cada petición lleva una sesión firmada.",
    ),
    "onboardingServerTitle": MessageLookupByLibrary.simpleMessage(
      "Conecta tu servidor",
    ),
    "onboardingSkip": MessageLookupByLibrary.simpleMessage("Saltar"),
    "onboardingWelcomeBody": MessageLookupByLibrary.simpleMessage(
      "Usa en el móvil las apps que creas con flujos de n8n. Cambias el flujo y la app se actualiza al momento, sin instalar nada nuevo.",
    ),
    "onboardingWelcomeTitle": MessageLookupByLibrary.simpleMessage(
      "Te damos la bienvenida a n8n Connect",
    ),
    "orSignInWith": MessageLookupByLibrary.simpleMessage("O inicia sesión con"),
    "passwordLabel": MessageLookupByLibrary.simpleMessage("Contraseña"),
    "permAlarmsTile": MessageLookupByLibrary.simpleMessage("Alarmas de n8n"),
    "permAutomationsHint": MessageLookupByLibrary.simpleMessage(
      "Activa las acciones automáticas desde dentro de cada app",
    ),
    "permAutomationsTitle": MessageLookupByLibrary.simpleMessage(
      "Automatizaciones",
    ),
    "permGrant": MessageLookupByLibrary.simpleMessage("Conceder"),
    "permGranted": MessageLookupByLibrary.simpleMessage("Concedido"),
    "permLocationAlwaysDescription": MessageLookupByLibrary.simpleMessage(
      "Necesario para que n8n lea dónde está el móvil con la app cerrada, por ejemplo para la alarma inteligente.",
    ),
    "permLocationAlwaysTitle": MessageLookupByLibrary.simpleMessage(
      "Ubicación todo el tiempo",
    ),
    "permLocationDescription": MessageLookupByLibrary.simpleMessage(
      "Permite que n8n lea dónde está el móvil mientras la app está abierta.",
    ),
    "permLocationTitle": MessageLookupByLibrary.simpleMessage("Ubicación"),
    "permNotificationsDescription": MessageLookupByLibrary.simpleMessage(
      "Permite que n8n muestre avisos y notificaciones en este móvil.",
    ),
    "permNotificationsTitle": MessageLookupByLibrary.simpleMessage(
      "Notificaciones",
    ),
    "permOpenSettings": MessageLookupByLibrary.simpleMessage("Abrir ajustes"),
    "permUnavailable": MessageLookupByLibrary.simpleMessage("No disponible"),
    "pushAutoRunHint": MessageLookupByLibrary.simpleMessage(
      "Con la app abierta, ejecuta las acciones push sin preguntar",
    ),
    "pushAutoRunTitle": MessageLookupByLibrary.simpleMessage(
      "Ejecutar acciones de n8n automáticamente",
    ),
    "pushDialogIgnore": MessageLookupByLibrary.simpleMessage("Ignorar"),
    "pushDialogIntro": MessageLookupByLibrary.simpleMessage("Acciones:"),
    "pushDialogRun": MessageLookupByLibrary.simpleMessage("Ejecutar"),
    "pushDialogTitle": MessageLookupByLibrary.simpleMessage(
      "n8n quiere ejecutar acciones",
    ),
    "reloadTooltip": MessageLookupByLibrary.simpleMessage("Recargar"),
    "retryButton": MessageLookupByLibrary.simpleMessage("Reintentar"),
    "runnerOfflineBanner": m31,
    "runnerUpdatedAt": m32,
    "saveButton": MessageLookupByLibrary.simpleMessage("Guardar"),
    "saveDetailsButton": MessageLookupByLibrary.simpleMessage(
      "Guardar Detalles",
    ),
    "selectedBingoCard": MessageLookupByLibrary.simpleMessage(
      "Cartón de Bingo Seleccionado",
    ),
    "serverChange": MessageLookupByLibrary.simpleMessage("Cambiar de servidor"),
    "serverNotConnected": MessageLookupByLibrary.simpleMessage("Sin conectar"),
    "serverResync": MessageLookupByLibrary.simpleMessage(
      "Volver a sincronizar el dispositivo",
    ),
    "serverResyncDone": MessageLookupByLibrary.simpleMessage(
      "Dispositivo sincronizado con el servidor",
    ),
    "serverResyncHint": MessageLookupByLibrary.simpleMessage(
      "Renueva la sesión y el token push en el servidor",
    ),
    "serverRole": m33,
    "serverSectionTitle": MessageLookupByLibrary.simpleMessage("Servidor n8n"),
    "settingsAboutTile": MessageLookupByLibrary.simpleMessage(
      "Acerca de n8n Connect",
    ),
    "settingsChangePasswordTile": MessageLookupByLibrary.simpleMessage(
      "Cambiar Contraseña",
    ),
    "settingsConfirmDeleteButton": MessageLookupByLibrary.simpleMessage(
      "Confirmar Eliminación",
    ),
    "settingsConfirmDeleteNoPasswordPrompt": MessageLookupByLibrary.simpleMessage(
      "¿Estás seguro de que quieres eliminar tu cuenta? Esta acción no se puede deshacer.",
    ),
    "settingsConfirmDeletePasswordPrompt": MessageLookupByLibrary.simpleMessage(
      "Por seguridad, introduce tu contraseña actual para eliminar tu cuenta. Esta acción no se puede deshacer.",
    ),
    "settingsConfirmDeleteTitle": MessageLookupByLibrary.simpleMessage(
      "Confirmar Eliminación de Cuenta",
    ),
    "settingsConfirmNewPasswordLabel": MessageLookupByLibrary.simpleMessage(
      "Confirmar Nueva Contraseña",
    ),
    "settingsCurrentPasswordLabel": MessageLookupByLibrary.simpleMessage(
      "Contraseña Actual",
    ),
    "settingsDeleteAccountTile": MessageLookupByLibrary.simpleMessage(
      "Eliminar Cuenta",
    ),
    "settingsDisplayNameHint": MessageLookupByLibrary.simpleMessage(
      "Introduce tu nombre de usuario",
    ),
    "settingsDisplayNameLabel": MessageLookupByLibrary.simpleMessage(
      "Nombre de Usuario",
    ),
    "settingsEmailLabel": MessageLookupByLibrary.simpleMessage(
      "Correo Electrónico",
    ),
    "settingsNewPasswordLabel": MessageLookupByLibrary.simpleMessage(
      "Nueva Contraseña",
    ),
    "settingsSaveNameTooltip": MessageLookupByLibrary.simpleMessage(
      "Guardar Nombre",
    ),
    "settingsSignOutTile": MessageLookupByLibrary.simpleMessage(
      "Cerrar Sesión",
    ),
    "settingsTitle": MessageLookupByLibrary.simpleMessage("Configuración"),
    "settingsTooltip": MessageLookupByLibrary.simpleMessage("Configuración"),
    "settingsTutorialTile": MessageLookupByLibrary.simpleMessage(
      "Ver el tutorial",
    ),
    "settingsUpdatePasswordButton": MessageLookupByLibrary.simpleMessage(
      "Actualizar Contraseña",
    ),
    "shareNoteLabel": MessageLookupByLibrary.simpleMessage("Nota (opcional)"),
    "shareNothingToShare": MessageLookupByLibrary.simpleMessage(
      "Nada que compartir todavía.",
    ),
    "shareSendButton": MessageLookupByLibrary.simpleMessage("Enviar a n8n"),
    "shareSendHint": MessageLookupByLibrary.simpleMessage(
      "El texto se envía a tu servidor de n8n.",
    ),
    "shareSent": MessageLookupByLibrary.simpleMessage("Enviado a n8n."),
    "shareTitle": MessageLookupByLibrary.simpleMessage("Compartir con n8n"),
    "signupButton": MessageLookupByLibrary.simpleMessage("Registrarse"),
    "signupPageTitle": MessageLookupByLibrary.simpleMessage("Registrarse"),
    "spanishLanguage": MessageLookupByLibrary.simpleMessage("Español"),
    "successAccountDeleted": MessageLookupByLibrary.simpleMessage(
      "Cuenta eliminada con éxito.",
    ),
    "successDisplayNameUpdated": MessageLookupByLibrary.simpleMessage(
      "¡Nombre de usuario actualizado con éxito!",
    ),
    "successPasswordUpdated": MessageLookupByLibrary.simpleMessage(
      "¡Contraseña actualizada con éxito!",
    ),
    "systemTheme": MessageLookupByLibrary.simpleMessage(
      "Predeterminado del Sistema",
    ),
    "themeSettings": MessageLookupByLibrary.simpleMessage("Tema"),
    "unsupportedComponent": m34,
    "useDeviceLanguage": MessageLookupByLibrary.simpleMessage(
      "Usar Idioma del Dispositivo",
    ),
    "userLabel": MessageLookupByLibrary.simpleMessage("Usuario"),
    "userNotLoaded": MessageLookupByLibrary.simpleMessage(
      "Usuario no cargado.",
    ),
  };
}
