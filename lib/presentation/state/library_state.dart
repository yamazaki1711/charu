import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../di/di.dart';
import '../../domain/model/library_models.dart';

/// Catalog merged with download status. Invalidate after
/// download/delete to refresh.
final libraryCatalogProvider = FutureProvider<List<LibraryBook>>((ref) async {
  final repo = ref.watch(libraryRepositoryProvider);
  return repo.getCatalog();
});
