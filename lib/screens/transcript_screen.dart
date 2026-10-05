import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/recording.dart';
import '../models/transcription.dart';
import '../services/share_service.dart';
import '../utils/formatters.dart';
import '../utils/languages.dart';

/// Lo que se pide al cerrar la pantalla de la transcripción.
enum TranscriptAction { transcribeAgain, delete }

/// Muestra la transcripción de una grabación, para leerla, copiarla o
/// compartirla. Devuelve una [TranscriptAction] si se pide volver a
/// transcribirla o eliminarla.
class TranscriptScreen extends StatelessWidget {
  const TranscriptScreen({super.key, required this.recording});

  final Recording recording;

  /// Con qué se transcribió: `Whisper (Base) · Español · Hoy, 10:30`.
  static String details(Transcript transcript, AppLocalizations l10n) => [
    switch (transcript.engine) {
      TranscriptionEngine.system => l10n.systemSpeechRecognition,
      TranscriptionEngine.whisper => switch (transcript.model) {
        final model? => 'Whisper (${whisperModelName(model)})',
        null => 'Whisper',
      },
    },
    if (transcript.language case final language?) languageName(language),
    formatRecordingDate(transcript.createdAt, l10n),
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final transcript = recording.transcript!;

    return Scaffold(
      appBar: AppBar(
        title: Text(recording.name),
        actions: [
          IconButton(
            tooltip: l10n.copy,
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: transcript.text));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.copied)));
            },
          ),
          Builder(
            builder: (buttonContext) => IconButton(
              tooltip: l10n.share,
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                // En iPad la hoja de compartir necesita un punto de anclaje.
                final box = buttonContext.findRenderObject() as RenderBox?;
                shareText(
                  transcript.text,
                  subject: recording.name,
                  origin: box != null && box.hasSize
                      ? box.localToGlobal(Offset.zero) & box.size
                      : null,
                );
              },
            ),
          ),
          PopupMenuButton<TranscriptAction>(
            tooltip: l10n.moreOptions,
            onSelected: (action) => Navigator.pop(context, action),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: TranscriptAction.transcribeAgain,
                child: ListTile(
                  leading: const Icon(Icons.refresh),
                  title: Text(l10n.transcribeAgain),
                ),
              ),
              PopupMenuItem(
                value: TranscriptAction.delete,
                child: ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: Text(l10n.deleteTranscript),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            details(transcript, l10n),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (recording.isTranscriptOutdated) ...[
            const SizedBox(height: 12),
            Card.filled(
              color: theme.colorScheme.tertiaryContainer,
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.onTertiaryContainer,
                ),
                title: Text(
                  l10n.transcriptOutdated,
                  style: TextStyle(
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SelectableText(
            transcript.text,
            key: const Key('transcript-text'),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

/// Nombre de un modelo de Whisper: `Tiny`, `Base`.
String whisperModelName(WhisperModel model) => switch (model) {
  WhisperModel.tiny => 'Tiny',
  WhisperModel.base => 'Base',
};
