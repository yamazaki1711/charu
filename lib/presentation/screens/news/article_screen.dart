import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/di.dart';
import '../../state/news_state.dart';
import '../../widgets/segmented_text_display.dart';

class ArticleScreen extends ConsumerStatefulWidget {
  final String articleId;

  const ArticleScreen({super.key, required this.articleId});

  @override
  ConsumerState<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends ConsumerState<ArticleScreen> {
  @override
  void initState() {
    super.initState();
    // Statistics: count the article as read and refresh the streak.
    ref
        .read(incrementArticlesReadUseCaseProvider)
        .call(count: 1);
    ref.read(updateStreakUseCaseProvider).call();
  }

  @override
  Widget build(BuildContext context) {
    final articleState = ref.watch(articleContentProvider(widget.articleId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Чтение текста'), centerTitle: true),
      body: articleState.when(
        data: (article) {
          // Constrain content width on wide screens (tablet).
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.source,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          article.source,
                          style: TextStyle(
                            fontSize: 16,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // The Magic Chinese Segmented Render:
                    SegmentedTextDisplay(
                      text: article.fullContent ?? 'Тело статьи не загрузилось.',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) =>
            Center(child: Text('Ошибка загрузки текста:\n$err')),
      ),
    );
  }
}
