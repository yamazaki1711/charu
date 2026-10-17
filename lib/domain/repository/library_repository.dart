import '../model/library_models.dart';

/// Repository for the curated Wikisource book catalog and downloaded books.
abstract class ILibraryRepository {
  /// Catalog entries from `assets/library/catalog.json`, merged with
  /// download status from the `library_books` table.
  Future<List<LibraryBook>> getCatalog();

  /// Downloads [book]'s text from Wikisource, saves it under the app's
  /// documents directory, and registers it in `library_books` +
  /// `reading_history` (so the existing reader/progress pipeline picks it
  /// up with no changes). Returns the updated, now-downloaded [LibraryBook].
  Future<LibraryBook> downloadBook(LibraryBook book,
      {bool convertToSimplified = true});

  /// Deletes the downloaded file and its `library_books`/`reading_history`
  /// rows. No-op if [book] was never downloaded.
  Future<void> deleteBook(LibraryBook book);
}
