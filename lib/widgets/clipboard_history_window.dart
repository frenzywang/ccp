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
    print('🏗️ ClipboardHistoryWindow build开始');

    // 确保ClipboardController已初始化
    ClipboardController controller;
    try {
      controller = Get.find<ClipboardController>();
      print('✅ 找到现有的ClipboardController实例');
    } catch (e) {
      print('⚠️ 未找到ClipboardController，创建新实例: $e');
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
  final RxList<ClipboardItem> filteredItems = <ClipboardItem>[].obs;

  bool _isProcessingKeyEvent = false;
  Timer? _keyEventTimer;
  late ClipboardController _controller;

  @override
  void initState() {
    super.initState();
    print('🏗️ _ClipboardHistoryPageState initState开始');

    _controller = widget.controller;
    _searchController.addListener(_filterItems);

    // 监听controller的items变化
    ever(_controller.items, (List<ClipboardItem> items) {
      print('📊 检测到items变化: ${items.length} 条记录');
      _filterItems();
    });

    // 立即刷新数据
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print('🔄 PostFrameCallback: 开始刷新剪贴板数据...');

      // 强制刷新剪贴板内容
      await _controller.refreshClipboard();

      // 初始化筛选
      _filterItems();

      print('✅ PostFrameCallback: 数据刷新完成');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _keyEventTimer?.cancel();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty) {
      filteredItems.value = _controller.items.toList();
    } else {
      filteredItems.value = _controller.items
          .where((item) => item.content.toLowerCase().contains(query))
          .toList();
    }

    selectedIndex.value = 0;
    print('🔍 筛选结果: ${filteredItems.length} 条记录');
  }

  void _onItemTap(ClipboardItem item) {
    print(
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
      print('❌ 键盘事件处理错误: $e');
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
        if (digitIndex < filteredItems.length) {
          print('⚡ 快捷键 Cmd+${digitIndex + 1} 选择第${digitIndex + 1}项');
          _onItemTap(filteredItems[digitIndex]);
          return;
        }
      }
    }

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        selectedIndex.value = (selectedIndex.value - 1).clamp(
          0,
          filteredItems.length - 1,
        );
        break;
      case LogicalKeyboardKey.arrowDown:
        selectedIndex.value = (selectedIndex.value + 1).clamp(
          0,
          filteredItems.length - 1,
        );
        break;
      case LogicalKeyboardKey.enter:
        if (filteredItems.isNotEmpty &&
            selectedIndex.value < filteredItems.length) {
          _onItemTap(filteredItems[selectedIndex.value]);
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
                        print('🚪 关闭按钮被点击');
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
                child: GetX<ClipboardController>(
                  init: _controller, // 明确指定使用的控制器实例
                  builder: (controller) {
                    print('🎨 UI Builder: items=${controller.items.length}');

                    print('📱 显示数据界面，filteredItems=${filteredItems.length}');
                    return Obx(() {
                      if (filteredItems.isEmpty) {
                        print('📭 显示空状态界面');
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
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      print('📋 显示列表界面，${filteredItems.length} 条记录');
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filteredItems.length,
                        itemBuilder: (context, index) {
                          final item = filteredItems[index];

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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                                _truncateText(
                                                  item.content,
                                                  100,
                                                ),
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
                    });
                  },
                ),
              ),
              // Footer
              Obx(() {
                if (filteredItems.isEmpty) return const SizedBox.shrink();

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
                        '共 ${filteredItems.length} 条记录',
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
