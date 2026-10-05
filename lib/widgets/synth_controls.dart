import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/synth_patch.dart';

/// Los controles del sintetizador, en una fila: la onda, la envolvente
/// (ataque, caída, sostenido y relajación), el filtro (brillo y resonancia)
/// y la desafinación. Mientras se arrastra un control solo cambia lo que
/// se ve; al soltarlo se llama a [onChanged] (preparar el sonido de las
/// teclas lleva un momento).
class SynthControls extends StatefulWidget {
  const SynthControls({
    super.key,
    required this.patch,
    required this.onChanged,
  });

  final SynthPatch patch;
  final ValueChanged<SynthPatch> onChanged;

  static const height = 64.0;

  @override
  State<SynthControls> createState() => _SynthControlsState();
}

class _SynthControlsState extends State<SynthControls> {
  late SynthPatch _patch = widget.patch;

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

    Widget time(
      String key,
      String label,
      Duration value,
      Duration max,
      SynthPatch Function(Duration) apply,
    ) => _SynthSlider(
      key: Key('synth-$key'),
      label: label,
      value: _timePosition(value, max),
      text: _formatTime(value),
      onChanged: (position) => _preview(apply(_timeAt(position, max))),
      onChangeEnd: (position) => _commit(apply(_timeAt(position, max))),
    );

    Widget level(
      String key,
      String label,
      double value,
      String text,
      SynthPatch Function(double) apply, {
      double max = 1,
    }) => _SynthSlider(
      key: Key('synth-$key'),
      label: label,
      value: value / max,
      text: text,
      onChanged: (position) => _preview(apply(position * max)),
      onChangeEnd: (position) => _commit(apply(position * max)),
    );

    String percent(double value) => '${(value * 100).round()} %';

    return SizedBox(
      height: SynthControls.height,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            SegmentedButton<SynthWave>(
              key: const Key('synth-wave'),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: [
                for (final wave in SynthWave.values)
                  ButtonSegment(
                    value: wave,
                    tooltip: switch (wave) {
                      SynthWave.saw => l10n.waveSaw,
                      SynthWave.square => l10n.waveSquare,
                      SynthWave.triangle => l10n.waveTriangle,
                      SynthWave.sine => l10n.waveSine,
                    },
                    icon: WaveIcon(wave),
                  ),
              ],
              selected: {patch.wave},
              onSelectionChanged: (selected) =>
                  _commit(patch.copyWith(wave: selected.single)),
            ),
            const SizedBox(width: 8),
            time(
              'attack',
              l10n.synthAttack,
              patch.attack,
              SynthPatch.maxAttack,
              (value) => patch.copyWith(attack: value),
            ),
            time(
              'decay',
              l10n.synthDecay,
              patch.decay,
              SynthPatch.maxDecay,
              (value) => patch.copyWith(decay: value),
            ),
            level(
              'sustain',
              l10n.synthSustain,
              patch.sustain,
              percent(patch.sustain),
              (value) => patch.copyWith(sustain: value),
            ),
            time(
              'release',
              l10n.synthRelease,
              patch.release,
              SynthPatch.maxRelease,
              (value) => patch.copyWith(release: value),
            ),
            level(
              'brightness',
              l10n.synthBrightness,
              patch.brightness,
              percent(patch.brightness),
              (value) => patch.copyWith(brightness: value),
            ),
            level(
              'resonance',
              l10n.synthResonance,
              patch.resonance,
              percent(patch.resonance),
              (value) => patch.copyWith(resonance: value),
            ),
            level(
              'detune',
              l10n.synthDetune,
              patch.detune,
              '${patch.detune.round()} ¢',
              (value) => patch.copyWith(detune: value),
              max: SynthPatch.maxDetune,
            ),
            IconButton(
              key: const Key('synth-reset'),
              tooltip: l10n.synthReset,
              icon: const Icon(Icons.restart_alt),
              onPressed: patch == const SynthPatch()
                  ? null
                  : () => _commit(const SynthPatch()),
            ),
          ],
        ),
      ),
    );
  }

  /// Los tiempos, con más precisión en los cortos: la posición del control
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

/// Un control del sintetizador: su nombre y su valor encima y, debajo, el
/// deslizador (de 0 a 1).
class _SynthSlider extends StatelessWidget {
  const _SynthSlider({
    super.key,
    required this.label,
    required this.value,
    required this.text,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final String label;
  final double value;
  final String text;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  static const width = 112.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$label · $text',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
          SizedBox(
            height: 32,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                value: value.clamp(0, 1),
                onChanged: onChanged,
                onChangeEnd: onChangeEnd,
              ),
            ),
          ),
        ],
      ),
    );
  }
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
