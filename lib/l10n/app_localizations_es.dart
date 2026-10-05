// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'HummingBox';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get delete => 'Eliminar';

  @override
  String get discard => 'Descartar';

  @override
  String get create => 'Crear';

  @override
  String get nameLabel => 'Nombre';

  @override
  String editedCopyName(String name) {
    return '$name (editada)';
  }

  @override
  String get loadRecordingsFailed => 'No se pudieron cargar las grabaciones';

  @override
  String get newFolder => 'Nueva carpeta';

  @override
  String get invalidFolderName => 'Ese nombre no vale para una carpeta';

  @override
  String get microphonePermission =>
      'Permite el acceso al micrófono en los ajustes para poder grabar';

  @override
  String get startRecordingFailed => 'No se pudo iniciar la grabación';

  @override
  String get saveRecordingFailed => 'No se pudo guardar la grabación';

  @override
  String savedAs(String name) {
    return 'Guardada como «$name»';
  }

  @override
  String get discardRecordingTitle => '¿Descartar la grabación?';

  @override
  String get discardRecordingMessage =>
      'Se perderá el audio grabado hasta ahora.';

  @override
  String get stopToPlay => 'Detén la grabación para poder reproducir';

  @override
  String get stopToEdit => 'Detén la grabación para poder editar';

  @override
  String get stopToLeave => 'Detén la grabación antes de salir';

  @override
  String get changesSaved => 'Cambios guardados';

  @override
  String get renameFailed => 'No se pudo renombrar la grabación';

  @override
  String get shareFailed => 'No se pudo compartir la grabación';

  @override
  String deleteTitle(String name) {
    return '¿Eliminar «$name»?';
  }

  @override
  String get deleteMessage => 'Esta acción no se puede deshacer.';

  @override
  String get recordingDeleted => 'Grabación eliminada';

  @override
  String get deleteFailed => 'No se pudo eliminar la grabación';

  @override
  String get settings => 'Opciones';

  @override
  String get rootFolder => 'Grabaciones';

  @override
  String get emptyFolderTitle => 'Esta carpeta está vacía';

  @override
  String get emptyFolderHint => 'Pulsa el botón rojo para grabar en ella.';

  @override
  String get noRecordingsTitle => 'Aún no hay grabaciones';

  @override
  String get noRecordingsHint => 'Pulsa el botón rojo para empezar a grabar.';

  @override
  String get folders => 'Carpetas';

  @override
  String get search => 'Buscar';

  @override
  String get searchHint => 'Nombre o transcripción';

  @override
  String get clearSearch => 'Borrar la búsqueda';

  @override
  String get pullToSearch => 'Tira para buscar';

  @override
  String get releaseToSearch => 'Suelta para buscar';

  @override
  String get noSearchResultsTitle => 'Sin resultados';

  @override
  String noSearchResultsHint(String query) {
    return 'Ninguna grabación tiene «$query» en el nombre ni en la transcripción.';
  }

  @override
  String get play => 'Reproducir';

  @override
  String get pause => 'Pausar';

  @override
  String get rename => 'Renombrar';

  @override
  String get moreOptions => 'Más opciones';

  @override
  String get edit => 'Editar';

  @override
  String get share => 'Compartir';

  @override
  String dateToday(String time) {
    return 'Hoy, $time';
  }

  @override
  String dateYesterday(String time) {
    return 'Ayer, $time';
  }

  @override
  String dateOther(String date, String time) {
    return '$date, $time';
  }

  @override
  String get stereo => 'estéreo';

  @override
  String channels(int count) {
    return '$count canales';
  }

  @override
  String bitDepth(int bits) {
    return '$bits bits';
  }

  @override
  String perMinute(String size) {
    return '$size por minuto';
  }

  @override
  String get renameRecording => 'Renombrar grabación';

  @override
  String get hideRecordPanel => 'Ocultar el panel de grabación';

  @override
  String get showRecordPanel => 'Mostrar el panel de grabación';

  @override
  String get countdownStatus => 'Empieza a grabar en…';

  @override
  String get waitingForVoice => 'Esperando a que hables…';

  @override
  String get readyToRecord => 'Lista para grabar';

  @override
  String get recordingStatus => 'Grabando';

  @override
  String get pausedStatus => 'En pausa';

  @override
  String countdownButton(int seconds) {
    return 'Grabar tras una cuenta atrás de $seconds s';
  }

  @override
  String get resume => 'Reanudar';

  @override
  String get voiceButton => 'Grabar al detectar la voz';

  @override
  String get stopAndSave => 'Detener y guardar';

  @override
  String get startNow => 'Empezar ya';

  @override
  String get record => 'Grabar';

  @override
  String get previewFailed => 'No se pudo preparar la escucha';

  @override
  String get editSaveFailed => 'No se pudo guardar la edición';

  @override
  String get discardChangesTitle => '¿Descartar los cambios?';

  @override
  String get discardChangesMessage =>
      'Los cambios que no has guardado se perderán.';

  @override
  String get editRecording => 'Editar grabación';

  @override
  String get reset => 'Restablecer';

  @override
  String get saving => 'Guardando…';

  @override
  String get saveCopy => 'Guardar copia';

  @override
  String get openAudioFailed => 'No se pudo abrir el audio para editarlo.';

  @override
  String get preparingAudio => 'Preparando el audio…';

  @override
  String get trimStartLabel => 'Inicio';

  @override
  String get durationLabel => 'Duración';

  @override
  String get trimEndLabel => 'Fin';

  @override
  String get playSelection => 'Escuchar la selección';

  @override
  String get volume => 'Volumen';

  @override
  String get normalize => 'Normalizar';

  @override
  String get clippingWarning => 'Las partes más fuertes se saturarán';

  @override
  String get fadeIn => 'Fundido de entrada';

  @override
  String get fadeOut => 'Fundido de salida';

  @override
  String get trimStartHandle => 'Inicio del recorte';

  @override
  String get trimEndHandle => 'Fin del recorte';

  @override
  String get playbackPosition => 'Posición de la reproducción';

  @override
  String get folderFailed => 'No se pudo usar esa carpeta';

  @override
  String get driveConnectFailed => 'No se pudo conectar con Google Drive';

  @override
  String get disconnectDriveTitle => '¿Desconectar Google Drive?';

  @override
  String get disconnectDriveMessage =>
      'Dejarán de guardarse copias en Drive. Las que ya están allí se conservan.';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get format => 'Formato';

  @override
  String get aacDescription =>
      'Comprimido: ocupa poco y se reproduce en cualquier dispositivo';

  @override
  String get wavDescription =>
      'Sin comprimir: la máxima fidelidad, pero ocupa mucho más';

  @override
  String get quality => 'Calidad';

  @override
  String get qualityLow => 'Baja';

  @override
  String get qualityMedium => 'Media';

  @override
  String get qualityHigh => 'Alta';

  @override
  String get countdown => 'Cuenta atrás';

  @override
  String secondsCount(int seconds) {
    return '$seconds segundos';
  }

  @override
  String countdownSubtitle(int seconds) {
    return '$seconds segundos antes de empezar a grabar con el botón de cuenta atrás';
  }

  @override
  String get keepScreenOn => 'Mantener la pantalla encendida';

  @override
  String get keepScreenOnSubtitle =>
      'Mientras se graba o se espera para empezar, para que el sistema no detenga la app';

  @override
  String get recordingSection => 'Grabación';

  @override
  String get formatNote =>
      'Se aplica a las grabaciones nuevas. Al editar, cada grabación conserva su formato.';

  @override
  String get storageSection => 'Dónde se guardan las grabaciones';

  @override
  String get deviceFolder => 'Carpeta del dispositivo';

  @override
  String get noFolder => 'Ninguna';

  @override
  String get chooseAnotherFolder => 'Elegir otra carpeta';

  @override
  String driveAccount(String email, String folder) {
    return '$email · carpeta «$folder»';
  }

  @override
  String get driveSaveCopy => 'Guardar una copia en tu Google Drive';

  @override
  String get driveUnavailable =>
      'No disponible: esta versión de la app no tiene configurado el acceso a Google';

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron añadir $count grabaciones',
      one: 'No se pudo añadir 1 grabación',
    );
    return '$_temp0';
  }

  @override
  String get readFolderFailed => 'No se pudo leer la carpeta';

  @override
  String get readRecordingsFailed => 'No se pudieron leer las grabaciones';

  @override
  String get driveReconnect => 'Vuelve a conectar tu cuenta de Google Drive';

  @override
  String get offline => 'Sin conexión';

  @override
  String get noFolderPermission =>
      'Ya no hay permiso para la carpeta. Elígela de nuevo.';

  @override
  String errorWithDetail(String message, String detail) {
    return '$message: $detail';
  }

  @override
  String newRecordingsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Hay $count grabaciones nuevas',
      one: 'Hay 1 grabación nueva',
    );
    return '$_temp0';
  }

  @override
  String get playFailed => 'No se pudo reproducir la grabación';

  @override
  String deleteFromFolderMessage(String folder) {
    return 'También se borrará de «$folder». Esta acción no se puede deshacer.';
  }

  @override
  String get deleteFromDriveMessage =>
      'Se moverá a la papelera de tu Google Drive.';

  @override
  String get syncing => 'Sincronizando…';

  @override
  String get syncFailed => 'No se pudo sincronizar todo';

  @override
  String get setupTitle => '¿Dónde quieres guardar las grabaciones?';

  @override
  String get setupMessage => 'Podrás cambiarlo después en las opciones.';

  @override
  String get setupFolder => 'En una carpeta del dispositivo';

  @override
  String get setupFolderDescription =>
      'En el almacenamiento interno, una tarjeta SD, iCloud Drive… Las grabaciones que ya haya en ella aparecerán en la app.';

  @override
  String get setupDrive => 'En Google Drive';

  @override
  String get setupDriveDescription =>
      'En una carpeta de tu Drive. Las que todavía no se hayan podido subir se guardarán dentro de la app.';

  @override
  String get storageFolderDescription =>
      'Las grabaciones se guardan en la carpeta elegida, con el nombre que les des y en su subcarpeta, y la app muestra todos los audios (.m4a y .wav) que hay en ella. Lo que borres, renombres o edites en la app cambia también en la carpeta.';

  @override
  String storageDriveDescription(String folder) {
    return 'Las grabaciones se guardan en la carpeta «$folder» de tu Google Drive y se descargan para escucharlas o editarlas. Las que todavía no se han podido subir (por ejemplo, sin conexión) se guardan dentro de la app. Si eliges una carpeta del dispositivo, se guardarán en ella y en Drive quedará una copia.';
  }

  @override
  String get stopUsingFolder => 'Dejar de usar la carpeta';

  @override
  String stopUsingFolderTitle(String folder) {
    return '¿Dejar de usar «$folder»?';
  }

  @override
  String get stopUsingFolderMessage =>
      'Las grabaciones se quedarán en la carpeta, pero dejarán de verse en la app. Después tendrás que elegir dónde guardar las nuevas.';

  @override
  String get stopUsingFolderDriveMessage =>
      'Las grabaciones se quedarán en la carpeta y la app pasará a usar las de tu Google Drive, donde se guardarán las nuevas.';

  @override
  String get stopUsing => 'Dejar de usarla';

  @override
  String get disconnectDriveStorageMessage =>
      'Las grabaciones se quedarán en tu Drive, pero dejarán de verse en la app. Después tendrás que elegir dónde guardar las nuevas.';

  @override
  String folderInUse(String folder) {
    return 'Las grabaciones se guardan ahora en «$folder»';
  }

  @override
  String saveFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron guardar $count grabaciones',
      one: 'No se pudo guardar 1 grabación',
    );
    return '$_temp0';
  }

  @override
  String get readDriveFailed => 'No se pudo leer Google Drive';

  @override
  String get syncNow => 'Sincronizar ahora';

  @override
  String get syncNowSubtitle =>
      'Guarda lo pendiente y busca cambios donde se guardan las grabaciones';

  @override
  String get transcribe => 'Transcribir';

  @override
  String get viewTranscript => 'Ver transcripción';

  @override
  String transcribingProgress(String percent) {
    return 'Transcribiendo… $percent';
  }

  @override
  String get preparingTranscription => 'Preparando la transcripción…';

  @override
  String get waitingToTranscribe => 'En espera para transcribir…';

  @override
  String get cancelTranscription => 'Cancelar transcripción';

  @override
  String get transcriptReady => 'Transcripción lista';

  @override
  String get view => 'Ver';

  @override
  String get transcriptionFailed => 'No se pudo transcribir la grabación';

  @override
  String get noSpeechRecognized => 'No se ha reconocido ninguna palabra';

  @override
  String get stopToTranscribe => 'Detén la grabación para poder transcribir';

  @override
  String get systemSpeechUnavailableTitle =>
      'El reconocimiento de voz no está disponible';

  @override
  String get systemSpeechUnavailableMessage =>
      'Este dispositivo no puede transcribir con el reconocimiento de voz del sistema (en Android, necesita la versión 13 o superior). Puedes instalar Whisper en las opciones.';

  @override
  String unsupportedLanguageMessage(String language) {
    return 'El reconocimiento de voz del sistema no admite «$language» en este dispositivo. Puedes instalar Whisper o elegir otro idioma en las opciones.';
  }

  @override
  String get openSettings => 'Abrir opciones';

  @override
  String downloadLanguageTitle(String language) {
    return '¿Descargar «$language»?';
  }

  @override
  String get downloadLanguageMessage =>
      'El reconocimiento de voz del sistema necesita descargar este idioma para transcribir en el dispositivo. Vuelve a intentarlo cuando termine la descarga.';

  @override
  String get download => 'Descargar';

  @override
  String get languageDownloading =>
      'El idioma se está descargando. Vuelve a intentarlo cuando termine.';

  @override
  String get speechPermission =>
      'Permite el reconocimiento de voz en los ajustes para poder transcribir';

  @override
  String get whisperNotInstalledTitle => 'Whisper no está instalado';

  @override
  String get whisperNotInstalledMessage =>
      'Para transcribir con Whisper, descarga un modelo en las opciones.';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado al portapapeles';

  @override
  String get transcribeAgain => 'Volver a transcribir';

  @override
  String get transcribeInLanguage => 'Transcribir en otro idioma';

  @override
  String get recordingLanguage => 'Idioma de la grabación';

  @override
  String get sameAsSettings => 'Como en las opciones';

  @override
  String get deleteTranscript => 'Eliminar transcripción';

  @override
  String get transcriptDeleted => 'Transcripción eliminada';

  @override
  String get transcriptOutdated =>
      'La grabación ha cambiado desde que se transcribió.';

  @override
  String get transcriptionSection => 'Transcripción';

  @override
  String get transcriptionEngine => 'Transcribir con';

  @override
  String get autoTranscribe => 'Transcribir automáticamente';

  @override
  String get autoTranscribeSubtitle =>
      'En segundo plano, las grabaciones que aún no tienen transcripción';

  @override
  String get autoTranscriptionFailed =>
      'No se pueden transcribir las grabaciones automáticamente';

  @override
  String get systemSpeechRecognition => 'Reconocimiento de voz del sistema';

  @override
  String get systemSpeechDescription =>
      'Sin descargas. En Android, necesita la versión 13 o superior';

  @override
  String get whisperDescription =>
      'En el dispositivo y sin conexión. Hay que descargar un modelo';

  @override
  String get whisperModel => 'Modelo de Whisper';

  @override
  String get whisperNotInstalled => 'Sin instalar. Toca para descargar uno';

  @override
  String whisperInstalled(String model, String size) {
    return 'Instalado: $model ($size)';
  }

  @override
  String whisperDownloading(String model, String percent, String size) {
    return 'Descargando $model… $percent de $size';
  }

  @override
  String get whisperDownloadFailed => 'No se pudo descargar el modelo';

  @override
  String get chooseWhisperModel => 'Descargar un modelo';

  @override
  String whisperTinyDescription(String size) {
    return '$size · Más rápido, menos preciso';
  }

  @override
  String whisperBaseDescription(String size) {
    return '$size · Más preciso, más lento';
  }

  @override
  String get deleteWhisperModel => 'Eliminar el modelo';

  @override
  String get deleteWhisperModelTitle => '¿Eliminar el modelo de Whisper?';

  @override
  String deleteWhisperModelMessage(String size) {
    return 'Se liberarán $size. Podrás volver a descargarlo.';
  }

  @override
  String get cancelDownload => 'Cancelar descarga';

  @override
  String get transcriptionLanguage => 'Idioma';

  @override
  String appLanguageOption(String language) {
    return 'El de la app ($language)';
  }

  @override
  String get detectLanguageOption => 'Detectar automáticamente (solo Whisper)';

  @override
  String get searchSection => 'Búsqueda';

  @override
  String get similarWords => 'Incluir palabras parecidas';

  @override
  String get similarWordsSubtitle =>
      'También con erratas o variantes, como «reunon» o «reuniones» para «reunión»';

  @override
  String get appearanceSection => 'Apariencia';

  @override
  String get theme => 'Tema';

  @override
  String get themeSystem => 'Automático (el del sistema)';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Oscuro';

  @override
  String get renameToTranscriptTitle => '¿Renombrar la grabación?';

  @override
  String renameToTranscriptMessage(String current, String name) {
    return 'Con la nueva transcripción, «$current» pasaría a llamarse «$name».';
  }

  @override
  String get keepName => 'Mantener';

  @override
  String get piano => 'Piano';

  @override
  String get pianoHint =>
      'Toca una tecla para oír su nota.\nDesliza sobre el teclado pequeño para moverte por él.';

  @override
  String get noteNames => 'Do Re Mi Fa Sol La Si';

  @override
  String get close => 'Cerrar';

  @override
  String get pianoOnly => 'Solo piano';

  @override
  String get pianoAndVoice => 'Piano y voz';

  @override
  String get pianoNothingPlayed =>
      'No hay nada que guardar: no se ha tocado ninguna nota';

  @override
  String get stopPlayback => 'Parar la reproducción';

  @override
  String get playAll => 'Reproducir una detrás de otra';

  @override
  String get repeat => 'Repetir';
}
