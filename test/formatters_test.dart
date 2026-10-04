import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:voicerecorder/controllers/recorder_controller.dart';
import 'package:voicerecorder/services/share_service.dart';
import 'package:voicerecorder/utils/formatters.dart';

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('formatDuration', () {
    test('formatea minutos y segundos', () {
      expect(formatDuration(Duration.zero), '00:00');
      expect(formatDuration(const Duration(seconds: 65)), '01:05');
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('incluye las horas cuando las hay', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '1:02:03',
      );
    });

    test('muestra las décimas si se piden', () {
      expect(
        formatDuration(const Duration(milliseconds: 1290), showTenths: true),
        '00:01,2',
      );
    });

    test('trata las duraciones negativas como cero', () {
      expect(formatDuration(const Duration(seconds: -3)), '00:00');
    });
  });

  group('formatRecordingDate', () {
    final now = DateTime(2026, 10, 4, 18);

    test('usa "Hoy" y "Ayer" para fechas recientes', () {
      expect(
        formatRecordingDate(DateTime(2026, 10, 4, 17, 45), now: now),
        'Hoy, 17:45',
      );
      expect(
        formatRecordingDate(DateTime(2026, 10, 3, 9, 3), now: now),
        'Ayer, 9:03',
      );
    });

    test('reconoce "Ayer" al cambiar de año', () {
      expect(
        formatRecordingDate(
          DateTime(2025, 12, 31, 23, 59),
          now: DateTime(2026, 1, 1, 0, 5),
        ),
        'Ayer, 23:59',
      );
    });

    test('muestra la fecha completa para fechas anteriores', () {
      expect(
        formatRecordingDate(DateTime(2026, 9, 28, 8, 30), now: now),
        '28 sept 2026, 8:30',
      );
    });
  });

  group('safeFileName', () {
    test('sustituye los caracteres no válidos', () {
      expect(
        safeFileName('Reunión 3/10: notas?', fallback: 'x'),
        'Reunión 3_10_ notas_',
      );
    });

    test('usa el valor alternativo si el nombre queda vacío', () {
      expect(safeFileName('   ', fallback: 'rec_1'), 'rec_1');
      expect(safeFileName('..', fallback: 'rec_1'), 'rec_1');
    });
  });

  group('RecorderController.normalizeAmplitude', () {
    test('convierte dBFS a un valor entre 0 y 1', () {
      expect(RecorderController.normalizeAmplitude(-160), 0);
      expect(RecorderController.normalizeAmplitude(-50), 0);
      expect(RecorderController.normalizeAmplitude(-25), 0.5);
      expect(RecorderController.normalizeAmplitude(0), 1);
      expect(RecorderController.normalizeAmplitude(3), 1);
      expect(RecorderController.normalizeAmplitude(double.nan), 0);
    });
  });
}
