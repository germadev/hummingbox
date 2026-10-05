import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:voicerecorder/app.dart';
import 'package:voicerecorder/l10n/app_localizations.dart';

import 'fakes.dart';

void main() {
  setUpAll(initializeDateFormatting);

  Map<String, dynamic> readArb(String language) =>
      jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
          as Map<String, dynamic>;

  test('los ocho idiomas tienen todos los textos', () {
    final languages = [
      for (final locale in AppLocalizations.supportedLocales)
        locale.languageCode,
    ];
    expect(languages.toSet(), {'es', 'en', 'it', 'pt', 'fr', 'de', 'zh', 'ja'});

    final template = readArb('en');
    final keys = {
      for (final key in template.keys)
        if (!key.startsWith('@')) key,
    };
    for (final language in languages) {
      final arb = readArb(language);
      final translated = {
        for (final key in arb.keys)
          if (!key.startsWith('@')) key,
      };
      expect(translated, keys, reason: 'app_$language.arb');
      for (final key in keys) {
        final text = arb[key] as String;
        expect(text.trim(), isNotEmpty, reason: '$language: $key');
        // Los mismos huecos que en inglés (salvo los plurales del chino y el
        // japonés, que no los necesitan).
        final placeholders =
            (template['@$key']?['placeholders'] as Map<String, dynamic>?)
                ?.keys ??
            const <String>[];
        for (final placeholder in placeholders) {
          expect(
            text,
            contains('{$placeholder'),
            reason: '$language: $key sin {$placeholder}',
          );
        }
      }
    }
  });

  group('idioma de la app', () {
    late InMemoryRecordingsRepository repository;
    late FakeAudioRecorderService recorder;

    setUp(() {
      repository = InMemoryRecordingsRepository();
      recorder = FakeAudioRecorderService();
    });

    Future<void> pumpIn(WidgetTester tester, Locale? locale) async {
      await tester.pumpWidget(
        VoiceRecorderApp(
          locale: locale,
          repository: repository,
          recorderFactory: () => recorder,
          playerFactory: FakeAudioPlayerService.new,
          editor: FakeRecordingEditor(repository: repository),
          sync: fakeStorageSync(repository),
          transcriber: FakeTranscriber(),
          whisper: fakeWhisperController(),
        ),
      );
      await tester.pumpAndSettle();
    }

    /// Nombre de la app (el título que se da al sistema).
    String appTitle(WidgetTester tester) =>
        tester.widget<Title>(find.byType(Title)).title;

    testWidgets('en inglés, también los nombres y los formatos', (
      tester,
    ) async {
      await pumpIn(tester, const Locale('en'));

      expect(appTitle(tester), 'Recorder');
      expect(find.text('No recordings yet'), findsOneWidget);
      expect(Intl.defaultLocale, 'en');

      await tester.tap(find.byKey(const Key('record-button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Recording'), findsOneWidget);
      // Separador decimal del inglés.
      expect(find.textContaining('00:00.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('record-button')));
      await tester.pumpAndSettle();

      expect(repository.recordings.single.name, 'Recording 1');
      expect(find.text('Saved as “Recording 1”'), findsOneWidget);
    });

    testWidgets('si el idioma del sistema no está, usa el inglés', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('ru')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpIn(tester, null);

      expect(appTitle(tester), 'Recorder');
    });

    testWidgets('sigue el idioma del sistema', (tester) async {
      tester.platformDispatcher.localesTestValue = const [Locale('ja', 'JP')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      await pumpIn(tester, null);

      expect(appTitle(tester), 'ボイスレコーダー');
      expect(find.text('まだ録音がありません'), findsOneWidget);
    });
  });
}
