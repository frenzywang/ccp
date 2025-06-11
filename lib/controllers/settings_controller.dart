import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import '../services/hotkey_service.dart';
import '../services/clipboard_data_service.dart';
import 'clipboard_controller.dart';

class SettingsController extends GetxController {
  final HotkeyService _hotkeyService = HotkeyService();
  final ClipboardDataService _clipboardDataService = ClipboardDataService();

  final RxString selectedKey = 'KeyV'.obs;
  final Rx<Set<HotKeyModifier>> selectedModifiers = Rx({
    HotKeyModifier.meta,
    HotKeyModifier.shift,
  });

  final RxInt maxItems = 50.obs;
  final RxBool isRecording = false.obs;

  VoidCallback? onCloseCallback;

  @override
  void onInit() {
    super.onInit();
    loadCurrentSettings();
  }

  void setCloseCallback(VoidCallback? callback) {
    onCloseCallback = callback;
  }

  void closeWindow() {
    print('🚪 SettingsController.closeWindow() 被调用');
    onCloseCallback?.call();
    print('📞 关闭回调已执行');
  }

  void loadCurrentSettings() {
    // maxItems 现在在 DataManager 中管理，设置为默认值
    maxItems.value = 50;
  }

  void startRecording() {
    isRecording.value = true;
  }

  void stopRecording() {
    isRecording.value = false;
  }

  void onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (isRecording.value) {
        stopRecording();
      } else {
        closeWindow();
      }
      return;
    }

    if (isRecording.value && event is KeyDownEvent) {
      final key = event.logicalKey;
      final modifiers = <HotKeyModifier>{};

      if (RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.metaLeft,
          ) ||
          RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.metaRight,
          )) {
        modifiers.add(HotKeyModifier.meta);
      }
      if (RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.shiftLeft,
          ) ||
          RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.shiftRight,
          )) {
        modifiers.add(HotKeyModifier.shift);
      }
      if (RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.altLeft,
          ) ||
          RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.altRight,
          )) {
        modifiers.add(HotKeyModifier.alt);
      }
      if (RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.controlLeft,
          ) ||
          RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.controlRight,
          )) {
        modifiers.add(HotKeyModifier.control);
      }

      if (_isValidKey(key) && modifiers.isNotEmpty) {
        selectedKey.value = _getKeyCode(key);
        selectedModifiers.value = modifiers;
        stopRecording();
      }
    }
  }

  bool _isValidKey(LogicalKeyboardKey key) {
    return key.keyLabel.length == 1 &&
        RegExp(r'[A-Za-z]').hasMatch(key.keyLabel);
  }

  String _getKeyCode(LogicalKeyboardKey key) {
    return 'Key${key.keyLabel.toUpperCase()}';
  }

  String getHotkeyText() {
    final modifierText = selectedModifiers.value
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

    final key = selectedKey.value.replaceAll('Key', '');
    return '$modifierText + $key';
  }

  Future<void> saveSettings() async {
    try {
      await _hotkeyService.saveHotkeyConfig(
        selectedKey.value,
        selectedModifiers.value.toList(),
      );
      // maxItems 现在由 DataManager 管理，这里只保存热键配置

      Get.snackbar('成功', '设置已保存');
    } catch (e) {
      Get.snackbar('错误', '保存失败: $e');
    }
  }

  Future<void> clearHistory() async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有粘贴板历史记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 通过 ClipboardController 清空历史
      try {
        final controller = Get.find<ClipboardController>();
        await controller.clearHistory();
        debugPrint('✅ 通过 ClipboardController 清空历史完成');
      } catch (e) {
        debugPrint('❌ 清空历史失败: $e');
      }
      Get.snackbar('成功', '历史记录已清空');
    }
  }

  void updateMaxItems(String value) {
    final intValue = int.tryParse(value);
    if (intValue != null && intValue > 0) {
      maxItems.value = intValue;
    }
  }
}
