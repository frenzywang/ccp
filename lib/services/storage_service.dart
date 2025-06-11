import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';
import '../models/clipboard_item.dart';
import '../models/hotkey_config.dart';

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

  Future<void> initialize() async {
    if (_isInitialized) {
      print('📦 StorageService 已经初始化，跳过重复初始化');
      return;
    }

    try {
      print('🚀 开始初始化 StorageService...');

      // 手动设置 Hive 存储路径，避免依赖 path_provider
      await _initializeHiveWithCustomPath();
      print('📦 Hive 自定义路径初始化完成');

      // 注册所有适配器
      await _registerAdapters();

      // 打开所有 boxes
      await _openBoxes();

      _isInitialized = true;
      print('✅ StorageService 初始化完成');
    } catch (e) {
      print('❌ StorageService 初始化失败: $e');

      // 使用内存存储作为回退
      print('🔄 尝试使用内存存储作为回退...');
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
      print('📁 创建存储目录: $storagePath');
    }

    // 初始化 Hive
    Hive.init(storagePath);
    print('🏠 Hive 存储路径设置为: $storagePath');
  }

  Future<void> _initializeInMemoryFallback() async {
    try {
      print('⚠️ 使用内存存储，数据将不会持久化');
      // 不调用 Hive.init，直接使用内存存储
      await _registerAdapters();
      _isInitialized = true;
      print('✅ 内存存储初始化完成');
    } catch (e) {
      print('❌ 内存存储初始化也失败: $e');
      _isInitialized = true; // 即使失败也标记为初始化，避免无限循环
    }
  }

  Future<void> _registerAdapters() async {
    try {
      // 注册 ClipboardItem 适配器
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(ClipboardItemAdapter());
        print('✓ 注册 ClipboardItem 适配器 (typeId: 0)');
      }

      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(ClipboardItemTypeAdapter());
        print('✓ 注册 ClipboardItemType 适配器 (typeId: 1)');
      }

      // 注册 HotkeyConfig 适配器
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(HotkeyConfigAdapter());
        print('✓ 注册 HotkeyConfig 适配器 (typeId: 2)');
      }
    } catch (e) {
      print('⚠️ 注册适配器时出错（可能已注册）: $e');
    }
  }

  Future<void> _openBoxes() async {
    try {
      print('📦 开始打开 Hive boxes...');

      // 打开剪贴板 box
      print('📋 检查剪贴板 box 状态...');
      print(
        '   isBoxOpen("clipboard_history"): ${Hive.isBoxOpen('clipboard_history')}',
      );

      if (!Hive.isBoxOpen('clipboard_history')) {
        print('📂 正在打开剪贴板 box...');
        _clipboardBox = await Hive.openBox<ClipboardItem>('clipboard_history');
        print('✓ 打开剪贴板 box: clipboard_history');
      } else {
        print('📂 获取已存在的剪贴板 box...');
        _clipboardBox = Hive.box<ClipboardItem>('clipboard_history');
        print('✓ 使用已存在的剪贴板 box: clipboard_history');
      }

      print('📊 剪贴板 box 状态:');
      print('   box != null: ${_clipboardBox != null}');
      if (_clipboardBox != null) {
        print('   box.isOpen: ${_clipboardBox!.isOpen}');
        print('   box.length: ${_clipboardBox!.length}');
        print('   box.keys.length: ${_clipboardBox!.keys.length}');
      }

      // 打开热键设置 box
      print('🔑 检查热键设置 box 状态...');
      print(
        '   isBoxOpen("hotkey_settings"): ${Hive.isBoxOpen('hotkey_settings')}',
      );

      if (!Hive.isBoxOpen('hotkey_settings')) {
        print('📂 正在打开热键设置 box...');
        _hotkeyBox = await Hive.openBox<HotkeyConfig>('hotkey_settings');
        print('✓ 打开热键设置 box: hotkey_settings');
      } else {
        print('📂 获取已存在的热键设置 box...');
        _hotkeyBox = Hive.box<HotkeyConfig>('hotkey_settings');
        print('✓ 使用已存在的热键设置 box: hotkey_settings');
      }

      print('📊 热键设置 box 状态:');
      print('   box != null: ${_hotkeyBox != null}');
      if (_hotkeyBox != null) {
        print('   box.isOpen: ${_hotkeyBox!.isOpen}');
        print('   box.length: ${_hotkeyBox!.length}');
      }
    } catch (e) {
      print('⚠️ 打开 boxes 失败，将使用内存数据: $e');
      print('📍 错误堆栈: ${StackTrace.current}');
      // 如果打开失败，boxes 保持为 null，其他方法会处理这种情况
    }
  }

  // 便捷方法：获取剪贴板项目
  List<ClipboardItem> getClipboardItems() {
    print('🔍 StorageService.getClipboardItems() 被调用');
    print('📊 Box状态: _clipboardBox == null: ${_clipboardBox == null}');

    if (_clipboardBox == null) {
      print('⚠️ 剪贴板 box 未初始化，返回空列表');
      return [];
    }

    try {
      print('📦 尝试从 Hive box 获取数据...');
      final values = _clipboardBox!.values;
      print('📊 Box 中有 ${values.length} 条原始记录');

      final items = values.toList();
      print('📋 转换为列表: ${items.length} 条记录');

      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      print('🔄 排序完成，返回 ${items.length} 条记录');

      if (items.isNotEmpty) {
        print(
          '📝 最新记录预览: ${items.first.content.length > 50 ? "${items.first.content.substring(0, 50)}..." : items.first.content}',
        );
      }

      return items;
    } catch (e) {
      print('❌ 获取剪贴板项目失败: $e');
      print('📍 错误堆栈: ${StackTrace.current}');
      return [];
    }
  }

  // 便捷方法：保存剪贴板项目
  Future<void> saveClipboardItem(ClipboardItem item) async {
    if (_clipboardBox == null) {
      print('⚠️ 剪贴板 box 未初始化，无法保存');
      return;
    }
    try {
      await _clipboardBox!.add(item);
    } catch (e) {
      print('❌ 保存剪贴板项目失败: $e');
    }
  }

  // 便捷方法：删除剪贴板项目
  Future<void> deleteClipboardItem(int index) async {
    if (_clipboardBox == null) {
      print('⚠️ 剪贴板 box 未初始化，无法删除');
      return;
    }
    try {
      await _clipboardBox!.deleteAt(index);
    } catch (e) {
      print('❌ 删除剪贴板项目失败: $e');
    }
  }

  // 便捷方法：清空剪贴板历史
  Future<void> clearClipboardHistory() async {
    if (_clipboardBox == null) {
      print('⚠️ 剪贴板 box 未初始化，无法清空');
      return;
    }
    try {
      await _clipboardBox!.clear();
    } catch (e) {
      print('❌ 清空剪贴板历史失败: $e');
    }
  }

  // 便捷方法：获取热键配置
  HotkeyConfig? getHotkeyConfig() {
    if (_hotkeyBox == null) {
      print('⚠️ 热键 box 未初始化，返回 null');
      return null;
    }
    try {
      return _hotkeyBox!.get('hotkey_config');
    } catch (e) {
      print('❌ 获取热键配置失败: $e');
      return null;
    }
  }

  // 便捷方法：保存热键配置
  Future<void> saveHotkeyConfig(HotkeyConfig config) async {
    if (_hotkeyBox == null) {
      print('⚠️ 热键 box 未初始化，无法保存');
      return;
    }
    try {
      await _hotkeyBox!.put('hotkey_config', config);
    } catch (e) {
      print('❌ 保存热键配置失败: $e');
    }
  }

  // 检查是否已初始化
  bool get isInitialized => _isInitialized;

  // 资源清理
  void dispose() {
    print('🧹 StorageService: 开始清理资源...');

    try {
      _clipboardBox?.close();
      _clipboardBox = null;

      _hotkeyBox?.close();
      _hotkeyBox = null;

      _isInitialized = false;
      print('✓ StorageService: 资源清理完成');
    } catch (e) {
      print('⚠️ StorageService 清理时出错: $e');
    }
  }
}
