import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import '../models/clipboard_item.dart';
import '../models/hotkey_config.dart';

/// 纯存储服务，只负责 Hive 存储操作
/// 不涉及内存数据管理和业务逻辑
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  bool _isInitialized = false;

  // Hive boxes
  Box<ClipboardItem>? _clipboardBox;
  Box<HotkeyConfig>? _hotkeyBox;

  // Getters for boxes
  Box<ClipboardItem>? get clipboardBox => _clipboardBox;
  Box<HotkeyConfig>? get hotkeyBox => _hotkeyBox;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('📦 StorageService 已经初始化，跳过重复初始化');
      return;
    }

    try {
      // 手动设置 Hive 存储路径，避免依赖 path_provider
      await _initializeHiveWithCustomPath();
      debugPrint('📦 Hive 自定义路径初始化完成');

      // 注册所有适配器
      await _registerAdapters();

      // 打开所有 boxes
      await _openBoxes();

      _isInitialized = true;
      debugPrint('✅ StorageService 初始化完成');
    } catch (e) {
      debugPrint('❌ StorageService 初始化失败: $e');

      // 使用内存存储作为回退
      debugPrint('🔄 尝试使用内存存储作为回退...');
      await _initializeInMemoryFallback();
    }
  }

  Future<void> _initializeHiveWithCustomPath() async {
    String storagePath;

    if (Platform.isMacOS) {
      // macOS: 使用用户主目录下的应用支持目录
      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      storagePath = '$homeDir/Library/Application Support/ccp_clipboard';
    } else if (Platform.isLinux) {
      // Linux: 使用 XDG 配置目录
      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final xdgConfig =
          Platform.environment['XDG_CONFIG_HOME'] ?? '$homeDir/.config';
      storagePath = '$xdgConfig/ccp_clipboard';
    } else if (Platform.isWindows) {
      // Windows: 使用 APPDATA 目录
      final appData = Platform.environment['APPDATA'] ?? 'C:\\temp';
      storagePath = '$appData\\ccp_clipboard';
    } else {
      // 其他平台：使用临时目录
      storagePath = '${Directory.systemTemp.path}/ccp_clipboard';
    }

    // 确保目录存在
    final directory = Directory(storagePath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      debugPrint('📁 创建存储目录: $storagePath');
    }

    // 初始化 Hive
    Hive.init(storagePath);
    debugPrint('🏠 Hive 存储路径设置为: $storagePath');
  }

  Future<void> _initializeInMemoryFallback() async {
    try {
      debugPrint('⚠️ 使用内存存储，数据将不会持久化');
      // 不调用 Hive.init，直接使用内存存储
      await _registerAdapters();
      _isInitialized = true;
      debugPrint('✅ 内存存储初始化完成');
    } catch (e) {
      debugPrint('❌ 内存存储初始化也失败: $e');
      _isInitialized = true; // 即使失败也标记为初始化，避免无限循环
    }
  }

  Future<void> _registerAdapters() async {
    try {
      // 注册 ClipboardItem 适配器
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ClipboardItemAdapter());
        debugPrint('✓ 注册 ClipboardItem 适配器 (typeId: 0)');
      }

      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ClipboardItemTypeAdapter());
        debugPrint('✓ 注册 ClipboardItemType 适配器 (typeId: 1)');
      }

      // 注册 HotkeyConfig 适配器
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(HotkeyConfigAdapter());
        debugPrint('✓ 注册 HotkeyConfig 适配器 (typeId: 2)');
      }
    } catch (e) {
      debugPrint('⚠️ 注册适配器时出错（可能已注册）: $e');
    }
  }

  Future<void> _openBoxes() async {
    try {
      debugPrint('📦 开始打开 Hive boxes...');

      // 打开剪贴板 box
      if (!Hive.isBoxOpen('clipboard_history')) {
        debugPrint('📂 正在打开剪贴板 box...');
        _clipboardBox = await Hive.openBox<ClipboardItem>('clipboard_history');
        debugPrint('✓ 打开剪贴板 box: clipboard_history');
      } else {
        debugPrint('📂 获取已存在的剪贴板 box...');
        _clipboardBox = Hive.box<ClipboardItem>('clipboard_history');
        debugPrint('✓ 使用已存在的剪贴板 box: clipboard_history');
      }

      debugPrint('📊 剪贴板 box 状态: ${_clipboardBox?.length ?? 0} 条记录');

      // 打开热键设置 box
      if (!Hive.isBoxOpen('hotkey_settings')) {
        debugPrint('📂 正在打开热键设置 box...');
        _hotkeyBox = await Hive.openBox<HotkeyConfig>('hotkey_settings');
        debugPrint('✓ 打开热键设置 box: hotkey_settings');
      } else {
        debugPrint('📂 获取已存在的热键设置 box...');
        _hotkeyBox = Hive.box<HotkeyConfig>('hotkey_settings');
        debugPrint('✓ 使用已存在的热键设置 box: hotkey_settings');
      }

      debugPrint('📊 热键设置 box 状态: ${_hotkeyBox?.length ?? 0} 条记录');
    } catch (e) {
      debugPrint('⚠️ 打开 boxes 失败，将使用内存数据: $e');
      // 如果打开失败，boxes 保持为 null，其他方法会处理这种情况
    }
  }

  /// 从存储加载所有剪贴板项目
  List<ClipboardItem> loadClipboardItems() {
    debugPrint('🔍 StorageService.loadClipboardItems() 被调用');

    if (_clipboardBox == null) {
      debugPrint('⚠️ 剪贴板 box 未初始化，返回空列表');
      return [];
    }

    try {
      final values = _clipboardBox!.values;
      debugPrint('📊 从 Hive 读取 ${values.length} 条记录');

      final items = values.toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('✅ 成功加载并排序 ${items.length} 条剪贴板记录');
      return items;
    } catch (e) {
      debugPrint('❌ 从存储加载剪贴板项目失败: $e');
      return [];
    }
  }

  /// 保存剪贴板项目到存储
  Future<void> saveClipboardItem(ClipboardItem item) async {
    if (_clipboardBox == null) {
      debugPrint('⚠️ 剪贴板 box 未初始化，跳过保存');
      return;
    }

    try {
      await _clipboardBox!.put(item.id, item);
      debugPrint('💾 剪贴板项目已保存到 Hive: ${item.id}');
    } catch (e) {
      debugPrint('❌ 保存剪贴板项目失败: $e');
    }
  }

  /// 批量保存剪贴板项目
  Future<void> saveClipboardItems(List<ClipboardItem> items) async {
    if (_clipboardBox == null) {
      debugPrint('⚠️ 剪贴板 box 未初始化，跳过批量保存');
      return;
    }

    try {
      final Map<String, ClipboardItem> itemsMap = {
        for (var item in items) item.id: item,
      };

      await _clipboardBox!.putAll(itemsMap);
      debugPrint('💾 批量保存 ${items.length} 个剪贴板项目到 Hive');
    } catch (e) {
      debugPrint('❌ 批量保存剪贴板项目失败: $e');
    }
  }

  /// 清空剪贴板历史记录
  Future<void> clearClipboardHistory() async {
    if (_clipboardBox == null) {
      debugPrint('⚠️ 剪贴板 box 未初始化，跳过清空');
      return;
    }

    try {
      await _clipboardBox!.clear();
      debugPrint('🗑️ 剪贴板历史记录已从 Hive 清空');
    } catch (e) {
      debugPrint('❌ 清空剪贴板历史记录失败: $e');
    }
  }

  /// 删除指定的剪贴板项目
  Future<void> deleteClipboardItem(String itemId) async {
    if (_clipboardBox == null) {
      debugPrint('⚠️ 剪贴板 box 未初始化，跳过删除');
      return;
    }

    try {
      await _clipboardBox!.delete(itemId);
      debugPrint('🗑️ 剪贴板项目已删除: $itemId');
    } catch (e) {
      debugPrint('❌ 删除剪贴板项目失败: $e');
    }
  }

  // === 热键配置相关方法 ===

  /// 获取热键配置
  HotkeyConfig? getHotkeyConfig(String key) {
    if (_hotkeyBox == null) {
      debugPrint('⚠️ 热键 box 未初始化');
      return null;
    }

    try {
      return _hotkeyBox!.get(key);
    } catch (e) {
      debugPrint('❌ 获取热键配置失败: $e');
      return null;
    }
  }

  /// 保存热键配置
  Future<void> saveHotkeyConfig(String key, HotkeyConfig config) async {
    if (_hotkeyBox == null) {
      debugPrint('⚠️ 热键 box 未初始化，跳过保存');
      return;
    }

    try {
      await _hotkeyBox!.put(key, config);
      debugPrint('🔑 热键配置已保存: $key');
    } catch (e) {
      debugPrint('❌ 保存热键配置失败: $e');
    }
  }

  /// 删除热键配置
  Future<void> deleteHotkeyConfig(String key) async {
    if (_hotkeyBox == null) {
      debugPrint('⚠️ 热键 box 未初始化，跳过删除');
      return;
    }

    try {
      await _hotkeyBox!.delete(key);
      debugPrint('🗑️ 热键配置已删除: $key');
    } catch (e) {
      debugPrint('❌ 删除热键配置失败: $e');
    }
  }

  /// 获取所有热键配置
  Map<String, HotkeyConfig> getAllHotkeyConfigs() {
    if (_hotkeyBox == null) {
      debugPrint('⚠️ 热键 box 未初始化，返回空配置');
      return {};
    }

    try {
      final Map<String, HotkeyConfig> configs = {};
      for (final key in _hotkeyBox!.keys) {
        final config = _hotkeyBox!.get(key);
        if (config != null) {
          configs[key.toString()] = config;
        }
      }

      debugPrint('🔑 获取到 ${configs.length} 个热键配置');
      return configs;
    } catch (e) {
      debugPrint('❌ 获取所有热键配置失败: $e');
      return {};
    }
  }

  /// 关闭存储服务
  Future<void> dispose() async {
    try {
      await _clipboardBox?.close();
      await _hotkeyBox?.close();
      debugPrint('🚪 StorageService 已关闭');
    } catch (e) {
      debugPrint('⚠️ 关闭 StorageService 时出错: $e');
    }
  }
}
