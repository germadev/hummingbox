import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/synth_patch.dart';

/// Un parámetro del sintetizador, con su valor como posición de una rueda
/// (de 0 a 1).
enum SynthParameter {
  wave,
  detune,
  attack,
  decay,
  sustain,
  release,
  brightness,
  resonance;

  /// Los parámetros por parejas, una para cada rueda (X e Y), como en los
  /// botones del panel.
  static const pairs = [
    (wave, detune),
    (attack, decay),
    (sustain, release),
    (brightness, resonance),
  ];

  String label(AppLocalizations l10n) => switch (this) {
    wave => l10n.synthWave,
    detune => l10n.synthDetune,
    attack => l10n.synthAttack,
    decay => l10n.synthDecay,
    sustain => l10n.synthSustain,
    release => l10n.synthRelease,
    brightness => l10n.synthBrightness,
    resonance => l10n.synthResonance,
  };

  /// Posición de la rueda con el valor de [patch].
  double positionIn(SynthPatch patch) => switch (this) {
    wave => patch.wave.index / (SynthWave.values.length - 1),
    detune => patch.detune / SynthPatch.maxDetune,
    attack => _timePosition(patch.attack, SynthPatch.maxAttack),
    decay => _timePosition(patch.decay, SynthPatch.maxDecay),
    sustain => patch.sustain,
    release => _timePosition(patch.release, SynthPatch.maxRelease),
    brightness => patch.brightness,
    resonance => patch.resonance,
  };

  /// [patch] con este parámetro en la posición [position] de la rueda.
  SynthPatch apply(SynthPatch patch, double position) {
    final p = position.clamp(0.0, 1.0);
    return switch (this) {
      wave => patch.copyWith(
        wave: SynthWave.values[(p * (SynthWave.values.length - 1)).round()],
      ),
      detune => patch.copyWith(detune: p * SynthPatch.maxDetune),
      attack => patch.copyWith(attack: _timeAt(p, SynthPatch.maxAttack)),
      decay => patch.copyWith(decay: _timeAt(p, SynthPatch.maxDecay)),
      sustain => patch.copyWith(sustain: p),
      release => patch.copyWith(release: _timeAt(p, SynthPatch.maxRelease)),
      brightness => patch.copyWith(brightness: p),
      resonance => patch.copyWith(resonance: p),
    };
  }

  /// El valor en [patch], como se muestra en la pantalla.
  String format(SynthPatch patch, AppLocalizations l10n) {
    String percent(double value) => '${(value * 100).round()} %';
    return switch (this) {
      wave => waveName(patch.wave, l10n),
      detune => '${patch.detune.round()} ¢',
      attack => _formatTime(patch.attack),
      decay => _formatTime(patch.decay),
      sustain => percent(patch.sustain),
      release => _formatTime(patch.release),
      brightness => percent(patch.brightness),
      resonance => percent(patch.resonance),
    };
  }

  /// Los tiempos, con más precisión en los cortos: la posición de la rueda
  /// es la raíz cuadrada de la parte del máximo.
  static double _timePosition(Duration value, Duration max) {
    final min = SynthPatch.minTime.inMicroseconds;
    final part = (value.inMicroseconds - min) / (max.inMicroseconds - min);
    return math.sqrt(part.clamp(0, 1));
  }

  static Duration _timeAt(double position, Duration max) {
    final min = SynthPatch.minTime.inMilliseconds;
    return Duration(
      milliseconds: (min + (max.inMilliseconds - min) * position * position)
          .round(),
    );
  }

  static String _formatTime(Duration value) => value.inMilliseconds < 1000
      ? '${value.inMilliseconds} ms'
      : '${(value.inMilliseconds / 1000).toStringAsFixed(1)} s';
}

/// Nombre de la onda [wave].
String waveName(SynthWave wave, AppLocalizations l10n) => switch (wave) {
  SynthWave.saw => l10n.waveSaw,
  SynthWave.square => l10n.waveSquare,
  SynthWave.triangle => l10n.waveTriangle,
  SynthWave.sine => l10n.waveSine,
};

