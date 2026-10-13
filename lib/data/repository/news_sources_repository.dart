import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/database_helper.dart';

/// Строка из таблицы news_sources.
class NewsSourceEntity {
  final int id;
  final String name;
  final String url;
  final String type;
  final bool enabled;

  const NewsSourceEntity({
    required this.id,
    required this.name,
    required this.url,
    required this.type,
    required this.enabled,
  });

  factory NewsSourceEntity.fromMap(Map<String, Object?> map) {
    return NewsSourceEntity(
      id: map['id'] as int,
      name: map['name'] as String,
      url: map['url'] as String,
      type: (map['type'] as String?) ?? 'rss',
      enabled: (map['enabled'] as int? ?? 1) == 1,
    );
  }
}

/// Хранилище источников новостей поверх таблицы news_sources
/// в read-only словаре (assets/db/charu_bkrs.db).
///
/// Table news_sources exists in the read-only dictionary DB, so
/// "toggling a source" is in-memory only for the current session.
/// This is intentional: the DB asset is immutable.
class NewsSourcesRepository {
  List<NewsSourceEntity>? _sources;

  /// Load all sources from DB (cached after first load).
  Future<List<NewsSourceEntity>> getSources() async {
    if (_sources != null) return _sources!;
    if (kIsWeb) {
      _sources = const [];
      return _sources!;
    }
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('news_sources');
    _sources = rows.map(NewsSourceEntity.fromMap).toList();
    return _sources!;
  }

  /// Sources with enabled = 1 (in-memory state).
  Future<List<NewsSourceEntity>> getEnabledSources() async {
    final all = await getSources();
    return all.where((s) => s.enabled).toList();
  }

  /// Toggle a source's enabled flag (in-memory, session-scoped).
  Future<void> setEnabled(int id, bool enabled) async {
    final all = await getSources();
    _sources = all.map((s) {
      if (s.id != id) return s;
      return NewsSourceEntity(
        id: s.id,
        name: s.name,
        url: s.url,
        type: s.type,
        enabled: enabled,
      );
    }).toList();
  }
}

/// Singleton provider for news sources.
final newsSourcesRepositoryProvider = Provider<NewsSourcesRepository>((ref) {
  return NewsSourcesRepository();
});

/// Live list of news sources (rebuilds on toggle).
final newsSourcesProvider =
    StateNotifierProvider<NewsSourcesNotifier, List<NewsSourceEntity>>(
  (ref) => NewsSourcesNotifier(ref),
);

class NewsSourcesNotifier extends StateNotifier<List<NewsSourceEntity>> {
  final Ref _ref;

  NewsSourcesNotifier(this._ref) : super(const []);

  /// Load sources from DB and refresh the list.
  Future<void> load() async {
    final repo = _ref.read(newsSourcesRepositoryProvider);
    state = await repo.getSources();
  }

  /// Toggle a source and immediately reload the feed.
  Future<void> toggle(int id, bool enabled) async {
    final repo = _ref.read(newsSourcesRepositoryProvider);
    await repo.setEnabled(id, enabled);
    state = await repo.getSources();
  }
}
