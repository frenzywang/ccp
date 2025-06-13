import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../models/clipboard_item.dart';
import '../controllers/clipboard_controller.dart';
import '../services/window_service.dart';
import '../services/clipboard_service.dart';
import '../services/native_clipboard_service.dart';
import 'dart:io';
import 'dart:typed_data';

class ClipboardHistoryWindow extends StatelessWidget {
  const ClipboardHistoryWindow({super.key});

  @override
  Widget build(BuildContext context) {
    print('🏗️ ClipboardHistoryWindow build开始');

    // 获取Controller实例
    final controller = Get.find<ClipboardController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (RawKeyEvent event) {
          if (event is RawKeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            print('⌨️ ESC键隐藏窗口');
            WindowService().hideClipboardHistory();
          }
        },
        child: GestureDetector(
          child: Focus(
            autofocus: false, // 不自动获得焦点，避免抢夺原应用焦点
            onFocusChange: (hasFocus) {
              print('🔍 剪贴板窗口焦点变化: $hasFocus');
              // 完全移除自动隐藏逻辑，让用户手动控制
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
      height: 30,
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
              print('⚙️ 点击设置按钮，打开设置窗口');
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
      print(
        '🎨 UI Builder: items=${items.length}, selectedIndex=$selectedIndex',
      );

      if (items.isEmpty) {
        print('📭 显示空状态界面');
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

      print('📋 显示列表界面，${items.length} 条记录');

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
                            // 根据类型显示不同内容
                            if (item.type == ClipboardItemType.image) ...[
                              // 图片内容
                              Row(
                                children: [
                                  // 图片缩略图
                                  if (item.imagePath != null &&
                                      File(item.imagePath!).existsSync())
                                    Container(
                                      width: 50,
                                      height: 50,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.file(
                                          File(item.imagePath!),
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey.shade200,
                                                  child: const Icon(
                                                    Icons.broken_image,
                                                    color: Colors.grey,
                                                    size: 24,
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 50,
                                      height: 50,
                                      margin: const EdgeInsets.only(right: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                        size: 24,
                                      ),
                                    ),
                                  // 图片信息
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.content,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        if (item.imageWidth != null &&
                                            item.imageHeight != null)
                                          Text(
                                            '${item.imageWidth}×${item.imageHeight}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
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
                            ],
                            const SizedBox(height: 4),
                            // 元数据
                            Row(
                              children: [
                                // 类型图标
                                Icon(
                                  item.type == ClipboardItemType.image
                                      ? Icons.image
                                      : Icons.text_fields,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(item.createdAt),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  item.type == ClipboardItemType.image
                                      ? 'Image'
                                      : '${item.content.length} chars',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                if (item.type == ClipboardItemType.text &&
                                    item.content.length > 120) ...[
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

    print(
      '🎹 按键事件: ${event.logicalKey.debugName}, Meta: ${event.logicalKey == LogicalKeyboardKey.meta}',
    );

    final items = controller.items;
    if (items.isEmpty) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
        print('🔙 Escape键: 隐藏窗口');
        WindowService().hideClipboardHistory();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.enter:
        print('✅ Enter键: 选择项目 ${controller.selectedIndex}');
        if (controller.selectedIndex < items.length) {
          _onItemTap(items[controller.selectedIndex], controller);
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        print('⬆️ 上箭头: 向上选择');
        controller.moveSelectionUp();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowDown:
        print('⬇️ 下箭头: 向下选择');
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
          print('🔢 Cmd+${index + 1}: 选择项目 $index');
          if (index < items.length) {
            _onItemTap(items[index], controller);
          }
          return KeyEventResult.handled;
        }
        break;

      // Command+0 (选择第10项)
      case LogicalKeyboardKey.digit0:
        if (HardwareKeyboard.instance.isMetaPressed) {
          print('🔢 Cmd+0: 选择项目 9 (第10项)');
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
    print('📋 选择剪贴板项目: $preview');

    try {
      // 0. 在复制前暂停剪贴板监听，防止循环触发
      try {
        final clipboardService = ClipboardService();
        clipboardService.pauseWatching(milliseconds: 3000);
        print('⏸️ 暂停剪贴板监听，防止循环触发');
      } catch (e) {
        print('⚠️ 暂停监听失败: $e');
      }

      // 1. 根据类型复制到系统剪贴板
      if (item.type == ClipboardItemType.image && item.imagePath != null) {
        // 图片类型：重新加载图片文件并设置到剪贴板
        print('🖼️ 正在重新加载图片文件: ${item.imagePath}');
        await _copyImageToClipboard(item.imagePath!);
      } else {
        // 文本类型：直接复制文本内容
        await controller.copyToClipboard(item.content);
        print('📋 内容已通过GetX复制到剪贴板');
      }

      // 2. 隐藏窗口
      final windowService = WindowService();
      await windowService.hideClipboardHistory();

      // 3. 模拟粘贴
      await windowService.simulatePaste();
      print('🎉 自动粘贴流程完成');
    } catch (e) {
      print('❌ 选择项目时出错: $e');
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

  Future<void> _copyImageToClipboard(String imagePath) async {
    try {
      // 读取图片文件
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        print('❌ 图片文件不存在: $imagePath');
        return;
      }

      final Uint8List imageData = await imageFile.readAsBytes();
      print('🖼️ 已读取图片文件: ${imageData.length} 字节');

      // 使用原生API设置图片到剪贴板
      final bool success = await NativeClipboardService.setImageData(imageData);
      if (success) {
        print('✅ 图片已成功设置到剪贴板');
      } else {
        print('❌ 设置图片到剪贴板失败');
      }
    } catch (e) {
      print('❌ 复制图片到剪贴板失败: $e');
    }
  }
}
