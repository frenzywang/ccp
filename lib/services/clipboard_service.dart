import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import '../controllers/clipboard_controller.dart';
import 'clipboard_data_service.dart';

/// 剪贴板监听服务
/// 负责监听系统剪贴板变化，将新内容传递给 ClipboardDataService
/// 不再独立管理剪贴板数据
class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  String? _lastClipboardContent;
  bool _isInitializing = false;

  // 剪贴板监听定时器
  Timer? _clipboardTimer;
  bool _isWatching = false;

  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    debugPrint('🚀 正在初始化剪贴板监听服务...');

    try {
      // 在单窗口模式下，直接启动剪贴板监听
      debugPrint('✅ 单窗口模式：开始剪贴板监听初始化');

      // 立即获取当前剪贴板内容并添加到数据服务
      await _addCurrentClipboardContent();

      // 启动剪贴板监听
      await _startWatching();

      debugPrint('✅ 剪贴板监听服务初始化完成');
    } catch (e) {
      debugPrint('❌ 剪贴板监听服务初始化出错: $e');

      // 即使出错也要尝试获取当前内容
      try {
        await _addCurrentClipboardContent();
      } catch (e2) {
        debugPrint('❌ 获取当前剪贴板内容也失败: $e2');
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _startWatching() async {
    if (_isWatching) return;

    try {
      _isWatching = true;

      // 获取当前剪贴板内容作为基准
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _lastClipboardContent = data?.text;
      debugPrint('✓ 基准剪贴板内容: ${_lastClipboardContent?.length ?? 0} 字符');

      debugPrint('👂 开始监听剪贴板变化（检查间隔：100ms）');

      // 使用定时器定期检测剪贴板变化
      _clipboardTimer = Timer.periodic(const Duration(milliseconds: 100), (
        timer,
      ) {
        _checkClipboardChange();
      });
    } catch (e) {
      debugPrint('❌ 启动剪贴板监听失败: $e');
      _isWatching = false;
    }
  }

  Future<void> _checkClipboardChange() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final currentContent = data?.text;

      if (currentContent != null &&
          currentContent.isNotEmpty &&
          currentContent != _lastClipboardContent) {
        final previewLength = 50;
        final preview = currentContent.length > previewLength
            ? "${currentContent.substring(0, previewLength)}..."
            : currentContent;

        debugPrint('🔥 剪贴板内容已更新: $preview');
        debugPrint('📊 内容长度: ${currentContent.length} 字符');

        // 将新内容传递给数据服务
        await _addClipboardItemToDataService(
          currentContent,
          ClipboardItemType.text,
        );

        // 更新最后已知内容
        _lastClipboardContent = currentContent;
      }
    } catch (e) {
      // 偶尔的错误可以忽略，但连续错误需要记录
      if (DateTime.now().millisecondsSinceEpoch % 10000 < 100) {
        debugPrint('⚠️ 剪贴板检查错误: $e');
      }
    }
  }

  Future<void> _addClipboardItemToDataService(
    String content,
    ClipboardItemType type,
  ) async {
    try {
      // 通过 ClipboardController 添加剪贴板项目
      try {
        final controller = Get.find<ClipboardController>();

        // 单窗口模式：直接添加到控制器
        await controller.addItem(content, type: type);
        debugPrint('✅ 单窗口模式：剪贴板项目已添加到历史记录');
      } catch (e) {
        debugPrint('❌ 未找到 ClipboardController: $e');
      }
    } catch (e) {
      debugPrint('❌ 传递剪贴板项目到数据服务失败: $e');
    }
  }

  Future<void> _addCurrentClipboardContent() async {
    try {
      debugPrint('📖 正在读取当前剪贴板内容...');
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final content = data.text!;
        debugPrint('✓ 获取到当前剪贴板内容: ${content.length} 字符');
        debugPrint(
          '内容预览: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}',
        );

        await _addClipboardItemToDataService(content, ClipboardItemType.text);
        _lastClipboardContent = content;
        debugPrint('✓ 当前剪贴板内容已添加到数据服务');
      } else {
        debugPrint('⚠️ 当前剪贴板为空或无文本内容');

        // 为了测试和用户体验，添加一个示例数据
        final welcomeText = '欢迎使用剪贴板历史管理器！\n复制一些文本来查看历史记录。';
        await _addClipboardItemToDataService(
          welcomeText,
          ClipboardItemType.text,
        );
        _lastClipboardContent = welcomeText;
        debugPrint('✓ 已添加欢迎示例数据');
      }
    } catch (e) {
      debugPrint('❌ 无法读取当前剪贴板内容: $e');

      // 即使出错也添加一个示例数据
      try {
        final errorText = '剪贴板历史管理器已启动\n开始复制文本查看历史记录';
        await _addClipboardItemToDataService(errorText, ClipboardItemType.text);
        _lastClipboardContent = errorText;
        debugPrint('✓ 已添加错误示例数据');
      } catch (e2) {
        debugPrint('❌ 添加示例数据也失败: $e2');
      }
    }
  }

  /// 停止监听
  void stopWatching() {
    if (_isWatching) {
      _clipboardTimer?.cancel();
      _isWatching = false;
      debugPrint('⏸️ 剪贴板监听已停止');
    }
  }

  /// 重新开始监听
  Future<void> resumeWatching() async {
    if (!_isWatching) {
      await _startWatching();
      debugPrint('▶️ 剪贴板监听已恢复');
    }
  }

  /// 检查是否正在监听
  bool get isWatching => _isWatching;

  /// 获取最后已知的剪贴板内容
  String? get lastClipboardContent => _lastClipboardContent;

  /// 手动触发剪贴板检查
  Future<void> manualCheck() async {
    debugPrint('🔄 手动触发剪贴板检查...');
    await _checkClipboardChange();
  }

  /// 资源清理
  void dispose() {
    debugPrint('🚪 关闭剪贴板监听服务...');
    _clipboardTimer?.cancel();
    _isWatching = false;
    _isInitializing = false;
    debugPrint('✅ 剪贴板监听服务已关闭');
  }
}
