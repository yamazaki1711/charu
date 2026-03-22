import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/model/file_models.dart';
import '../../../di/di.dart';
import '../../state/file_state.dart';

/// 📁 Files screen — local file browser and reading history.
class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recentFilesAsync = ref.watch(recentFilesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Файлы'),
        centerTitle: true,
      ),
      body: recentFilesAsync.when(
        data: (files) {
          if (files.isEmpty) {
            return _buildEmptyState(theme);
          }
          return _buildFileList(files, theme);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Text('Ошибка: $error'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openFile,
        icon: const Icon(Icons.folder_open),
        label: const Text('Открыть файл'),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 24),
          Text(
            'Нет открытых файлов',
            style: TextStyle(
              fontSize: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажмите "Открыть файл" чтобы начать чтение',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList(List<LocalFile> files, ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final file = files[index];
        return _FileCard(
          file: file,
          onTap: () => _openFileForReading(file),
          onRemove: () => _removeFile(file),
        );
      },
    );
  }

  Future<void> _openFile() async {
    final openFile = ref.read(openFileUseCaseProvider);
    final file = await openFile();

    if (file != null && mounted) {
      _openFileForReading(file);
    }
  }

  void _openFileForReading(LocalFile file) {
    context.push('/files/reader', extra: {'path': file.path, 'name': file.name});
  }

  Future<void> _removeFile(LocalFile file) async {
    final repo = ref.read(fileRepositoryProvider);
    await repo.removeFileFromHistory(file.path);

    if (mounted) {
      ref.invalidate(recentFilesProvider);
    }
  }
}

class _FileCard extends StatelessWidget {
  final LocalFile file;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FileCard({
    required this.file,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _FileTypeIcon(type: file.type),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatLastOpened(file.lastOpened),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: onRemove,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ],
            ),
            if (file.progressPercent > 0) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: file.progressPercent / 100,
                backgroundColor: theme.colorScheme.outline.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${file.progressPercent.toStringAsFixed(1)}% прочитано',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatLastOpened(DateTime? date) {
    if (date == null) return 'Не открыт';
    
    final now = DateTime.now();
    final diff = now.difference(date);
    
    if (diff.inMinutes < 1) return 'Только что';
    if (diff.inHours < 1) return '${diff.inMinutes} мин. назад';
    if (diff.inDays < 1) return '${diff.inHours} ч. назад';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    
    return '${date.day}.${date.month}.${date.year}';
  }
}

class _FileTypeIcon extends StatelessWidget {
  final FileFormat type;

  const _FileTypeIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    IconData icon;
    switch (type) {
      case FileFormat.txt:
        icon = Icons.description;
        break;
      case FileFormat.html:
        icon = Icons.language;
        break;
      case FileFormat.epub:
        icon = Icons.menu_book;
        break;
      case FileFormat.unknown:
        icon = Icons.insert_drive_file;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }
}
