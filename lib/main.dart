import 'package:flutter/material.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform, Process;
import 'dart:convert';
import 'dart:async';
import 'services/clipboard_service.dart';
import 'services/window_service.dart';
import 'services/system_tray_service.dart';
import 'services/hotkey_service.dart';
import 'services/clipboard_data_service.dart';
import 'services/storage_service.dart';
import 'widgets/clipboard_history_window.dart';
import 'widgets/settings_window.dart';
import 'package:get/get.dart';
import 'controllers/clipboard_controller.dart';
import 'models/clipboard_item.dart';

// 添加自动粘贴功能的导入
import 'dart:ffi';

// macOS 系统调用
final class CGPoint extends Struct {
  @Double()
  external double x;
  @Double()
  external double y;
}

// 模拟粘贴功能 - 直接模拟按键事件
Future<void> _simulatePaste() async {
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

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await _initializeMacOSSpecific();
  }

  if (args.isNotEmpty && args.first == 'multi_window') {
    // 这是子窗口 (现在只有设置窗口了)
    final windowId = int.parse(args[1]);
    final windowArgs = args.length > 2 && args[2].isNotEmpty
        ? jsonDecode(args[2]) as Map<String, dynamic>
        : <String, dynamic>{};

    debugPrint('Starting sub-window: $windowId with args: $windowArgs');
    final windowType = windowArgs['windowType'] as String? ?? 'unknown';

    // 子窗口不需要任何特殊的服务初始化
    if (windowType == 'settings') {
      runApp(SettingsApp(windowId: windowId));
    }
  } else {
    // 这是主窗口 (现在是剪贴板历史列表)
    debugPrint('Starting main window as Clipboard History');

    // 主窗口需要初始化所有核心服务
    await _initializeMainWindow();

    // 设置方法处理器，以监听窗口事件（如焦点变化）
    DesktopMultiWindow.setMethodHandler((
      MethodCall call,
      int fromWindowId,
    ) async {
      switch (call.method) {
        case 'onWindowFocus':
          debugPrint("主窗口获得焦点");
          break;
        case 'onWindowBlur':
          debugPrint("主窗口失去焦点，准备隐藏...");
          // 调用隐藏方法
          WindowService().hideClipboardHistory();
          break;
      }
    });

    // 设置应用退出时的清理
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

    // 主应用直接运行剪贴板历史窗口
    runApp(const ClipboardHistoryApp(isMainWindow: true));
  }
}

/// 设置一个方法处理器，用于响应来自子窗口的调用
void _setupMethodHandler() {
  DesktopMultiWindow.setMethodHandler((
    MethodCall call,
    int fromWindowId,
  ) async {
    debugPrint('主窗口收到方法调用: ${call.method} from window $fromWindowId');

    switch (call.method) {
      // 当子窗口请求剪贴板历史记录时
      case 'request_history':
        try {
          final controller = Get.find<ClipboardController>();
          // 将 ClipboardItem 列表转换为可序列化的 Map 列表
          final history = controller.items
              .map((item) => item.toJson())
              .toList();
          debugPrint('准备返回历史记录，共 ${history.length} 条');
          return history; // 将数据返回给调用方
        } catch (e) {
          debugPrint('❌ 处理 request_history 时出错: $e');
          return []; // 出错时返回空列表
        }

      // 当子窗口中的某个项目被选中时
      case 'item_selected':
        try {
          // 解析参数
          final json = call.arguments as Map<String, dynamic>;
          final item = ClipboardItem.fromJson(json);
          debugPrint('📋 收到选中项目: ${item.content}');

          // 1. 复制到系统剪贴板
          final clipboardController = Get.find<ClipboardController>();
          await clipboardController.copyToClipboard(item.content);

          // 2. 隐藏历史记录窗口
          await WindowService().hideClipboardHistory();

          // 3. 模拟粘贴
          await _simulatePaste();
        } catch (e) {
          debugPrint('❌ 处理 item_selected 时出错: $e');
        }
        break;
      default:
        debugPrint('主窗口收到未知的调用: ${call.method}');
    }
  });
}

Future<void> _initializeMacOSSpecific() async {
  try {
    debugPrint('Initializing macOS-specific settings...');

    // 设置应用程序为后台运行，减少与输入法的冲突
    // 这有助于避免 IMKCFRunLoopWakeUpReliable 错误

    // 添加短暂延迟让系统准备就绪
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint('✓ macOS initialization completed');
  } catch (e) {
    debugPrint('macOS initialization warning: $e');
    // 不要因为初始化失败而停止应用程序
  }
}

// 主窗口的应用实例，现在直接是剪贴板历史
class ClipboardHistoryApp extends StatelessWidget {
  final int? windowId;
  final bool isMainWindow;

  const ClipboardHistoryApp({
    super.key,
    this.windowId,
    this.isMainWindow = false,
  });

  @override
  Widget build(BuildContext context) {
    // 为了兼容，我们依然使用 GetMaterialApp
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: ClipboardHistoryWindow(),
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

    // 主进程不需要清理ClipboardService
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

    // 2. 在主进程中启动剪贴板监听
    await ClipboardService().initialize();
    debugPrint('✅ 剪贴板监听服务启动完成');

    // 3. 初始化窗口服务
    await WindowService().initialize();
    await SystemTrayService().initialize();
    debugPrint('✅ 窗口和系统托盘服务初始化完成');

    // 4. 使用HotkeyService统一管理热键
    await HotkeyService().initialize();
    debugPrint('✅ 热键服务初始化完成');

    debugPrint('🎉 主窗口：初始化完成');
  } catch (e) {
    debugPrint('❌ 主窗口初始化失败: $e');
  }
}

/// 子窗口的初始化现在非常简单，甚至可以不需要
Future<void> _initializeSubWindow(List<dynamic>? clipboardData) async {
  debugPrint('ℹ️ 子窗口初始化，当前无需特殊操作。');
  // 以前的逻辑都移到主窗口了
}

// 设置窗口应用
class SettingsApp extends StatelessWidget {
  final int windowId;

  const SettingsApp({super.key, required this.windowId});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Settings',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: SettingsWindow(
        onClose: () async {
          try {
            debugPrint('🔥 SettingsApp onClose 被调用，准备关闭设置窗口');
            debugPrint('🆔 当前窗口ID: $windowId');

            // 直接关闭窗口
            final controller = WindowController.fromWindowId(windowId);
            debugPrint('📋 创建 WindowController 实例成功');

            await controller.close();
            debugPrint('✅ 设置窗口已关闭');
          } catch (e) {
            debugPrint('❌ 关闭设置窗口时出错: $e');
            debugPrint('堆栈信息: ${StackTrace.current}');
          }
        },
      ),
    );
  }
}
