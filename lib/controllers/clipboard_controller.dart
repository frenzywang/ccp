import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../models/clipboard_item.dart';
import '../services/storage_service.dart';
import '../services/clipboard_service.dart';
import '../services/window_channel_service.dart';
import 'package:flutter/services.dart';

class ClipboardController extends GetxController {
  // 数据存储 - Controller 直接管理数据
  final RxList<ClipboardItem> _items = <ClipboardItem>[].obs;
  final RxList<ClipboardItem> _filteredItems = <ClipboardItem>[].obs;
  final RxString _searchQuery = ''.obs;
  final RxString _lastClipboardContent = ''.obs;
  final RxBool _isInitialized = false.obs;

  // 服务实例
  StorageService? _storageService;
  final WindowChannelService _channelService = WindowChannelService();

  // 进程类型标识（由main.dart设置）
  static bool _isMainProcessFlag = true;
  static void setProcessType({required bool isMainProcess}) {
    _isMainProcessFlag = isMainProcess;
  }

  bool get _isMainProcess => _isMainProcessFlag;

  @override
  void onInit() {
    super.onInit();
    debugPrint('🎮 ClipboardController: 初始化');
    _initializeController();
  }

  // Getters
  List<ClipboardItem> get items => _items;
  List<ClipboardItem> get filteredItems => _filteredItems;
  String get searchQuery => _searchQuery.value;
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.length;
  bool get isInitialized => _isInitialized.value;

  /// 初始化控制器
  Future<void> _initializeController() async {
    try {
      // 检查是否为主进程（有 StorageService）
      bool isMainProcess = await _initializeAsMainProcess();

      if (!isMainProcess) {
        // 子进程：通过 Channel 从主进程获取数据
        await _initializeAsSubProcess();
      }

      _isInitialized.value = true;
      debugPrint('✅ ClipboardController: 初始化完成');
    } catch (e) {
      debugPrint('❌ ClipboardController 初始化失败: $e');
    }
  }

  /// 尝试作为主进程初始化
  Future<bool> _initializeAsMainProcess() async {
    try {
      _storageService = StorageService();
      await _storageService!.initialize();

      // 从存储加载数据
      final items = _storageService!.loadClipboardItems();
      _items.assignAll(items);
      _applyFilter();

      // 设置Channel处理器，为子进程提供数据
      _channelService.setupMainProcess(() => _items.toList());

      debugPrint('✅ 主进程：从存储加载了 ${items.length} 条数据，已设置Channel处理器');
      return true;
    } catch (e) {
      debugPrint('⚠️ 非主进程或存储初始化失败: $e');
      return false;
    }
  }

  /// 作为子进程初始化
  Future<void> _initializeAsSubProcess() async {
    try {
      // 子进程：请求主进程数据
      await _requestDataFromMainProcess();
      debugPrint('✅ 子进程：通过Channel获取数据完成');
    } catch (e) {
      debugPrint('❌ 子进程数据获取失败: $e');
    }
  }

  /// 请求主进程数据（Channel 通信）
  Future<void> _requestDataFromMainProcess() async {
    try {
      debugPrint('📡 子进程：通过Channel请求主进程数据...');
      final items = await _channelService.requestDataFromMain();
      _items.assignAll(items);
      _applyFilter();
      debugPrint('✅ 子进程：通过Channel获取了 ${items.length} 条数据');
    } catch (e) {
      debugPrint('❌ Channel通信失败，尝试临时方案: $e');
      // 临时方案：从存储加载
      try {
        final tempStorage = StorageService();
        await tempStorage.initialize();
        final items = tempStorage.loadClipboardItems();
        _items.assignAll(items);
        _applyFilter();
        debugPrint('📥 子进程：临时从存储加载了 ${items.length} 条数据');
      } catch (e2) {
        debugPrint('❌ 子进程数据加载完全失败: $e2');
      }
    }
  }

  /// 添加新项目（仅主进程）
  Future<void> addItem(
    String content, {
    ClipboardItemType type = ClipboardItemType.text,
  }) async {
    if (_storageService == null) return; // 只有主进程可以添加

    // 检查是否已存在
    final existingIndex = _items.indexWhere((item) => item.content == content);

    if (existingIndex != -1) {
      // 移动到顶部
      final item = _items.removeAt(existingIndex);
      _items.insert(0, item);
    } else {
      // 添加新项目
      final newItem = ClipboardItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        type: type,
        createdAt: DateTime.now(),
      );
      _items.insert(0, newItem);

      // 限制总数
      if (_items.length > 50) {
        _items.removeRange(50, _items.length);
      }
    }

    // 异步保存到存储
    _saveToStorage();
    _applyFilter();
    _lastClipboardContent.value = content;
  }

  /// 保存到存储
  void _saveToStorage() {
    if (_storageService == null) return;

    Future.microtask(() async {
      try {
        _storageService!.saveClipboardItems(_items);
        debugPrint('💾 数据已保存到存储');
      } catch (e) {
        debugPrint('❌ 保存失败: $e');
      }
    });
  }

  /// 搜索过滤
  void search(String query) {
    _searchQuery.value = query;
    _applyFilter();
  }

  /// 搜索过滤（别名方法）
  void searchItems(String query) {
    search(query);
  }

  /// 应用过滤
  void _applyFilter() {
    if (_searchQuery.value.isEmpty) {
      _filteredItems.assignAll(_items);
    } else {
      final query = _searchQuery.value.toLowerCase();
      final filtered = _items.where((item) {
        return item.content.toLowerCase().contains(query);
      }).toList();
      _filteredItems.assignAll(filtered);
    }
    debugPrint(
      '🔍 过滤结果: ${_filteredItems.length} 条记录 (查询: "${_searchQuery.value}")',
    );
  }

  /// 复制到剪贴板
  Future<void> copyToClipboard(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      debugPrint('📋 内容已复制到剪贴板');
    } catch (e) {
      debugPrint('❌ 复制失败: $e');
    }
  }

  /// 删除项目
  void deleteItem(String id) {
    _items.removeWhere((item) => item.id == id);
    _saveToStorage();
    _applyFilter();
  }

  /// 清空历史
  Future<void> clearHistory() async {
    _items.clear();
    _filteredItems.clear();
    if (_storageService != null) {
      _storageService!.clearClipboardHistory();
    }
    debugPrint('🗑️ 剪贴板历史已清空');
  }

  /// 强制刷新数据
  void refreshData() {
    _applyFilter();
    debugPrint('🔄 ClipboardController: 数据已刷新');
  }

  @override
  void onClose() {
    debugPrint('🔥 ClipboardController: 正在清理资源');
    super.onClose();
  }
}
