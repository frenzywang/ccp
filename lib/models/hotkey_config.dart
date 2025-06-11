import 'package:hive/hive.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

part 'hotkey_config.g.dart';

@HiveType(typeId: 2)
class HotkeyConfig extends HiveObject {
  @HiveField(0)
  String keyCode;

  @HiveField(1)
  List<String> modifiers;

  HotkeyConfig({required this.keyCode, required this.modifiers});

  // 默认热键配置: Cmd+Shift+V
  factory HotkeyConfig.defaultConfig() {
    return HotkeyConfig(keyCode: 'KeyV', modifiers: ['meta', 'shift']);
  }

  // 将字符串列表转换为 HotKeyModifier 列表
  List<HotKeyModifier> get hotKeyModifiers {
    return modifiers.map((name) {
      switch (name) {
        case 'meta':
          return HotKeyModifier.meta;
        case 'shift':
          return HotKeyModifier.shift;
        case 'alt':
          return HotKeyModifier.alt;
        case 'control':
          return HotKeyModifier.control;
        default:
          return HotKeyModifier.meta;
      }
    }).toList();
  }

  // 从 HotKeyModifier 列表创建字符串列表
  static List<String> modifiersToStrings(List<HotKeyModifier> modifiers) {
    return modifiers.map((modifier) {
      switch (modifier) {
        case HotKeyModifier.meta:
          return 'meta';
        case HotKeyModifier.shift:
          return 'shift';
        case HotKeyModifier.alt:
          return 'alt';
        case HotKeyModifier.control:
          return 'control';
        default:
          return 'meta';
      }
    }).toList();
  }

  // 获取热键描述
  String getDescription() {
    final modifierText = modifiers
        .map((modifier) {
          switch (modifier) {
            case 'meta':
              return 'Cmd';
            case 'shift':
              return 'Shift';
            case 'alt':
              return 'Alt';
            case 'control':
              return 'Ctrl';
            default:
              return '';
          }
        })
        .join(' + ');

    final key = keyCode.replaceAll('Key', '');
    return '$modifierText + $key';
  }

  @override
  String toString() {
    return 'HotkeyConfig(keyCode: $keyCode, modifiers: $modifiers)';
  }
}
