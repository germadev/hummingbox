import 'package:flutter/material.dart';

/// Menú lateral con la carpeta de grabaciones y sus subcarpetas. Se abre
/// deslizando desde la izquierda o con el botón de la barra superior.
class FolderDrawer extends StatelessWidget {
  const FolderDrawer({
    super.key,
    required this.rootName,
    required this.folders,
    required this.counts,
    required this.selected,
    required this.onSelected,
    required this.onCreate,
  });

  /// Nombre de la carpeta principal.
  final String rootName;

  /// Subcarpetas, ya ordenadas.
  final List<String> folders;

  /// Número de grabaciones por subcarpeta (vacío para la principal).
  final Map<String, int> counts;

  /// Subcarpeta abierta; vacío para la principal.
  final String selected;
  final ValueChanged<String> onSelected;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget item(
      String folder, {
      required String label,
      required IconData icon,
    }) {
      final count = counts[folder] ?? 0;
      return _FolderTile(
        key: Key('folder-$folder'),
        icon: icon,
        label: label,
        count: count,
        selected: folder == selected,
        onTap: () => onSelected(folder),
      );
    }

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Carpetas',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            item('', label: rootName, icon: Icons.folder_special_outlined),
            if (folders.isNotEmpty) const Divider(indent: 16, endIndent: 16),
            for (final folder in folders)
              item(folder, label: folder, icon: Icons.folder_outlined),
            const Divider(indent: 16, endIndent: 16),
            ListTile(
              key: const Key('new-folder'),
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('Nueva carpeta'),
              shape: const StadiumBorder(),
              onTap: onCreate,
            ),
          ],
        ),
      ),
    );
  }
}

/// Elemento del menú: icono, nombre y número de grabaciones, resaltado si
/// es la carpeta abierta.
class _FolderTile extends StatelessWidget {
  const _FolderTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(selected ? Icons.folder_open : icon),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: count > 0 ? Text('$count') : null,
      selected: selected,
      selectedColor: colors.onSecondaryContainer,
      selectedTileColor: colors.secondaryContainer,
      shape: const StadiumBorder(),
      onTap: onTap,
    );
  }
}
