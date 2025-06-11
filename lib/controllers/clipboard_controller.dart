import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/clipboard_item.dart';

class ClipboardController extends GetxController {
  // 响应式状态
  final RxList<ClipboardItem> items = <ClipboardItem>[].obs;
  final RxBool isLoading = false.obs;
  final RxString lastClipboardContent = ''.obs;

  // 配置
  final int maxItems = 50;

  // 定时器
  Timer? _clipboardTimer;
  bool _isWatching = false;

  // Hive box
  Box<ClipboardItem>? _clipboardBox;

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
    _clipboardBox?.close();
    print('📋 ClipboardController 已关闭');
    super.onClose();
  }

  /// 初始化剪贴板服务
  Future<void> initialize() async {
    try {
      isLoading.value = true;
      print('🚀 开始初始化剪贴板控制器...');

      // 初始化 Hive
      await _initializeHive();

      // 从 Hive 加载历史记录
      await _loadFromHive();

      // 立即获取当前剪贴板内容
      await _addCurrentClipboardContent();

      // 启动剪贴板监听
      await _startWatching();

      print('✅ 剪贴板控制器初始化完成，共 ${items.length} 条记录');
    } catch (e) {
      print('❌ 剪贴板控制器初始化失败: $e');
      _addSampleData();
    } finally {
      isLoading.value = false;
    }
  }

  /// 初始化 Hive 数据库
  Future<void> _initializeHive() async {
    try {
      // 注册适配器（如果还没注册）
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ClipboardItemAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ClipboardItemTypeAdapter());
      }

      // 检查Hive是否已初始化路径
      try {
        // 尝试使用已初始化的路径或手动指定路径
        if (!Hive.isBoxOpen('clipboard_history')) {
          // 优先使用已初始化的路径，如果失败则手动指定
          try {
            await Hive.initFlutter();
            print('📦 Hive 使用Flutter默认路径初始化完成');
          } catch (e) {
            print('⚠️ Flutter路径初始化失败，使用应用支持目录: $e');
            // 手动指定应用支持目录
            final documentsDir =
                '${Directory.systemTemp.parent.path}/Library/Application Support/ccp';
            await Directory(documentsDir).create(recursive: true);
            Hive.init(documentsDir);
            print('📦 Hive 使用应用支持目录初始化完成: $documentsDir');
          }
        }
      } catch (e) {
        print('⚠️ Hive路径已存在或初始化过程出错: $e');
      }

      // 打开 box
      if (!Hive.isBoxOpen('clipboard_history')) {
        _clipboardBox = await Hive.openBox<ClipboardItem>('clipboard_history');
        print('📦 Hive box 已打开: clipboard_history');
      } else {
        _clipboardBox = Hive.box<ClipboardItem>('clipboard_history');
        print('📦 使用已存在的 Hive box: clipboard_history');
      }

      // 从 Hive 加载数据
      _loadFromHive();
    } catch (e) {
      print('❌ 初始化 Hive 失败: $e');
      // 如果Hive完全失败，则使用内存存储
      _addSampleData();
    }
  }

  /// 从 Hive 加载历史记录
  Future<void> _loadFromHive() async {
    try {
      if (_clipboardBox == null) return;

      final hiveItems = _clipboardBox!.values.toList();

      // 按创建时间倒序排列（最新的在前面）
      hiveItems.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      items.clear();
      items.addAll(hiveItems);

      if (items.isNotEmpty) {
        lastClipboardContent.value = items.first.content;
      }

      print('📚 从 Hive 加载了 ${items.length} 条历史记录');
    } catch (e) {
      print('❌ 从 Hive 加载失败: $e');
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

  /// 添加剪贴板项目
  Future<void> addClipboardItem(String content, ClipboardItemType type) async {
    if (content.isEmpty || _clipboardBox == null) return;

    try {
      // 检查是否是重复内容
      final existingIndex = items.indexWhere((item) => item.content == content);
      if (existingIndex != -1) {
        // 如果已存在，更新时间并移动到顶部
        final existingItem = items[existingIndex];
        await _clipboardBox!.delete(existingItem.id);
        items.removeAt(existingIndex);

        final updatedItem = ClipboardItem(
          id: existingItem.id,
          content: content,
          type: type,
          createdAt: DateTime.now(),
        );

        await _clipboardBox!.put(updatedItem.id, updatedItem);
        items.insert(0, updatedItem);
        print(
          '📝 已存在的内容移动到顶部: ${content.length > 30 ? "${content.substring(0, 30)}..." : content}',
        );
      } else {
        // 添加新项目
        final item = ClipboardItem(
          id: _generateId(),
          content: content,
          type: type,
          createdAt: DateTime.now(),
        );

        await _clipboardBox!.put(item.id, item);
        items.insert(0, item);
        print(
          '➕ 新增剪贴板项目: ${content.length > 30 ? "${content.substring(0, 30)}..." : content}',
        );
      }

      // 更新最后的剪贴板内容
      lastClipboardContent.value = content;

      // 保持最大数量限制
      while (items.length > maxItems) {
        final oldestItem = items.last;
        await _clipboardBox!.delete(oldestItem.id);
        items.removeLast();
      }

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

  /// 清空历史记录
  Future<void> clearHistory() async {
    try {
      await _clipboardBox?.clear();
      items.clear();
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

  /// 生成唯一ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        math.Random().nextInt(1000).toString();
  }

  /// 强制刷新剪贴板内容（子窗口使用）
  Future<void> refreshClipboard() async {
    print('🔄 强制刷新剪贴板内容...');

    // 重新从 Hive 加载
    await _loadFromHive();

    // 检查当前剪贴板内容
    await _addCurrentClipboardContent();

    print('✅ 剪贴板内容刷新完成，当前有 ${items.length} 条记录');
  }
}
