/// Con qué suenan las teclas del piano.
enum Instrument {
  piano(program: 0),
  organ(program: 16, sustained: true),
  guitar(program: 24),
  marimba(program: 12),
  synth(program: 81, sustained: true);

  const Instrument({required this.program, this.sustained = false});

  /// Programa General MIDI (desde 0) con el que se guarda en el `.mid`:
  /// Acoustic Grand Piano, Drawbar Organ, Acoustic Guitar (nylon), Marimba y
  /// Lead 2 (sawtooth).
  final int program;

  /// Si suena mientras se mantiene pulsada la tecla (y se apaga al
  /// soltarla); si no, suena hasta apagarse sola, como un piano.
  final bool sustained;

  /// El instrumento de [name] (su nombre en los metadatos), o `null`.
  static Instrument? byName(Object? name) => values.asNameMap()[name];

  /// El instrumento más parecido al programa General MIDI [program] (de 0 a
  /// 127): por familias, y el piano si no hay ninguno parecido.
  static Instrument forProgram(int program) => switch (program) {
    >= 8 && <= 15 => marimba,
    >= 16 && <= 23 => organ,
    >= 24 && <= 39 => guitar,
    >= 80 && <= 103 => synth,
    _ => piano,
  };
}
