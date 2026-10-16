/// A work from the curated Wikisource catalog (`assets/library/catalog.json`),
/// optionally already downloaded to the device.
class LibraryBook {
  final String id;
  final String wikisourceTitle;
  final String author;
  final String titleDisplay;
  final String year;
  final String genre;
  final String level;
  final String? filePath;
  final DateTime? downloadedAt;
  final int charCount;

  const LibraryBook({
    required this.id,
    required this.wikisourceTitle,
    required this.author,
    required this.titleDisplay,
    required this.year,
    required this.genre,
    required this.level,
    this.filePath,
    this.downloadedAt,
    this.charCount = 0,
  });

  bool get isDownloaded => filePath != null;

  String get sourceUrl =>
      'https://zh.wikisource.org/wiki/${Uri.encodeComponent(wikisourceTitle)}';

  factory LibraryBook.fromCatalogJson(Map<String, dynamic> json) {
    return LibraryBook(
      id: json['id'] as String,
      wikisourceTitle: json['wikisourceTitle'] as String,
      author: json['author'] as String,
      titleDisplay: json['titleDisplay'] as String,
      year: json['year'] as String? ?? '',
      genre: json['genre'] as String? ?? '',
      level: json['level'] as String? ?? '',
    );
  }

  LibraryBook copyWithDownload({
    required String filePath,
    required DateTime downloadedAt,
    required int charCount,
  }) {
    return LibraryBook(
      id: id,
      wikisourceTitle: wikisourceTitle,
      author: author,
      titleDisplay: titleDisplay,
      year: year,
      genre: genre,
      level: level,
      filePath: filePath,
      downloadedAt: downloadedAt,
      charCount: charCount,
    );
  }
}
