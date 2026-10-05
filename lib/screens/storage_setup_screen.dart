import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../services/storage_sync.dart';

/// Menú inicial: se muestra mientras no se ha elegido dónde guardar las
/// grabaciones, en una carpeta del dispositivo o en Google Drive (al
/// instalar la app o si se deja de usar el destino en las opciones).
class StorageSetupScreen extends StatefulWidget {
  const StorageSetupScreen({super.key, required this.sync});

  final StorageSync sync;

  @override
  State<StorageSetupScreen> createState() => _StorageSetupScreenState();
}

class _StorageSetupScreenState extends State<StorageSetupScreen> {
  bool _busy = false;

  StorageSync get _sync => widget.sync;

  Future<void> _pickFolder() => _run(() async {
    final folder = await _sync.folders.pickFolder();
    if (folder != null) await _sync.setFolder(folder);
  }, failed: (l10n) => l10n.folderFailed);

  Future<void> _connectDrive() {
    final folderName = context.l10n.appTitle;
    return _run(() async {
      final drive = await _sync.drive.connect(folderName: folderName);
      if (drive != null) await _sync.setDrive(drive);
    }, failed: (l10n) => l10n.driveConnectFailed);
  }

  Future<void> _run(
    Future<void> Function() action, {
    required String Function(AppLocalizations l10n) failed,
  }) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failed(context.l10n))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final driveAvailable = _sync.drive.isAvailable;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 72,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.setupTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.setupMessage,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _Option(
              key: const Key('setup-folder'),
              icon: Icons.folder_outlined,
              title: l10n.setupFolder,
              subtitle: l10n.setupFolderDescription,
              onTap: _busy ? null : _pickFolder,
            ),
            const SizedBox(height: 12),
            _Option(
              key: const Key('setup-drive'),
              icon: Icons.add_to_drive,
              title: l10n.setupDrive,
              subtitle: driveAvailable
                  ? l10n.setupDriveDescription
                  : l10n.driveUnavailable,
              onTap: _busy || !driveAvailable ? null : _connectDrive,
            ),
            if (_busy) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, size: 32),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
