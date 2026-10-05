import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'l10n/l10n.dart';
import 'screens/home_screen.dart';
import 'services/audio_player_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/copy_sync.dart';
import 'services/recording_editor.dart';
import 'services/recordings_repository.dart';

/// Morado del icono (`docs/icono.svg`), del que sale el tema de la app.
const brandPurple = Color(0xFF5B3FD9);

/// Rojo del punto del icono, para los controles de grabación.
const recordRed = Color(0xFFFF4D4D);

class VoiceRecorderApp extends StatelessWidget {
  const VoiceRecorderApp({
    super.key,
    required this.repository,
    required this.recorderFactory,
    required this.playerFactory,
    required this.editor,
    required this.sync,
    this.locale,
  });

  /// Idiomas de la app. El primero, inglés, es el que se usa si el del
  /// sistema no es ninguno de ellos.
  static final supportedLocales = [
    const Locale('en'),
    for (final locale in AppLocalizations.supportedLocales)
      if (locale.languageCode != 'en') locale,
  ];

  final RecordingsRepository repository;
  final AudioRecorderService Function() recorderFactory;
  final AudioPlayerService Function() playerFactory;
  final RecordingEditor editor;
  final CopySync sync;

  /// Idioma fijo (para los tests); si es `null`, el del sistema.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      locale: locale,
      supportedLocales: supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (preferred, supported) {
        final resolved = basicLocaleListResolution(preferred, supported);
        // Las fechas y los números se formatean en el mismo idioma.
        Intl.defaultLocale = resolved.toLanguageTag();
        return resolved;
      },
      home: HomeScreen(
        repository: repository,
        recorderFactory: recorderFactory,
        playerFactory: playerFactory,
        editor: editor,
        sync: sync,
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    // Con `fidelity` los tonos conservan la saturación del morado (los de
    // por defecto lo apagan). En el tema claro se usa tal cual como color
    // principal; en el oscuro, el principal es un lila como el del icono.
    var colorScheme = ColorScheme.fromSeed(
      seedColor: brandPurple,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    );
    if (brightness == Brightness.light) {
      colorScheme = colorScheme.copyWith(primary: brandPurple);
    }
    return ThemeData(colorScheme: colorScheme, useMaterial3: true);
  }
}
