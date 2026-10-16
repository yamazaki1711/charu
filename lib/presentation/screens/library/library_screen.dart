import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../di/di.dart';
import '../../../domain/model/library_models.dart';
import '../../state/app_settings_state.dart';
import '../../state/library_state.dart';

/// 📚 Library screen — curated public-domain Chinese books from Wikisource.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final Set<String> _downloadingIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalogAsync = ref.watch(libraryCatalogProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Библиотека'),
        centerTitle: true,
      ),
      body: catalogAsync.when(
        data: (books) => _buildList(books, theme),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Ошибка: $error')),
      ),
    );
  }

  Widget _buildList(List<LibraryBook> books, ThemeData theme) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: books.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final book = books[index];
        return _BookCard(
          book: book,
          isDownloading: _downloadingIds.contains(book.id),
          onDownload: () => _download(book),
          onRead: () => _read(book),
          onDelete: () => _delete(book),
        );
      },
    );
  }

  Future<void> _download(LibraryBook book) async {
    setState(() => _downloadingIds.add(book.id));
    try {
      final repo = ref.read(libraryRepositoryProvider);
      final keepTraditional = ref.read(libraryKeepTraditionalProvider);
      await repo.downloadBook(book, convertToSimplified: !keepTraditional);
      ref.invalidate(libraryCatalogProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось скачать: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingIds.remove(book.id));
    }
  }

  void _read(LibraryBook book) {
    context.push('/files/reader', extra: {
      'path': book.filePath,
      'name': book.titleDisplay,
    });
  }

  Future<void> _delete(LibraryBook book) async {
    final repo = ref.read(libraryRepositoryProvider);
    await repo.deleteBook(book);
    ref.invalidate(libraryCatalogProvider);
  }
}

class _BookCard extends StatelessWidget {
  final LibraryBook book;
  final bool isDownloading;
  final VoidCallback onDownload;
  final VoidCallback onRead;
  final VoidCallback onDelete;

  const _BookCard({
    required this.book,
    required this.isDownloading,
    required this.onDownload,
    required this.onRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: book.isDownloaded ? onRead : (isDownloading ? null : onDownload),
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.menu_book,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.titleDisplay,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${book.author} · ${book.genre} · ${book.level}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _trailing(theme),
          ],
        ),
      ),
    );
  }

  Widget _trailing(ThemeData theme) {
    if (isDownloading) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (book.isDownloaded) {
      return IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Удалить',
        onPressed: onDelete,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
      );
    }
    return IconButton(
      icon: const Icon(Icons.download),
      tooltip: 'Скачать',
      onPressed: onDownload,
      color: theme.colorScheme.primary,
    );
  }
}
