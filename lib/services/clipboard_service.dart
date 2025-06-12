import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import '../controllers/clipboard_controller.dart';
import 'clipboard_data_service.dart';
import 'crash_handler_service.dart';
import 'package:uuid/uuid.dart';

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

      // 获取当前剪贴板内容作为基准
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _lastClipboardContent = data?.text;
      print('✓ 基准剪贴板内容: ${_lastClipboardContent?.length ?? 0} 字符');

      print('👂 开始监听剪贴板变化（检查间隔：100ms）');

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

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final currentContent = data?.text;

      if (currentContent != null &&
          currentContent.isNotEmpty &&
          currentContent != _lastClipboardContent) {
        final previewLength = 50;
        final preview = currentContent.length > previewLength
            ? "${currentContent.substring(0, previewLength)}..."
            : currentContent;

        print('🔥 剪贴板内容已更新: $preview');
        print('📊 内容长度: ${currentContent.length} 字符');

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
        print('⚠️ 剪贴板检查错误: $e');
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
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        _lastClipboardContent = data.text!;
        final preview = _lastClipboardContent!.length > 50
            ? '${_lastClipboardContent!.substring(0, 50)}...'
            : _lastClipboardContent!;
        print('📋 当前剪贴板内容: $preview');

        // 将当前剪贴板内容添加到历史记录
        await _addClipboardItemToDataService(
          _lastClipboardContent!,
          ClipboardItemType.text,
        );
        print('✅ 当前剪贴板内容已添加到历史记录');
      } else {
        print('📋 当前剪贴板为空或无文本内容');
      }
    } catch (e, stack) {
      print('⚠️ 读取当前剪贴板内容失败: $e');
      await CrashHandlerService().logError('读取剪贴板内容失败', e, stack);
    }
  }

  /// 剪贴板变化回调
  void _onClipboardChanged() async {
    try {
      if (!_isWatching) return;

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text == null || data!.text!.isEmpty) {
        return;
      }

      final newContent = data.text!;

      // 检查是否是重复内容
      if (_lastClipboardContent == newContent) {
        return;
      }

      _lastClipboardContent = newContent;

      final preview = newContent.length > 50
          ? '${newContent.substring(0, 50)}...'
          : newContent;
      print('📋 剪贴板内容已变化: $preview');

      // 创建剪贴板项目
      final item = ClipboardItem(
        id: const Uuid().v4(),
        content: newContent,
        createdAt: DateTime.now(),
        type: ClipboardItemType.text,
      );

      // 更新控制器
      final controller = Get.find<ClipboardController>();
      controller.addItem(item.content);

      print('✅ 剪贴板项目已添加到历史记录');
    } catch (e, stack) {
      print('❌ 处理剪贴板变化失败: $e');
      await CrashHandlerService().logError('处理剪贴板变化失败', e, stack);
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
