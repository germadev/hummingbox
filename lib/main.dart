import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'controllers/whisper_controller.dart';
import 'services/audio_codec.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/folder_access.dart';
import 'services/google_drive.dart';
import 'services/recording_editor.dart';
import 'services/recordings_repository.dart';
import 'services/settings_store.dart';
import 'services/speech_recognition.dart';
import 'services/storage_sync.dart';
import 'services/transcriber.dart';
import 'services/whisper_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Formatos de fecha de todos los idiomas; el de la app se elige al
  // resolver el idioma (ver VoiceRecorderApp).
  await initializeDateFormatting();

  final repository = FileRecordingsRepository();
  final sync = StorageSync(
    repository: repository,
    store: FileSettingsStore(),
    folders: const PlatformFolderAccess(),
    // Los IDs de cliente de Google se pasan al compilar con --dart-define
    // (ver README → «Google Drive»).
    drive: GoogleDriveService(
      iosClientId: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
      serverClientId: const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    ),
  );

  // Con las opciones ya leídas, la app se abre con el tema elegido.
  await sync.load();

  final whisper = PluginWhisperService();

  runApp(
    VoiceRecorderApp(
      repository: repository,
      recorderFactory: RecordAudioRecorderService.new,
      playerFactory: AudioplayersPlayerService.new,
      editor: RecordingEditor(
        codec: const PlatformAudioCodec(),
        repository: repository,
        // Las grabaciones guardadas fuera de la app se leen de allí.
        audioPath: sync.audioPath,
      ),
      sync: sync,
      transcriber: Transcriber(
        codec: const PlatformAudioCodec(),
        system: const PlatformSystemSpeech(),
        whisper: whisper,
        audioPath: sync.audioPath,
      ),
      whisper: WhisperController(whisper),
    ),
  );
}
