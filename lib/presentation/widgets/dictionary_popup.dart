import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/dictionary_models.dart';
import '../../di/di.dart';

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

  String _formatTranslation(String text) {
    if (text.isEmpty) return text;
    
    // ── Pre-clean garbage from raw DB data (HTML/Audio tags leaking in) ──
    String formatted = text;
    
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
    
    // Add structural newlines before typical dictionary enumerations: 1) 2. I. II.
    formatted = formatted.replaceAllMapped(
      RegExp(r'(?<=\s|\n|^)(?=\b([1-9][0-9]*[.)]|I{1,3}\.|IV\.|V\.|VI{0,3}\.)\s)'),
      (match) => '\n\n',
    );
    
    // Visually separate Chinese examples from Russian definitions
    formatted = formatted.replaceAllMapped(
      RegExp(r'([а-яА-ЯёЁa-zA-Z\.?!,;])\s*([\u4E00-\u9FFF\u3400-\u4DBF]+)'),
      (match) => '${match.group(1)}\n\n${match.group(2)}',
    );
    
    // Separate Russian translation from preceding Chinese text/pinyin
    formatted = formatted.replaceAllMapped(
      RegExp(r'([\u4E00-\u9FFF\u3400-\u4DBF]+)\s*([а-яА-ЯёЁA-Z])'),
      (match) => '${match.group(1)}\n\n${match.group(2)}',
    );
    
    // Collapse excessive empty lines
    formatted = formatted.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    return formatted.trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    final formattedTranslation = _formatTranslation(result.translation ?? 'Нет перевода');

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
          const Divider(),
          const SizedBox(height: 16),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Text(
                formattedTranslation,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.6,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                final saveUseCase = ref.read(saveWordUseCaseProvider);
                await saveUseCase.call(result);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Слово сохранено в словарь')),
                  );
                  Navigator.of(context).pop();
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
