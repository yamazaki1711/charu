import 'package:flutter/material.dart';

import '../../domain/model/progress_models.dart';

/// GitHub-style activity heatmap: one column per week, one cell per day,
/// shaded by how much reading happened that day (articles + words + minutes).
class ActivityHeatmap extends StatelessWidget {
  final List<DailyStats> stats;

  const ActivityHeatmap({super.key, required this.stats});

  int _activityScore(DailyStats s) =>
      s.articlesRead * 3 + s.wordsEncountered + s.wordsSaved * 2 + (s.readingMinutes ~/ 5);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const days = 70;
    final today = DateTime.now();
    final startDate = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: days - 1));

    final byDate = <String, DailyStats>{
      for (final s in stats) s.date: s,
    };

    String fmt(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final scores = List<int>.generate(days, (i) {
      final d = startDate.add(Duration(days: i));
      final s = byDate[fmt(d)];
      return s == null ? 0 : _activityScore(s);
    });

    final maxScore = scores.fold<int>(1, (a, b) => b > a ? b : a);

    Color cellColor(int score) {
      if (score <= 0) {
        return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
      }
      final intensity = (score / maxScore).clamp(0.15, 1.0);
      return theme.colorScheme.primary.withValues(alpha: intensity);
    }

    // Pad the front so the first column starts on a Monday-aligned grid.
    final leadingEmpty = startDate.weekday - 1; // Mon=1..Sun=7 -> 0..6
    final cells = <int?>[
      ...List.filled(leadingEmpty, null),
      ...scores,
    ];
    final weeks = (cells.length / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '🔥 Активность',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true,
          child: Row(
            children: List.generate(weeks, (week) {
              return Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Column(
                  children: List.generate(7, (day) {
                    final idx = week * 7 + day;
                    final score = idx < cells.length ? cells[idx] : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: score == null ? Colors.transparent : cellColor(score),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Последние $days дней',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
