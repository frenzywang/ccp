import 'dart:async';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import 'storage_service.dart';

/// 全局数据管理器，统一管理剪贴板数据
/// 程序启动时从 Hive 加载一次，之后所有操作都在内存中进行
/// 只在数据变化时异步写入 Hive
class DataManager extends GetxController {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  // 内存中的剪贴板数据
  final RxList<ClipboardItem> _items = <ClipboardItem>[].obs;
  final RxBool _isInitialized = false.obs;
  final RxString _lastClipboardContent = ''.obs;

  // 存储服务
  final StorageService _storageService = StorageService();

  // 配置
  final int maxItems = 50;

  // Getters
  List<ClipboardItem> get items => _items;
  bool get isInitialized => _isInitialized.value;
  String get lastClipboardContent => _lastClipboardContent.value;

  /// 初始化数据管理器（仅在程序启动时调用一次）
  Future<void> initialize() async {
    if (_isInitialized.value) {
      print('📦 DataManager 已初始化，跳过');
      return;
    }

    try {
      print('🚀 初始化 DataManager...');

      // 确保存储服务已初始化
      await _storageService.initialize();

      // 从 Hive 加载历史数据到内存
      await _loadFromStorage();

      _isInitialized.value = true;
      print('✅ DataManager 初始化完成，共 ${_items.length} 条记录');
    } catch (e) {
      print('❌ DataManager 初始化失败: $e');
      // 即使失败也标记为已初始化，避免重复尝试
      _isInitialized.value = true;
    }
  }

  /// 从存储加载数据到内存（仅在初始化时调用）
  Future<void> _loadFromStorage() async {
    try {
      print('📚 从 Hive 加载数据到内存...');
      final storageItems = _storageService.getClipboardItems();
      print('📊 从 Hive 加载了 ${storageItems.length} 条记录');

      _items.clear();
      _items.addAll(storageItems);

      if (_items.isNotEmpty) {
        _lastClipboardContent.value = _items.first.content;
      }

      print('✅ 数据加载到内存完成，共 ${_items.length} 条记录');
    } catch (e) {
      print('❌ 从存储加载数据失败: $e');
    }
  }

  /// 添加新的剪贴板项目（内存操作 + 异步存储）
  Future<void> addClipboardItem(String content, ClipboardItemType type) async {
    if (content.isEmpty) return;

    try {
      // 检查是否是重复内容
      final existingIndex = _items.indexWhere(
        (item) => item.content == content,
      );

      ClipboardItem newItem;

      if (existingIndex != -1) {
        // 如果已存在，更新时间并移动到顶部
        final existingItem = _items[existingIndex];
        _items.removeAt(existingIndex);

        newItem = ClipboardItem(
          id: existingItem.id,
          content: content,
          type: type,
          createdAt: DateTime.now(),
        );

        _items.insert(0, newItem);
        print(
          '📝 已存在内容移动到顶部: ${content.length > 30 ? "${content.substring(0, 30)}..." : content}',
        );
      } else {
        // 添加新项目
        newItem = ClipboardItem(
          id: _generateId(),
          content: content,
          type: type,
          createdAt: DateTime.now(),
        );

        _items.insert(0, newItem);
        print(
          '➕ 新增剪贴板项目: ${content.length > 30 ? "${content.substring(0, 30)}..." : content}',
        );
      }

      // 更新最后的剪贴板内容
      _lastClipboardContent.value = content;

      // 保持最大数量限制
      while (_items.length > maxItems) {
        _items.removeLast();
      }

      print('📊 内存数据更新完成，当前 ${_items.length} 条记录');

      // 异步保存到 Hive（不阻塞界面）
      _saveToStorageAsync(newItem);
    } catch (e) {
      print('❌ 添加剪贴板项目失败: $e');
    }
  }

  /// 异步保存到存储（不阻塞主线程）
  void _saveToStorageAsync(ClipboardItem item) {
    Timer.run(() async {
      try {
        await _storageService.saveClipboardItem(item);
        print('💾 项目已异步保存到 Hive');
      } catch (e) {
        print('⚠️ 异步保存失败: $e');
      }
    });
  }

  /// 清空历史记录
  Future<void> clearHistory() async {
    try {
      _items.clear();
      _lastClipboardContent.value = '';

      // 异步清空存储
      Timer.run(() async {
        try {
          await _storageService.clearClipboardHistory();
          print('💾 Hive 历史记录已异步清空');
        } catch (e) {
          print('⚠️ 异步清空失败: $e');
        }
      });

      print('🗑️ 内存中的剪贴板历史已清空');
    } catch (e) {
      print('❌ 清空历史记录失败: $e');
    }
  }

  /// 获取筛选后的项目列表
  List<ClipboardItem> getFilteredItems(String query) {
    if (query.isEmpty) {
      return _items.toList();
    }

    return _items
        .where(
          (item) => item.content.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();
  }

  /// 更新最后的剪贴板内容
  void updateLastClipboardContent(String content) {
    _lastClipboardContent.value = content;
  }

  /// 生成唯一ID
  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        (DateTime.now().microsecond % 1000).toString();
  }

  /// 获取数据变化流（用于响应式更新）
  Stream<List<ClipboardItem>> get itemsStream => _items.stream;

  /// 强制刷新（给子窗口用，但实际上不需要重新加载）
  Future<void> refreshData() async {
    print('🔄 DataManager: 数据刷新请求（使用内存数据）');
    // 只是触发一下 UI 更新，数据已经在内存中了
    _items.refresh();
    print('✅ DataManager: 内存数据已刷新，${_items.length} 条记录');
  }
}
