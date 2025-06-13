import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import 'package:flutter/services.dart';

class ClipboardController extends GetxController {
  // 静态进程标志
  static bool _isMainProcessFlag = true;

  // 内存中的剪贴板数据 - 使用响应式变量
  final RxList<ClipboardItem> _items = <ClipboardItem>[].obs;

  // 简单的通知机制
  final RxInt _updateTrigger = 0.obs;

  // 选中索引管理
  final RxInt _selectedIndex = 0.obs;

  // Getters - 正确返回响应式变量
  List<ClipboardItem> get items => _items;
  int get itemCount => _items.length;
  bool get isEmpty => _items.isEmpty;
  int get selectedIndex => _selectedIndex.value;

  // 进程类型管理
  static void setProcessType({required bool isMainProcess}) {
    print('🔧 ClipboardController.setProcessType() 被调用: $isMainProcess');
    _isMainProcessFlag = isMainProcess;
    print('✅ _isMainProcessFlag 已设置为: $_isMainProcessFlag');
  }

  bool get _isMainProcess {
    return _isMainProcessFlag;
  }

  // 公共getter用于外部访问进程类型
  bool get isMainProcess => _isMainProcess;

  @override
  void onInit() {
    super.onInit();
    print('🎮 ClipboardController: 初始化');
    print('🔍 进程检测: _isMainProcess = $_isMainProcess');
    print('✅ ClipboardController: 初始化完成');
  }

  // 添加剪贴板项目（单窗口模式）
  Future<void> addItem(
    String content, {
    ClipboardItemType type = ClipboardItemType.text,
    String? imagePath,
    int? imageWidth,
    int? imageHeight,
  }) async {
    print(
      '🔥 addItem 被调用，内容: ${content.substring(0, content.length > 30 ? 30 : content.length)}...',
    );
    print('🔥 当前列表长度: ${_items.length}');

    // 过滤重复内容
    if (_items.any((item) => item.content == content)) {
      print(
        '🔄 内容已存在，移动到顶部: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}',
      );
      _items.removeWhere((item) => item.content == content);
    } else {
      print(
        '➕ 新增剪贴板项目: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}',
      );
    }

    // 创建新项目并添加到顶部
    final newItem = ClipboardItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: type,
      createdAt: DateTime.now(),
      imagePath: imagePath,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    _items.insert(0, newItem);
    print('🔥 项目已插入，新的列表长度: ${_items.length}');

    // 保持最多100条记录
    if (_items.length > 100) {
      _items.removeRange(100, _items.length);
    }

    // 强制触发响应式更新
    _items.refresh();
    _notifyUpdate();
    print('📊 单窗口模式：内存数据更新完成，当前 ${_items.length} 条记录');
    print('🔥 响应式更新触发器值: ${_updateTrigger.value}');
    print('💫 强制刷新RxList完成');
  }

  // 添加剪贴板项目（子进程版本）
  Future<void> addItemInSubProcess(
    String content, {
    ClipboardItemType type = ClipboardItemType.text,
    String? imagePath,
    int? imageWidth,
    int? imageHeight,
  }) async {
    if (_isMainProcess) {
      print('⚠️ 主进程应使用addItem方法');
      return;
    }

    print(
      '🔥 addItemInSubProcess 被调用，内容: ${content.substring(0, content.length > 30 ? 30 : content.length)}...',
    );
    print('🔥 当前列表长度: ${_items.length}');

    // 过滤重复内容
    if (_items.any((item) => item.content == content)) {
      print(
        '🔄 内容已存在，移动到顶部: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}',
      );
      _items.removeWhere((item) => item.content == content);
    } else {
      print(
        '➕ 新增剪贴板项目: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}',
      );
    }

    // 创建新项目并添加到顶部
    final newItem = ClipboardItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: type,
      createdAt: DateTime.now(),
      imagePath: imagePath,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    _items.insert(0, newItem);
    print('🔥 项目已插入，新的列表长度: ${_items.length}');

    // 保持最多100条记录
    if (_items.length > 100) {
      _items.removeRange(100, _items.length);
    }

    // 强制触发响应式更新
    _items.refresh();
    _notifyUpdate();
    print('📊 子进程：内存数据更新完成，当前 ${_items.length} 条记录');
    print('🔥 响应式更新触发器值: ${_updateTrigger.value}');
    print('💫 强制刷新RxList完成');
  }

  // 从存储加载数据（子进程）- 现在只清空数据，不从存储加载
  Future<void> loadFromStorage() async {
    try {
      _items.clear();
      _notifyUpdate();
      print('✅ 子进程：内存数据已清空，准备接收新的剪贴板数据');
    } catch (e) {
      print('❌ 清空内存数据失败: $e');
    }
  }

  // 复制到剪贴板
  Future<void> copyToClipboard(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
      print('📋 内容已复制到剪贴板');
    } catch (e) {
      print('❌ 复制到剪贴板失败: $e');
    }
  }

  // 刷新数据（触发UI更新）
  void refreshData() {
    _notifyUpdate();
    print('🔄 ClipboardController: 数据已刷新');
  }

  // 清空历史记录
  Future<void> clearHistory() async {
    _items.clear();
    _selectedIndex.value = 0;
    _notifyUpdate();
    print('🗑️ 剪贴板历史已清空（仅内存）');
  }

  // 选择管理方法
  void moveSelectionUp() {
    if (_items.isNotEmpty) {
      _selectedIndex.value = (_selectedIndex.value - 1).clamp(
        0,
        _items.length - 1,
      );
      print('⬆️ 选中索引: ${_selectedIndex.value}');
    }
  }

  void moveSelectionDown() {
    if (_items.isNotEmpty) {
      _selectedIndex.value = (_selectedIndex.value + 1).clamp(
        0,
        _items.length - 1,
      );
      print('⬇️ 选中索引: ${_selectedIndex.value}');
    }
  }

  void resetSelection() {
    _selectedIndex.value = 0;
  }

  // 通知更新
  void _notifyUpdate() {
    _updateTrigger.value++;
    // 确保选中索引在有效范围内
    if (_selectedIndex.value >= _items.length && _items.isNotEmpty) {
      _selectedIndex.value = _items.length - 1;
    }
  }

  @override
  void onClose() {
    print('🧹 ClipboardController: 销毁');
    super.onClose();
  }
}
