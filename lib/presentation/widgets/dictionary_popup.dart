import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui' as ui;

import '../../domain/model/dictionary_models.dart';
import '../../di/di.dart';

/// Dictionary Popup Modal with Liquid Glass background blur,
/// but a solid opaque card for CJK text readability.
class DictionaryPopup extends ConsumerWidget {
  final DictionaryResult result;

  const DictionaryPopup({
    super.key,
    required this.result,
  });

  /// Helper to show this modal globally.
  static Future<void> show(BuildContext context, DictionaryResult result) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5), // Semi-transparent overlay
      builder: (ctx) => DictionaryPopup(result: result),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surface;
    
    // Liquid Glass outer container (Blur applied behind the dialog)
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30), // From Concept v4
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          // SOLID INNER CARD for CJK Readability (Rule 10.3)
          decoration: BoxDecoration(
            color: cardColor, // Opaque
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2), // Light border 
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon + Chinese Word
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (result.icon != null) ...[
                    Text(result.icon!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      result.chineseWord,
                      style: const TextStyle(
                        fontSize: 36, // Large clear font for CJK
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Pinyin
              Text(
                result.pinyin,
                style: TextStyle(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Translation
              Text(
                result.translation ?? 'Нет перевода',
                style: const TextStyle(
                  fontSize: 18, // Clean body font
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    icon: const Icon(Icons.close),
                    label: const Text('Закрыть'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Call SaveUseCase
                      final saveUseCase = ref.read(saveWordUseCaseProvider);
                      await saveUseCase.call(result);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Слово сохранено 💾')),
                        );
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('Сохранить'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.surface,
                      elevation: 0,
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
