import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/model/progress_models.dart';
import '../../state/progress_state.dart';
import '../../widgets/activity_heatmap.dart';

/// 📊 Progress screen — streak counter, stats dashboard.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summaryAsync = ref.watch(progressSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Прогресс'),
        centerTitle: true,
      ),
      body: summaryAsync.when(
        data: (summary) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(progressSummaryProvider);
              ref.invalidate(vocabularyProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Streak Card
                  _StreakCard(
                    currentStreak: summary.currentStreak,
                    maxStreak: summary.maxStreak,
                  ),
                  const SizedBox(height: 16),

                  // Spaced-repetition review CTA
                  const _ReviewCta(),
                  const SizedBox(height: 16),

                  // Stats Grid
                  _StatsGrid(summary: summary),
                  const SizedBox(height: 24),

                  // Achievements
                  _AchievementsSection(summary: summary),
                  const SizedBox(height: 24),

                  // Activity heatmap
                  Consumer(
                    builder: (context, ref, _) {
                      final heatmapAsync = ref.watch(activityHeatmapProvider);
                      return heatmapAsync.when(
                        data: (stats) => ActivityHeatmap(stats: stats),
                        loading: () => const SizedBox(
                          height: 100,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Vocabulary Section
                  Text(
                    '📚 Выученные слова',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Consumer(
                    builder: (context, ref, child) {
                      final vocabAsync = ref.watch(vocabularyProvider);
                      return vocabAsync.when(
                        data: (words) {
                          if (words.isEmpty) {
                            return _buildEmptyVocabulary(theme);
                          }

                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: words.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              return _VocabularyCard(word: words[index]);
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, stack) => Center(child: Text('Ошибка: $err')),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Ошибка: $err')),
      ),
    );
  }

  Widget _buildEmptyVocabulary(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.bookmarks_outlined,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Text(
            'Пока нет сохранённых слов',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int currentStreak;
  final int maxStreak;

  const _StreakCard({
    required this.currentStreak,
    required this.maxStreak,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHot = currentStreak > 0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isHot
              ? [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                ]
              : [
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHot ? Icons.local_fire_department : Icons.bolt,
              size: 36,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHot ? 'Ударный режим!' : 'Нет активной серии',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isHot
                        ? theme.colorScheme.onPrimaryContainer
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHot
                      ? '$currentStreak дн. подряд (макс. $maxStreak)'
                      : 'Начните читать сегодня',
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onPrimaryContainer.withValues(
                      alpha: 0.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final ProgressSummary summary;

  const _StatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _StatCard(
          icon: Icons.article,
          label: 'Статей',
          value: summary.totalArticlesRead.toString(),
          color: theme.colorScheme.primary,
        ),
        _StatCard(
          icon: Icons.menu_book,
          label: 'Слов в словаре',
          value: summary.totalWordsSaved.toString(),
          color: theme.colorScheme.secondary,
        ),
        _StatCard(
          icon: Icons.access_time,
          label: 'Минут чтения',
          value: summary.totalReadingMinutes.toString(),
          color: theme.colorScheme.tertiary,
        ),
        _StatCard(
          icon: Icons.emoji_events,
          label: 'Макс. серия',
          value: summary.maxStreak.toString(),
          color: theme.colorScheme.error,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _VocabularyCard extends StatelessWidget {
  final VocabularyWord word;

  const _VocabularyCard({required this.word});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  word.word,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                word.pinyin,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            word.translation,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Call-to-action card that links to [ReviewScreen], showing how many
/// saved words are due today (hidden entirely when nothing is due).
class _ReviewCta extends ConsumerWidget {
  const _ReviewCta();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dueAsync = ref.watch(dueWordsProvider);

    return dueAsync.when(
      data: (due) {
        if (due.isEmpty) return const SizedBox.shrink();
        return InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            await context.push('/progress/review');
            ref.invalidate(dueWordsProvider);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.style, color: theme.colorScheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Повторить ${due.length} слов${_wordSuffix(due.length)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.colorScheme.onSecondaryContainer),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  String _wordSuffix(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return '';
    if ([2, 3, 4].contains(mod10) && ![12, 13, 14].contains(mod100)) return 'а';
    return '';
  }
}

/// Simple, purely-derived achievement badges — no new persisted state,
/// just thresholds over [ProgressSummary].
class _AchievementsSection extends StatelessWidget {
  final ProgressSummary summary;

  const _AchievementsSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final achievements = <({String emoji, String title, bool unlocked})>[
      (emoji: '📖', title: 'Первая статья', unlocked: summary.totalArticlesRead >= 1),
      (emoji: '🔥', title: '7 дней подряд', unlocked: summary.maxStreak >= 7),
      (emoji: '💪', title: '30 дней подряд', unlocked: summary.maxStreak >= 30),
      (emoji: '📚', title: '50 слов', unlocked: summary.totalWordsSaved >= 50),
      (emoji: '🎓', title: '100 слов', unlocked: summary.totalWordsSaved >= 100),
      (emoji: '⏱️', title: 'Час чтения', unlocked: summary.totalReadingMinutes >= 60),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🏆 Достижения',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: achievements.map((a) {
            return Opacity(
              opacity: a.unlocked ? 1.0 : 0.35,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: a.unlocked
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(a.emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(
                      a.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: a.unlocked
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
