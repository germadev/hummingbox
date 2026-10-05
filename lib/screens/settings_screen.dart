import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/recording_options.dart';
import '../services/settings_store.dart';
import '../services/storage_sync.dart';
import '../utils/formatters.dart';
import '../widgets/dialogs.dart';

/// Opciones de la app: formato y calidad de las grabaciones y dónde se
/// guardan.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.sync});

  final StorageSync sync;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  StorageSync get _sync => widget.sync;

  Future<void> _pickFolder() async {
    try {
      final folder = await _sync.folders.pickFolder();
      if (folder == null || !mounted) return;
      await _sync.setFolder(folder);
      _showMessage((l10n) => l10n.folderInUse(folder.name));
    } catch (_) {
      _showMessage((l10n) => l10n.folderFailed);
    }
  }

  Future<void> _clearFolder() async {
    final settings = _sync.settings;
    final folder = settings.folder;
    if (folder == null) return;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.stopUsingFolderTitle(folder.name),
      // Con Drive conectado, las grabaciones pasan a guardarse en él.
      message: settings.drive != null
          ? l10n.stopUsingFolderDriveMessage
          : l10n.stopUsingFolderMessage,
      confirmLabel: l10n.stopUsing,
    );
    if (!confirmed || !mounted) return;
    await _sync.setFolder(null);
    _closeIfNoStorage();
  }

  /// Sin destino, se vuelve a la pantalla principal, que muestra el menú
  /// inicial para elegir otro.
  void _closeIfNoStorage() {
    if (mounted && _sync.settings.storage == null) Navigator.pop(context);
  }

  Future<void> _connectDrive() async {
    setState(() => _busy = true);
    try {
      final drive = await _sync.drive.connect(
        folderName: context.l10n.appTitle,
      );
      if (drive != null) await _sync.setDrive(drive);
    } catch (_) {
      _showMessage((l10n) => l10n.driveConnectFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnectDrive() async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.disconnectDriveTitle,
      message: _sync.settings.storage == StorageKind.drive
          ? context.l10n.disconnectDriveStorageMessage
          : context.l10n.disconnectDriveMessage,
      confirmLabel: context.l10n.disconnect,
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
    _closeIfNoStorage();
  }

  Future<void> _chooseFormat() async {
    final options = _sync.settings.recording;
    final l10n = context.l10n;
    final format = await showChoiceDialog(
      context,
      title: l10n.format,
      selected: options.format,
      choices: [
        for (final format in RecordingFormat.values)
          Choice(
            format,
            _formatTitle(format),
            subtitle: switch (format) {
              RecordingFormat.aac => l10n.aacDescription,
              RecordingFormat.wav => l10n.wavDescription,
            },
          ),
      ],
    );
    if (format == null) return;
    await _sync.setRecordingOptions(options.copyWith(format: format));
  }

  Future<void> _chooseQuality() async {
    final options = _sync.settings.recording;
    final l10n = context.l10n;
    final quality = await showChoiceDialog(
      context,
      title: l10n.quality,
      selected: options.quality,
      choices: [
        for (final quality in RecordingQuality.values)
          Choice(
            quality,
            _qualityTitle(quality, l10n),
            subtitle: _qualityDetails(options.copyWith(quality: quality), l10n),
          ),
      ],
    );
    if (quality == null) return;
    await _sync.setRecordingOptions(options.copyWith(quality: quality));
  }

  Future<void> _chooseCountdown() async {
    final l10n = context.l10n;
    final seconds = await showChoiceDialog(
      context,
      title: l10n.countdown,
      selected: _sync.settings.countdownSeconds,
      choices: [
        for (final seconds in AppSettings.countdownChoices)
          Choice(seconds, l10n.secondsCount(seconds)),
      ],
    );
    if (seconds == null) return;
    await _sync.setCountdown(seconds);
  }

  static String _formatTitle(RecordingFormat format) =>
      '${formatName(format)} (${format.extension})';

  static String _qualityTitle(
    RecordingQuality quality,
    AppLocalizations l10n,
  ) => switch (quality) {
    RecordingQuality.low => l10n.qualityLow,
    RecordingQuality.medium => l10n.qualityMedium,
    RecordingQuality.high => l10n.qualityHigh,
  };

  /// `44,1 kHz · 128 kbps · 1 MB por minuto` (en español).
  static String _qualityDetails(
    RecordingOptions options,
    AppLocalizations l10n,
  ) => [
    formatSampleRate(options.sampleRate),
    switch (options.format) {
      RecordingFormat.aac => formatBitRate(options.bitRate),
      RecordingFormat.wav => l10n.bitDepth(16),
    },
    l10n.perMinute(formatMegabytes(options.bytesPerMinute)),
  ].join(' · ');

  /// Muestra un aviso con el texto que devuelve [message] en el idioma de la
  /// app (se lee al mostrarlo, así que se puede llamar tras un `await`).
  void _showMessage(String Function(AppLocalizations l10n) message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message(context.l10n))));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
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
              _SectionTitle(l10n.recordingSection),
              ListTile(
                key: const Key('format-option'),
                leading: const Icon(Icons.audio_file_outlined),
                title: Text(l10n.format),
                subtitle: Text(_formatTitle(recording.format)),
                onTap: _chooseFormat,
              ),
              ListTile(
                key: const Key('quality-option'),
                leading: const Icon(Icons.high_quality_outlined),
                title: Text(l10n.quality),
                subtitle: Text(
                  '${_qualityTitle(recording.quality, l10n)} · '
                  '${_qualityDetails(recording, l10n)}',
                ),
                onTap: _chooseQuality,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                child: Text(
                  l10n.formatNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                key: const Key('countdown-option'),
                leading: const Icon(Icons.timer_outlined),
                title: Text(l10n.countdown),
                subtitle: Text(
                  l10n.countdownSubtitle(settings.countdownSeconds),
                ),
                onTap: _chooseCountdown,
              ),
              const Divider(),
              _SectionTitle(l10n.storageSection),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  switch ((settings.storage, drive)) {
                    (StorageKind.drive, final drive?) =>
                      l10n.storageDriveDescription(drive.folderName),
                    _ => l10n.storageFolderDescription,
                  },
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              ListTile(
                key: const Key('folder-option'),
                leading: const Icon(Icons.folder_outlined),
                title: Text(l10n.deviceFolder),
                subtitle: Text(folder == null ? l10n.noFolder : folder.name),
                trailing: folder == null
                    ? const Icon(Icons.chevron_right)
                    : IconButton(
                        tooltip: l10n.stopUsingFolder,
                        icon: const Icon(Icons.close),
                        onPressed: _clearFolder,
                      ),
                onTap: _pickFolder,
              ),
              if (folder != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: _pickFolder,
                      child: Text(l10n.chooseAnotherFolder),
                    ),
                  ),
                ),
              if (errors[FolderTarget.targetKey] case final error?)
                _ErrorText(error),
              const Divider(),
              SwitchListTile(
                key: const Key('drive-option'),
                secondary: const Icon(Icons.add_to_drive),
                title: const Text('Google Drive'),
                subtitle: Text(switch ((drive, driveAvailable)) {
                  (final drive?, _) => l10n.driveAccount(
                    drive.email,
                    drive.folderName,
                  ),
                  (null, true) => l10n.driveSaveCopy,
                  (null, false) => l10n.driveUnavailable,
                }),
                isThreeLine: !driveAvailable && drive == null,
                value: drive != null,
                onChanged: _busy || (!driveAvailable && drive == null)
                    ? null
                    : (enabled) =>
                          enabled ? _connectDrive() : _disconnectDrive(),
              ),
              if (_busy) const LinearProgressIndicator(),
              if (errors[DriveTarget.targetKey] case final error?)
                _ErrorText(error, drive: true),
              if (settings.storage != null) ...[
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
                  title: Text(_sync.syncing ? l10n.syncing : l10n.syncNow),
                  subtitle: Text(l10n.syncNowSubtitle),
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
  const _ErrorText(this.error, {this.drive = false});

  final SyncError error;

  /// Si es el error de Google Drive (si no, el de la carpeta).
  final bool drive;

  String text(AppLocalizations l10n) {
    final message = switch (error.kind) {
      SyncErrorKind.upload => l10n.saveFailed(error.count),
      SyncErrorKind.import => l10n.importFailed(error.count),
      SyncErrorKind.read =>
        drive ? l10n.readDriveFailed : l10n.readFolderFailed,
      SyncErrorKind.readRecordings => l10n.readRecordingsFailed,
      SyncErrorKind.driveAuth => l10n.driveReconnect,
    };
    final detail = error.offline
        ? l10n.offline
        : (error.noPermission ? l10n.noFolderPermission : error.detail);
    return detail == null ? message : l10n.errorWithDetail(message, detail);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
      child: Text(
        text(context.l10n),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }
}
