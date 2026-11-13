import '../../domain/entities/file_item.dart';

class FileItemModel extends FileItem {
  const FileItemModel({
    required super.name,
    super.size,
    super.modifiedAt,
    super.downloadUrl,
  });

  factory FileItemModel.fromDynamic(dynamic item) {
    if (item is String) {
      return FileItemModel(name: item);
    } else if (item is Map<String, dynamic>) {
      final name = item['name'] ?? item['filename'] ?? item['file'] ?? 'unnamed';
      final size = item['size'] is int
          ? item['size'] as int
          : (item['size'] != null ? int.tryParse(item['size'].toString()) : null);
      DateTime? modifiedAt;
      if (item['modified_at'] != null) {
        modifiedAt = DateTime.tryParse(item['modified_at'].toString());
      } else if (item['date'] != null) {
        modifiedAt = DateTime.tryParse(item['date'].toString());
      }
      final downloadUrl = item['url'] ?? item['download_url'];

      return FileItemModel(
        name: name.toString(),
        size: size,
        modifiedAt: modifiedAt,
        downloadUrl: downloadUrl?.toString(),
      );
    }
    return FileItemModel(name: item.toString());
  }

  static List<FileItemModel> fromResponse(dynamic data) {
    if (data == null) return [];
    if (data is List) {
      return data.map((e) => FileItemModel.fromDynamic(e)).toList();
    } else if (data is Map<String, dynamic>) {
      if (data['files'] is List) {
        return (data['files'] as List).map((e) => FileItemModel.fromDynamic(e)).toList();
      } else if (data['items'] is List) {
        return (data['items'] as List).map((e) => FileItemModel.fromDynamic(e)).toList();
      }
    }
    return [];
  }
}
