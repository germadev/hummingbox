import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../audio/piano_tone.dart';
import '../l10n/l10n.dart';
import '../controllers/piano_recorder.dart';
import '../models/recording.dart';
import '../services/piano_sound.dart';
import '../utils/formatters.dart';

/// Panel del piano, que se abre deslizando hacia la izquierda: un teclado
/// de octava y media y, debajo, todas las octavas en pequeño con la parte
/// ampliada destacada. Deslizando sobre ellas se cambia la parte ampliada.
///
/// Se ve siempre en horizontal, con las teclas ocupando todo el alto que
/// queda. Si la pantalla está en vertical, se dibuja girado ([portraitTurns])
/// para verlo en horizontal girando el móvil, sin que la pantalla gire (ver
/// [orientationsFor]): así se ve igual mientras se desliza para abrirlo.
class PianoPanel extends StatefulWidget {
  const PianoPanel({
    super.key,
    required this.sound,
    required this.firstKey,
    required this.recorder,
    required this.mode,
    required this.onRecord,
    required this.onStop,
    required this.target,
    required this.portraitTurns,
    this.onClose,
  });

  final PianoSound sound;

  /// Graba lo que se toca (y la voz, si se elige).
  final PianoRecorder recorder;

  /// Qué se graba al pulsar «Grabar». Se conserva al cerrar el panel.
  final ValueNotifier<PianoRecordingMode> mode;

  /// Al pulsar «Grabar»: devuelve el aviso que se muestra si no se pudo
  /// empezar (p. ej. sin permiso del micrófono), o `null`.
  final Future<String?> Function(PianoRecordingMode mode) onRecord;

  /// La grabación sobre la que se toca, si se abrió para acompañarla: al
  /// grabar suena desde el principio.
  final ValueListenable<Recording?> target;

  /// Al parar la grabación: devuelve lo guardado, si se guardó algo.
  final Future<Recording?> Function() onStop;

  /// Primera tecla blanca de la parte ampliada (su posición en
  /// [PianoKeys.whiteKeys]). Se conserva al cerrar el panel.
  final ValueNotifier<int> firstKey;

  /// Cuartos de vuelta en el sentido de las agujas del reloj con los que se
  /// dibuja con la pantalla en vertical: 1 para verlo girando el móvil hacia
  /// la izquierda y 3 hacia la derecha. Se conserva al cerrar el panel.
  final ValueNotifier<int> portraitTurns;

  final VoidCallback? onClose;

  /// Teclas blancas de la parte ampliada: octava y media.
  static const visibleWhiteKeys = 11;

  /// Primera tecla blanca más alta posible.
  static int get lastFirstKey => PianoKeys.whiteKeys.length - visibleWhiteKeys;

  /// Orientaciones de la pantalla mientras está abierto, si se abrió en
  /// [orientation]: la misma, para que no gire al girar el móvil. En
  /// vertical, el piano ya está girado (ver [portraitTurns]).
  static List<DeviceOrientation> orientationsFor(Orientation orientation) =>
      switch (orientation) {
        Orientation.portrait => const [DeviceOrientation.portraitUp],
        Orientation.landscape => const [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      };

  /// Al abrirlo por primera vez: desde el Do3, en la tesitura de la voz.
  static final initialFirstKey = PianoKeys.whiteKeys.indexOf(48);

  @override
  State<PianoPanel> createState() => _PianoPanelState();
}

class _PianoPanelState extends State<PianoPanel> {
  /// La última tecla tocada, para mostrar su nota.
  int? _lastKey;

  /// Aviso sobre la grabación (p. ej. que se ha guardado), en lugar de la
  /// nota, hasta tocar otra tecla.
  String? _message;

  @override
  void initState() {
    super.initState();
    widget.firstKey.addListener(_prepare);
    _prepare();
  }

  @override
  void dispose() {
    widget.firstKey.removeListener(_prepare);
    super.dispose();
  }

