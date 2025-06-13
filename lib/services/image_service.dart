import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;

class ImageService {
  static final ImageService _instance = ImageService._internal();
  factory ImageService() => _instance;
  ImageService._internal();

  late String _imagesCacheDir;

  /// 初始化图片服务
  Future<void> initialize() async {
    try {
      final appDir = await getApplicationSupportDirectory();
      _imagesCacheDir = path.join(appDir.path, 'clipboard_images');

      // 确保目录存在
      final dir = Directory(_imagesCacheDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      print('✅ 图片缓存目录已初始化: $_imagesCacheDir');
    } catch (e) {
      print('❌ 图片服务初始化失败: $e');
      rethrow;
    }
  }

  /// 保存图片数据到本地缓存
  Future<Map<String, dynamic>?> saveImageData(Uint8List imageData) async {
    try {
      // 解析图片以获取尺寸信息
      final image = img.decodeImage(imageData);
      if (image == null) {
        print('❌ 无法解析图片数据');
        return null;
      }

      // 生成唯一文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'clipboard_image_$timestamp.png';
      final filePath = path.join(_imagesCacheDir, fileName);

      // 保存图片文件
      final file = File(filePath);
      await file.writeAsBytes(imageData);

      print('✅ 图片已保存: $filePath');
      print('📐 图片尺寸: ${image.width}x${image.height}');

      return {
        'imagePath': filePath,
        'imageWidth': image.width,
        'imageHeight': image.height,
        'content': '图片 (${image.width}x${image.height})', // 用于显示的文本描述
      };
    } catch (e) {
      print('❌ 保存图片失败: $e');
      return null;
    }
  }

  /// 生成图片缩略图
  Future<String?> generateThumbnail(
    String imagePath, {
    int maxSize = 150,
  }) async {
    try {
      final file = File(imagePath);
      if (!await file.exists()) {
        print('❌ 图片文件不存在: $imagePath');
        return null;
      }

      final imageData = await file.readAsBytes();
      final image = img.decodeImage(imageData);
      if (image == null) return null;

      // 计算缩略图尺寸
      int thumbnailWidth, thumbnailHeight;
      if (image.width > image.height) {
        thumbnailWidth = maxSize;
        thumbnailHeight = (image.height * maxSize / image.width).round();
      } else {
        thumbnailHeight = maxSize;
        thumbnailWidth = (image.width * maxSize / image.height).round();
      }

      // 生成缩略图
      final thumbnail = img.copyResize(
        image,
        width: thumbnailWidth,
        height: thumbnailHeight,
        interpolation: img.Interpolation.linear,
      );

      // 保存缩略图
      final thumbnailFileName = 'thumb_${path.basename(imagePath)}';
      final thumbnailPath = path.join(_imagesCacheDir, thumbnailFileName);
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(img.encodePng(thumbnail));

      return thumbnailPath;
    } catch (e) {
      print('❌ 生成缩略图失败: $e');
      return null;
    }
  }

  /// 清理过期的图片缓存
  Future<void> cleanupExpiredImages({int maxDays = 30}) async {
    try {
      final dir = Directory(_imagesCacheDir);
      if (!await dir.exists()) return;

      final cutoffTime = DateTime.now().subtract(Duration(days: maxDays));
      final files = await dir.list().toList();

      int deletedCount = 0;
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          if (stat.modified.isBefore(cutoffTime)) {
            await file.delete();
            deletedCount++;
          }
        }
      }

      print('✅ 清理了 $deletedCount 个过期图片缓存');
    } catch (e) {
      print('❌ 清理图片缓存失败: $e');
    }
  }

  /// 获取图片缓存大小
  Future<int> getCacheSize() async {
    try {
      final dir = Directory(_imagesCacheDir);
      if (!await dir.exists()) return 0;

      int totalSize = 0;
      final files = await dir.list().toList();
      for (final file in files) {
        if (file is File) {
          final stat = await file.stat();
          totalSize += stat.size;
        }
      }

      return totalSize;
    } catch (e) {
      print('❌ 获取缓存大小失败: $e');
      return 0;
    }
  }

  /// 格式化文件大小显示
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
