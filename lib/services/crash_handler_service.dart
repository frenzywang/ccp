import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class CrashHandlerService {
  static final CrashHandlerService _instance = CrashHandlerService._internal();
  factory CrashHandlerService() => _instance;
  CrashHandlerService._internal();

  late File _logFile;
  bool _initialized = false;

  /// 初始化崩溃处理服务
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // 创建日志文件
      await _initializeLogFile();

      // 设置Flutter错误处理器
      FlutterError.onError = _handleFlutterError;

      // 设置Platform异常处理器
      PlatformDispatcher.instance.onError = _handlePlatformError;

      _initialized = true;
      await logMessage('🚀 崩溃处理服务已初始化');

      print('✅ CrashHandlerService 初始化完成');
    } catch (e) {
      print('❌ CrashHandlerService 初始化失败: $e');
    }
  }

  /// 初始化日志文件
  Future<void> _initializeLogFile() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (!await logsDir.exists()) {
        await logsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      _logFile = File('${logsDir.path}/crash_log_$timestamp.txt');

      // 创建文件（如果不存在）
      if (!await _logFile.exists()) {
        await _logFile.create();
        await _logFile.writeAsString('=== CCP Crash Log - $timestamp ===\n');
      }
    } catch (e) {
      print('❌ 无法创建日志文件: $e');
      // 如果无法创建文件，使用临时文件
      _logFile = File('/tmp/ccp_crash_log.txt');
    }
  }

  /// 处理Flutter层错误
  void _handleFlutterError(FlutterErrorDetails details) {
    print('🔥 Flutter错误捕获: ${details.exception}');

    _logFlutterError(details);

    // 在debug模式下显示错误详情
    if (kDebugMode) {
      FlutterError.presentError(details);
    }
  }

  /// 处理Platform层错误
  bool _handlePlatformError(Object error, StackTrace stack) {
    print('💥 Platform错误捕获: $error');

    _logPlatformError(error, stack);

    return true; // 表示错误已处理
  }

  /// 记录Flutter错误到文件
  Future<void> _logFlutterError(FlutterErrorDetails details) async {
    final timestamp = DateTime.now().toIso8601String();
    final errorInfo =
        '''
[$timestamp] FLUTTER ERROR:
Exception: ${details.exception}
Library: ${details.library ?? 'Unknown'}
Context: ${details.context ?? 'No context'}
Stack Trace:
${details.stack ?? 'No stack trace available'}

''';

    await _writeToLogFile(errorInfo);
  }

  /// 记录Platform错误到文件
  Future<void> _logPlatformError(Object error, StackTrace stack) async {
    final timestamp = DateTime.now().toIso8601String();
    final errorInfo =
        '''
[$timestamp] PLATFORM ERROR:
Error: $error
Stack Trace:
$stack

''';

    await _writeToLogFile(errorInfo);
  }

  /// 记录自定义消息
  Future<void> logMessage(String message) async {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] INFO: $message\n';
    await _writeToLogFile(logEntry);
  }

  /// 写入日志文件
  Future<void> _writeToLogFile(String content) async {
    try {
      if (_initialized) {
        await _logFile.writeAsString(content, mode: FileMode.append);
      }
    } catch (e) {
      print('❌ 无法写入日志文件: $e');
    }
  }

  /// 记录自定义错误
  Future<void> logError(
    String message, [
    Object? error,
    StackTrace? stack,
  ]) async {
    print('⚠️ 自定义错误: $message${error != null ? ' - $error' : ''}');

    final timestamp = DateTime.now().toIso8601String();
    final errorInfo =
        '''
[$timestamp] CUSTOM ERROR:
Message: $message
${error != null ? 'Error: $error' : ''}
${stack != null ? 'Stack Trace:\n$stack' : ''}

''';

    await _writeToLogFile(errorInfo);
  }

  /// 获取最新的日志内容
  Future<String> getRecentLogs() async {
    try {
      if (await _logFile.exists()) {
        final content = await _logFile.readAsString();
        final lines = content.split('\n');

        // 返回最近50行日志
        if (lines.length > 50) {
          return lines.skip(lines.length - 50).join('\n');
        }
        return content;
      }
    } catch (e) {
      print('❌ 读取日志文件失败: $e');
    }

    return '暂无日志记录';
  }

  /// 清理旧日志文件
  Future<void> cleanupOldLogs() async {
    try {
      final directory = await getApplicationSupportDirectory();
      final logsDir = Directory('${directory.path}/logs');

      if (await logsDir.exists()) {
        final files = await logsDir.list().toList();
        final now = DateTime.now();

        for (final file in files) {
          if (file is File && file.path.contains('crash_log_')) {
            final stat = await file.stat();
            final daysDiff = now.difference(stat.modified).inDays;

            // 删除7天前的日志
            if (daysDiff > 7) {
              await file.delete();
              print('🗑️ 删除旧日志文件: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      print('❌ 清理日志文件失败: $e');
    }
  }

  /// 获取日志文件路径
  String get logFilePath => _logFile.path;
}
