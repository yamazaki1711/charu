import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/file_models.dart';
import '../../di/di.dart';

/// Notifier for recent files state
class RecentFilesNotifier extends AsyncNotifier<List<LocalFile>> {
  @override
  Future<List<LocalFile>> build() async {
    return _fetch();
  }

  Future<List<LocalFile>> _fetch() async {
    final useCase = ref.read(getRecentFilesUseCaseProvider);
    return await useCase();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }
}

/// Provider for recent files
final recentFilesProvider = AsyncNotifierProvider<RecentFilesNotifier, List<LocalFile>>(
  RecentFilesNotifier.new,
);
