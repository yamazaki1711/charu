import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/di.dart';
import '../../widgets/segmented_text_display.dart';

/// 📖 Reader screen for local files (TXT, HTML, EPUB)
class ReaderScreen extends ConsumerStatefulWidget {
  final String filePath;
  final String fileName;

  /// When set, the reader shows this text directly instead of reading
  /// [filePath] from disk — used for the bundled demo story (no real file,
  /// so position/bookmark persistence is skipped).
  final String? demoText;

  const ReaderScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    this.demoText,
  });

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  String? _content;
  bool _isLoading = true;
  String? _error;

  final ScrollController _scrollController = ScrollController();
  Timer? _sessionTick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Add ~1 reading minute every 60 seconds of active reading, and persist
    // the scroll position so the file resumes where the user left off.
    _sessionTick = Timer.periodic(const Duration(seconds: 60), (_) {
      ref.read(addReadingMinutesUseCaseProvider).call(minutes: 1);
      ref.read(updateStreakUseCaseProvider).call();
      _savePosition();
    });
    _loadFile();
  }

  @override
  void dispose() {
    _sessionTick?.cancel();
    _savePosition();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Pause/resume the reading-minute ticker with the app lifecycle.
    if (state == AppLifecycleState.resumed) {
      _sessionTick ??= Timer.periodic(const Duration(seconds: 60), (_) {
        ref.read(addReadingMinutesUseCaseProvider).call(minutes: 1);
        ref.read(updateStreakUseCaseProvider).call();
        _savePosition();
      });
    } else {
      _sessionTick?.cancel();
      _sessionTick = null;
      _savePosition();
    }
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
    });

    if (widget.demoText != null) {
      setState(() {
        _content = widget.demoText;
        _isLoading = false;
      });
      return;
    }

    try {
      final readFile = ref.read(readFileContentUseCaseProvider);
      final content = await readFile(widget.filePath);
      final history =
          await ref.read(getFileByPathUseCaseProvider).call(widget.filePath);

      setState(() {
        _content = content;
        _isLoading = false;
      });

      // Resume at the last saved position (stored as a character offset;
      // translated back to a scroll fraction once the list is laid out).
      final lastPosition = history?.lastPosition ?? 0;
      if (lastPosition > 0 && content.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients) return;
          final maxExtent = _scrollController.position.maxScrollExtent;
          if (maxExtent <= 0) return;
          final fraction = (lastPosition / content.length).clamp(0.0, 1.0);
          _scrollController.jumpTo(maxExtent * fraction);
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Converts the current scroll fraction to a character offset and
  /// persists it (position is stored in characters, not pixels, so it
  /// stays meaningful across font-size and screen-size changes).
  void _savePosition() {
    if (widget.demoText != null) return; // no real file to persist against
    final content = _content;
    if (content == null || content.isEmpty) return;
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final fraction = maxExtent > 0
        ? (_scrollController.offset / maxExtent).clamp(0.0, 1.0)
        : 0.0;
    final charPosition = (fraction * content.length).round();
    ref
        .read(saveReadingPositionUseCaseProvider)
        .call(widget.filePath, charPosition);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.fileName,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: _addBookmark,
            tooltip: 'Закладка',
          ),
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки файла',
              style: TextStyle(
                fontSize: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadFile,
              icon: const Icon(Icons.refresh),
              label: const Text('Попробовать снова'),
            ),
          ],
        ),
      );
    }

    if (_content == null || _content!.isEmpty) {
      return Center(
        child: Text(
          'Файл пуст',
          style: TextStyle(
            fontSize: 18,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    // Constrain content width on wide screens (tablet) so Chinese text
    // lines don't stretch across the full screen. Wrapped in a scroll view
    // since SegmentedTextDisplay renders a single unbounded RichText.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: SegmentedTextDisplay(text: _content!),
        ),
      ),
    );
  }

  Future<void> _addBookmark() async {
    if (widget.demoText != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Закладки недоступны в демо-тексте')),
        );
      }
      return;
    }
    final content = _content;
    final position = content != null && content.isNotEmpty
        ? (() {
            final maxExtent = _scrollController.hasClients
                ? _scrollController.position.maxScrollExtent
                : 0.0;
            final fraction = maxExtent > 0
                ? (_scrollController.offset / maxExtent).clamp(0.0, 1.0)
                : 0.0;
            return (fraction * content.length).round();
          })()
        : 0;

    try {
      await ref
          .read(saveBookmarkUseCaseProvider)
          .call(widget.filePath, position);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Закладка сохранена')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения закладки: $e')),
        );
      }
    }
  }
}
