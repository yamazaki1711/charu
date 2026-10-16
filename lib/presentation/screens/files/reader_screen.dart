import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../../../di/di.dart';
import '../../state/app_settings_state.dart' show readerMarginProvider;
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

  /// Current scroll position as a 0..1 fraction, kept in sync with the
  /// scroll controller for the position slider's thumb + "N%" label.
  double _scrollFraction = 0.0;

  /// Non-null while the user has overridden the screen brightness for this
  /// reading session (reset on dispose — never a permanent device change).
  double? _brightnessOverride;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    // Add ~1 reading minute every 60 seconds of active reading, and persist
    // the scroll position so the file resumes where the user left off.
    _sessionTick = Timer.periodic(const Duration(seconds: 60), (_) {
      ref.read(addReadingMinutesUseCaseProvider).call(minutes: 1);
      ref.read(updateStreakUseCaseProvider).call();
      _savePosition();
    });
    _loadFile();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final fraction =
        maxExtent > 0 ? (_scrollController.offset / maxExtent).clamp(0.0, 1.0) : 0.0;
    if ((fraction - _scrollFraction).abs() > 0.001) {
      setState(() => _scrollFraction = fraction);
    }
  }

  @override
  void dispose() {
    _sessionTick?.cancel();
    _savePosition();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (_brightnessOverride != null) {
      // Best-effort: never block screen teardown on the platform channel.
      ScreenBrightness().resetApplicationScreenBrightness().catchError((_) {});
    }
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
            icon: const Icon(Icons.brightness_6_outlined),
            onPressed: _showBrightnessSlider,
            tooltip: 'Яркость',
          ),
          IconButton(
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: widget.demoText != null ? null : _showBookmarksList,
            tooltip: 'Закладки',
          ),
          IconButton(
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _addBookmark,
            tooltip: 'Добавить закладку здесь',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(theme)),
          if (!_isLoading && _error == null && _content != null && _content!.isNotEmpty)
            _buildPositionSlider(theme),
        ],
      ),
    );
  }

  /// Position slider + "N%" label — lets you jump anywhere in a long text
  /// instead of scrolling blindly (a 100k-character book is a lot of
  /// flicking). Dragging computes the matching scroll offset directly, same
  /// scroll-fraction math as [_savePosition]/[_loadFile]'s resume logic.
  Widget _buildPositionSlider(ThemeData theme) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                ),
                child: Slider(
                  value: _scrollFraction.clamp(0.0, 1.0),
                  onChanged: (value) {
                    if (!_scrollController.hasClients) return;
                    final maxExtent = _scrollController.position.maxScrollExtent;
                    setState(() => _scrollFraction = value);
                    _scrollController.jumpTo(maxExtent * value);
                  },
                  onChangeEnd: (_) => _savePosition(),
                ),
              ),
            ),
            SizedBox(
              width: 42,
              child: Text(
                '${(_scrollFraction * 100).round()}%',
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showBrightnessSlider() async {
    double current;
    try {
      current = _brightnessOverride ?? await ScreenBrightness().application;
    } catch (_) {
      current = 0.5;
    }
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Row(
                children: [
                  const Icon(Icons.brightness_low),
                  Expanded(
                    child: Slider(
                      value: current.clamp(0.01, 1.0),
                      min: 0.01,
                      max: 1.0,
                      onChanged: (value) async {
                        setSheetState(() => current = value);
                        _brightnessOverride = value;
                        try {
                          await ScreenBrightness().setApplicationScreenBrightness(value);
                        } catch (_) {
                          // Unsupported on this platform/device — ignore.
                        }
                      },
                    ),
                  ),
                  const Icon(Icons.brightness_high),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showBookmarksList() async {
    final bookmarks =
        await ref.read(getBookmarksUseCaseProvider).call(widget.filePath);
    if (!mounted) return;

    final content = _content;
    final target = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollController) {
            if (bookmarks.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Пока нет закладок в этом файле'),
                ),
              );
            }
            return ListView.separated(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: bookmarks.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (ctx, i) {
                final b = bookmarks[i];
                final percent = content != null && content.isNotEmpty
                    ? (b.position / content.length * 100).clamp(0, 100).round()
                    : 0;
                final preview = content != null && b.position < content.length
                    ? content
                        .substring(
                          b.position,
                          (b.position + 40).clamp(0, content.length),
                        )
                        .replaceAll('\n', ' ')
                    : '';
                return ListTile(
                  leading: const Icon(Icons.bookmark),
                  title: Text('$percent% · $preview…', maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_formatDate(b.createdAt)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref.read(removeBookmarkUseCaseProvider).call(b.id);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      _showBookmarksList();
                    },
                  ),
                  onTap: () => Navigator.of(ctx).pop(b.position),
                );
              },
            );
          },
        );
      },
    );

    if (target != null && content != null && content.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scrollController.hasClients) return;
        final maxExtent = _scrollController.position.maxScrollExtent;
        if (maxExtent <= 0) return;
        final fraction = (target / content.length).clamp(0.0, 1.0);
        _scrollController.jumpTo(maxExtent * fraction);
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
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
    final margin = ref.watch(readerMarginProvider);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: margin, vertical: 16),
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
