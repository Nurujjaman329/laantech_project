import 'package:equatable/equatable.dart';

class FileItem extends Equatable {
  final String name;
  final int? size;
  final DateTime? modifiedAt;
  final String? downloadUrl;

  const FileItem({
    required this.name,
    this.size,
    this.modifiedAt,
    this.downloadUrl,
  });

  String get formattedSize {
    if (size == null || size! <= 0) return 'Unknown size';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double bytes = size!.toDouble();
    while (bytes >= 1024 && i < suffixes.length - 1) {
      bytes /= 1024;
      i++;
    }
    return '${bytes.toStringAsFixed(1)} ${suffixes[i]}';
  }

  @override
  List<Object?> get props => [name, size, modifiedAt, downloadUrl];
}
