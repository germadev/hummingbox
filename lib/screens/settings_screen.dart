import 'package:flutter/material.dart';

import '../models/recording_options.dart';
import '../services/copy_sync.dart';
import '../services/settings_store.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';

/// Opciones de la app: formato y calidad de las grabaciones y dónde se
/// guardan.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.sync});

  final CopySync sync;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _scanning = false;

  CopySync get _sync => widget.sync;

  Future<void> _pickFolder() async {
    try {
      final picked = await _sync.folders.pickFolder();
      if (picked == null || !mounted) return;
      var folder = picked;

      // Antes de copiar a la app lo que haya en la carpeta, se pregunta (por
      // si se elige por error una carpeta con mucha música, por ejemplo).
      setState(() => _scanning = true);
      final FolderScan scan;
      try {
        scan = await _sync.scanFolder(picked);
      } finally {
        if (mounted) setState(() => _scanning = false);
      }
      if (scan.count > 0) {
        if (!mounted) return;
        final files = scan.count == 1 ? '1 audio' : '${scan.count} audios';
        final add = await showConfirmDialog(
          context,
          title: '¿Añadir las grabaciones de la carpeta?',
          message:
              '«${picked.name}» tiene $files '
              '(${formatMegabytes(scan.bytes)}) que no están en la app. Si '
              'los añades, aparecerán en la lista y se copiarán a la app.',
          confirmLabel: 'Añadir',
          cancelLabel: 'No añadir',
        );
        folder = picked.withImportFiles(add);
      }
      await _sync.setFolder(folder);
    } catch (_) {
      _showMessage('No se pudo usar esa carpeta');
    }
  }

  Future<void> _clearFolder() async {
    await _sync.setFolder(null);
    _showMessage('Las copias que ya están en la carpeta se conservan');
  }

  Future<void> _connectDrive() async {
    setState(() => _busy = true);
    try {
      final drive = await _sync.drive.connect();
      if (drive != null) await _sync.setDrive(drive);
    } catch (_) {
      _showMessage('No se pudo conectar con Google Drive');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnectDrive() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '¿Desconectar Google Drive?',
      message:
          'Dejarán de guardarse copias en Drive. Las que ya están allí se '
          'conservan.',
      confirmLabel: 'Desconectar',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy = true);
    try {
      await _sync.drive.disconnect();
    } catch (_) {
      // Aunque falle el cierre de sesión, se deja de usar Drive.
    }
    await _sync.setDrive(null);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _chooseFormat() async {
    final options = _sync.settings.recording;
    final format = await showChoiceDialog(
      context,
      title: 'Formato',
      selected: options.format,
      choices: [
        for (final format in RecordingFormat.values)
          Choice(
            format,
            _formatTitle(format),
            subtitle: switch (format) {
              RecordingFormat.aac =>
                'Comprimido: ocupa poco y se reproduce en cualquier '
                    'dispositivo',
              RecordingFormat.wav =>
                'Sin comprimir: la máxima fidelidad, pero ocupa mucho más',
            },
          ),
      ],
    );
    if (format == null) return;
    await _sync.setRecordingOptions(options.copyWith(format: format));
  }

  Future<void> _chooseQuality() async {
    final options = _sync.settings.recording;
    final quality = await showChoiceDialog(
      context,
      title: 'Calidad',
      selected: options.quality,
      choices: [
        for (final quality in RecordingQuality.values)
          Choice(
            quality,
            _qualityTitle(quality),
            subtitle: _qualityDetails(options.copyWith(quality: quality)),
          ),
      ],
    );
    if (quality == null) return;
    await _sync.setRecordingOptions(options.copyWith(quality: quality));
  }

  Future<void> _chooseCountdown() async {
    final seconds = await showChoiceDialog(
      context,
      title: 'Cuenta atrás',
      selected: _sync.settings.countdownSeconds,
      choices: [
        for (final seconds in AppSettings.countdownChoices)
          Choice(seconds, '$seconds segundos'),
      ],
    );
    if (seconds == null) return;
    await _sync.setCountdown(seconds);
  }

  static String _formatTitle(RecordingFormat format) =>
      '${formatName(format)} (${format.extension})';

  static String _qualityTitle(RecordingQuality quality) => switch (quality) {
    RecordingQuality.low => 'Baja',
    RecordingQuality.medium => 'Media',
    RecordingQuality.high => 'Alta',
  };

  /// `44,1 kHz · 128 kbps · 1 MB por minuto`.
  static String _qualityDetails(RecordingOptions options) => [
    formatSampleRate(options.sampleRate),
    switch (options.format) {
      RecordingFormat.aac => formatBitRate(options.bitRate),
      RecordingFormat.wav => '16 bits',
    },
    '${formatMegabytes(options.bytesPerMinute)} por minuto',
  ].join(' · ');

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Opciones')),
      body: ListenableBuilder(
        listenable: _sync,
        builder: (context, _) {
          final settings = _sync.settings;
          final recording = settings.recording;
          final folder = settings.folder;
          final drive = settings.drive;
          final driveAvailable = _sync.drive.isAvailable;
          final errors = _sync.errors;

          return ListView(
            children: [
              const _SectionTitle('Grabación'),
              ListTile(
                key: const Key('format-option'),
                leading: const Icon(Icons.audio_file_outlined),
                title: const Text('Formato'),
                subtitle: Text(_formatTitle(recording.format)),
                onTap: _chooseFormat,
              ),
              ListTile(
                key: const Key('quality-option'),
                leading: const Icon(Icons.high_quality_outlined),
                title: const Text('Calidad'),
                subtitle: Text(
                  '${_qualityTitle(recording.quality)} · '
                  '${_qualityDetails(recording)}',
                ),
                onTap: _chooseQuality,
              ),
              ListTile(
                key: const Key('countdown-option'),
                leading: const Icon(Icons.timer_outlined),
                title: const Text('Cuenta atrás'),
                subtitle: Text(
                  '${settings.countdownSeconds} segundos antes de empezar a '
                  'grabar con el botón ⏱',
                ),
                onTap: _chooseCountdown,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                child: Text(
                  'Se aplica a las grabaciones nuevas. Al editar, cada '
                  'grabación conserva su formato.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const Divider(),
              const _SectionTitle('Dónde se guardan las grabaciones'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Las grabaciones se guardan siempre dentro de la app. '
                  'Además, puedes guardar una copia de cada una en una carpeta '
                  'del dispositivo y en Google Drive, con el nombre que le '
                  'hayas dado y en su subcarpeta. Las copias se actualizan al '
                  'renombrar o editar una grabación, pero no se borran al '
                  'eliminarla.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                key: const Key('folder-option'),
                leading: const Icon(Icons.folder_outlined),
                title: const Text('Carpeta del dispositivo'),
                subtitle: Text(
                  folder == null
                      ? 'No se guarda en ninguna carpeta'
                      : folder.name,
                ),
                trailing: folder == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        tooltip: 'Dejar de guardar en la carpeta',
                        icon: const Icon(Icons.close),
                        onPressed: _clearFolder,
                      ),
                onTap: _pickFolder,
              ),
              if (_scanning) const LinearProgressIndicator(),
              if (folder != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: _pickFolder,
                      child: const Text('Elegir otra carpeta'),
                    ),
                  ),
                ),
                SwitchListTile(
                  key: const Key('import-option'),
                  secondary: const Icon(Icons.library_music_outlined),
                  title: const Text('Mostrar las grabaciones de la carpeta'),
                  subtitle: const Text(
                    'Añade a la app los audios (.m4a y .wav) que haya en la '
                    'carpeta y en sus subcarpetas',
                  ),
                  value: folder.importFiles,
                  onChanged: _sync.setImportFiles,
                ),
              ],
              if (errors[FolderCopyTarget.targetKey] case final error?)
                _ErrorText(error),
              const Divider(),
              SwitchListTile(
                key: const Key('drive-option'),
                secondary: const Icon(Icons.add_to_drive),
                title: const Text('Google Drive'),
                subtitle: Text(switch ((drive, driveAvailable)) {
                  (final drive?, _) => '${drive.email} · carpeta «Grabadora»',
                  (null, true) => 'Guardar una copia en tu Google Drive',
                  (null, false) =>
                    'No disponible: esta versión de la app no tiene '
                        'configurado el acceso a Google',
                }),
                isThreeLine: !driveAvailable && drive == null,
                value: drive != null,
                onChanged: _busy || (!driveAvailable && drive == null)
                    ? null
                    : (enabled) =>
                          enabled ? _connectDrive() : _disconnectDrive(),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (errors[DriveCopyTarget.targetKey] case final error?)
                _ErrorText(error),
              if (folder != null || drive != null) ...[
                const Divider(),
                ListTile(
                  leading: _sync.syncing
                      ? const SizedBox.square(
                          dimension: 24,
                          child: Padding(
                            padding: EdgeInsets.all(2),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : const Icon(Icons.sync),
                  title: Text(
                    _sync.syncing ? 'Guardando copias…' : 'Copiar ahora',
                  ),
                  subtitle: const Text(
                    'Se copia solo lo que falta o ha cambiado',
                  ),
                  enabled: !_sync.syncing,
                  onTap: _sync.sync,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);

  final CopyError error;

  String get text {
    final count = error.count;
    final message = switch (error.kind) {
      CopyErrorKind.copy =>
        count == 1
            ? 'No se pudo copiar 1 grabación'
            : 'No se pudieron copiar $count grabaciones',
      CopyErrorKind.import =>
        count == 1
            ? 'No se pudo añadir 1 grabación de la carpeta'
            : 'No se pudieron añadir $count grabaciones de la carpeta',
      CopyErrorKind.readFolder => 'No se pudo leer la carpeta',
      CopyErrorKind.readRecordings => 'No se pudieron leer las grabaciones',
      CopyErrorKind.driveAuth => 'Vuelve a conectar tu cuenta de Google Drive',
    };
    final detail = error.offline ? 'Sin conexión' : error.detail;
    return detail == null ? message : '$message: $detail';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
