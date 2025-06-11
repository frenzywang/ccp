import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/settings_controller.dart';

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
        height: 600,
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
                child: Padding(
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
                      const Spacer(),

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
}
