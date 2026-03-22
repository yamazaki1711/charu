/// Domain model representing a local file (TXT, HTML, EPUB)
class LocalFile {
  final String id;
  final String path;
  final String name;
  final FileFormat type;
  final DateTime? lastOpened;
  final int lastPosition;
  final double progressPercent;
  final int totalLength;

  const LocalFile({
    required this.id,
    required this.path,
    required this.name,
    required this.type,
    this.lastOpened,
    this.lastPosition = 0,
    this.progressPercent = 0,
    this.totalLength = 0,
  });

  bool get isCompleted => progressPercent >= 100;
}

enum FileFormat {
  txt('txt'),
  html('html'),
  epub('epub'),
  unknown('unknown');

  final String extension;
  const FileFormat(this.extension);
}

/// Model for reading session statistics
class ReadingSession {
  final String fileId;
  final DateTime startTime;
  final DateTime endTime;
  final int wordsRead;
  final int newWords;
  final int minutesSpent;

  const ReadingSession({
    required this.fileId,
    required this.startTime,
    required this.endTime,
    required this.wordsRead,
    required this.newWords,
    required this.minutesSpent,
  });
}
