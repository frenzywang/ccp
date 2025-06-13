import 'dart:typed_data';
import 'package:flutter/services.dart';

class NativeClipboardService {
  static const MethodChannel _channel = MethodChannel('native_clipboard');

  /// 检查剪贴板是否包含图片
  static Future<bool> hasImage() async {
    try {
      final result = await _channel.invokeMethod('hasImage');
      return result == true;
    } catch (e) {
      print('❌ 检查剪贴板图片失败: $e');
      return false;
    }
  }

  /// 检查剪贴板是否包含文本
  static Future<bool> hasText() async {
    try {
      final result = await _channel.invokeMethod('hasText');
      return result == true;
    } catch (e) {
      print('❌ 检查剪贴板文本失败: $e');
      return false;
    }
  }

  /// 获取剪贴板中的图片数据
  static Future<Uint8List?> getImageData() async {
    try {
      final result = await _channel.invokeMethod('getImageData');
      if (result != null && result is Uint8List) {
        return result;
      }
      return null;
    } catch (e) {
      print('❌ 获取剪贴板图片数据失败: $e');
      return null;
    }
  }

  /// 获取剪贴板中的文本数据
  static Future<String?> getTextData() async {
    try {
      final result = await _channel.invokeMethod('getTextData');
      if (result != null && result is String) {
        return result;
      }
      return null;
    } catch (e) {
      print('❌ 获取剪贴板文本数据失败: $e');
      return null;
    }
  }

  /// 检查剪贴板内容类型
  static Future<String> getClipboardType() async {
    try {
      final result = await _channel.invokeMethod('getClipboardType');
      return result?.toString() ?? 'unknown';
    } catch (e) {
      print('❌ 获取剪贴板类型失败: $e');
      return 'unknown';
    }
  }

  /// 获取剪贴板变化时间戳（用于检测变化）
  static Future<int> getChangeCount() async {
    try {
      final result = await _channel.invokeMethod('getChangeCount');
      return result ?? 0;
    } catch (e) {
      print('❌ 获取剪贴板变化计数失败: $e');
      return 0;
    }
  }

  /// 获取所有剪贴板类型
  static Future<List<String>> getAllClipboardTypes() async {
    try {
      final result = await _channel.invokeMethod('getAllClipboardTypes');
      if (result != null && result is List) {
        return result.cast<String>();
      }
      return [];
    } catch (e) {
      print('❌ 获取剪贴板类型列表失败: $e');
      return [];
    }
  }

  /// 获取剪贴板项目详细信息
  static Future<List<Map<String, dynamic>>> getClipboardItemsInfo() async {
    try {
      final result = await _channel.invokeMethod('getClipboardItemsInfo');
      if (result != null && result is List) {
        return result.cast<Map<String, dynamic>>();
      }
      return [];
    } catch (e) {
      print('❌ 获取剪贴板项目信息失败: $e');
      return [];
    }
  }

  /// 设置图片数据到剪贴板
  static Future<bool> setImageData(Uint8List imageData) async {
    try {
      final result = await _channel.invokeMethod('setImageData', {
        'imageData': imageData,
      });
      return result == true;
    } catch (e) {
      print('❌ 设置图片数据到剪贴板失败: $e');
      return false;
    }
  }

  /// 获取剪贴板中的文件URL列表
  static Future<List<Map<String, dynamic>>> getFileURLs() async {
    try {
      final result = await _channel.invokeMethod('getFileURLs');
      if (result != null && result is List) {
        // 安全的类型转换
        return result
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      return [];
    } catch (e) {
      print('❌ 获取文件URL失败: $e');
      return [];
    }
  }

  /// 检测剪贴板变化和类型的综合方法
  static Future<ClipboardChangeInfo?> checkClipboardChange(
    int lastChangeCount,
  ) async {
    try {
      final currentChangeCount = await getChangeCount();

      // 没有变化
      if (currentChangeCount == lastChangeCount) {
        return null;
      }

      final clipboardType = await getClipboardType();
      String? textContent;
      Uint8List? imageData;

      if (clipboardType == 'text') {
        textContent = await getTextData();
      } else if (clipboardType == 'image') {
        imageData = await getImageData();
      }

      return ClipboardChangeInfo(
        changeCount: currentChangeCount,
        type: clipboardType,
        textContent: textContent,
        imageData: imageData,
      );
    } catch (e) {
      print('❌ 检测剪贴板变化失败: $e');
      return null;
    }
  }
}

/// 剪贴板变化信息
class ClipboardChangeInfo {
  final int changeCount;
  final String type;
  final String? textContent;
  final Uint8List? imageData;

  ClipboardChangeInfo({
    required this.changeCount,
    required this.type,
    this.textContent,
    this.imageData,
  });

  bool get hasText => textContent != null && textContent!.isNotEmpty;
  bool get hasImage => imageData != null && imageData!.isNotEmpty;

  @override
  String toString() {
    return 'ClipboardChangeInfo(changeCount: $changeCount, type: $type, '
        'hasText: $hasText, hasImage: $hasImage)';
  }
}
