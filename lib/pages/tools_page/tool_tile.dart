import 'package:flutter/material.dart';

import '../../mixins/loading_state_mixin.dart';
import '../../widgets/loading_indicator.dart';

class ToolTile extends StatefulWidget {
  const ToolTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isAdmin = false,
    this.canEdit = false,
    this.canDelete = false,
    this.onEdit,
    this.onDelete,
    this.itemType = 'embedded',
    this.description,
    this.isFileLoading = false,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isAdmin;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String itemType;
  final String? description;
  final bool isFileLoading;

  @override
  State<ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<ToolTile> with LoadingStateMixin {
  bool _isHovered = false;

  Future<void> _handleTap() async {
    if (isLoading('tap')) {
      return;
    }

    try {
      await withLoading('tap', () async {
        await Future.delayed(const Duration(milliseconds: 200));
        widget.onTap();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка відкриття: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleEdit() async {
    if (isLoading('edit')) {
      return;
    }

    try {
      await withLoading('edit', () async {
        widget.onEdit?.call();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка редагування: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    if (isLoading('delete')) {
      return;
    }

    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) {
      return;
    }

    try {
      await withLoading('delete', () async {
        widget.onDelete?.call();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Помилка видалення: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 8),
                const Text('Підтвердження'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Видалити інструмент:'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(widget.icon, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.title,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Скасувати'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Видалити'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildLoadingOverlay() {
    final isAnyLoading =
        isLoading('tap') || isLoading('edit') || isLoading('delete');
    if (!widget.isFileLoading && !isAnyLoading) {
      return const SizedBox.shrink();
    }

    String message = widget.isFileLoading ? 'Завантаження...' : 'Обробка...';
    if (isLoading('tap')) {
      message = 'Відкриття...';
    } else if (isLoading('edit')) {
      message = 'Редагування...';
    } else if (isLoading('delete')) {
      message = 'Видалення...';
    }

    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: LoadingIndicator(message: message, size: 32)),
      ),
    );
  }

  Widget _buildPopupMenu() {
    final hasAdminActions =
        widget.isAdmin &&
        ((widget.canEdit && widget.onEdit != null) ||
            (widget.canDelete && widget.onDelete != null));
    if (!hasAdminActions) {
      return const SizedBox.shrink();
    }

    final isAnyLoading = isLoading('edit') || isLoading('delete');

    return Positioned(
      top: 4,
      right: 4,
      child: isAnyLoading
          ? Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const LoadingIndicator(size: 12),
            )
          : Material(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              elevation: 1,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                iconSize: 16,
                icon: const Icon(Icons.more_vert, size: 16),
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      await _handleEdit();
                      break;
                    case 'delete':
                      await _handleDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (widget.canEdit && widget.onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, size: 16),
                        title: Text('Редагувати'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  if (widget.canDelete && widget.onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(
                          Icons.delete,
                          size: 16,
                          color: Colors.red,
                        ),
                        title: Text('Видалити'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnyLoading =
        isLoading('tap') || isLoading('edit') || isLoading('delete');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: _isHovered && !isAnyLoading
            ? (Matrix4.identity()..scale(1.02))
            : Matrix4.identity(),
        child: Card(
          elevation: _isHovered && !isAnyLoading ? 4 : 1,
          shadowColor: theme.colorScheme.primary.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: _isHovered && !isAnyLoading
                ? BorderSide(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1.5,
                  )
                : BorderSide.none,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: isAnyLoading ? null : _handleTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 24,
                              color: Colors.purple[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Text(
                              widget.title,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: isAnyLoading ? Colors.grey : null,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (widget.description != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.description!,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.widgets,
                                  size: 10,
                                  color: Colors.purple[700],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'вбудований',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: Colors.purple[700],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildLoadingOverlay(),
              _buildPopupMenu(),
            ],
          ),
        ),
      ),
    );
  }
}
