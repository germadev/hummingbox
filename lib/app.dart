import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/recordings_repository.dart';

/// Rojo de los controles de grabación.
const recordRed = Color(0xFFE53935);

class VoiceRecorderApp extends StatelessWidget {
  const VoiceRecorderApp({
    super.key,
    required this.repository,
    required this.recorderFactory,
    required this.playerFactory,
  });

  final RecordingsRepository repository;
  final AudioRecorderService Function() recorderFactory;
  final AudioPlayerService Function() playerFactory;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Grabadora',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: const Locale('es'),
      supportedLocales: const [Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeScreen(
        repository: repository,
        recorderFactory: recorderFactory,
        playerFactory: playerFactory,
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: recordRed,
        brightness: brightness,
      ),
      useMaterial3: true,
    );
  }
}
