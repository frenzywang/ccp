import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:async';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  bool _isHistoryWindowOpen = false;
  bool _isSettingsWindowOpen = false;
  int? _historyWindowId;
  int? _settingsWindowId;

  bool get isHistoryWindowOpen => _isHistoryWindowOpen;
  bool get isSettingsWindowOpen => _isSettingsWindowOpen;

  Future<void> initialize() async {
    print('✓ Multi-window service initialized');
  }

  Future<void> showClipboardHistory() async {
    print('🚀 WindowService.showClipboardHistory() 被调用');
    print('showClipboardHistory: 准备创建新窗口...');

    try {
      // 如果之前有窗口，先尝试关闭
      if (_historyWindowId != null) {
        print('发现旧窗口ID: $_historyWindowId，尝试关闭...');
        try {
          final oldWindow = WindowController.fromWindowId(_historyWindowId!);
          await oldWindow.close();
          print('✅ 已关闭旧窗口: $_historyWindowId');
        } catch (e) {
          print('⚠️ 旧窗口可能已关闭: $e');
        }
      } else {
        print('✨ 没有旧窗口，直接创建新窗口');
      }

      // 总是创建新窗口
      print('📝 开始创建新的剪贴板历史窗口...');
      final window = await DesktopMultiWindow.createWindow(
        jsonEncode({
          'windowType': 'clipboard_history',
          'title': 'Clipboard History',
        }),
      );

      _historyWindowId = window.windowId;
      print('🆔 新窗口创建成功，ID: ${_historyWindowId}');

      // 设置窗口属性
      print('⚙️ 设置窗口属性...');
      await window.setFrame(const Offset(0, 0) & const Size(400, 600));
      await window.center();
      await window.setTitle('Clipboard History');

      // 显示窗口
      print('👁️ 显示窗口...');
      await window.show();

      _isHistoryWindowOpen = true;
      print('✅ 剪贴板历史窗口创建和显示完成！');
    } catch (e) {
      print('❌ 创建剪贴板历史窗口时出错: $e');
      print('错误堆栈: ${e.toString()}');
      // 确保失败时重置状态
      _isHistoryWindowOpen = false;
      _historyWindowId = null;
    }
  }

  Future<void> showSettings() async {
    if (_isSettingsWindowOpen && _settingsWindowId != null) {
      // 尝试激活已存在的窗口
      try {
        final window = WindowController.fromWindowId(_settingsWindowId!);
        await window.show();
        print('Activated existing settings window');
        return;
      } catch (e) {
        print('Failed to activate existing settings window: $e');
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

      // 设置窗口属性
      await window.setFrame(const Offset(0, 0) & const Size(600, 500));
      await window.center();
      await window.setTitle('Settings');

      // 显示窗口 - show() 方法会自动将窗口带到前面
      await window.show();

      _isSettingsWindowOpen = true;
      print('✓ Settings window created and shown');
    } catch (e) {
      print('Error creating settings window: $e');
    }
  }

  Future<void> closeClipboardHistory() async {
    if (_isHistoryWindowOpen && _historyWindowId != null) {
      try {
        final window = WindowController.fromWindowId(_historyWindowId!);
        await window.close();
        _isHistoryWindowOpen = false;
        _historyWindowId = null;
        print('✓ Clipboard history window closed');
      } catch (e) {
        print('Error closing clipboard history window: $e');
      }
    }
  }

  Future<void> closeSettings() async {
    if (_isSettingsWindowOpen && _settingsWindowId != null) {
      try {
        final window = WindowController.fromWindowId(_settingsWindowId!);
        await window.close();
        _isSettingsWindowOpen = false;
        _settingsWindowId = null;
        print('✓ Settings window closed');
      } catch (e) {
        print('Error closing settings window: $e');
      }
    }
  }

  Future<void> dispose() async {
    await closeClipboardHistory();
    await closeSettings();
  }

  // 添加重置状态的公共方法
  void resetHistoryWindowState() {
    _isHistoryWindowOpen = false;
    _historyWindowId = null;
    print('History window state has been reset');
  }

  void resetSettingsWindowState() {
    _isSettingsWindowOpen = false;
    _settingsWindowId = null;
    print('Settings window state has been reset');
  }
}
