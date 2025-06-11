import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:system_tray/system_tray.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:io' show Platform, exit, Process;
import 'dart:convert';
import 'dart:async';
import 'services/clipboard_service.dart';
import 'services/window_service.dart';
import 'services/system_tray_service.dart';
import 'services/hotkey_service.dart';
import 'widgets/clipboard_history_window.dart';
import 'widgets/settings_window.dart';
import 'models/clipboard_item.dart';
import 'package:get/get.dart';
import 'controllers/clipboard_controller.dart';
import 'package:hive_flutter/hive_flutter.dart';

// 添加自动粘贴功能的导入
import 'dart:ffi';
import 'package:ffi/ffi.dart';

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

  // macOS特定的初始化，减少输入法相关错误
  if (Platform.isMacOS) {
    await _initializeMacOSSpecific();
  }

  // 检查是否是子窗口 - 使用 multi_window 参数检查
  if (args.isNotEmpty && args.first == 'multi_window') {
    // 这是一个子窗口 - 不需要初始化Hive，只初始化GetX
    await _initializeGetXForSubWindow();

    final windowId = int.parse(args[1]);
    final windowArgs = args.length > 2 && args[2].isNotEmpty
        ? jsonDecode(args[2]) as Map<String, dynamic>
        : <String, dynamic>{};

    debugPrint('Starting sub-window: $windowId with args: $windowArgs');

    final windowType = windowArgs['windowType'] as String? ?? 'unknown';

    if (windowType == 'settings') {
      runApp(
        GetMaterialApp(
          debugShowCheckedModeBanner: false,
          home: SettingsApp(windowId: windowId),
        ),
      );
    } else {
      runApp(
        GetMaterialApp(
          debugShowCheckedModeBanner: false,
          home: ClipboardHistoryApp(windowId: windowId),
        ),
      );
    }
  } else {
    // 这是主窗口 - 完整初始化
    debugPrint('Starting main window');

    // 初始化GetX和Hive
    await _initializeGetX();

    // 初始化所有服务
    await WindowService().initialize();
    await SystemTrayService().initialize();

    // 使用HotkeyService统一管理热键
    await HotkeyService().initialize();

    // 设置应用退出时的清理
    WidgetsBinding.instance.addObserver(_AppLifecycleObserver());

    runApp(const MyApp());
  }
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Clipboard Manager',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const MainWindow(),
    );
  }
}

class MainWindow extends StatelessWidget {
  const MainWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clipboard Manager (GetX)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.content_paste, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            const Text(
              'Clipboard Manager',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Press Cmd+Shift+V to open clipboard history',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => WindowService().showClipboardHistory(),
              child: const Text('Open Clipboard History'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => WindowService().showSettings(),
              child: const Text('Open Settings'),
            ),
            const SizedBox(height: 16),
            // 使用GetX显示剪贴板状态
            GetX<ClipboardController>(
              builder: (controller) {
                return Column(
                  children: [
                    Text(
                      'Clipboard items: ${controller.items.length}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    if (controller.isLoading.value)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('监听中...', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    if (controller.items.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '最新剪贴板内容:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              controller.items.first.content.length > 100
                                  ? '${controller.items.first.content.substring(0, 100)}...'
                                  : controller.items.first.content,
                              style: const TextStyle(fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// 剪贴板历史窗口应用
class ClipboardHistoryApp extends StatelessWidget {
  final int windowId;

  const ClipboardHistoryApp({super.key, required this.windowId});

  @override
  Widget build(BuildContext context) {
    return ClipboardHistoryWindow(
      onItemSelected: (item) async {
        try {
          debugPrint(
            '🎯 GetX: 用户选择了项目: ${item.content.length > 50 ? "${item.content.substring(0, 50)}..." : item.content}',
          );

          // 使用GetX Controller复制到剪贴板
          final controller = Get.find<ClipboardController>();
          await controller.copyToClipboard(item.content);
          debugPrint('📋 内容已通过GetX复制到剪贴板');

          // 关闭窗口
          debugPrint('🚪 开始关闭窗口...');
          final windowController = WindowController.fromWindowId(windowId);
          await windowController.close();
          debugPrint('✅ 窗口已关闭');

          // 等待窗口关闭，然后执行自动粘贴
          debugPrint('⏰ 等待窗口关闭后执行自动粘贴...');
          await Future.delayed(const Duration(milliseconds: 100));
          await _simulatePaste();
          debugPrint('🎉 自动粘贴流程完成');
        } catch (e) {
          debugPrint('❌ 选择项目时出错: $e');
        }
      },
      onClose: () async {
        try {
          debugPrint('关闭剪贴板历史窗口');

          // 关闭窗口
          final controller = WindowController.fromWindowId(windowId);
          await controller.close();
        } catch (e) {
          debugPrint('关闭窗口时出错: $e');
        }
      },
    );
  }
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
            // 通知WindowService并关闭窗口
            await WindowService().closeSettings();
          } catch (e) {
            debugPrint('Error closing settings window: $e');
          }
        },
      ),
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

    // 清理其他资源
    ClipboardService().dispose();
    debugPrint('✓ 应用资源清理完成');
  }
}

/// 初始化GetX和全局控制器（主窗口）
Future<void> _initializeGetX() async {
  debugPrint('🚀 主窗口：初始化GetX和Hive...');

  // 初始化 Hive
  await Hive.initFlutter();
  debugPrint('📦 Hive 已初始化');

  // 注册全局ClipboardController
  Get.put(ClipboardController(), permanent: true);

  debugPrint('✅ 主窗口：GetX初始化完成');
}

/// 初始化GetX控制器（子窗口）
Future<void> _initializeGetXForSubWindow() async {
  debugPrint('🚀 子窗口：初始化GetX...');

  // 子窗口中ClipboardController会自己处理Hive初始化
  // 只需要注册控制器即可
  Get.put(ClipboardController(), permanent: true);

  debugPrint('✅ 子窗口：GetX初始化完成');
}
