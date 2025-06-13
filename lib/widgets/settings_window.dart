import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';
import '../services/crash_handler_service.dart';
import '../services/keyboard_service.dart';
import '../services/window_service.dart';

class SettingsWindow extends StatelessWidget {
  final VoidCallback? onClose;

  const SettingsWindow({super.key, this.onClose});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());

    // 设置关闭回调
    controller.setCloseCallback(onClose);

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: controller.onKeyEvent,
      child: Container(
        width: 500,
        height: 700,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: controller.closeWindow,
                      icon: const Icon(Icons.close),
                      tooltip: '关闭 (Esc)',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.1),
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hotkey Settings
                      const Text(
                        '快捷键设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('当前快捷键:'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Obx(
                                    () => Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: controller.isRecording.value
                                            ? Colors.red.withOpacity(0.1)
                                            : Theme.of(
                                                context,
                                              ).inputDecorationTheme.fillColor,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: controller.isRecording.value
                                              ? Colors.red
                                              : Theme.of(context).dividerColor,
                                        ),
                                      ),
                                      child: Text(
                                        controller.isRecording.value
                                            ? '按下新的快捷键...'
                                            : controller.getHotkeyText(),
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          color: controller.isRecording.value
                                              ? Colors.red
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Obx(
                                  () => ElevatedButton(
                                    onPressed: controller.isRecording.value
                                        ? controller.stopRecording
                                        : controller.startRecording,
                                    child: Text(
                                      controller.isRecording.value
                                          ? '取消'
                                          : '更改',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Obx(
                              () => controller.isRecording.value
                                  ? const Column(
                                      children: [
                                        SizedBox(height: 8),
                                        Text(
                                          '请按下新的快捷键组合。确保包含修饰键（Cmd/Ctrl/Alt/Shift）。',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // History Settings
                      const Text(
                        '历史记录设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('最大保存记录数:'),
                                const Spacer(),
                                SizedBox(
                                  width: 100,
                                  child: Obx(
                                    () => TextFormField(
                                      initialValue: controller.maxItems.value
                                          .toString(),
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      onChanged: controller.updateMaxItems,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: controller.clearHistory,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('清空历史记录'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.1),
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 自动粘贴说明 - 只显示自动粘贴信息
                      const Text(
                        '自动粘贴设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '自动粘贴已启用（推荐）',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '选择剪贴板项目后会自动粘贴到当前应用。需要在系统设置中授予辅助功能权限。',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 权限管理
                      const Text(
                        '权限管理',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _checkAccessibilityPermission,
                                child: const Text('检查辅助功能权限'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _requestAccessibilityPermission,
                                child: const Text('申请辅助功能权限'),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 使用说明
                      const Text(
                        '使用说明',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('• 使用 Cmd+Shift+V 打开剪贴板历史窗口'),
                            Text('• 使用 Cmd+1~9 快速粘贴历史记录'),
                            Text('• 点击系统托盘图标也可打开窗口'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 日志管理
                      const Text(
                        '日志管理',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _showCrashLogs,
                                child: const Text('查看崩溃日志'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _clearCrashLogs,
                                child: const Text('清理旧日志'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: controller.saveSettings,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('保存设置'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示崩溃日志对话框
  void _showCrashLogs() async {
    try {
      final logs = await CrashHandlerService().getRecentLogs();
      final logPath = CrashHandlerService().logFilePath;

      if (Get.context != null) {
        showDialog(
          context: Get.context!,
          builder: (context) => AlertDialog(
            title: const Text('崩溃日志'),
            content: SizedBox(
              width: 600,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '日志文件位置: $logPath',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: SelectableText(
                          logs,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('关闭'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('显示崩溃日志失败: $e');
      if (Get.context != null) {
        ScaffoldMessenger.of(
          Get.context!,
        ).showSnackBar(SnackBar(content: Text('无法读取崩溃日志: $e')));
      }
    }
  }

  /// 清理旧日志文件
  void _clearCrashLogs() async {
    try {
      await CrashHandlerService().cleanupOldLogs();
      if (Get.context != null) {
        ScaffoldMessenger.of(
          Get.context!,
        ).showSnackBar(const SnackBar(content: Text('旧日志文件已清理')));
      }
    } catch (e) {
      print('清理日志失败: $e');
      if (Get.context != null) {
        ScaffoldMessenger.of(
          Get.context!,
        ).showSnackBar(SnackBar(content: Text('清理日志失败: $e')));
      }
    }
  }

  /// 检查辅助功能权限
  void _checkAccessibilityPermission() async {
    try {
      final hasPermission = await KeyboardService.hasAccessibilityPermission();
      if (Get.context != null) {
        ScaffoldMessenger.of(Get.context!).showSnackBar(
          SnackBar(
            content: Text(hasPermission ? '✅ 已有辅助功能权限' : '❌ 缺少辅助功能权限'),
            backgroundColor: hasPermission ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('检查辅助功能权限失败: $e');
      if (Get.context != null) {
        ScaffoldMessenger.of(
          Get.context!,
        ).showSnackBar(SnackBar(content: Text('检查权限失败: $e')));
      }
    }
  }

  /// 请求辅助功能权限
  void _requestAccessibilityPermission() async {
    try {
      await KeyboardService.requestAccessibilityPermission();
      if (Get.context != null) {
        showDialog(
          context: Get.context!,
          builder: (context) => AlertDialog(
            title: const Text('权限申请指导'),
            content: const SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('系统设置已打开，请按以下步骤操作：'),
                  SizedBox(height: 12),
                  Text('1. 在"隐私与安全性"页面中，点击左侧的"辅助功能"'),
                  Text('2. 点击右下角的"+"按钮'),
                  Text('3. 找到并选择 ccp 应用'),
                  Text('4. 确保应用旁边的开关是打开状态'),
                  SizedBox(height: 12),
                  Text(
                    '提示：如果找不到应用，可以点击下方的"显示应用路径"按钮获取具体位置。',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => _showAppPath(),
                child: const Text('显示应用路径'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      print('请求辅助功能权限失败: $e');
      if (Get.context != null) {
        ScaffoldMessenger.of(
          Get.context!,
        ).showSnackBar(SnackBar(content: Text('请求权限失败: $e')));
      }
    }
  }

  /// 显示应用路径信息
  void _showAppPath() async {
    if (Get.context != null) {
      showDialog(
        context: Get.context!,
        builder: (context) => AlertDialog(
          title: const Text('应用路径信息'),
          content: const SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '您可以在 Finder 中搜索 "ccp.app" 来找到应用位置。',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      );
    }
  }
}
