import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'crash_handler_service.dart';

class KeyboardService {
  static const MethodChannel _channel = MethodChannel('com.ccp.keyboard');

  /// 检查是否有辅助功能权限
  static Future<bool> hasAccessibilityPermission() async {
    try {
      final result = await _channel.invokeMethod('hasAccessibilityPermission');
      print('🔍 权限检查结果: $result');
      return result == true;
    } catch (e) {
      print('❌ 检查辅助功能权限失败: $e');
      return false;
    }
  }

  /// 请求辅助功能权限
  static Future<void> requestAccessibilityPermission() async {
    try {
      await _channel.invokeMethod('requestAccessibilityPermission');
    } catch (e) {
      print('❌ 请求辅助功能权限失败: $e');
    }
  }

  /// 模拟粘贴操作 (Cmd+V)
  static Future<bool> simulatePaste() async {
    try {
      print('🍝 开始模拟 Cmd+V 按键...');

      // 记录操作日志
      await CrashHandlerService().logMessage('开始模拟粘贴操作');

      final result = await _channel.invokeMethod('simulatePaste');
      print('✅ 模拟 Cmd+V 成功: $result');

      // 记录成功日志
      await CrashHandlerService().logMessage('模拟粘贴操作成功');

      return result == true;
    } on PlatformException catch (e, stack) {
      print('❌ Platform异常: ${e.code} - ${e.message}');

      // 记录具体的平台异常
      await CrashHandlerService().logError(
        'Platform异常: ${e.code} - ${e.message}',
        e,
        stack,
      );

      // 根据错误类型给出不同的处理
      switch (e.code) {
        case 'NO_ACCESSIBILITY_PERMISSION':
          print('💡 需要在系统偏好设置 > 安全性与隐私 > 辅助功能中添加此应用');
          break;
        case 'EVENT_CREATION_FAILED':
          print('💡 键盘事件创建失败，可能是系统限制');
          break;
        default:
          print('💡 未知的平台错误');
      }

      return false;
    } catch (e, stack) {
      print('❌ 模拟 Cmd+V 失败: $e');

      // 记录错误到崩溃日志
      await CrashHandlerService().logError('模拟粘贴操作失败', e, stack);

      return false;
    }
  }
}
