import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:voicerecorder/app.dart';
import 'package:voicerecorder/l10n/app_localizations.dart';

/// Los tests comprueban los textos en español.
const testLocale = Locale('es');

/// Textos en español, para los tests que no montan widgets.
final es = lookupAppLocalizations(testLocale);

/// Prepara los formatos de número y fecha en español.
void useSpanishFormats() => Intl.defaultLocale = 'es';

/// Una `MaterialApp` en español con las traducciones de la app.
Widget localizedApp({required Widget home}) {
  useSpanishFormats();
  return MaterialApp(
    locale: testLocale,
    supportedLocales: VoiceRecorderApp.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: home,
  );
}
