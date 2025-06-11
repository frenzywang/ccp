import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'window_service.dart';
import '../models/hotkey_config.dart';

class HotkeyService {
  static final HotkeyService _instance = HotkeyService._internal();
  factory HotkeyService() => _instance;
  HotkeyService._internal();

  HotKey? _currentHotkey;
  void Function()? _onHotkeyPressed;

  // 防抖控制
  Timer? _debounceTimer;
  bool _isHotkeyProcessing = false;

  // Hive box
  Box<HotkeyConfig>? _hotkeyBox;
  HotkeyConfig? _currentConfig;

  // Default hotkey: Cmd+Shift+V
  String _defaultKeyCode = 'KeyV';
  List<HotKeyModifier> _defaultModifiers = [
    HotKeyModifier.meta,
    HotKeyModifier.shift,
  ];

  Future<void> initialize() async {
    await _initializeHive();
    await _loadHotkeyConfig();
    await _registerHotkey();
  }

  Future<void> _initializeHive() async {
    try {
      // 注册适配器（如果还没注册）
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(HotkeyConfigAdapter());
      }

      // 打开 box
      if (!Hive.isBoxOpen('hotkey_settings')) {
        _hotkeyBox = await Hive.openBox<HotkeyConfig>('hotkey_settings');
        print('📦 Hive hotkey box 已打开: hotkey_settings');
      } else {
        _hotkeyBox = Hive.box<HotkeyConfig>('hotkey_settings');
        print('📦 使用已存在的 Hive hotkey box: hotkey_settings');
      }
    } catch (e) {
      print('❌ 初始化热键 Hive 失败: $e');
    }
  }

  Future<void> _loadHotkeyConfig() async {
    try {
      if (_hotkeyBox == null) {
        print('⚠️ Hive box 未初始化，使用默认配置');
        _setDefaultConfig();
        return;
      }

      // 从 Hive 获取配置
      _currentConfig = _hotkeyBox!.get('hotkey_config');

      if (_currentConfig == null) {
        print('📝 未找到热键配置，创建默认配置');
        _currentConfig = HotkeyConfig.defaultConfig();
        await _hotkeyBox!.put('hotkey_config', _currentConfig!);
      }

      _defaultKeyCode = _currentConfig!.keyCode;
      _defaultModifiers = _currentConfig!.hotKeyModifiers;

      print('✅ 热键配置加载成功: ${_currentConfig!.getDescription()}');
    } catch (e) {
      print('❌ 加载热键配置失败: $e');
      _setDefaultConfig();
    }
  }

  void _setDefaultConfig() {
    _defaultKeyCode = 'KeyV';
    _defaultModifiers = [HotKeyModifier.meta, HotKeyModifier.shift];
  }

  Future<void> saveHotkeyConfig(
    String keyCode,
    List<HotKeyModifier> modifiers,
  ) async {
    try {
      if (_hotkeyBox == null) {
        print('⚠️ Hive box 未初始化，无法保存配置');
        return;
      }

      // 创建新的配置对象
      final newConfig = HotkeyConfig(
        keyCode: keyCode,
        modifiers: HotkeyConfig.modifiersToStrings(modifiers),
      );

      // 保存到 Hive
      await _hotkeyBox!.put('hotkey_config', newConfig);
      _currentConfig = newConfig;

      _defaultKeyCode = keyCode;
      _defaultModifiers = modifiers;

      print('✅ 热键配置已保存: ${newConfig.getDescription()}');

      // 先清理再重新注册
      await _cleanupAndRegister();
    } catch (e) {
      print('❌ 保存热键配置失败: $e');
    }
  }

  Future<void> _cleanupAndRegister() async {
    print('🔄 重新配置热键...');

    // 1. 取消防抖定时器
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isHotkeyProcessing = false;

    // 2. 清理旧热键
    await _unregisterHotkey();

    // 3. 等待一下确保清理完成
    await Future.delayed(const Duration(milliseconds: 300));

    // 4. 注册新热键
    await _registerHotkey();
  }

  Future<void> _registerHotkey() async {
    try {
      print('🔑 注册热键: ${getHotkeyDescription()}');

      // 使用PhysicalKeyboardKey替代LogicalKeyboardKey以保持一致性
      _currentHotkey = HotKey(
        key: _getPhysicalKey(_defaultKeyCode),
        modifiers: _defaultModifiers,
        scope: HotKeyScope.system,
      );

      await hotKeyManager.register(
        _currentHotkey!,
        keyDownHandler: (hotKey) {
          print('🔥 热键触发: ${hotKey.key} + ${hotKey.modifiers}');
          _handleHotkeyWithDebounce();
        },
      );

      print('✅ 热键注册成功: ${getHotkeyDescription()}');
    } catch (e) {
      print('❌ 热键注册失败: $e');
      rethrow;
    }
  }

  void _handleHotkeyWithDebounce() {
    print('🎯 热键处理函数被调用');

    // 如果正在处理热键，忽略新的触发
    if (_isHotkeyProcessing) {
      print('⚠️ 热键正在处理中，忽略此次触发...');
      return;
    }

    print('⏰ 设置防抖定时器...');

    // 取消之前的防抖定时器
    _debounceTimer?.cancel();

    // 设置新的防抖定时器
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      print('✨ 防抖定时器触发，开始显示剪贴板历史');
      _isHotkeyProcessing = true;

      // 调用回调或默认行为
      if (_onHotkeyPressed != null) {
        _onHotkeyPressed!();
      } else {
        _showClipboardHistory();
      }

      // 延迟重置处理状态，避免快速连续触发
      Timer(const Duration(milliseconds: 500), () {
        _isHotkeyProcessing = false;
        print('🔄 热键处理状态已重置');
      });
    });
  }

  Future<void> _showClipboardHistory() async {
    try {
      await WindowService().showClipboardHistory();
      print('✅ 剪贴板历史显示完成');
    } catch (e) {
      print('❌ 显示剪贴板历史出错: $e');
      _isHotkeyProcessing = false;
    }
  }

  Future<void> _unregisterHotkey() async {
    print('🧹 开始清理热键...');

    // 方法1: 清理当前热键
    if (_currentHotkey != null) {
      try {
        await hotKeyManager.unregister(_currentHotkey!);
        print('✓ 当前热键已取消注册');
      } catch (e) {
        print('⚠️ 取消当前热键失败: $e');
      }
      _currentHotkey = null;
    }

    // 方法2: 清理所有热键（保险起见）
    try {
      await hotKeyManager.unregisterAll();
      print('✓ 所有热键已清理');
    } catch (e) {
      print('⚠️ 清理所有热键失败: $e');
    }
  }

  void setHotkeyHandler(void Function() handler) {
    _onHotkeyPressed = handler;
  }

  // 使用PhysicalKeyboardKey替代LogicalKeyboardKey
  PhysicalKeyboardKey _getPhysicalKey(String keyCode) {
    final keyMap = {
      'KeyV': PhysicalKeyboardKey.keyV,
      'KeyC': PhysicalKeyboardKey.keyC,
      'KeyX': PhysicalKeyboardKey.keyX,
      'KeyZ': PhysicalKeyboardKey.keyZ,
      'KeyS': PhysicalKeyboardKey.keyS,
      'KeyA': PhysicalKeyboardKey.keyA,
      'KeyD': PhysicalKeyboardKey.keyD,
      'KeyF': PhysicalKeyboardKey.keyF,
      'KeyG': PhysicalKeyboardKey.keyG,
      'KeyH': PhysicalKeyboardKey.keyH,
      'KeyJ': PhysicalKeyboardKey.keyJ,
      'KeyK': PhysicalKeyboardKey.keyK,
      'KeyL': PhysicalKeyboardKey.keyL,
      'KeyQ': PhysicalKeyboardKey.keyQ,
      'KeyW': PhysicalKeyboardKey.keyW,
      'KeyE': PhysicalKeyboardKey.keyE,
      'KeyR': PhysicalKeyboardKey.keyR,
      'KeyT': PhysicalKeyboardKey.keyT,
      'KeyY': PhysicalKeyboardKey.keyY,
      'KeyU': PhysicalKeyboardKey.keyU,
      'KeyI': PhysicalKeyboardKey.keyI,
      'KeyO': PhysicalKeyboardKey.keyO,
      'KeyP': PhysicalKeyboardKey.keyP,
    };
    return keyMap[keyCode] ?? PhysicalKeyboardKey.keyV; // Default to 'V'
  }

  // 保留LogicalKeyboardKey方法供设置窗口使用
  LogicalKeyboardKey _getLogicalKey(String keyCode) {
    final keyMap = {
      'KeyV': LogicalKeyboardKey.keyV,
      'KeyC': LogicalKeyboardKey.keyC,
      'KeyX': LogicalKeyboardKey.keyX,
      'KeyZ': LogicalKeyboardKey.keyZ,
      'KeyS': LogicalKeyboardKey.keyS,
      'KeyA': LogicalKeyboardKey.keyA,
      'KeyD': LogicalKeyboardKey.keyD,
      'KeyF': LogicalKeyboardKey.keyF,
      'KeyG': LogicalKeyboardKey.keyG,
      'KeyH': LogicalKeyboardKey.keyH,
      'KeyJ': LogicalKeyboardKey.keyJ,
      'KeyK': LogicalKeyboardKey.keyK,
      'KeyL': LogicalKeyboardKey.keyL,
      'KeyQ': LogicalKeyboardKey.keyQ,
      'KeyW': LogicalKeyboardKey.keyW,
      'KeyE': LogicalKeyboardKey.keyE,
      'KeyR': LogicalKeyboardKey.keyR,
      'KeyT': LogicalKeyboardKey.keyT,
      'KeyY': LogicalKeyboardKey.keyY,
      'KeyU': LogicalKeyboardKey.keyU,
      'KeyI': LogicalKeyboardKey.keyI,
      'KeyO': LogicalKeyboardKey.keyO,
      'KeyP': LogicalKeyboardKey.keyP,
    };
    return keyMap[keyCode] ?? LogicalKeyboardKey.keyV; // Default to 'V'
  }

  String getHotkeyDescription() {
    if (_currentConfig != null) {
      return _currentConfig!.getDescription();
    }

    // 回退到默认实现
    final modifierText = _defaultModifiers
        .map((modifier) {
          switch (modifier) {
            case HotKeyModifier.meta:
              return 'Cmd';
            case HotKeyModifier.shift:
              return 'Shift';
            case HotKeyModifier.alt:
              return 'Alt';
            case HotKeyModifier.control:
              return 'Ctrl';
            default:
              return '';
          }
        })
        .join(' + ');

    final key = _defaultKeyCode.replaceAll('Key', '');
    return '$modifierText + $key';
  }

  void dispose() {
    print('🧹 HotkeyService: 开始清理资源...');

    // 取消防抖定时器
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _isHotkeyProcessing = false;

    // 清理热键
    _unregisterHotkey();

    // 关闭 Hive box
    _hotkeyBox?.close();
    _hotkeyBox = null;

    print('✓ HotkeyService: 资源清理完成');
  }
}
