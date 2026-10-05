// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Grabadora';

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
  String get defaultRecordingName => 'Grabación';

  @override
  String editedCopyName(String name) {
    return '$name (editada)';
  }

  @override
  String get loadRecordingsFailed => 'No se pudieron cargar las grabaciones';

  @override
  String importedFromFolder(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se han añadido $count grabaciones de la carpeta',
      one: 'Se ha añadido 1 grabación de la carpeta',
    );
    return '$_temp0';
  }

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
  String get savingCopies => 'Guardando copias…';

  @override
  String get copiesFailed => 'No se pudieron guardar algunas copias';

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
  String get importTitle => '¿Añadir las grabaciones de la carpeta?';

  @override
  String importMessage(String folder, int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count audios',
      one: '1 audio',
    );
    return '«$folder» tiene $_temp0 ($size) que no están en la app. Si los añades, aparecerán en la lista y se copiarán a la app.';
  }

  @override
  String get add => 'Añadir';

  @override
  String get dontAdd => 'No añadir';

  @override
  String get folderFailed => 'No se pudo usar esa carpeta';

  @override
  String get copiesKept => 'Las copias que ya están en la carpeta se conservan';

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
  String get recordingSection => 'Grabación';

  @override
  String get formatNote =>
      'Se aplica a las grabaciones nuevas. Al editar, cada grabación conserva su formato.';

  @override
  String get storageSection => 'Dónde se guardan las grabaciones';

  @override
  String get storageDescription =>
      'Las grabaciones se guardan siempre dentro de la app. Además, puedes guardar una copia de cada una en una carpeta del dispositivo y en Google Drive, con el nombre que le hayas dado y en su subcarpeta. Las copias se actualizan al renombrar o editar una grabación, pero no se borran al eliminarla.';

  @override
  String get deviceFolder => 'Carpeta del dispositivo';

  @override
  String get noFolder => 'No se guarda en ninguna carpeta';

  @override
  String get stopSavingToFolder => 'Dejar de guardar en la carpeta';

  @override
  String get chooseAnotherFolder => 'Elegir otra carpeta';

  @override
  String get showFolderRecordings => 'Mostrar las grabaciones de la carpeta';

  @override
  String get showFolderRecordingsSubtitle =>
      'Añade a la app los audios (.m4a y .wav) que haya en la carpeta y en sus subcarpetas';

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
  String get copyNow => 'Copiar ahora';

  @override
  String get copyNowSubtitle => 'Se copia solo lo que falta o ha cambiado';

  @override
  String copyFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron copiar $count grabaciones',
      one: 'No se pudo copiar 1 grabación',
    );
    return '$_temp0';
  }

  @override
  String importFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'No se pudieron añadir $count grabaciones de la carpeta',
      one: 'No se pudo añadir 1 grabación de la carpeta',
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
}
