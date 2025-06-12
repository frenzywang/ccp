import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'dart:convert';
import '../main.dart';
import '../widgets/settings_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:get/get.dart';
import '../controllers/clipboard_controller.dart';
import 'keyboard_service.dart';
import 'hotkey_service.dart';
import 'clipboard_service.dart';

// 自动粘贴的实现选项
enum PasteMethod {
  disabled('禁用自动粘贴'),
  swiftNative('自动粘贴（推荐）');

  const PasteMethod(this.displayName);
  final String displayName;
}

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  /// 显示剪贴板历史窗口（快捷键触发）
  /// 显示窗口但不抢夺焦点，保持原应用的输入焦点用于自动粘贴
  Future<void> showClipboardHistory() async {
    print('🚀 WindowService.showClipboardHistory() - 显示窗口（不抢夺焦点）');

    try {
      // 检查窗口当前状态
      final isVisible = await windowManager.isVisible();
      final isMinimized = await windowManager.isMinimized();
      print('🔍 窗口当前状态: 可见=$isVisible, 最小化=$isMinimized');

      if (isVisible) {
        print('⚠️ 窗口已经可见，先隐藏再显示');
        await windowManager.hide();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 显示窗口
      await windowManager.show();

      // 等待一下确保窗口显示
      await Future.delayed(const Duration(milliseconds: 50));

      // 再次检查状态
      final isVisibleAfter = await windowManager.isVisible();
      print('🔍 显示后窗口状态: 可见=$isVisibleAfter');

      if (!isVisibleAfter) {
        print('❌ 窗口显示失败，尝试强制显示');
        // 尝试其他方法
        await windowManager.restore();
        await windowManager.show();
      }

      print('✅ 窗口已显示，原应用焦点已保持');
    } catch (e) {
      print('❌ 显示剪贴板历史窗口时出错: $e');
    }
  }

  /// 隐藏剪贴板历史窗口
  /// 使用window_manager隐藏主窗口
  Future<void> hideClipboardHistory() async {
    print('🙈 隐藏剪贴板历史窗口');
    try {
      // 隐藏窗口
      await windowManager.hide();

      // 重置热键处理状态，确保下次可以正常显示
      try {
        HotkeyService().resetHotkeyProcessingState();
      } catch (e) {
        print('⚠️ 重置热键状态失败: $e');
      }

      print('✅ 剪贴板历史窗口已隐藏');
    } catch (e) {
      print('❌ 隐藏窗口时出错: $e');
    }
  }

  /// 选择并粘贴剪贴板项目（通过系统级热键触发）
  Future<void> selectClipboardItem(int index) async {
    print('🎯 selectClipboardItem: 选择第${index + 1}项');

    try {
      // 通过 Get 获取控制器
      final controller = Get.find<ClipboardController>();
      final items = controller.items;

      if (index < items.length) {
        final item = items[index];
        print(
          '📋 选择的项目: ${item.content.substring(0, item.content.length > 30 ? 30 : item.content.length)}...',
        );

        // 1. 复制到剪贴板
        await controller.copyToClipboard(item.content);
        print('📋 内容已复制到剪贴板');

        // 2. 隐藏窗口
        await hideClipboardHistory();

        // 3. 模拟粘贴
        await simulatePaste();
        print('🎉 自动粘贴完成');
      } else {
        print('⚠️ 选择的索引超出范围: $index >= ${items.length}');
      }
    } catch (e) {
      print('❌ 选择剪贴板项目失败: $e');
    }
  }

  /// 将设置显示为对话框
  void showSettingsDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) {
      print('❌ 无法显示设置对话框：navigator context为null');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true, // 点击外部可关闭
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: SettingsWindow(
          onClose: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  // 为了兼容性保留这个方法
  void showSettings() {
    showSettingsDialog();
  }

  Future<void> closeClipboardHistory() async {
    // 改为隐藏而不是关闭
    await hideClipboardHistory();
  }

  Future<void> dispose() async {
    print('✓ Window service disposed');
  }

  // 当前使用的粘贴方法（默认使用Swift Native）
  PasteMethod _currentPasteMethod = PasteMethod.swiftNative;

  // 从 main.dart 移动过来的模拟粘贴功能
  Future<void> simulatePaste() async {
    switch (_currentPasteMethod) {
      case PasteMethod.disabled:
        print('🚫 自动粘贴已禁用，内容已复制到剪贴板，请手动使用 Cmd+V 粘贴');
        // 可以考虑添加一个系统通知
        _showPasteNotification();
        break;

      case PasteMethod.swiftNative:
        await _simulatePasteWithSwiftNative();
        break;
    }
  }

  // 显示粘贴提示通知
  void _showPasteNotification() {
    // 这里可以添加系统通知或其他提示方式
    print('💡 提示：内容已复制到剪贴板，请手动按 Cmd+V 粘贴');
  }

  // 使用 Swift Native Method Channel 模拟粘贴
  Future<void> _simulatePasteWithSwiftNative() async {
    try {
      print('🍝 使用 Swift Native Method Channel 模拟 Cmd+V...');

      // 暂停剪贴板监听，防止自动粘贴操作被监听器捕获
      try {
        final clipboardService = ClipboardService();
        clipboardService.pauseWatching(milliseconds: 3000); // 暂停3秒
        print('⏸️ 已暂停剪贴板监听，防止干扰');
      } catch (e) {
        print('⚠️ 暂停剪贴板监听失败: $e');
      }

      // 等待窗口完全隐藏
      await Future.delayed(const Duration(milliseconds: 200));
      print('🍝 窗口已隐藏');

      // 调用 Swift 端的键盘模拟
      final success = await KeyboardService.simulatePaste();

      if (success) {
        print('✅ Swift Native 粘贴成功');
      } else {
        print('❌ Swift Native 粘贴失败，回退到禁用状态');
        _currentPasteMethod = PasteMethod.disabled;
        print('🔄 自动切换到禁用粘贴模式');
      }
    } catch (e) {
      print('💥 Swift Native 模拟粘贴异常: $e');
      // 如果 Swift Native 失败，回退到禁用状态
      _currentPasteMethod = PasteMethod.disabled;
      print('🔄 自动切换到禁用粘贴模式');
    }
  }

  // 设置粘贴方法
  void setPasteMethod(PasteMethod method) {
    _currentPasteMethod = method;
    print('🔧 粘贴方法已设置为: ${method.displayName}');
  }

  // 获取当前粘贴方法
  PasteMethod get currentPasteMethod => _currentPasteMethod;
}
