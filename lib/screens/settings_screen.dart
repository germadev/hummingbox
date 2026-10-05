import 'package:flutter/material.dart';

import '../controllers/whisper_controller.dart';
import '../l10n/l10n.dart';
import '../models/recording_options.dart';
import '../models/transcription.dart';
import '../services/settings_store.dart';
import '../services/storage_sync.dart';
import '../utils/formatters.dart';
import '../utils/languages.dart';
import '../widgets/dialogs.dart';
import 'transcript_screen.dart';

/// Opciones de la app: formato y calidad de las grabaciones, dónde se
/// guardan y cómo se transcriben.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.sync, required this.whisper});

  final StorageSync sync;

  /// Instalación de Whisper, para transcribir con él.
  final WhisperController whisper;

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

  // --- Transcripción ---

  WhisperController get _whisper => widget.whisper;

  Future<void> _chooseEngine() async {
    final l10n = context.l10n;
    final transcription = _sync.settings.transcription;
    final engine = await showChoiceDialog(
      context,
      title: l10n.transcriptionEngine,
      selected: transcription.engine,
      choices: [
        Choice(
          TranscriptionEngine.system,
          l10n.systemSpeechRecognition,
          subtitle: l10n.systemSpeechDescription,
        ),
        Choice(
          TranscriptionEngine.whisper,
          'Whisper',
          subtitle: l10n.whisperDescription,
        ),
      ],
    );
    if (engine == null) return;
    await _sync.setTranscription(transcription.copyWith(engine: engine));
    // Para usar Whisper hay que descargar un modelo.
    if (engine == TranscriptionEngine.whisper &&
        _whisper.installed == null &&
        _whisper.downloading == null &&
        mounted) {
      await _chooseWhisperModel();
    }
  }

  Future<void> _chooseWhisperModel() async {
    final l10n = context.l10n;
    final model = await showChoiceDialog<WhisperModel?>(
      context,
      title: l10n.chooseWhisperModel,
      selected: _whisper.installed,
      choices: [
        for (final model in WhisperModel.values)
          Choice(
            model,
            whisperModelName(model),
            subtitle: switch (model) {
              WhisperModel.tiny => l10n.whisperTinyDescription(
                formatMegabytes(model.bytes),
              ),
              WhisperModel.base => l10n.whisperBaseDescription(
                formatMegabytes(model.bytes),
              ),
            },
          ),
      ],
    );
    if (model == null || model == _whisper.installed) return;
    try {
      await _whisper.install(model);
    } catch (_) {
      _showMessage((l10n) => l10n.whisperDownloadFailed);
    }
  }

  Future<void> _deleteWhisperModel() async {
    final installed = _whisper.installed;
    if (installed == null) return;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.deleteWhisperModelTitle,
      message: l10n.deleteWhisperModelMessage(formatMegabytes(installed.bytes)),
      confirmLabel: l10n.delete,
    );
    if (confirmed) await _whisper.uninstall();
  }

  Future<void> _chooseLanguage() async {
    final l10n = context.l10n;
    final transcription = _sync.settings.transcription;
    final appLanguage = Localizations.localeOf(context).languageCode;
    final language = await showChoiceDialog(
      context,
      title: l10n.transcriptionLanguage,
      selected: transcription.language,
      choices: [
        Choice(
          TranscriptionSettings.appLanguage,
          l10n.appLanguageOption(languageName(appLanguage)),
        ),
        Choice(TranscriptionSettings.detectLanguage, l10n.detectLanguageOption),
        for (final code in transcriptionLanguages)
          Choice(code, languageName(code)),
      ],
    );
    if (language == null) return;
    await _sync.setTranscription(transcription.copyWith(language: language));
  }

  Future<void> _chooseTheme() async {
    final l10n = context.l10n;
    final theme = await showChoiceDialog(
      context,
      title: l10n.theme,
      selected: _sync.settings.theme,
      choices: [
        for (final theme in AppTheme.values)
          Choice(theme, _themeTitle(theme, l10n)),
      ],
    );
    if (theme == null) return;
    await _sync.setTheme(theme);
  }

  static String _themeTitle(AppTheme theme, AppLocalizations l10n) =>
      switch (theme) {
        AppTheme.system => l10n.themeSystem,
        AppTheme.light => l10n.themeLight,
        AppTheme.dark => l10n.themeDark,
      };

  String _languageTitle(String language, AppLocalizations l10n) =>
      transcriptionLanguageTitle(
        language,
        l10n,
        appLanguage: Localizations.localeOf(context).languageCode,
      );

  String _whisperSubtitle(AppLocalizations l10n) {
    if (_whisper.downloading case final model?) {
      return l10n.whisperDownloading(
        whisperModelName(model),
        formatPercent(_whisper.progress ?? 0),
        formatMegabytes(model.bytes),
      );
    }
    if (_whisper.installed case final model?) {
      return l10n.whisperInstalled(
        whisperModelName(model),
        formatMegabytes(model.bytes),
      );
    }
    return l10n.whisperNotInstalled;
  }

  static String _formatTitle(RecordingFormat format) =>
      '${formatName(format)} (${format.extension})';

  static String _qualityTitle(
    RecordingQuality quality,
    AppLocalizations l10n,
  ) => switch (quality) {
    RecordingQuality.minimum => l10n.qualityMinimum,
    RecordingQuality.low => l10n.qualityLow,
    RecordingQuality.medium => l10n.qualityMedium,
    RecordingQuality.high => l10n.qualityHigh,
    RecordingQuality.veryHigh => l10n.qualityVeryHigh,
    RecordingQuality.maximum => l10n.qualityMaximum,
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
        listenable: Listenable.merge([_sync, _whisper]),
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
              SwitchListTile(
                key: const Key('keep-screen-on-option'),
                secondary: const Icon(Icons.light_mode_outlined),
                title: Text(l10n.keepScreenOn),
                subtitle: Text(l10n.keepScreenOnSubtitle),
                value: settings.keepScreenOn,
                onChanged: _sync.setKeepScreenOn,
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
              const Divider(),
              _SectionTitle(l10n.transcriptionSection),
              SwitchListTile(
                key: const Key('auto-transcribe-option'),
                secondary: const Icon(Icons.auto_awesome_outlined),
                title: Text(l10n.autoTranscribe),
                subtitle: Text(l10n.autoTranscribeSubtitle),
                value: settings.transcription.automatic,
                onChanged: (automatic) => _sync.setTranscription(
                  settings.transcription.copyWith(automatic: automatic),
                ),
              ),
              ListTile(
                key: const Key('transcription-engine-option'),
                leading: const Icon(Icons.notes),
                title: Text(l10n.transcriptionEngine),
                subtitle: Text(switch (settings.transcription.engine) {
                  TranscriptionEngine.system => l10n.systemSpeechRecognition,
                  TranscriptionEngine.whisper => 'Whisper',
                }),
                onTap: _chooseEngine,
              ),
              ListTile(
                key: const Key('whisper-model-option'),
                leading: const Icon(Icons.download_for_offline_outlined),
                title: Text(l10n.whisperModel),
                subtitle: Text(_whisperSubtitle(l10n)),
                trailing: _whisper.downloading != null
                    ? IconButton(
                        tooltip: l10n.cancelDownload,
                        icon: const Icon(Icons.close),
                        onPressed: _whisper.cancelInstall,
                      )
                    : _whisper.installed != null
                    ? IconButton(
                        tooltip: l10n.deleteWhisperModel,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: _deleteWhisperModel,
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _whisper.downloading == null
                    ? _chooseWhisperModel
                    : null,
              ),
              if (_whisper.downloading != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
                  child: LinearProgressIndicator(value: _whisper.progress),
                ),
              ListTile(
                key: const Key('transcription-language-option'),
                leading: const Icon(Icons.translate),
                title: Text(l10n.transcriptionLanguage),
                subtitle: Text(
                  _languageTitle(settings.transcription.language, l10n),
                ),
                onTap: _chooseLanguage,
              ),
              const Divider(),
              _SectionTitle(l10n.searchSection),
              SwitchListTile(
                key: const Key('similar-words-option'),
                secondary: const Icon(Icons.manage_search),
                title: Text(l10n.similarWords),
                subtitle: Text(l10n.similarWordsSubtitle),
                value: settings.searchSimilarWords,
                onChanged: _sync.setSearchSimilarWords,
              ),
              const Divider(),
              _SectionTitle(l10n.appearanceSection),
              ListTile(
                key: const Key('theme-option'),
                leading: const Icon(Icons.brightness_6_outlined),
                title: Text(l10n.theme),
                subtitle: Text(_themeTitle(settings.theme, l10n)),
                onTap: _chooseTheme,
              ),
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
