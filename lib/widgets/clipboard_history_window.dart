import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import '../controllers/clipboard_controller.dart';
import '../services/window_service.dart';

class ClipboardHistoryWindow extends StatelessWidget {
  const ClipboardHistoryWindow({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🏗️ ClipboardHistoryWindow build开始');

    // 获取Controller实例
    final controller = Get.find<ClipboardController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            debugPrint('⌨️ ESC键隐藏窗口');
            WindowService().hideClipboardHistory();
          }
        },
        child: GestureDetector(
          // 点击空白区域隐藏窗口
          onTap: () {
            debugPrint('👆 点击空白区域，隐藏窗口');
            WindowService().hideClipboardHistory();
          },
          child: Focus(
            autofocus: false, // 不自动获得焦点，避免抢夺原应用焦点
            onFocusChange: (hasFocus) {
              if (!hasFocus) {
                debugPrint('🙈 剪贴板窗口失去焦点，自动隐藏');
                // 延迟隐藏，避免立即触发
                Future.delayed(const Duration(milliseconds: 200), () {
                  WindowService().hideClipboardHistory();
                });
              }
            },
            onKeyEvent: (node, event) =>
                _handleKeyEvent(node, event, controller),
            child: GestureDetector(
              // 防止内容区域的点击事件冒泡
              onTap: () {},
              child: Container(
                width: double.infinity,
                height: double.infinity,
                child: Column(
                  children: [
                    // 标题栏
                    _buildHeader(),
                    // 内容区域
                    Expanded(child: _buildContent(controller)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Icon(Icons.content_paste, color: Colors.grey, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Clipboard History',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.settings, size: 18),
            onPressed: () {
              debugPrint('⚙️ 点击设置按钮，打开设置窗口');
              WindowService().showSettings();
            },
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ClipboardController controller) {
    return Obx(() {
      // 监听更新触发器和列表变化
      controller.items;
      final selectedIndex = controller.selectedIndex;
      final items = List<ClipboardItem>.from(controller.items);
      debugPrint(
        '🎨 UI Builder: items=${items.length}, selectedIndex=$selectedIndex',
      );

      if (items.isEmpty) {
        debugPrint('📭 显示空状态界面');
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.content_paste_off, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No clipboard history',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Copy some text to get started',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        );
      }

      debugPrint('📋 显示列表界面，${items.length} 条记录');

      return ListView.builder(
        primary: true,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: items.length,
        shrinkWrap: false,
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = index == selectedIndex;
          final isTopTen = index < 10;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.blue.withOpacity(0.3), width: 2)
                  : null,
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _onItemTap(item, controller),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 热键提示圆圈（前10项）
                      if (isTopTen)
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.8),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '⌘${index == 9 ? '0' : '${index + 1}'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      // 内容区域
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 文本内容
                            Text(
                              _truncateText(item.content, 120),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            // 元数据
                            Row(
                              children: [
                                Text(
                                  _formatTime(item.createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${item.content.length} chars',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (item.content.length > 120) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.more_horiz,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ],
                              ],
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
        },
      );
    });
  }

  KeyEventResult _handleKeyEvent(
    FocusNode node,
    KeyEvent event,
    ClipboardController controller,
  ) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    debugPrint(
      '🎹 按键事件: ${event.logicalKey.debugName}, Meta: ${event.logicalKey == LogicalKeyboardKey.meta}',
    );

    final items = controller.items;
    if (items.isEmpty) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        debugPrint('🔙 Escape键: 隐藏窗口');
        WindowService().hideClipboardHistory();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
        debugPrint('✅ Enter键: 选择项目 ${controller.selectedIndex}');
        if (controller.selectedIndex < items.length) {
          _onItemTap(items[controller.selectedIndex], controller);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        debugPrint('⬆️ 上箭头: 向上选择');
        controller.moveSelectionUp();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        debugPrint('⬇️ 下箭头: 向下选择');
        controller.moveSelectionDown();
        return KeyEventResult.handled;

      // Command+1-9 快捷键
      case LogicalKeyboardKey.digit1:
      case LogicalKeyboardKey.digit2:
      case LogicalKeyboardKey.digit3:
      case LogicalKeyboardKey.digit4:
      case LogicalKeyboardKey.digit5:
      case LogicalKeyboardKey.digit6:
      case LogicalKeyboardKey.digit7:
      case LogicalKeyboardKey.digit8:
      case LogicalKeyboardKey.digit9:
        if (HardwareKeyboard.instance.isMetaPressed) {
          final index =
              int.parse(event.logicalKey.debugName!.split('digit')[1]) - 1;
          debugPrint('🔢 Cmd+${index + 1}: 选择项目 $index');
          if (index < items.length) {
            _onItemTap(items[index], controller);
          }
          return KeyEventResult.handled;
        }
        break;

      // Command+0 (选择第10项)
      case LogicalKeyboardKey.digit0:
        if (HardwareKeyboard.instance.isMetaPressed) {
          debugPrint('🔢 Cmd+0: 选择项目 9 (第10项)');
          if (items.length > 9) {
            _onItemTap(items[9], controller);
          }
          return KeyEventResult.handled;
        }
        break;
    }

    return KeyEventResult.ignored;
  }

  void _onItemTap(ClipboardItem item, ClipboardController controller) async {
    final preview = item.content.length > 50
        ? '${item.content.substring(0, 50)}...'
        : item.content;
    debugPrint('📋 选择剪贴板项目: $preview');

    try {
      // 1. 直接使用 Controller 复制到系统剪贴板
      await controller.copyToClipboard(item.content);
      debugPrint('📋 内容已通过GetX复制到剪贴板');

      // 2. 隐藏窗口
      final windowService = WindowService();
      await windowService.hideClipboardHistory();
      debugPrint('🙈 窗口已隐藏');

      // 3. 模拟粘贴
      await windowService.simulatePaste();
      debugPrint('🎉 自动粘贴流程完成');
    } catch (e) {
      debugPrint('❌ 选择项目时出错: $e');
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
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
}
