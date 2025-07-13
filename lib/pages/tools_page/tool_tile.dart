import 'package:flutter/material.dart';

class ToolTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const ToolTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Stack(
        children: [
          Positioned.fill(
            child: InkWell(
              onTap: onTap,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 48),
                    const SizedBox(height: 8),
                    Text(title, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
          if (isAdmin && (onEdit != null || onDelete != null))
            Positioned(
              top: 0,
              right: 0,
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      debugPrint('[tools] deleteItem called');
                    onDelete?.call();
                    });
                  }
                },
                itemBuilder: (context) => [
                  if (onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Редагувати'),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Видалити'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