/// Colores del panel, como los de un aparato (iguales con el tema claro y
/// el oscuro).
abstract final class _Colors {
  static const body = Color(0xFFDCDDDA);
  static const key = Color(0xFFF3F3F1);
  static const keyEdge = Color(0xFFB9BAB6);
  static const dark = Color(0xFF2A2A2A);
  static const screen = Color(0xFF121212);
  static const orange = Color(0xFFFF5A1F);
  static const ledOff = Color(0xFF9C9D99);
  static const label = Color(0xFF55564F);
  static const screenLabel = Color(0xFF8D8D8D);
}

/// El sintetizador, como un aparato: una pantalla con los dos parámetros
/// que se están cambiando, cuatro botones para elegir la pareja (onda y
/// desafinación, ataque y caída, sostenido y relajación, brillo y
/// resonancia) y dos ruedas, X (naranja) e Y (negra), para cambiarlos.
///
/// Mientras se gira una rueda solo cambia lo que se ve; al soltarla se llama
/// a [onChanged] (preparar el sonido de las teclas lleva un momento).
class SynthControls extends StatefulWidget {
  const SynthControls({
    super.key,
    required this.patch,
    required this.onChanged,
  });

  final SynthPatch patch;
  final ValueChanged<SynthPatch> onChanged;

  static const height = 104.0;

  @override
  State<SynthControls> createState() => _SynthControlsState();
}

class _SynthControlsState extends State<SynthControls> {
  late SynthPatch _patch = widget.patch;

  /// La pareja de parámetros de las ruedas (en [SynthParameter.pairs]).
  var _pair = 0;

  @override
  void didUpdateWidget(SynthControls old) {
    super.didUpdateWidget(old);
    if (old.patch != widget.patch) _patch = widget.patch;
  }

  void _preview(SynthPatch patch) => setState(() => _patch = patch);

  void _commit(SynthPatch patch) {
    setState(() => _patch = patch);
    if (patch != widget.patch) widget.onChanged(patch);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final patch = _patch;
    final (x, y) = SynthParameter.pairs[_pair];

    Widget knob(String name, SynthParameter parameter, bool orange) => _Knob(
      key: Key('synth-knob-$name'),
      name: name.toUpperCase(),
      label: parameter.label(l10n),
      format: (position) =>
          parameter.format(parameter.apply(patch, position), l10n),
      position: parameter.positionIn(patch),
      color: orange ? _Colors.orange : _Colors.dark,
      // La onda va a saltos: cuatro posiciones.
      steps: parameter == SynthParameter.wave ? SynthWave.values.length : null,
      onChanged: (position) => _preview(parameter.apply(patch, position)),
      onChangeEnd: (position) => _commit(parameter.apply(patch, position)),
    );

    return Container(
      height: SynthControls.height,
      color: _Colors.body,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _Screen(x: x, y: y, patch: patch),
          ),
          const SizedBox(width: 10),
          // Las parejas de parámetros, en dos filas.
          SizedBox(
            width: 2 * _PairKey.width + 6,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < SynthParameter.pairs.length; i++)
                  _PairKey(
                    key: Key('synth-pair-$i'),
                    top: SynthParameter.pairs[i].$1.label(l10n),
                    bottom: SynthParameter.pairs[i].$2.label(l10n),
                    selected: i == _pair,
                    onTap: () => setState(() => _pair = i),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          knob('x', x, true),
          const SizedBox(width: 6),
          knob('y', y, false),
          const SizedBox(width: 6),
          _ResetKey(
            onPressed: patch == const SynthPatch()
                ? null
                : () => _commit(const SynthPatch()),
          ),
        ],
      ),
    );
  }
}

/// La pantalla: los dos parámetros de las ruedas, con su nombre y su valor
/// (el de X en naranja, como su rueda).
class _Screen extends StatelessWidget {
  const _Screen({required this.x, required this.y, required this.patch});

