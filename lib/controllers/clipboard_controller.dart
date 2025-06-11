import 'dart:async';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import '../services/data_manager.dart';

class ClipboardController extends GetxController {
  // 响应式状态
  final RxList<ClipboardItem> items = <ClipboardItem>[].obs;
  final RxString lastClipboardContent = ''.obs;

  // 配置
  final int maxItems = 50;

  // 定时器
  Timer? _clipboardTimer;
  bool _isWatching = false;

  // 数据管理器
  final DataManager _dataManager = DataManager();

  @override
  void onInit() {
    super.onInit();
    print('📋 ClipboardController 初始化中...');
    initialize();
  }

  @override
  void onClose() {
    _clipboardTimer?.cancel();
    _isWatching = false;
    print('📋 ClipboardController 已关闭');
    super.onClose();
  }

  /// 初始化剪贴板服务
  Future<void> initialize() async {
    try {
      print('🚀 开始初始化剪贴板控制器...');
      print('📍 当前进程信息: ${DateTime.now().millisecondsSinceEpoch}');

      // 确保数据管理器已初始化
      print('📦 开始初始化数据管理器...');
      await _dataManager.initialize();
      print('✅ 数据管理器初始化完成，已初始化: ${_dataManager.isInitialized}');

      // 从数据管理器获取数据（内存操作，非常快）
      print('📚 从数据管理器获取数据...');
      _syncFromDataManager();
      print('✅ 数据同步完成，共 ${items.length} 条记录');

      // 立即获取当前剪贴板内容
      print('📋 获取当前剪贴板内容...');
      await _addCurrentClipboardContent();

      // 启动剪贴板监听
      print('👂 启动剪贴板监听...');
      await _startWatching();

      print('✅ 剪贴板控制器初始化完成，共 ${items.length} 条记录');
    } catch (e) {
      print('❌ 剪贴板控制器初始化失败: $e');
      print('🔄 添加示例数据作为回退...');
      _addSampleData();
    }
  }

  /// 从数据管理器同步数据到本地（内存操作）
  void _syncFromDataManager() {
    try {
      print('🔍 开始从数据管理器同步数据...');
      final dataManagerItems = _dataManager.items;
      print('📊 数据管理器返回 ${dataManagerItems.length} 条记录');

      items.clear();
      items.addAll(dataManagerItems);

      if (items.isNotEmpty) {
        lastClipboardContent.value = items.first.content;
        print('📝 设置最新内容: ${items.first.content.length} 字符');
      } else {
        print('⚠️ 数据管理器中没有数据');
      }

      print('📚 从数据管理器同步了 ${items.length} 条历史记录');
    } catch (e) {
      print('❌ 从数据管理器同步失败: $e');
    }
  }

  /// 启动剪贴板监听
  Future<void> _startWatching() async {
    if (_isWatching) return;

    try {
      _isWatching = true;

      // 获取当前剪贴板内容作为基准
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final currentContent = data?.text ?? '';
      if (currentContent != lastClipboardContent.value) {
        lastClipboardContent.value = currentContent;
      }
      print('✓ 基准剪贴板内容: ${lastClipboardContent.value.length} 字符');

      print('✓ 开始监听剪贴板变化（检查间隔：300ms）');

      // 定期检查剪贴板变化
      _clipboardTimer = Timer.periodic(const Duration(milliseconds: 300), (
        timer,
      ) {
        _checkClipboardChange();
      });
    } catch (e) {
      print('❌ 启动剪贴板监听失败: $e');
      _isWatching = false;
    }
  }

  /// 检查剪贴板变化
  Future<void> _checkClipboardChange() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final currentContent = data?.text ?? '';

      if (currentContent.isNotEmpty &&
          currentContent != lastClipboardContent.value) {
        print(
          '🎯 检测到剪贴板变化: ${currentContent.length > 30 ? "${currentContent.substring(0, 30)}..." : currentContent}',
        );
        await addClipboardItem(currentContent, ClipboardItemType.text);
      }
    } catch (e) {
      // 静默处理偶发错误
      if (DateTime.now().millisecondsSinceEpoch % 10000 < 300) {
        print('⚠️ 剪贴板检查错误: $e');
      }
    }
  }

  /// 添加剪贴板项目（使用数据管理器）
  Future<void> addClipboardItem(String content, ClipboardItemType type) async {
    if (content.isEmpty) return;

    try {
      // 使用数据管理器添加项目（内存操作 + 异步存储）
      await _dataManager.addClipboardItem(content, type);

      // 立即同步到本地状态（内存操作，非常快）
      _syncFromDataManager();

      print('✅ 剪贴板更新完成，当前共 ${items.length} 条记录');
    } catch (e) {
      print('❌ 添加剪贴板项目失败: $e');
    }
  }

  /// 复制内容到剪贴板
  Future<void> copyToClipboard(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      print('📋 内容已复制到剪贴板: ${content.length} 字符');
    } catch (e) {
      print('❌ 复制到剪贴板失败: $e');
    }
  }

  /// 清空历史记录（使用数据管理器）
  Future<void> clearHistory() async {
    try {
      await _dataManager.clearHistory();
      _syncFromDataManager();
      print('🗑️ 剪贴板历史已清空');
    } catch (e) {
      print('❌ 清空历史记录失败: $e');
    }
  }

  /// 获取当前剪贴板内容并添加到历史
  Future<void> _addCurrentClipboardContent() async {
    try {
      print('📖 正在读取当前剪贴板内容...');
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final content = data.text!;
        print('✓ 获取到当前剪贴板内容: ${content.length} 字符');
        print(
          '内容预览: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}',
        );

        // 总是添加当前内容，addClipboardItem会处理重复逻辑
        await addClipboardItem(content, ClipboardItemType.text);
      } else {
        print('⚠️ 当前剪贴板为空或无文本内容');
      }
    } catch (e) {
      print('❌ 读取当前剪贴板内容失败: $e');
    }
  }

  /// 添加示例数据
  void _addSampleData() {
    print('📝 添加欢迎示例数据');
    addClipboardItem('欢迎使用剪贴板管理器！请复制一些文本来开始使用。', ClipboardItemType.text);
  }

  /// 强制刷新剪贴板内容（子窗口使用，现在变成内存操作）
  Future<void> refreshClipboard() async {
    print('🔄 强制刷新剪贴板内容...');

    try {
      // 使用数据管理器刷新（内存操作）
      await _dataManager.refreshData();

      // 同步到本地状态
      _syncFromDataManager();

      // 检查当前剪贴板内容
      await _addCurrentClipboardContent();

      print('✅ 剪贴板内容刷新完成，当前有 ${items.length} 条记录');
    } catch (e) {
      print('❌ 刷新剪贴板内容失败: $e');
    }
  }
}
