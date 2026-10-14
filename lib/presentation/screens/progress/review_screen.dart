import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/di.dart';
import '../../../domain/model/progress_models.dart';

/// Карточки-повторения сохранённых слов (упрощённый интервальный алгоритм,
/// см. [ProgressRepositoryImpl._reviewIntervalDays]).
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  List<VocabularyWord>? _queue;
  int _index = 0;
  bool _revealed = false;
  int _rememberedCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final due = await ref.read(getWordsDueForReviewUseCaseProvider).call();
    if (!mounted) return;
    setState(() {
      _queue = due;
      _index = 0;
      _revealed = false;
      _rememberedCount = 0;
    });
  }

  Future<void> _grade(bool remembered) async {
    final word = _queue![_index];
    if (remembered) _rememberedCount++;
    try {
      await ref
          .read(markWordReviewedUseCaseProvider)
          .call(word.id, remembered: remembered);
    } catch (_) {
      // Best-effort — the card still advances even if the write failed.
    }
    if (!mounted) return;
    setState(() {
      _index++;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final queue = _queue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Повторение слов'),
        centerTitle: true,
      ),
      body: queue == null
          ? const Center(child: CircularProgressIndicator())
          : queue.isEmpty
              ? _buildEmpty(theme)
              : _index >= queue.length
                  ? _buildDone(theme, queue.length)
                  : _buildCard(theme, queue[_index]),
    );
  }

  Widget _buildEmpty(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Повторять пока нечего',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Сохраняйте слова при чтении — они появятся здесь по расписанию.',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDone(ThemeData theme, int total) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🎉', style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text(
              'Готово! $_rememberedCount из $total',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('К прогрессу'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(ThemeData theme, VocabularyWord word) {
    final queueLen = _queue!.length;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          LinearProgressIndicator(value: _index / queueLen),
          const SizedBox(height: 8),
          Text(
            '${_index + 1} / $queueLen',
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _revealed = true),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                // A long dictionary entry (many senses/examples) must never
                // overflow past this card's bounds — that previously let
                // the card's own text bleed over the "Не помню"/"Помню"
                // buttons below it. Scrolling inside a card this tall is a
                // bit unusual, but it's the only way to guarantee the
                // buttons stay put; LayoutBuilder + a min-height
                // ConstrainedBox keeps short entries vertically centered
                // like before, while long ones simply scroll.
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - 96, // minus vertical padding
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  word.word,
                                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                if (!_revealed) ...[
                                  const SizedBox(height: 24),
                                  Text(
                                    'Нажмите, чтобы открыть перевод',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    word.pinyin,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontStyle: FontStyle.italic,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 12),
                                  Text(
                                    word.translation,
                                    style: const TextStyle(fontSize: 18),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_revealed)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _grade(false),
                    icon: const Icon(Icons.close),
                    label: const Text('Не помню'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                      side: BorderSide(color: theme.colorScheme.error),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _grade(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Помню'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => setState(() => _revealed = true),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Показать перевод'),
              ),
            ),
        ],
      ),
    );
  }
}
