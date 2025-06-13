import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import '../controllers/clipboard_controller.dart';
import 'crash_handler_service.dart';
import 'image_service.dart';
import 'native_clipboard_service.dart';
import 'package:uuid/uuid.dart';
import 'dart:typed_data';

/// 剪贴板监听服务
/// 负责监听系统剪贴板变化，将新内容传递给 ClipboardDataService
/// 不再独立管理剪贴板数据
class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  String? _lastClipboardContent;
  bool _isInitializing = false;
  int _lastChangeCount = 0; // 跟踪剪贴板变化计数

  // 剪贴板监听定时器
  Timer? _clipboardTimer;
  bool _isWatching = false;

  // 添加暂停监听的机制
  bool _isPaused = false;
  Timer? _pauseTimer;

  /// 暂停剪贴板监听（防止自动粘贴时的干扰）
  void pauseWatching({int milliseconds = 2000}) {
    if (!_isWatching) return;

    _isPaused = true;
    print('⏸️ 暂停剪贴板监听 ${milliseconds}ms');

    // 取消之前的暂停定时器
    _pauseTimer?.cancel();

    // 设置恢复定时器
    _pauseTimer = Timer(Duration(milliseconds: milliseconds), () {
      _isPaused = false;
      print('▶️ 恢复剪贴板监听');
    });
  }

  /// 立即恢复剪贴板监听
  void resumeWatchingImmediately() {
    _pauseTimer?.cancel();
    _isPaused = false;
    print('▶️ 立即恢复剪贴板监听');
  }

  /// 初始化剪贴板监听服务
  Future<void> initialize() async {
    try {
      print('🎯 开始初始化剪贴板服务...');

      // 记录初始化开始
      await CrashHandlerService().logMessage('剪贴板服务初始化开始');

      // 首先读取当前剪贴板内容
      await _initializeCurrentClipboard();

      // 启动剪贴板监听
      await _startWatching();

      _isWatching = true;
      print('✅ 剪贴板监听服务已启动');

      // 记录初始化成功
      await CrashHandlerService().logMessage('剪贴板服务初始化成功');
    } catch (e, stack) {
      print('❌ 初始化剪贴板服务失败: $e');

      // 记录初始化失败
      await CrashHandlerService().logError('剪贴板服务初始化失败', e, stack);

      _isWatching = false;
      rethrow;
    }
  }

  Future<void> _startWatching() async {
    if (_isWatching) return;

    try {
      _isWatching = true;

      print('👂 开始监听剪贴板变化（检查间隔：100ms）');
      print('✓ 使用原生插件监听，基准变化计数: $_lastChangeCount');

      // 使用定时器定期检测剪贴板变化
      _clipboardTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        _checkClipboardChange();
      });
    } catch (e) {
      print('❌ 启动剪贴板监听失败: $e');
      _isWatching = false;
    }
  }

  Future<void> _checkClipboardChange() async {
    try {
      // 如果监听被暂停，跳过检查
      if (_isPaused) {
        return;
      }

      // 直接使用原生API检测剪贴板变化（简化版本）
      try {
        final currentChangeCount =
            await NativeClipboardService.getChangeCount();

        if (currentChangeCount == _lastChangeCount) {
          return; // 没有变化
        }

        print('📋 检测到剪贴板变化计数: $currentChangeCount (上次: $_lastChangeCount)');
        _lastChangeCount = currentChangeCount;

        final clipboardType = await NativeClipboardService.getClipboardType();
        print('📋 剪贴板类型: $clipboardType');

        // 获取所有类型信息用于调试
        final allTypes = await NativeClipboardService.getAllClipboardTypes();
        print('📋 所有剪贴板类型: $allTypes');

        if (clipboardType == 'image') {
          final hasImage = await NativeClipboardService.hasImage();
          print('🖼️ 检测到图片类型，hasImage: $hasImage');

          if (hasImage) {
            final imageData = await NativeClipboardService.getImageData();
            if (imageData != null && imageData.isNotEmpty) {
              print('🖼️ 获取到图片数据: ${imageData.length} 字节');
              await _handleImageClipboard(imageData);
              return;
            } else {
              print('❌ 图片数据为空');
            }
          }
        } else if (clipboardType == 'file') {
          print('📁 检测到文件类型');
          await _handleFileClipboard();
          return;
        } else if (clipboardType == 'text') {
          final hasText = await NativeClipboardService.hasText();
          print('📝 检测到文本类型，hasText: $hasText');

          if (hasText) {
            final textData = await NativeClipboardService.getTextData();
            if (textData != null && textData.isNotEmpty) {
              print('📝 获取到文本数据: ${textData.length} 字符');
              await _handleTextClipboard(textData);
              return;
            } else {
              print('❌ 文本数据为空');
            }
          }
        } else {
          print('⚠️ 未知或不支持的剪贴板类型: $clipboardType');
        }
      } catch (nativeError) {
        print('❌ 原生插件调用失败: $nativeError');
        throw nativeError; // 抛出错误，触发回退机制
      }
    } catch (e) {
      // 如果原生插件失败，回退到Flutter API
      try {
        await _handleTextClipboardFallback();
      } catch (fallbackError) {
        // 偶尔的错误可以忽略，但连续错误需要记录
        if (DateTime.now().millisecondsSinceEpoch % 10000 < 100) {
          print('⚠️ 剪贴板检查错误（原生+回退都失败）: $e, $fallbackError');
        }
      }
    }
  }

  /// 处理图片剪贴板
  Future<void> _handleImageClipboard(Uint8List imageData) async {
    try {
      print('🖼️ 处理图片剪贴板内容，数据大小: ${imageData.length} 字节');

      // 保存图片并添加到历史记录
      final imageService = ImageService();
      final savedImageInfo = await imageService.saveImageData(imageData);

      if (savedImageInfo != null) {
        await _addClipboardItemToDataService(
          savedImageInfo['content'],
          ClipboardItemType.image,
          imagePath: savedImageInfo['imagePath'],
          imageWidth: savedImageInfo['imageWidth'],
          imageHeight: savedImageInfo['imageHeight'],
        );
        print('✅ 图片已保存并添加到历史记录');

        // 清空文本内容，因为现在是图片
        _lastClipboardContent = null;
      } else {
        print('❌ 保存图片失败');
      }
    } catch (e) {
      print('❌ 处理图片剪贴板失败: $e');
    }
  }

  /// 处理文件剪贴板
  Future<void> _handleFileClipboard() async {
    try {
      final fileInfos = await NativeClipboardService.getFileURLs();
      print('📁 获取到 ${fileInfos.length} 个文件');

      for (final fileInfo in fileInfos) {
        // 安全的类型转换
        final Map<String, dynamic> safeFileInfo = Map<String, dynamic>.from(
          fileInfo,
        );
        final filePath = safeFileInfo['path'] as String?;
        final fileName = safeFileInfo['name'] as String?;
        final isImage = safeFileInfo['isImage'] as bool? ?? false;
        final exists = safeFileInfo['exists'] as bool? ?? false;

        if (filePath == null || fileName == null || !exists) {
          print('⚠️ 跳过无效文件: $fileName');
          continue;
        }

        print('📁 处理文件: $fileName, 是图片: $isImage');

        if (isImage) {
          // 如果是图片文件，读取文件内容并保存
          await _handleImageFile(filePath, fileName);
        } else {
          // 如果是其他文件，保存文件路径信息
          await _handleOtherFile(filePath, fileName);
        }
      }
    } catch (e) {
      print('❌ 处理文件剪贴板失败: $e');
    }
  }

  /// 处理图片文件
  Future<void> _handleImageFile(String filePath, String fileName) async {
    try {
      final File imageFile = File(filePath);
      if (!await imageFile.exists()) {
        print('❌ 图片文件不存在: $filePath');
        return;
      }

      final Uint8List imageData = await imageFile.readAsBytes();
      print('📁 读取图片文件: $fileName, ${imageData.length} 字节');

      // 保存图片并添加到历史记录
      final imageService = ImageService();
      final savedImageInfo = await imageService.saveImageData(imageData);

      if (savedImageInfo != null) {
        await _addClipboardItemToDataService(
          savedImageInfo['content'],
          ClipboardItemType.image,
          imagePath: savedImageInfo['imagePath'],
          imageWidth: savedImageInfo['imageWidth'],
          imageHeight: savedImageInfo['imageHeight'],
        );
        print('✅ 图片文件已保存并添加到历史记录: $fileName');

        // 清空文本内容，因为现在是图片
        _lastClipboardContent = null;
      } else {
        print('❌ 保存图片文件失败: $fileName');
      }
    } catch (e) {
      print('❌ 处理图片文件失败: $e');
    }
  }

  /// 处理其他文件
  Future<void> _handleOtherFile(String filePath, String fileName) async {
    try {
      final content = '文件: $fileName';
      print('📁 处理其他文件: $fileName');

      await _addClipboardItemToDataService(content, ClipboardItemType.text);

      _lastClipboardContent = content;
      print('✅ 文件信息已添加到历史记录: $fileName');
    } catch (e) {
      print('❌ 处理其他文件失败: $e');
    }
  }

  /// 处理文本剪贴板
  Future<void> _handleTextClipboard(String textContent) async {
    try {
      if (textContent.isNotEmpty && textContent != _lastClipboardContent) {
        final previewLength = 50;
        final preview = textContent.length > previewLength
            ? "${textContent.substring(0, previewLength)}..."
            : textContent;

        print('🔥 剪贴板文本内容已更新: $preview');
        print('📊 内容长度: ${textContent.length} 字符');

        // 将新内容传递给数据服务
        await _addClipboardItemToDataService(
          textContent,
          ClipboardItemType.text,
        );

        // 更新最后已知内容
        _lastClipboardContent = textContent;
      }
    } catch (e) {
      print('❌ 处理文本剪贴板失败: $e');
    }
  }

  /// 备用的文本剪贴板处理（使用Flutter API）
  Future<void> _handleTextClipboardFallback() async {
    try {
      final textData = await Clipboard.getData(Clipboard.kTextPlain);
      final currentTextContent = textData?.text;

      if (currentTextContent != null &&
          currentTextContent.isNotEmpty &&
          currentTextContent != _lastClipboardContent) {
        final previewLength = 50;
        final preview = currentTextContent.length > previewLength
            ? "${currentTextContent.substring(0, previewLength)}..."
            : currentTextContent;

        print('🔥 剪贴板文本内容已更新: $preview');
        print('📊 内容长度: ${currentTextContent.length} 字符');

        // 将新内容传递给数据服务
        await _addClipboardItemToDataService(
          currentTextContent,
          ClipboardItemType.text,
        );

        // 更新最后已知内容
        _lastClipboardContent = currentTextContent;
      }
    } catch (e) {
      print('❌ 处理文本剪贴板失败: $e');
    }
  }

  Future<void> _addClipboardItemToDataService(
    String content,
    ClipboardItemType type, {
    String? imagePath,
    int? imageWidth,
    int? imageHeight,
  }) async {
    try {
      // 通过 ClipboardController 添加剪贴板项目
      try {
        final controller = Get.find<ClipboardController>();

        // 单窗口模式：直接添加到控制器
        await controller.addItem(
          content,
          type: type,
          imagePath: imagePath,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
        );
        print('✅ 单窗口模式：剪贴板项目已添加到历史记录');
      } catch (e) {
        print('❌ 未找到 ClipboardController: $e');
      }
    } catch (e) {
      print('❌ 传递剪贴板项目到数据服务失败: $e');
    }
  }

  /// 初始化当前剪贴板内容
  Future<void> _initializeCurrentClipboard() async {
    try {
      // 获取当前剪贴板变化计数作为基准
      _lastChangeCount = await NativeClipboardService.getChangeCount();
      print('📋 初始化剪贴板变化计数: $_lastChangeCount');

      // 检查当前剪贴板类型
      final clipboardType = await NativeClipboardService.getClipboardType();
      print('📋 当前剪贴板类型: $clipboardType');

      if (clipboardType == 'text') {
        final textContent = await NativeClipboardService.getTextData();
        if (textContent != null && textContent.isNotEmpty) {
          _lastClipboardContent = textContent;
          final preview = textContent.length > 50
              ? '${textContent.substring(0, 50)}...'
              : textContent;
          print('📋 当前剪贴板内容: $preview');

          // 将当前剪贴板内容添加到历史记录
          await _addClipboardItemToDataService(
            textContent,
            ClipboardItemType.text,
          );
          print('✅ 当前剪贴板内容已添加到历史记录');
        }
      } else if (clipboardType == 'image') {
        final imageData = await NativeClipboardService.getImageData();
        if (imageData != null && imageData.isNotEmpty) {
          print('📋 当前剪贴板包含图片: ${imageData.length} 字节');

          // 保存图片并添加到历史记录
          final imageService = ImageService();
          final savedImageInfo = await imageService.saveImageData(imageData);

          if (savedImageInfo != null) {
            await _addClipboardItemToDataService(
              savedImageInfo['content'],
              ClipboardItemType.image,
              imagePath: savedImageInfo['imagePath'],
              imageWidth: savedImageInfo['imageWidth'],
              imageHeight: savedImageInfo['imageHeight'],
            );
            print('✅ 当前剪贴板图片已添加到历史记录');
          }
        }
      } else {
        print('📋 当前剪贴板为空或包含未知类型内容');
      }
    } catch (e, stack) {
      print('⚠️ 读取当前剪贴板内容失败: $e');
      print('🔄 回退到Flutter API读取剪贴板内容');

      // 如果原生API失败，回退到Flutter API
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        if (data?.text != null && data!.text!.isNotEmpty) {
          _lastClipboardContent = data.text!;
          final preview = _lastClipboardContent!.length > 50
              ? '${_lastClipboardContent!.substring(0, 50)}...'
              : _lastClipboardContent!;
          print('📋 当前剪贴板内容（Flutter API）: $preview');

          await _addClipboardItemToDataService(
            _lastClipboardContent!,
            ClipboardItemType.text,
          );
          print('✅ 当前剪贴板内容已添加到历史记录（Flutter API）');
        }
      } catch (fallbackError) {
        print('❌ Flutter API读取剪贴板也失败: $fallbackError');
      }

      await CrashHandlerService().logError('读取剪贴板内容失败', e, stack);
    }
  }

  /// 停止监听
  void stopWatching() {
    if (_isWatching) {
      _clipboardTimer?.cancel();
      _isWatching = false;
      print('⏸️ 剪贴板监听已停止');
    }
  }

  /// 重新开始监听
  Future<void> resumeWatching() async {
    if (!_isWatching) {
      await _startWatching();
      print('▶️ 剪贴板监听已恢复');
    }
  }

  /// 检查是否正在监听
  bool get isWatching => _isWatching;

  /// 获取最后已知的剪贴板内容
  String? get lastClipboardContent => _lastClipboardContent;

  /// 手动触发剪贴板检查
  Future<void> manualCheck() async {
    print('🔄 手动触发剪贴板检查...');
    await _checkClipboardChange();
  }

  /// 资源清理
  void dispose() {
    print('🚪 关闭剪贴板监听服务...');
    _clipboardTimer?.cancel();
    _pauseTimer?.cancel();
    _isWatching = false;
    _isPaused = false;
    _isInitializing = false;
    print('✅ 剪贴板监听服务已关闭');
  }
}
