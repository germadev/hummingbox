import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'app.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/recordings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');

  runApp(
    VoiceRecorderApp(
      repository: FileRecordingsRepository(),
      recorderFactory: RecordAudioRecorderService.new,
      playerFactory: AudioplayersPlayerService.new,
    ),
  );
}
