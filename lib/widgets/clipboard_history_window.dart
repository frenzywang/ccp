import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import '../controllers/clipboard_controller.dart';

class ClipboardHistoryWindow extends StatelessWidget {
  final Function(ClipboardItem)? onItemSelected;
  final VoidCallback? onClose;

  const ClipboardHistoryWindow({super.key, this.onItemSelected, this.onClose});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ ClipboardHistoryWindow build开始');

    // 确保ClipboardController已初始化
    ClipboardController controller;
    try {
      controller = Get.find<ClipboardController>();
      debugPrint('✅ 找到现有的ClipboardController实例');
    } catch (e) {
      debugPrint('⚠️ 未找到ClipboardController，创建新实例: $e');
      controller = Get.put(ClipboardController(), permanent: true);
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _ClipboardHistoryPage(
        onItemSelected: onItemSelected,
        onClose: onClose,
        controller: controller,
      ),
    );
  }
}

class _ClipboardHistoryPage extends StatefulWidget {
  final Function(ClipboardItem)? onItemSelected;
  final VoidCallback? onClose;
  final ClipboardController controller;

  const _ClipboardHistoryPage({
    this.onItemSelected,
    this.onClose,
    required this.controller,
  });

  @override
  State<_ClipboardHistoryPage> createState() => _ClipboardHistoryPageState();
}

class _ClipboardHistoryPageState extends State<_ClipboardHistoryPage> {
  final TextEditingController _searchController = TextEditingController();
  final RxInt selectedIndex = 0.obs;

  bool _isProcessingKeyEvent = false;
  Timer? _keyEventTimer;
  late ClipboardController _controller;

  @override
  void initState() {
    super.initState();
    debugPrint('🏗️ _ClipboardHistoryPageState initState开始');

    _controller = widget.controller;

    // 直接使用controller的过滤结果，不需要额外监听
    // filteredItems 将直接从 controller.filteredItems 获取

    // 监听搜索框变化，使用controller的搜索功能
    _searchController.addListener(() {
      _controller.searchItems(_searchController.text);
    });

    // 立即应用过滤（数据已经在内存中）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('🔄 PostFrameCallback: 应用初始过滤...');
      debugPrint('📊 PostFrameCallback: 当前数据总数 = ${_controller.items.length}');
      _controller.refreshData();
      debugPrint(
        '✅ PostFrameCallback: 过滤应用完成, filteredItems = ${_controller.filteredItems.length}',
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _keyEventTimer?.cancel();
    super.dispose();
  }

  void _onItemTap(ClipboardItem item) {
    debugPrint(
      '🎯 用户选择了项目: ${item.content.length > 50 ? "${item.content.substring(0, 50)}..." : item.content}',
    );
    widget.onItemSelected?.call(item);
    widget.onClose?.call();
  }

  KeyEventResult _onKeyEvent(KeyEvent event) {
    if (_isProcessingKeyEvent || event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }

    try {
      _isProcessingKeyEvent = true;
      _handleKeyDown(event);

      Timer(const Duration(milliseconds: 100), () {
        _isProcessingKeyEvent = false;
      });

      return KeyEventResult.handled;
    } catch (e) {
      debugPrint('❌ 键盘事件处理错误: $e');
      _isProcessingKeyEvent = false;
      return KeyEventResult.handled;
    }
  }

  void _handleKeyDown(KeyDownEvent event) {
    // 处理 Command + 数字键快捷选择
    if (event.logicalKey.keyId >= LogicalKeyboardKey.digit1.keyId &&
        event.logicalKey.keyId <= LogicalKeyboardKey.digit9.keyId) {
      if (HardwareKeyboard.instance.isMetaPressed) {
        final digitIndex =
            event.logicalKey.keyId - LogicalKeyboardKey.digit1.keyId;
        if (digitIndex < _controller.filteredItems.length) {
          debugPrint('⚡ 快捷键 Cmd+${digitIndex + 1} 选择第${digitIndex + 1}项');
          _onItemTap(_controller.filteredItems[digitIndex]);
          return;
        }
      }
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        selectedIndex.value = (selectedIndex.value - 1).clamp(
          0,
          _controller.filteredItems.length - 1,
        );
        break;
      case LogicalKeyboardKey.arrowDown:
        selectedIndex.value = (selectedIndex.value + 1).clamp(
          0,
          _controller.filteredItems.length - 1,
        );
        break;
      case LogicalKeyboardKey.enter:
        if (_controller.filteredItems.isNotEmpty &&
            selectedIndex.value < _controller.filteredItems.length) {
          _onItemTap(_controller.filteredItems[selectedIndex.value]);
        }
        break;
      case LogicalKeyboardKey.escape:
        widget.onClose?.call();
        break;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => _onKeyEvent(event),
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.white,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(width: 8),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        debugPrint('🚪 关闭按钮被点击');
                        widget.onClose?.call();
                      },
                      icon: const Icon(Icons.close, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        minimumSize: const Size(32, 32),
                      ),
                    ),
                  ],
                ),
              ),
              // Search bar
              Container(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: '搜索剪贴板历史...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF1F3F4),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              // Content
              Expanded(
                child: Obx(() {
                  debugPrint(
                    '🎨 UI Builder: items=${_controller.items.length}',
                  );

                  debugPrint(
                    '📱 显示数据界面，filteredItems=${_controller.filteredItems.length}',
                  );
                  if (_controller.filteredItems.isEmpty) {
                    debugPrint('📭 显示空状态界面');
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.content_paste_off,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '暂无剪贴板历史',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '复制一些文本开始使用',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  debugPrint(
                    '📋 显示列表界面，${_controller.filteredItems.length} 条记录',
                  );
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _controller.filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _controller.filteredItems[index];

                      return Obx(() {
                        final isSelected = index == selectedIndex.value;

                        return Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          child: Material(
                            color: isSelected
                                ? Colors.blue.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => _onItemTap(item),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // 序号显示
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey.shade400,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.text_snippet,
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey.shade600,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _truncateText(item.content, 100),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? Colors.blue
                                                  : Colors.black87,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatTime(item.createdAt),
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      });
                    },
                  );
                }),
              ),
              // Footer
              Obx(() {
                if (_controller.filteredItems.isEmpty)
                  return const SizedBox.shrink();

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '共 ${_controller.filteredItems.length} 条记录',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        '↑↓ 选择 • Enter 粘贴 • Cmd+1-9 快选 • Esc 退出',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
