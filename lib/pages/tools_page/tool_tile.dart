import 'package:flutter/material.dart';
import '../../../mixins/loading_state_mixin.dart';
import '../../../widgets/loading_indicator.dart';

class ToolTile extends StatefulWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  final bool isAdmin;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isFolder;
  final String? description;

  const ToolTile({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.isAdmin = false,
    this.onEdit,
    this.onDelete,
    this.isFolder = false,
    this.description,
  });

  @override
  State<ToolTile> createState() => _ToolTileState();
}

class _ToolTileState extends State<ToolTile> with LoadingStateMixin {
  bool _isHovered = false;

  Future<void> _handleTap() async {
    if (isLoading('tap')) return;
    
    try {
      await withLoading('tap', () async {
        // Додаємо невелику затримку для показу індикатора
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
    if (isLoading('edit')) return;
    
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
    if (isLoading('delete')) return;
    
    // Показуємо підтвердження
    final confirmed = await _showDeleteConfirmation();
    if (!confirmed) return;
    
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
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Підтвердження'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Видалити ${widget.isFolder ? 'папку' : 'інструмент'}:'),
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
            if (widget.isFolder) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, 
                         size: 16, 
                         color: Colors.orange[700]),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Всі інструменти в цій папці також будуть видалені',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
    ) ?? false;
  }

  Color _getIconColor(BuildContext context) {
    final theme = Theme.of(context);
    
    if (isLoading('tap')) {
      return Colors.grey.withOpacity(0.5);
    } else if (widget.isFolder) {
      return Colors.amber[700] ?? Colors.amber;
    } else {
      return _isHovered 
          ? theme.colorScheme.primary
          : theme.colorScheme.primary.withOpacity(0.7);
    }
  }

  Widget _buildLoadingOverlay() {
    if (!isLoading('tap')) return const SizedBox.shrink();
    
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: LoadingIndicator(
            message: 'Завантаження...',
            size: 32,
          ),
        ),
      ),
    );
  }

  Widget _buildAdminMenu() {
    if (!widget.isAdmin || (widget.onEdit == null && widget.onDelete == null)) {
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
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
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
                icon: const Icon(
                  Icons.more_vert,
                  size: 16,
                ),
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
                  if (widget.onEdit != null)
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit, size: 16),
                        title: Text('Редагувати'),
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    ),
                  if (widget.onDelete != null)
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete, 
                                    size: 16, 
                                    color: Colors.red),
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
    final isAnyLoading = isLoading('tap') || isLoading('edit') || isLoading('delete');
    
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
              // Основний контент
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
                          // Іконка
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _getIconColor(context).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 24,
                              color: _getIconColor(context),
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // Назва
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
                          
                          // Опис (якщо є і є місце)
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
                          
                          // Індикатор типу (компактний)
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: widget.isFolder 
                                  ? Colors.amber.withOpacity(0.15)
                                  : Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  widget.isFolder ? Icons.folder : Icons.build,
                                  size: 10,
                                  color: widget.isFolder 
                                      ? Colors.amber[700]
                                      : Colors.blue[700],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.isFolder ? 'папка' : 'файл',
                                  style: TextStyle(
                                    fontSize: 8,
                                    color: widget.isFolder 
                                        ? Colors.amber[700]
                                        : Colors.blue[700],
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
              
              // Оверлей завантаження
              _buildLoadingOverlay(),
              
              // Меню адміністратора
              _buildAdminMenu(),
            ],
          ),
        ),
      ),
    );
  }
}