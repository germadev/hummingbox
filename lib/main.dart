import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'services/audio_codec.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/copy_sync.dart';
import 'services/folder_access.dart';
import 'services/google_drive.dart';
import 'services/recording_editor.dart';
import 'services/recordings_repository.dart';
import 'services/settings_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');

  final repository = FileRecordingsRepository();

  runApp(
    VoiceRecorderApp(
      repository: repository,
      recorderFactory: RecordAudioRecorderService.new,
      playerFactory: AudioplayersPlayerService.new,
      editor: RecordingEditor(
        codec: const PlatformAudioCodec(),
        repository: repository,
      ),
      sync: CopySync(
        repository: repository,
        store: FileSettingsStore(),
        folders: const PlatformFolderAccess(),
        // Los IDs de cliente de Google se pasan al compilar con
        // --dart-define (ver README → «Google Drive»).
        drive: GoogleDriveService(
          iosClientId: const String.fromEnvironment('GOOGLE_IOS_CLIENT_ID'),
          serverClientId: const String.fromEnvironment(
            'GOOGLE_SERVER_CLIENT_ID',
          ),
        ),
      ),
    ),
  );
}
