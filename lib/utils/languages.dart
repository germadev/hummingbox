import '../l10n/app_localizations.dart';
import '../models/transcription.dart';

/// Idiomas que se pueden elegir para transcribir: los de la app.
const transcriptionLanguages = ['es', 'en', 'it', 'pt', 'fr', 'de', 'zh', 'ja'];

/// Nombre de un idioma en ese idioma («Español», «English»…) a partir de su
/// código o etiqueta («es», «es-ES»). Si no es uno de los de la app, la
/// etiqueta tal cual.
String languageName(String tag) {
  final code = tag.split(RegExp('[-_]')).first.toLowerCase();
  return switch (code) {
    'es' => 'Español',
    'en' => 'English',
    'it' => 'Italiano',
    'pt' => 'Português',
    'fr' => 'Français',
    'de' => 'Deutsch',
    'zh' || 'cmn' => '中文',
    'ja' => '日本語',
    _ => tag,
  };
}

/// Cómo se muestra el idioma de la transcripción elegido en las opciones
/// ([TranscriptionSettings.language]), con [appLanguage] el de la app.
String transcriptionLanguageTitle(
  String language,
  AppLocalizations l10n, {
  required String appLanguage,
}) => switch (language) {
  TranscriptionSettings.appLanguage => l10n.appLanguageOption(
    languageName(appLanguage),
  ),
  TranscriptionSettings.detectLanguage => l10n.detectLanguageOption,
  final code => languageName(code),
};
