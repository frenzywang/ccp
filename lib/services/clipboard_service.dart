import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/clipboard_item.dart';

class ClipboardService {
  static final ClipboardService _instance = ClipboardService._internal();
  factory ClipboardService() => _instance;
  ClipboardService._internal();

  final List<ClipboardItem> _items = [];
  final StreamController<List<ClipboardItem>> _controller =
      StreamController<List<ClipboardItem>>.broadcast();

  String? _lastClipboardContent;
  int maxItems = 50;

  bool _isInitializing = false;

  // 剪贴板监听定时器
  Timer? _clipboardTimer;
  bool _isWatching = false;

  Stream<List<ClipboardItem>> get itemsStream => _controller.stream;
  List<ClipboardItem> get items => List.unmodifiable(_items);

  Future<void> initialize() async {
    if (_isInitializing) return;
    _isInitializing = true;

    print('正在初始化剪贴板服务...');

    try {
      // 首先清空旧数据
      _items.clear();

      // 立即获取当前剪贴板内容
      await _addCurrentClipboardContent();

      // 启动剪贴板监听
      await _startWatching();

      print('剪贴板服务初始化完成，共 ${_items.length} 条记录');

      // 通知订阅者
      _controller.add(_items);
    } catch (e) {
      print('剪贴板服务初始化出错: $e');
      // 即使出错也要尝试获取当前内容
      try {
        await _addCurrentClipboardContent();
        _controller.add(_items);
      } catch (e2) {
        print('获取当前剪贴板内容也失败: $e2');
        // 提供最基本的默认数据
        _addBasicSampleData();
      }
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _startWatching() async {
    if (_isWatching) return;

    try {
      _isWatching = true;

      // 获取当前剪贴板内容作为基准
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      _lastClipboardContent = data?.text;
      print('✓ 基准剪贴板内容: ${_lastClipboardContent?.length ?? 0} 字符');

      print('✓ 开始监听剪贴板变化（检查间隔：300ms）');

      // 使用更短的定时器间隔来更快地检测剪贴板变化
      _clipboardTimer = Timer.periodic(const Duration(milliseconds: 300), (
        timer,
      ) {
        _checkClipboardChange();
      });
    } catch (e) {
      print('启动剪贴板监听失败: $e');
      _isWatching = false;
    }
  }

  Future<void> _checkClipboardChange() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final currentContent = data?.text;

      if (currentContent != null &&
          currentContent.isNotEmpty &&
          currentContent != _lastClipboardContent) {
        print(
          '🎯 检测到剪贴板变化: ${currentContent.length > 30 ? "${currentContent.substring(0, 30)}..." : currentContent}',
        );
        await _addClipboardItem(currentContent, ClipboardItemType.text);
      }
    } catch (e) {
      // 偶尔的错误可以忽略，但连续错误需要记录
      if (DateTime.now().millisecondsSinceEpoch % 10000 < 300) {
        print('剪贴板检查错误: $e');
      }
    }
  }

  Future<void> _addClipboardItem(String content, ClipboardItemType type) async {
    if (content == _lastClipboardContent) return;

    _lastClipboardContent = content;

    // Remove existing item with same content
    _items.removeWhere((item) => item.content == content);

    // Add new item at the beginning
    final item = ClipboardItem(
      id: _generateId(),
      content: content,
      type: type,
      createdAt: DateTime.now(),
    );

    _items.insert(0, item);

    // Keep only maxItems
    if (_items.length > maxItems) {
      _items.removeRange(maxItems, _items.length);
    }

    _controller.add(_items);
    print('✓ 剪贴板项目已添加，当前共 ${_items.length} 条记录');
  }

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() +
        math.Random().nextInt(1000).toString();
  }

  Future<void> copyToClipboard(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
    } catch (e) {
      print('Error copying to clipboard: $e');
    }
  }

  Future<void> clearHistory() async {
    _items.clear();
    _controller.add(_items);
    print('✓ 剪贴板历史已清空');
  }

  void dispose() {
    _clipboardTimer?.cancel();
    _isWatching = false;
    _controller.close();
  }

  Future<void> _addCurrentClipboardContent() async {
    try {
      print('正在读取当前剪贴板内容...');
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null && data!.text!.isNotEmpty) {
        final content = data.text!;
        print('✓ 获取到当前剪贴板内容: ${content.length} 字符');
        print(
          '内容预览: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}',
        );

        await _addClipboardItem(content, ClipboardItemType.text);
        print('✓ 当前剪贴板内容已添加到历史记录');
      } else {
        print('⚠️ 当前剪贴板为空或无文本内容');
      }
    } catch (e) {
      print('❌ 无法读取当前剪贴板内容: $e');
    }
  }

  void _addBasicSampleData() {
    if (_items.isEmpty) {
      print('⚠️ 添加基本示例数据，因为无法获取剪贴板内容');
      _items.add(
        ClipboardItem(
          id: _generateId(),
          content: '欢迎使用剪贴板管理器！请复制一些文本来开始使用。',
          type: ClipboardItemType.text,
          createdAt: DateTime.now(),
        ),
      );
      _controller.add(_items);
      print('✓ 已添加基本示例数据');
    }
  }
}
