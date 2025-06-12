import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform, Process;
import '../main.dart';
import '../widgets/settings_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:get/get.dart';
import '../controllers/clipboard_controller.dart';

class WindowService {
  static final WindowService _instance = WindowService._internal();
  factory WindowService() => _instance;
  WindowService._internal();

  /// 显示剪贴板历史窗口（快捷键触发）
  /// 显示窗口但不抢夺焦点，保持原应用的输入焦点用于自动粘贴
  Future<void> showClipboardHistory() async {
    debugPrint('🚀 WindowService.showClipboardHistory() - 显示窗口（不抢夺焦点）');

    try {
      // 先显示窗口
      await windowManager.show();

      // 在macOS上，使用特殊的窗口级别来避免抢夺焦点
      if (Platform.isMacOS) {
        // 立即取消焦点，让原应用保持焦点
        await _refocusPreviousApp();
      }

      debugPrint('✅ 窗口已显示，原应用焦点已保持');
    } catch (e) {
      debugPrint('❌ 显示剪贴板历史窗口时出错: $e');
    }
  }

  /// 重新聚焦到之前的应用
  Future<void> _refocusPreviousApp() async {
    if (Platform.isMacOS) {
      try {
        // 短暂延迟后重新聚焦到前台应用
        await Future.delayed(const Duration(milliseconds: 50));

        final result = await Process.run('osascript', [
          '-e',
          '''
          tell application "System Events"
            set frontApps to (name of application processes whose frontmost is true)
            if (count of frontApps) > 0 then
              set frontApp to item 1 of frontApps
              if frontApp is not "ccp" then
                tell application frontApp to activate
              end if
            end if
          end tell
          ''',
        ]);

        if (result.exitCode == 0) {
          debugPrint('✅ 成功重新聚焦到之前的应用');
        }
      } catch (e) {
        debugPrint('⚠️ 重新聚焦失败: $e');
      }
    }
  }

  /// 隐藏剪贴板历史窗口
  /// 使用window_manager隐藏主窗口
  Future<void> hideClipboardHistory() async {
    debugPrint('🙈 隐藏剪贴板历史窗口');
    try {
      // 隐藏窗口
      await windowManager.hide();
      debugPrint('✅ 剪贴板历史窗口已隐藏');
    } catch (e) {
      debugPrint('❌ 隐藏窗口时出错: $e');
    }
  }

  /// 选择并粘贴剪贴板项目（通过系统级热键触发）
  Future<void> selectClipboardItem(int index) async {
    debugPrint('🎯 selectClipboardItem: 选择第${index + 1}项');

    try {
      // 通过 Get 获取控制器
      final controller = Get.find<ClipboardController>();
      final items = controller.items;

      if (index < items.length) {
        final item = items[index];
        debugPrint(
          '📋 选择的项目: ${item.content.substring(0, item.content.length > 30 ? 30 : item.content.length)}...',
        );

        // 1. 复制到剪贴板
        await controller.copyToClipboard(item.content);
        debugPrint('📋 内容已复制到剪贴板');

        // 2. 隐藏窗口
        await hideClipboardHistory();
        debugPrint('🙈 窗口已隐藏');

        // 3. 模拟粘贴
        await simulatePaste();
        debugPrint('🎉 自动粘贴完成');
      } else {
        debugPrint('⚠️ 选择的索引超出范围: $index >= ${items.length}');
      }
    } catch (e) {
      debugPrint('❌ 选择剪贴板项目失败: $e');
    }
  }

  /// 将设置显示为对话框
  void showSettingsDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint('❌ 无法显示设置对话框：navigator context为null');
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
    debugPrint('✓ Window service disposed');
  }

  // 从 main.dart 移动过来的模拟粘贴功能
  Future<void> simulatePaste() async {
    if (Platform.isMacOS) {
      try {
        debugPrint('🍝 开始模拟 Cmd+V 按键...');

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
