import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'dart:async';
import 'window_service.dart';
import 'storage_service.dart';
import '../models/hotkey_config.dart';

class HotkeyService {
  static final HotkeyService _instance = HotkeyService._internal();
  factory HotkeyService() => _instance;
  HotkeyService._internal();

  HotKey? _currentHotkey;
  List<HotKey> _numberHotkeys = []; // 数字热键列表
  void Function()? _onHotkeyPressed;

  // 防抖控制
  Timer? _debounceTimer;
  bool _isHotkeyProcessing = false;

  // 存储服务
  final StorageService _storageService = StorageService();
  HotkeyConfig? _currentConfig;

  // Default hotkey: Cmd+Shift+V
  String _defaultKeyCode = 'KeyV';
  List<HotKeyModifier> _defaultModifiers = [
    HotKeyModifier.meta,
    HotKeyModifier.shift,
  ];

  Future<void> initialize() async {
    await _storageService.initialize();
    await _loadHotkeyConfig();
    await _cleanupAndRegister();
  }

  Future<void> _loadHotkeyConfig() async {
    try {
      // 从存储服务获取配置
      _currentConfig = _storageService.getHotkeyConfig('default_hotkey');

      if (_currentConfig == null) {
        print('📝 未找到热键配置，创建默认配置');
        _currentConfig = HotkeyConfig.defaultConfig();
        await _storageService.saveHotkeyConfig(
          'default_hotkey',
          _currentConfig!,
        );
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
      // 创建新的配置对象
      final newConfig = HotkeyConfig(
        keyCode: keyCode,
        modifiers: HotkeyConfig.modifiersToStrings(modifiers),
      );

      // 保存到存储服务
      await _storageService.saveHotkeyConfig('default_hotkey', newConfig);
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

      // 注册数字热键（Cmd+1 到 Cmd+9, Cmd+0）
      await _registerNumberHotkeys();
    } catch (e) {
      print('❌ 热键注册失败: $e');
      rethrow;
    }
  }

  // 注册数字热键用于选择剪贴板项目
  Future<void> _registerNumberHotkeys() async {
    try {
      print('🔢 注册数字热键...');

      // 先清理已有的数字热键
      await _unregisterNumberHotkeys();

      // 注册 Cmd+1 到 Cmd+9
      for (int i = 1; i <= 9; i++) {
        final hotkey = HotKey(
          key: _getPhysicalKey('Digit$i'),
          modifiers: [HotKeyModifier.meta],
          scope: HotKeyScope.inapp,
        );

        await hotKeyManager.register(
          hotkey,
          keyDownHandler: (hotKey) {
            _handleNumberHotkey(i - 1); // 0-based index
          },
        );

        _numberHotkeys.add(hotkey);
      }

      // 注册 Cmd+0 为第10项
      final hotkey0 = HotKey(
        key: _getPhysicalKey('Digit0'),
        modifiers: [HotKeyModifier.meta],
        scope: HotKeyScope.inapp,
      );

      await hotKeyManager.register(
        hotkey0,
        keyDownHandler: (hotKey) {
          _handleNumberHotkey(9); // 第10项，index为9
        },
      );

      _numberHotkeys.add(hotkey0);

      print('✅ 数字热键注册成功: Cmd+1-9, Cmd+0 (应用级别)');
    } catch (e) {
      print('❌ 数字热键注册失败: $e');
    }
  }

  // 处理数字热键选择
  void _handleNumberHotkey(int index) {
    print('🔢 数字热键触发: 选择第${index + 1}项');

    // 这里需要调用控制器来选择并粘贴对应的项目
    // 由于是系统级热键，我们需要通过 WindowService 来处理
    WindowService().selectClipboardItem(index);
  }

  // 清理数字热键
  Future<void> _unregisterNumberHotkeys() async {
    for (final hotkey in _numberHotkeys) {
      try {
        await hotKeyManager.unregister(hotkey);
      } catch (e) {
        print('⚠️ 清理数字热键失败: $e');
      }
    }
    _numberHotkeys.clear();
    print('✓ 数字热键已清理');
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

      // 缩短重置时间，避免阻塞后续操作
      Timer(const Duration(milliseconds: 300), () {
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
      // 出错时立即重置状态
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

    // 清理数字热键
    await _unregisterNumberHotkeys();

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
      // 添加数字键映射
      'Digit0': PhysicalKeyboardKey.digit0,
      'Digit1': PhysicalKeyboardKey.digit1,
      'Digit2': PhysicalKeyboardKey.digit2,
      'Digit3': PhysicalKeyboardKey.digit3,
      'Digit4': PhysicalKeyboardKey.digit4,
      'Digit5': PhysicalKeyboardKey.digit5,
      'Digit6': PhysicalKeyboardKey.digit6,
      'Digit7': PhysicalKeyboardKey.digit7,
      'Digit8': PhysicalKeyboardKey.digit8,
      'Digit9': PhysicalKeyboardKey.digit9,
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
      // 添加数字键映射
      'Digit0': LogicalKeyboardKey.digit0,
      'Digit1': LogicalKeyboardKey.digit1,
      'Digit2': LogicalKeyboardKey.digit2,
      'Digit3': LogicalKeyboardKey.digit3,
      'Digit4': LogicalKeyboardKey.digit4,
      'Digit5': LogicalKeyboardKey.digit5,
      'Digit6': LogicalKeyboardKey.digit6,
      'Digit7': LogicalKeyboardKey.digit7,
      'Digit8': LogicalKeyboardKey.digit8,
      'Digit9': LogicalKeyboardKey.digit9,
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

    print('✓ HotkeyService: 资源清理完成');
  }

  // 添加一个方法来手动重置热键处理状态
  void resetHotkeyProcessingState() {
    _isHotkeyProcessing = false;
    print('👋 手动重置热键处理状态');
  }
}
