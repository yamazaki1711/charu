import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/model/dictionary_models.dart';
import '../../di/di.dart';
import '../state/progress_state.dart' show savedWordsSetProvider;
import 'pinyin_helper.dart';

class DictionaryPopup extends ConsumerWidget {
  final DictionaryResult result;

  const DictionaryPopup({super.key, required this.result});

  static Future<void> show(BuildContext context, DictionaryResult result) {
    // We need to get the ProviderContainer from the current context
    // so the bottom sheet can access Riverpod providers
    final container = ProviderScope.containerOf(context);
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => UncontrolledProviderScope(
        container: container,
        child: DictionaryPopup(result: result),
      ),
    );
  }

  /// Formats a single translation line.
  String _formatLine(String line) {
    if (line.isEmpty) return line;

    // ── Pre-clean garbage from raw DB data (HTML/Audio tags leaking in) ──
    String formatted = line;

    // Remove lines/fragments about audio/browser support
    formatted = formatted.replaceAll(RegExp(r'您的浏览器不支持\s*audio?'), '');
    formatted = formatted.replaceAll(RegExp(r'ваш браузер не поддерживает тег\s*audio?'), '');
    formatted = formatted.replaceAll(RegExp(r'Your browser does not support\s*(the\s*)?audio\s*(element|tag)?\.?', caseSensitive: false), '');
    // Remove "mp3标签修改器" and similar exact phrases
    formatted = formatted.replaceAll('mp3标签修改器', '');
    formatted = formatted.replaceAll('редактор mp3 тегов', '');

    // Remove standalone mp3/audio file references or fragments
    formatted = formatted.replaceAll(RegExp(r'https?://[^\s]+\.(mp3|ogg)'), '');
    formatted = formatted.replaceAll(RegExp(r'\bmp3\b', caseSensitive: false), '');

    // Clean up excessive horizontal spaces but preserve intentional newlines
    formatted = formatted.replaceAll(RegExp(r'[ \t]+'), ' ');

    return formatted.trim();
  }

  /// Builds the body widget for the translation area.
  ///
  /// For online BKRS results with pinyin-annotated examples, each Chinese
  /// example is shown with its pinyin (grey, smaller) above the Russian
  /// translation. For offline results, the raw translation text is rendered
  /// as-is (already formatted by the DB).
  Widget _buildTranslationBody(BuildContext context, String translation, List<PinyinExample> examples) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final pinyinStyle = TextStyle(
      fontSize: 14,
      color: onSurface.withValues(alpha: 0.5),
      fontStyle: FontStyle.italic,
      height: 1.2,
    );

    // If we have pinyin-annotated examples (online BKRS), render them
    // as structured cards with pinyin above each Chinese example.
    if (examples.isNotEmpty) {
      final children = <Widget>[];
      for (final ex in examples) {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pinyin (grey, smaller)
              if (ex.pinyin != null && ex.pinyin!.isNotEmpty)
                Text(ex.pinyin!, style: pinyinStyle),
              // Chinese example
              Text(
                ex.chinese,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    // Fallback: render the raw translation text (offline BKRS, toponyms, etc.)
    // Split on newlines to allow per-line pinyin annotation if needed.
    final lines = translation.split('\n');
    final children = <Widget>[];
    for (final rawLine in lines) {
      final line = _formatLine(rawLine);
      if (line.isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }
      // Check if this line starts with a Chinese example (followed by Russian).
      // If so, show pinyin above it.
      final chineseMatch =
          RegExp(r'^([\u4E00-\u9FFF\u3400-\u4DBF]+)(\s+([а-яА-ЯёЁa-zA-Z].*)|$)').firstMatch(line);
      if (chineseMatch != null) {
        final chinese = chineseMatch.group(1)!.trim();
        final rest = (chineseMatch.group(3) ?? '').trim();
        // Generate pinyin for the Chinese part.
        final pinyin = PinyinHelper.getPinyin(chinese);
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pinyin, style: pinyinStyle),
              Text(
                chinese,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.4),
              ),
              if (rest.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  rest,
                  style: TextStyle(
                    fontSize: 16,
                    color: onSurface.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ));
      } else {
        // Plain line (no Chinese example at the start).
        children.add(Text(
          line,
          style: TextStyle(
            fontSize: 18,
            height: 1.6,
            color: onSurface,
          ),
        ));
        children.add(const SizedBox(height: 4));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final rawTranslation = result.translation ?? 'Нет перевода';

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle for bottom sheet
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (result.icon != null) ...[
                Text(result.icon!, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  result.chineseWord,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            result.pinyin,
            style: TextStyle(
              fontSize: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ActionIcon(
                icon: Icons.copy_outlined,
                tooltip: 'Копировать',
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: result.chineseWord));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Скопировано')),
                    );
                  }
                },
              ),
              const SizedBox(width: 8),
              _ActionIcon(
                icon: Icons.share_outlined,
                tooltip: 'Поделиться',
                onTap: () {
                  final text = rawTranslation == 'Нет перевода'
                      ? '${result.chineseWord} (${result.pinyin})'
                      : '${result.chineseWord} (${result.pinyin}) — $rawTranslation';
                  SharePlus.instance.share(ShareParams(text: text));
                },
              ),
              const SizedBox(width: 8),
              _ActionIcon(
                icon: Icons.open_in_new,
                tooltip: 'Искать на bkrs.info',
                onTap: () => launchUrl(
                  Uri.parse(
                    'https://bkrs.info/slovo.php?ch=${Uri.encodeComponent(result.chineseWord)}',
                  ),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildTranslationBody(context, rawTranslation, result.examples),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                try {
                  final saveUseCase = ref.read(saveWordUseCaseProvider);
                  await saveUseCase.call(result);
                  // Statistics: count the saved word and refresh the streak.
                  // Errors from the progress repository are rethrown and
                  // surfaced here so the user is informed (task #5).
                  await ref
                      .read(incrementWordsSavedUseCaseProvider)
                      .call(count: 1);
                  await ref.read(updateStreakUseCaseProvider).call();
                  ref.invalidate(savedWordsSetProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Слово сохранено в словарь')),
                    );
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Ошибка сохранения: $e'),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.bookmark_add),
              label: const Text(
                'Сохранить для повторения',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                foregroundColor: theme.colorScheme.onPrimaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.8),
      ),
    );
  }
}
