import 'package:hive/hive.dart';

part 'clipboard_item.g.dart';

@HiveType(typeId: 1)
enum ClipboardItemType {
  @HiveField(0)
  text,
  @HiveField(1)
  image,
  @HiveField(2)
  file,
}

@HiveType(typeId: 0)
class ClipboardItem {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final ClipboardItemType type;

  @HiveField(3)
  final DateTime createdAt;

  // 图片相关属性
  @HiveField(4)
  final String? imagePath; // 图片文件路径

  @HiveField(5)
  final int? imageWidth; // 图片宽度

  @HiveField(6)
  final int? imageHeight; // 图片高度

  ClipboardItem({
    required this.id,
    required this.content,
    required this.type,
    required this.createdAt,
    this.imagePath,
    this.imageWidth,
    this.imageHeight,
  });

  /// 从JSON创建ClipboardItem (兼容旧数据)
  factory ClipboardItem.fromJson(Map<String, dynamic> json) {
    return ClipboardItem(
      id: json['id'] as String,
      content: json['content'] as String,
      type: ClipboardItemType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ClipboardItemType.text,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      imagePath: json['imagePath'] as String?,
      imageWidth: json['imageWidth'] as int?,
      imageHeight: json['imageHeight'] as int?,
    );
  }

  /// 转换为JSON (兼容性)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'type': type.toString(),
      'createdAt': createdAt.toIso8601String(),
      'imagePath': imagePath,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
    };
  }

  @override
  String toString() {
    return 'ClipboardItem(id: $id, content: $content, type: $type, createdAt: $createdAt, imagePath: $imagePath, imageWidth: $imageWidth, imageHeight: $imageHeight)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ClipboardItem &&
        other.id == id &&
        other.content == content &&
        other.type == type &&
        other.createdAt == createdAt &&
        other.imagePath == imagePath &&
        other.imageWidth == imageWidth &&
        other.imageHeight == imageHeight;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        content.hashCode ^
        type.hashCode ^
        createdAt.hashCode ^
        imagePath.hashCode ^
        imageWidth.hashCode ^
        imageHeight.hashCode;
  }
}