  final SynthParameter x;
  final SynthParameter y;
  final SynthPatch patch;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    Widget value(String knob, SynthParameter parameter, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$knob · ${parameter.label(l10n).toUpperCase()}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _Colors.screenLabel,
            fontSize: 10,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            if (parameter == SynthParameter.wave) ...[
              IconTheme(
                data: IconThemeData(color: color),
                child: WaveIcon(patch.wave),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  parameter.format(patch, l10n),
                  key: Key('synth-screen-$knob'),
                  maxLines: 1,
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: _Colors.screen,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(child: value('X', x, _Colors.orange)),
          const SizedBox(width: 12),
          Expanded(child: value('Y', y, Colors.white)),
        ],
      ),
    );
  }
}

/// Un botón claro, como las teclas del aparato, con un LED que se enciende
/// si es la pareja elegida.
class _PairKey extends StatelessWidget {
  const _PairKey({
    super.key,
    required this.top,
    required this.bottom,
    required this.selected,
    required this.onTap,
  });

  final String top;
  final String bottom;
  final bool selected;
  final VoidCallback onTap;

  static const width = 84.0;
  static const height = 37.0;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(color: _Colors.label, fontSize: 9.5, height: 1.15);
    return Semantics(
      button: true,
      selected: selected,
      label: '$top, $bottom',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        // El borde de abajo, más oscuro, da relieve a la tecla.
        child: Container(
          width: width,
          height: height,
          padding: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            color: _Colors.keyEdge,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _Colors.key,
              borderRadius: BorderRadius.circular(4),
            ),
            padding: const EdgeInsets.fromLTRB(6, 3, 4, 2),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? _Colors.orange : _Colors.ledOff,
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: _Colors.orange.withValues(alpha: 0.6),
                              blurRadius: 4,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        top,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                      Text(
                        bottom,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: style,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// La tecla oscura para volver al sonido por defecto.
class _ResetKey extends StatelessWidget {
  const _ResetKey({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.synthReset,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: GestureDetector(
          key: const Key('synth-reset'),
          onTap: onPressed,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _Colors.dark,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(0, 3)),
              ],
            ),
            child: Icon(
              Icons.restart_alt,
              size: 20,
              color: onPressed == null ? Colors.white38 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Una rueda: se gira arrastrando el dedo hacia arriba o hacia la derecha
/// (sube) y hacia abajo o hacia la izquierda (baja). Con [steps], va a
/// saltos.
class _Knob extends StatefulWidget {
  const _Knob({
    super.key,
    required this.name,
    required this.label,
    required this.format,
    required this.position,
    required this.color,
    required this.onChanged,
    required this.onChangeEnd,
    this.steps,
  });

  final String name;
  final String label;

  /// El valor en la posición dada, como se muestra.
  final String Function(double position) format;
  final double position;
  final Color color;
  final int? steps;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  /// Lo que hay que arrastrar para ir de un extremo al otro.
  static const travel = 180.0;

  static const size = 60.0;

  @override
  State<_Knob> createState() => _KnobState();
}

class _KnobState extends State<_Knob> {
  int? _pointer;

  /// Posición sin redondear a los saltos, mientras se arrastra.
  double _dragged = 0;

  double _snapped(double position) {
    final steps = widget.steps;
    if (steps == null) return position.clamp(0, 1);
    return (position.clamp(0, 1) * (steps - 1)).round() / (steps - 1);
  }

  /// La posición un paso más arriba (o más abajo, si [up] es `false`).
  double _step({required bool up}) {
    final steps = widget.steps;
    final step = steps == null ? 0.05 : 1 / (steps - 1);
    return _snapped(widget.position + (up ? step : -step));
  }

  @override
  Widget build(BuildContext context) {
    // Con los dedos directamente: cualquier dirección vale, sin competir con
    // los arrastres del panel.
    return Semantics(
      slider: true,
      label: '${widget.name} · ${widget.label}',
      value: widget.format(widget.position),
      increasedValue: widget.format(_step(up: true)),
      decreasedValue: widget.format(_step(up: false)),
      onIncrease: () => widget.onChangeEnd(_step(up: true)),
      onDecrease: () => widget.onChangeEnd(_step(up: false)),
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (_pointer != null) return;
          _pointer = event.pointer;
          _dragged = widget.position;
        },
        onPointerMove: (event) {
          if (event.pointer != _pointer) return;
          final delta = event.localDelta;
          _dragged = (_dragged + (delta.dx - delta.dy) / _Knob.travel).clamp(
            0,
            1,
          );
          final position = _snapped(_dragged);
          if (position != widget.position) widget.onChanged(position);
        },
        onPointerUp: (event) {
          if (event.pointer != _pointer) return;
          _pointer = null;
          widget.onChangeEnd(_snapped(_dragged));
        },
        onPointerCancel: (event) {
          if (event.pointer != _pointer) return;
          _pointer = null;
          widget.onChangeEnd(_snapped(_dragged));
        },
        child: SizedBox(
          width: _Knob.size + 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CustomPaint(
                size: const Size.square(_Knob.size),
                painter: _KnobPainter(widget.position, widget.color),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  widget.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter(this.position, this.color);

  final double position;
  final Color color;

  /// La rueda gira tres cuartos de vuelta: de abajo a la izquierda (0) a
  /// abajo a la derecha (1).
  static const _start = 3 * math.pi / 4;
  static const _sweep = 3 * math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    // Las marcas alrededor.
    final ticks = Paint()
      ..color = _Colors.label
      ..strokeWidth = 1.2;
    for (var i = 0; i <= 10; i++) {
      final angle = _start + _sweep * i / 10;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (radius - 1),
        center + direction * (radius - (i % 5 == 0 ? 6 : 4)),
        ticks,
      );
    }
    // La rueda, con un poco de relieve.
    final knobRadius = radius - 8;
    canvas
      ..drawCircle(
        center + const Offset(0, 1.5),
        knobRadius,
        Paint()..color = Colors.black26,
      )
      ..drawCircle(
        center,
        knobRadius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.3, -0.4),
            colors: [Color.lerp(color, Colors.white, 0.25)!, color],
          ).createShader(Rect.fromCircle(center: center, radius: knobRadius)),
      );
    // La marca de la posición.
    final angle = _start + _sweep * position.clamp(0, 1);
    final direction = Offset(math.cos(angle), math.sin(angle));
    canvas.drawLine(
      center + direction * knobRadius * 0.25,
      center + direction * (knobRadius - 3),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.position != position || old.color != color;
}

/// Dibujo de un periodo y medio de la onda [wave], del color de los iconos.
class WaveIcon extends StatelessWidget {
  const WaveIcon(this.wave, {super.key});

  final SynthWave wave;

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color ?? Colors.black;
    return CustomPaint(
      size: const Size(24, 16),
      painter: _WavePainter(wave, color),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter(this.wave, this.color);

  final SynthWave wave;
  final Color color;

  double _valueAt(double phase) => switch (wave) {
    SynthWave.saw => 2 * phase - 1,
    SynthWave.square => phase < 0.5 ? 1 : -1,
    SynthWave.triangle => 1 - 4 * (phase - 0.5).abs(),
    SynthWave.sine => math.sin(2 * math.pi * phase),
  };

  @override
  void paint(Canvas canvas, Size size) {
    const periods = 1.5;
    const points = 60;
    final path = Path();
    double? previous;
    for (var i = 0; i <= points; i++) {
      final t = i / points;
      final value = _valueAt((t * periods) % 1);
      final x = t * size.width;
      final y = size.height / 2 - value * size.height / 2 * 0.85;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Los saltos de la sierra y la cuadrada, en vertical.
        if (previous != null && (value - previous).abs() > 1) {
          path.lineTo(x, size.height / 2 - previous * size.height / 2 * 0.85);
        }
        path.lineTo(x, y);
      }
      previous = value;
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) =>
      old.wave != wave || old.color != color;
}
