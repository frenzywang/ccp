import 'package:flutter/material.dart';
import 'dart:io' show Platform, exit;
import 'dart:async';
import 'services/clipboard_service.dart';
import 'services/window_service.dart';
import 'services/system_tray_service.dart';
import 'services/hotkey_service.dart';
import 'widgets/clipboard_history_window.dart';
import 'package:get/get.dart';
import 'controllers/clipboard_controller.dart';
import 'package:window_manager/window_manager.dart';

// 添加自动粘贴功能的导入
import 'dart:ffi' hide Size;

// macOS 系统调用
final class CGPoint extends Struct {
  @Double()
  external double x;
  @Double()
  external double y;
}

// 全局 NavigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化窗口管理器
  await windowManager.ensureInitialized();

  // 配置窗口选项
  WindowOptions windowOptions = const WindowOptions(
    size: Size(500, 700),
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  // 等待窗口准备好后再显示
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 初始时隐藏窗口，等待快捷键触发
    await windowManager.hide();
  });

  debugPrint('Starting main window as Clipboard History');

  // 主窗口需要初始化所有核心服务
  await _initializeMainWindow();

  // 设置应用退出时的清理
  WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

  // 主应用直接运行剪贴板历史窗口
  runApp(const ClipboardHistoryApp());
}

// 主窗口的应用实例，现在直接是剪贴板历史
class ClipboardHistoryApp extends StatelessWidget {
  const ClipboardHistoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 使用 GetMaterialApp
    return GetMaterialApp(
      navigatorKey: navigatorKey, // 设置全局Key
      debugShowCheckedModeBanner: false,
      home: const ClipboardHistoryWindow(), // 直接显示剪贴板历史窗口
    );
  }
}

// 应用生命周期观察者，用于清理资源
class _AppLifecycleObserver extends WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.detached) {
      _cleanup();
    }
  }

  void _cleanup() async {
    debugPrint('🧹 应用即将退出，清理资源...');

    // 使用HotkeyService清理热键
    try {
      HotkeyService().dispose();
      debugPrint('✓ 热键已通过HotkeyService清理');
    } catch (e) {
      debugPrint('⚠️ 热键清理失败: $e');
    }

    debugPrint('✓ 应用资源清理完成');
  }
}

/// 初始化主窗口（完整的服务初始化）
Future<void> _initializeMainWindow() async {
  debugPrint('🚀 主窗口：开始初始化...');

  try {
    // 1. 初始化GetX控制器
    Get.put(ClipboardController(), permanent: true);
    debugPrint('✅ GetX控制器初始化完成');

    // 2. 启动剪贴板监听服务
    await ClipboardService().initialize();
    debugPrint('✅ 剪贴板监听服务启动完成');

    // 4. 初始化系统托盘
    await SystemTrayService().initialize();
    // 5. 设置系统托盘回调
    SystemTrayService().setCallbacks(
      onShowHistory: WindowService().showClipboardHistory,
      onSettings: () {
        // 直接调用 WindowService 中的设置对话框方法
        WindowService().showSettingsDialog();
      },
      onQuit: () async {
        exit(0);
      },
    );
    debugPrint('✅ 系统托盘服务初始化并设置回调完成');

    // 6. 使用HotkeyService统一管理热键
    await HotkeyService().initialize();
    debugPrint('✅ 热键服务初始化完成');

    debugPrint('🎉 主窗口：初始化完成');
  } catch (e) {
    debugPrint('❌ 主窗口初始化失败: $e');
  }
}