  /// Prepara el sonido de las teclas a la vista.
  void _prepare() {
    final whites = PianoKeys.whiteKeys;
    final first = whites[widget.firstKey.value];
    final last =
        whites[widget.firstKey.value + PianoPanel.visibleWhiteKeys - 1];
    unawaited(
      widget.sound.prepare([for (var key = first; key <= last; key++) key]),
    );
  }

  void _play(int key) {
    setState(() {
      _lastKey = key;
      _message = null;
    });
    unawaited(widget.sound.play(key));
    widget.recorder.noteOn(key);
  }

  Future<void> _record(PianoRecordingMode mode) async {
    setState(() => _message = null);
    final error = await widget.onRecord(mode);
    if (!mounted || error == null) return;
    setState(() => _message = error);
  }

  Future<void> _stop() async {
    final mode = widget.recorder.mode;
    final saved = await widget.onStop();
    if (!mounted) return;
    final l10n = context.l10n;
    setState(
      () => _message = switch (saved) {
        final saved? when mode == PianoRecordingMode.accompaniment =>
          l10n.pianoAdded(saved.name),
        final saved? => l10n.savedAs(saved.name),
        null
            when mode == PianoRecordingMode.piano ||
                mode == PianoRecordingMode.accompaniment =>
          l10n.pianoNothingPlayed,
        null => l10n.saveRecordingFailed,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    // Los arrastres horizontales no cierran el panel (solo se cierra con su
    // botón o con «atrás»): al tocar es fácil arrastrar sin querer.
    return RawGestureDetector(
      behavior: HitTestBehavior.opaque,
      gestures: {
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              HorizontalDragGestureRecognizer
            >(HorizontalDragGestureRecognizer.new, (recognizer) {
              recognizer.onUpdate = (_) {};
            }),
      },
      child: SafeArea(
        child: ValueListenableBuilder<int>(
          valueListenable: widget.portraitTurns,
          builder: (context, turns, _) {
            final quarterTurns = portrait ? turns : 0;
            final media = MediaQuery.of(context);
            return RotatedBox(
              key: const Key('piano-rotation'),
              quarterTurns: quarterTurns,
              // Dentro, como si la pantalla estuviera en horizontal, y con
              // los menús y las ayudas girados con el piano.
              child: MediaQuery(
                data: quarterTurns.isOdd
                    ? media.copyWith(size: media.size.flipped)
                    : media,
                child: Overlay.wrap(
                  child: Material(
                    type: MaterialType.transparency,
                    child: _buildPanel(context, rotated: quarterTurns != 0),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPanel(BuildContext context, {required bool rotated}) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final names = noteNames(l10n.noteNames);
    final lastKey = _lastKey;
    return Column(
      children: [
        // El título, la nota de la última tecla tocada (o cómo se usa) y
        // el botón de cerrar, en una línea: el resto es para las teclas.
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
          child: Row(
            children: [
              Text(l10n.piano, style: theme.textTheme.titleLarge),
              const SizedBox(width: 16),
              Expanded(
                child: _message != null
                    ? Text(
                        _message!,
                        key: const Key('piano-message'),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      )
                    : lastKey == null
                    ? Text(
                        l10n.pianoHint,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      )
                    // Si no cabe (p. ej. con el nombre de la grabación
                    // que se acompaña), más pequeña.
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              noteName(lastKey, names),
                              key: const Key('piano-note'),
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${PianoKeys.frequency(lastKey).toStringAsFixed(1)}'
                              ' Hz',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              _RecordControls(
                recorder: widget.recorder,
                mode: widget.mode,
                target: widget.target,
                onRecord: _record,
                onStop: _stop,
              ),
              // Girado, para darle la vuelta si se ve al revés.
              if (rotated)
                IconButton(
                  key: const Key('piano-turn'),
                  tooltip: l10n.pianoTurnAround,
                  icon: const Icon(Icons.screen_rotation),
                  onPressed: () => widget.portraitTurns.value =
                      (widget.portraitTurns.value + 2) % 4,
                )
              else
                const SizedBox(width: 4),
              IconButton(
                tooltip: l10n.close,
                icon: const Icon(Icons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        // Las teclas, siempre de grave (izquierda) a agudo (derecha).
        Expanded(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ValueListenableBuilder<int>(
              valueListenable: widget.firstKey,
              builder: (context, first, _) => Column(
                children: [
                  Expanded(
                    child: PianoKeyboard(
                      key: const Key('piano-keyboard'),
                      firstKey: first,
                      whiteKeys: PianoPanel.visibleWhiteKeys,
                      names: names,
                      onPressed: _play,
                      onReleased: widget.recorder.noteOff,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: PianoOverview(
                      key: const Key('piano-overview'),
                      firstKey: first,
                      visibleWhiteKeys: PianoPanel.visibleWhiteKeys,
                      onChanged: (value) => widget.firstKey.value = value,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Qué grabar (el piano siempre y, si se elige, también la voz) y el botón para grabar o,
/// mientras se graba, para parar con el tiempo grabado.
class _RecordControls extends StatelessWidget {
  const _RecordControls({
    required this.recorder,
    required this.mode,
    required this.target,
    required this.onRecord,
    required this.onStop,
  });

  final PianoRecorder recorder;
  final ValueNotifier<PianoRecordingMode> mode;
  final ValueListenable<Recording?> target;
  final Future<void> Function(PianoRecordingMode mode) onRecord;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([recorder, mode, target]),
      builder: (context, _) {
        final recording = recorder.isRecording;
        final saving = recorder.isSaving;
        final over = recorder.target ?? target.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Al acompañar una grabación, sobre cuál; si no, qué se graba.
            if (over != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  l10n.pianoOver(over.name),
                  key: const Key('piano-target'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            else
              // El piano siempre se graba (está siempre marcado); la voz,
              // si se marca.
              SegmentedButton<PianoRecordingMode>(
                key: const Key('piano-mode'),
                showSelectedIcon: false,
                multiSelectionEnabled: true,
                segments: [
                  ButtonSegment(
                    value: PianoRecordingMode.piano,
                    icon: const Icon(Icons.piano),
                    tooltip: l10n.pianoAlwaysRecorded,
                  ),
                  ButtonSegment(
                    value: PianoRecordingMode.pianoAndVoice,
                    icon: const Icon(Icons.mic),
                    tooltip: l10n.pianoAndVoice,
                  ),
                ],
                selected: {
                  PianoRecordingMode.piano,
                  if (mode.value == PianoRecordingMode.pianoAndVoice)
                    PianoRecordingMode.pianoAndVoice,
                },
                onSelectionChanged: recording || saving
                    ? null
                    : (selected) => mode.value =
                          selected.contains(PianoRecordingMode.pianoAndVoice)
                          ? PianoRecordingMode.pianoAndVoice
                          : PianoRecordingMode.piano,
              ),
            const SizedBox(width: 8),
            if (saving)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              )
            else if (recording)
              FilledButton.icon(
                key: const Key('piano-stop'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                ),
                onPressed: onStop,
                icon: const Icon(Icons.stop),
                label: Text(
                  formatDuration(recorder.elapsed),
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              )
            else
              FilledButton.icon(
                key: const Key('piano-record'),
                onPressed: () => onRecord(mode.value),
                icon: const Icon(Icons.fiber_manual_record),
                label: Text(l10n.record),
              ),
          ],
        );
      },
    );
  }
}

/// Nombres de las siete notas naturales, de Do a Si, a partir de [names]
/// (separados por espacios, p. ej. «Do Re Mi Fa Sol La Si» o
/// «C D E F G A B»).
List<String> noteNames(String names) {
  final list = names.split(RegExp(r'\s+')).where((n) => n.isNotEmpty).toList();
  return list.length == 7 ? list : const ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
}

/// Nombre de la nota de la tecla [key] con su octava: «La4», «Do♯3».
String noteName(int key, List<String> names) {
  const naturals = [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6];
  final pitchClass = key % 12;
  final sharp = PianoKeys.isBlack(key) ? '♯' : '';
  return '${names[naturals[pitchClass]]}$sharp${PianoKeys.octave(key)}';
}

/// Teclado ampliado: [whiteKeys] teclas blancas desde la de posición
/// [firstKey] (en [PianoKeys.whiteKeys]), con sus negras. Se pueden tocar
/// varias a la vez y deslizar el dedo de una a otra.
class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({
    super.key,
    required this.firstKey,
    required this.whiteKeys,
    required this.names,
    required this.onPressed,
    this.onReleased,
  });

  final int firstKey;
  final int whiteKeys;
  final List<String> names;

  /// Al pulsar una tecla (o llegar a ella deslizando el dedo).
  final ValueChanged<int> onPressed;

  /// Al soltar una tecla (o salir de ella deslizando el dedo), si no la
  /// sigue pulsando otro dedo.
  final ValueChanged<int>? onReleased;

  /// Alto de las negras respecto al de las blancas.
  static const blackHeight = 0.6;

  /// Ancho de las negras respecto al de las blancas.
  static const blackWidth = 0.6;

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  /// Tecla bajo cada dedo.
  final _pointers = <int, int>{};

  Set<int> get _pressed => _pointers.values.toSet();

  /// Tecla en [position] (dentro de [size]), o `null` si no hay ninguna.
  int? _keyAt(Offset position, Size size) {
    if (position.dx < 0 ||
        position.dy < 0 ||
        position.dx >= size.width ||
        position.dy >= size.height) {
      return null;
    }
    final whiteWidth = size.width / widget.whiteKeys;
    if (position.dy < size.height * PianoKeyboard.blackHeight) {
      for (final (key, rect) in _blackKeys(size)) {
        if (rect.contains(position)) return key;
      }
    }
    final index = widget.firstKey + position.dx ~/ whiteWidth;
    return index < PianoKeys.whiteKeys.length
        ? PianoKeys.whiteKeys[index]
        : null;
  }

  Iterable<(int, Rect)> _blackKeys(Size size) =>
      blackKeyRects(size, widget.firstKey, widget.whiteKeys);

  void _update(int pointer, Offset position) {
    final size = context.size;
    if (size == null) return;
    final key = _keyAt(position, size);
    final previous = _pointers[pointer];
    if (key == previous) return;
    setState(() {
      if (key == null) {
        _pointers.remove(pointer);
      } else {
        _pointers[pointer] = key;
      }
    });
    _releaseIfFree(previous);
    if (key != null) widget.onPressed(key);
  }

  void _release(int pointer) {
    if (!_pointers.containsKey(pointer)) return;
    final key = _pointers[pointer];
    setState(() => _pointers.remove(pointer));
    _releaseIfFree(key);
  }

  /// Avisa de que se ha soltado [key], si ya no la pulsa ningún dedo.
  void _releaseIfFree(int? key) {
    if (key != null && !_pointers.containsValue(key)) {
      widget.onReleased?.call(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Los arrastres horizontales son para tocar, no para cerrar el panel.
    return RawGestureDetector(
      gestures: {
        HorizontalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
              HorizontalDragGestureRecognizer
            >(HorizontalDragGestureRecognizer.new, (recognizer) {
              recognizer.onUpdate = (_) {};
            }),
      },
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) => _update(event.pointer, event.localPosition),
        onPointerMove: (event) => _update(event.pointer, event.localPosition),
        onPointerUp: (event) => _release(event.pointer),
        onPointerCancel: (event) => _release(event.pointer),
        child: CustomPaint(
          size: Size.infinite,
          painter: _KeyboardPainter(
            firstKey: widget.firstKey,
            whiteKeys: widget.whiteKeys,
            names: widget.names,
            pressed: _pressed,
            pressedColor: colors.primary,
            outline: colors.outlineVariant,
            labelColor: colors.outline,
          ),
        ),
      ),
    );
  }
}

/// Las teclas negras entre las [whiteKeys] blancas desde la de posición
/// [firstKey], con su rectángulo en un teclado de tamaño [size]. La que
/// quedaría cortada en el borde derecho no se muestra.
List<(int, Rect)> blackKeyRects(Size size, int firstKey, int whiteKeys) {
  final whiteWidth = size.width / whiteKeys;
  final width = whiteWidth * PianoKeyboard.blackWidth;
  final height = size.height * PianoKeyboard.blackHeight;
  return [
    for (var i = 0; i < whiteKeys - 1; i++)
      if (firstKey + i + 1 < PianoKeys.whiteKeys.length &&
          PianoKeys.isBlack(PianoKeys.whiteKeys[firstKey + i] + 1))
        (
          PianoKeys.whiteKeys[firstKey + i] + 1,
          Rect.fromLTWH((i + 1) * whiteWidth - width / 2, 0, width, height),
        ),
  ];
}

class _KeyboardPainter extends CustomPainter {
  _KeyboardPainter({
    required this.firstKey,
    required this.whiteKeys,
    required this.names,
    required this.pressed,
    required this.pressedColor,
    required this.outline,
    required this.labelColor,
  });

  final int firstKey;
  final int whiteKeys;
  final List<String> names;
  final Set<int> pressed;
  final Color pressedColor;
  final Color outline;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    final whiteWidth = size.width / whiteKeys;
    final radius = const Radius.circular(6);
    final border = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < whiteKeys; i++) {
      final index = firstKey + i;
      if (index >= PianoKeys.whiteKeys.length) break;
      final key = PianoKeys.whiteKeys[index];
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(i * whiteWidth + 1, 0, whiteWidth - 2, size.height),
        bottomLeft: radius,
        bottomRight: radius,
      );
      canvas
        ..drawRRect(
          rect,
          Paint()
            ..color = pressed.contains(key)
                ? Color.lerp(Colors.white, pressedColor, 0.45)!
                : Colors.white,
        )
        ..drawRRect(rect, border);
      // El nombre de la nota abajo y, en los do, su octava.
      final label = key % 12 == 0 ? noteName(key, names) : names[_natural(key)];
      final text = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: key % 12 == 0 ? Colors.black87 : labelColor,
            fontSize: (whiteWidth * 0.32).clamp(8.0, 14.0),
            fontWeight: key % 12 == 0 ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: whiteWidth - 2);
      text.paint(
        canvas,
        Offset(
          i * whiteWidth + (whiteWidth - text.width) / 2,
          size.height - text.height - 8,
        ),
      );
    }
    for (final (key, rect) in blackKeyRects(size, firstKey, whiteKeys)) {
      final rounded = RRect.fromRectAndCorners(
        rect,
        bottomLeft: const Radius.circular(4),
        bottomRight: const Radius.circular(4),
      );
      canvas.drawRRect(
        rounded,
        Paint()
          ..color = pressed.contains(key)
              ? Color.lerp(Colors.black, pressedColor, 0.7)!
              : const Color(0xFF222222),
      );
    }
  }

  static int _natural(int key) =>
      const [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6][key % 12];

  @override
  bool shouldRepaint(_KeyboardPainter old) =>
      old.firstKey != firstKey ||
      old.whiteKeys != whiteKeys ||
      old.names != names ||
      !_sameSet(old.pressed, pressed) ||
      old.pressedColor != pressedColor ||
      old.outline != outline ||
      old.labelColor != labelColor;

  static bool _sameSet(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Todas las teclas en pequeño, ocupando todo el ancho, con la parte
/// ampliada ([visibleWhiteKeys] blancas desde [firstKey]) destacada. Al
/// tocar o deslizar el dedo, la parte ampliada pasa a estar centrada en él.
class PianoOverview extends StatelessWidget {
  const PianoOverview({
    super.key,
    required this.firstKey,
    required this.visibleWhiteKeys,
    required this.onChanged,
  });

  final int firstKey;
  final int visibleWhiteKeys;
  final ValueChanged<int> onChanged;

  static const height = 52.0;

  void _moveTo(double x, double width) {
    final whiteWidth = width / PianoKeys.whiteKeys.length;
    final first = (x / whiteWidth - visibleWhiteKeys / 2).round().clamp(
      0,
      PianoKeys.whiteKeys.length - visibleWhiteKeys,
    );
    if (first != firstKey) onChanged(first);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (details) => _moveTo(details.localPosition.dx, width),
          onHorizontalDragStart: (details) =>
              _moveTo(details.localPosition.dx, width),
          onHorizontalDragUpdate: (details) =>
              _moveTo(details.localPosition.dx, width),
          child: CustomPaint(
            size: Size(width, height),
            painter: _OverviewPainter(
              firstKey: firstKey,
              visibleWhiteKeys: visibleWhiteKeys,
              highlight: colors.primary,
              outline: colors.outlineVariant,
              labelColor: colors.outline,
            ),
          ),
        );
      },
    );
  }
}

class _OverviewPainter extends CustomPainter {
  _OverviewPainter({
    required this.firstKey,
    required this.visibleWhiteKeys,
    required this.highlight,
    required this.outline,
    required this.labelColor,
  });

  final int firstKey;
  final int visibleWhiteKeys;
  final Color highlight;
  final Color outline;
  final Color labelColor;

  /// Alto del número de las octavas, debajo de las teclas.
  static const _labelHeight = 14.0;

  @override
  void paint(Canvas canvas, Size size) {
    final whites = PianoKeys.whiteKeys;
    final whiteWidth = size.width / whites.length;
    final keysHeight = size.height - _labelHeight;
    final selected = Rect.fromLTWH(
      firstKey * whiteWidth,
      0,
      visibleWhiteKeys * whiteWidth,
      keysHeight,
    );
    final line = Paint()
      ..color = outline
      ..strokeWidth = 0.5;

    // Fuera de la parte ampliada, las teclas se ven apagadas.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, keysHeight),
      Paint()..color = Color.lerp(Colors.white, outline, 0.6)!,
    );
    canvas.drawRect(selected, Paint()..color = Colors.white);
    for (var i = 1; i < whites.length; i++) {
      canvas.drawLine(
        Offset(i * whiteWidth, 0),
        Offset(i * whiteWidth, keysHeight),
        line,
      );
    }
    for (var i = 0; i < whites.length; i++) {
      final black = whites[i] + 1;
      if (!PianoKeys.isBlack(black) || black > PianoKeys.highest) continue;
      final width = whiteWidth * PianoKeyboard.blackWidth;
      final inside = i + 1 > firstKey && i + 1 < firstKey + visibleWhiteKeys;
      canvas.drawRect(
        Rect.fromLTWH(
          (i + 1) * whiteWidth - width / 2,
          0,
          width,
          keysHeight * PianoKeyboard.blackHeight,
        ),
        Paint()..color = inside ? const Color(0xFF222222) : Colors.black45,
      );
    }
    // El número de cada octava, bajo su do.
    for (var i = 0; i < whites.length; i++) {
      if (whites[i] % 12 != 0) continue;
      final text = TextPainter(
        text: TextSpan(
          text: '${PianoKeys.octave(whites[i])}',
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(
          i * whiteWidth + (whiteWidth - text.width) / 2,
          keysHeight + (_labelHeight - text.height) / 2,
        ),
      );
    }
    // La parte ampliada, destacada.
    canvas
      ..drawRect(
        Rect.fromLTWH(0, 0, size.width, keysHeight),
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(selected.inflate(1), const Radius.circular(3)),
        Paint()
          ..color = highlight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
  }

  @override
  bool shouldRepaint(_OverviewPainter old) =>
      old.firstKey != firstKey ||
      old.visibleWhiteKeys != visibleWhiteKeys ||
      old.highlight != highlight ||
      old.outline != outline ||
      old.labelColor != labelColor;
}
