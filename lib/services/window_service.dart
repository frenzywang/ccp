import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:get/get.dart';
import '../controllers/clipboard_controller.dart';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  bool _isSettingsWindowOpen = false;
  int? _historyWindowId;
  int? _settingsWindowId;
  WindowController? _historyWindowController;
  WindowController? _settingsWindowController;

  // 添加一个定时器来定期更新持久窗口的数据
  Timer? _dataUpdateTimer;

  bool get isSettingsWindowOpen => _isSettingsWindowOpen;

  /// 初始化窗口服务：不创建窗口，只初始化服务
  Future<void> initialize() async {
    debugPrint('🚀 WindowService.initialize() - 初始化服务...');
    // 移除启动时创建窗口，改为按需创建
    debugPrint('✓ Multi-window service initialized');
  }

  /// 创建持久的剪贴板历史窗口（启动时执行一次）
  Future<void> _createPersistentClipboardWindow() async {
    try {
      debugPrint('📝 创建持久剪贴板历史窗口...');

      final window = await DesktopMultiWindow.createWindow(
        jsonEncode({
          'windowType': 'clipboard_history',
          'title': 'Clipboard History',
        }),
      );

      _historyWindowId = window.windowId;
      _historyWindowController = window;
      debugPrint('🆔 持久窗口创建成功，ID: $_historyWindowId');

      debugPrint('⚙️ 设置窗口属性...');
      await window.setFrame(const Offset(0, 0) & const Size(500, 700));
      await window.center();
      await window.setTitle('Clipboard History');

      debugPrint('✅ 持久剪贴板历史窗口创建完成');
    } catch (e) {
      debugPrint('❌ 创建持久剪贴板历史窗口失败: $e');
    }
  }

  /// 显示剪贴板历史窗口（快捷键触发）
  Future<void> showClipboardHistory() async {
    debugPrint('🚀 WindowService.showClipboardHistory() - 显示窗口');
    try {
      // 如果窗口控制器不存在，说明是第一次或者被销毁了，需要创建
      if (_historyWindowController == null || _historyWindowId == null) {
        debugPrint('🆕 窗口不存在，开始创建...');
        await _createPersistentClipboardWindow();
        // 如果创建后控制器仍然是 null，说明创建失败
        if (_historyWindowController == null) {
          debugPrint('❌ 创建窗口失败，退出');
          return;
        }
        debugPrint('✅ 新窗口创建成功');
      }

      // 不论是新创建的还是已存在的，都执行显示和居中操作
      // show() 方法能将隐藏的窗口显示出来，或将已显示的窗口带到前台
      debugPrint('👁️ 显示窗口 (ID: $_historyWindowId)');
      await _historyWindowController!.show();
      await _historyWindowController!.center();
      debugPrint('✅ 窗口已显示并居中');
    } catch (e) {
      debugPrint('❌ 显示剪贴板历史窗口时出错: $e');
      // 出错时重置状态，以便下次可以重新创建
      _historyWindowController = null;
      _historyWindowId = null;
    }
  }

  /// 隐藏剪贴板历史窗口
  Future<void> hideClipboardHistory() async {
    debugPrint('🙈 隐藏剪贴板历史窗口');

    if (_historyWindowController != null) {
      try {
        await _historyWindowController!.hide();
        debugPrint('✅ 剪贴板历史窗口已隐藏');
      } catch (e) {
        debugPrint('❌ 隐藏窗口时出错: $e');
      }
    }
  }

  Future<void> showSettings() async {
    if (_isSettingsWindowOpen && _settingsWindowId != null) {
      // 尝试激活已存在的窗口
      try {
        final window = WindowController.fromWindowId(_settingsWindowId!);
        await window.show();
        debugPrint('Activated existing settings window');
        return;
      } catch (e) {
        debugPrint('Failed to activate existing settings window: $e');
        // 如果激活失败，继续创建新窗口
        _isSettingsWindowOpen = false;
        _settingsWindowId = null;
      }
    }

    try {
      final window = await DesktopMultiWindow.createWindow(
        jsonEncode({'windowType': 'settings', 'title': 'Settings'}),
      );

      _settingsWindowId = window.windowId;
      _settingsWindowController = window;

      // 设置窗口属性
      await window.setFrame(const Offset(0, 0) & const Size(600, 500));
      await window.center();
      await window.setTitle('Settings');

      // 显示窗口 - show() 方法会自动将窗口带到前面
      await window.show();

      _isSettingsWindowOpen = true;
      debugPrint('✓ Settings window created and shown');
    } catch (e) {
      debugPrint('Error creating settings window: $e');
    }
  }

  Future<void> closeClipboardHistory() async {
    // 改为隐藏而不是关闭
    await hideClipboardHistory();
  }

  Future<void> closeSettings() async {
    if (_isSettingsWindowOpen && _settingsWindowId != null) {
      try {
        final window = WindowController.fromWindowId(_settingsWindowId!);
        await window.close();
        _isSettingsWindowOpen = false;
        _settingsWindowId = null;
        _settingsWindowController = null;
        debugPrint('✓ Settings window closed');
      } catch (e) {
        debugPrint('Error closing settings window: $e');
      }
    }
  }

  Future<void> dispose() async {
    // 停止定时器
    _dataUpdateTimer?.cancel();
    _dataUpdateTimer = null;

    // 真正关闭窗口（应用退出时）
    if (_historyWindowController != null) {
      try {
        await _historyWindowController!.close();
        debugPrint('✓ Persistent clipboard window closed');
      } catch (e) {
        debugPrint('Error closing persistent clipboard window: $e');
      }
    }
    await closeSettings();
  }

  void resetSettingsWindowState() {
    _isSettingsWindowOpen = false;
    _settingsWindowId = null;
    _settingsWindowController = null;
    debugPrint('Settings window state has been reset');
  }

  // 从 main.dart 移动过来的模拟粘贴功能
  Future<void> simulatePaste() async {
    if (Platform.isMacOS) {
      try {
        debugPrint('🍝 开始模拟 Cmd+V 按键...');

        // 等待窗口完全关闭并找到前台应用
        await Future.delayed(const Duration(milliseconds: 800));

        debugPrint('📝 使用 key code 9 直接模拟 Cmd+V...');

        // 方案1: 直接使用 key code
        final result = await Process.run('osascript', [
          '-e',
          'tell application "System Events" to key code 9 using command down',
        ]);

        debugPrint('📤 key code 方案退出码: ${result.exitCode}');

        if (result.exitCode == 0) {
          debugPrint('✅ Cmd+V 按键模拟成功');
        } else {
          debugPrint('❌ key code 方案失败，尝试备用方案...');
          debugPrint('stderr: ${result.stderr}');

          // 方案2: 激活前台应用后发送按键
          final result2 = await Process.run('osascript', [
            '-e',
            '''
          tell application "System Events"
            set frontApp to name of first application process whose frontmost is true
            tell application frontApp to activate
            delay 0.2
            key code 9 using command down
          end tell
          ''',
          ]);

          if (result2.exitCode == 0) {
            debugPrint('✅ 备用方案成功');
          } else {
            debugPrint('❌ 备用方案也失败: ${result2.stderr}');

            // 方案3: 使用 keystroke
            final result3 = await Process.run('osascript', [
              '-e',
              'tell application "System Events" to keystroke "v" using command down',
            ]);

            if (result3.exitCode == 0) {
              debugPrint('✅ keystroke 方案成功');
            } else {
              debugPrint('❌ 所有方案都失败了: ${result3.stderr}');
            }
          }
        }
      } catch (e) {
        debugPrint('💥 模拟按键异常: $e');
      }
    } else {
      debugPrint('⚠️ 非macOS平台，跳过模拟粘贴');
    }
  }
}
