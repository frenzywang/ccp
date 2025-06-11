import 'package:flutter/services.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:convert';
import '../models/clipboard_item.dart';

/// 窗口间通信服务
class WindowChannelService {
  static const String _channelName = 'clipboard_data_channel';

  // 单例模式
  static final WindowChannelService _instance =
      WindowChannelService._internal();
  factory WindowChannelService() => _instance;
  WindowChannelService._internal();

  /// 主进程：设置数据提供者
  void setupMainProcess(List<ClipboardItem> Function() dataProvider) {
    DesktopMultiWindow.setMethodHandler((call, fromWindowId) async {
      switch (call.method) {
        case 'requestClipboardData':
          // 子窗口请求剪贴板数据
          final items = dataProvider();
          return items
              .map(
                (item) => {
                  'id': item.id,
                  'content': item.content,
                  'type': item.type.toString(),
                  'createdAt': item.createdAt.millisecondsSinceEpoch,
                },
              )
              .toList();

        case 'updateClipboardData':
          // 子窗口返回数据变更
          final updatedData = call.arguments as List<dynamic>;
          // TODO: 处理数据更新
          return 'success';

        default:
          return 'unknown_method';
      }
    });
  }

  /// 子进程：请求主进程数据
  Future<List<ClipboardItem>> requestDataFromMain() async {
    try {
      final result = await DesktopMultiWindow.invokeMethod(
        0, // 主窗口ID
        'requestClipboardData',
      );

      if (result is List) {
        return result.map((itemData) {
          final data = itemData as Map<String, dynamic>;
          return ClipboardItem(
            id: data['id'] as String,
            content: data['content'] as String,
            type: ClipboardItemType.values.firstWhere(
              (e) => e.toString() == data['type'],
              orElse: () => ClipboardItemType.text,
            ),
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              data['createdAt'] as int,
            ),
          );
        }).toList();
      }

      return [];
    } catch (e) {
      print('❌ 子进程请求数据失败: $e');
      return [];
    }
  }

  /// 子进程：向主进程发送数据变更
  Future<void> sendDataToMain(List<ClipboardItem> items) async {
    try {
      final data = items
          .map(
            (item) => {
              'id': item.id,
              'content': item.content,
              'type': item.type.toString(),
              'createdAt': item.createdAt.millisecondsSinceEpoch,
            },
          )
          .toList();

      await DesktopMultiWindow.invokeMethod(
        0, // 主窗口ID
        'updateClipboardData',
        data,
      );
    } catch (e) {
      print('❌ 子进程发送数据失败: $e');
    }
  }
}
