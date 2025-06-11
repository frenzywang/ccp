import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import '../services/hotkey_service.dart';
import '../services/clipboard_service.dart';

class SettingsWindow extends StatefulWidget {
  final VoidCallback? onClose;

  const SettingsWindow({super.key, this.onClose});

  @override
  State<SettingsWindow> createState() => _SettingsWindowState();
}

class _SettingsWindowState extends State<SettingsWindow> {
  final HotkeyService _hotkeyService = HotkeyService();
  final ClipboardService _clipboardService = ClipboardService();

  String _selectedKey = 'KeyV';
  Set<HotKeyModifier> _selectedModifiers = {
    HotKeyModifier.meta,
    HotKeyModifier.shift,
  };

  int _maxItems = 50;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }

  void _loadCurrentSettings() {
    _maxItems = _clipboardService.maxItems;
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
    });
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
    });
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      if (_isRecording) {
        _stopRecording();
      } else {
        widget.onClose?.call();
      }
      return;
    }

    if (_isRecording && event is KeyDownEvent) {
      final key = event.logicalKey;
      final modifiers = <HotKeyModifier>{};

      if (RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.metaLeft,
          ) ||
          RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.metaRight,
          )) {
        modifiers.add(HotKeyModifier.meta);
      }
      if (RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.shiftLeft,
          ) ||
          RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.shiftRight,
          )) {
        modifiers.add(HotKeyModifier.shift);
      }
      if (RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.altLeft,
          ) ||
          RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.altRight,
          )) {
        modifiers.add(HotKeyModifier.alt);
      }
      if (RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.controlLeft,
          ) ||
          RawKeyboard.instance.keysPressed.contains(
            LogicalKeyboardKey.controlRight,
          )) {
        modifiers.add(HotKeyModifier.control);
      }

      if (_isValidKey(key) && modifiers.isNotEmpty) {
        setState(() {
          _selectedKey = _getKeyCode(key);
          _selectedModifiers = modifiers;
        });
        _stopRecording();
      }
    }
  }

  bool _isValidKey(LogicalKeyboardKey key) {
    return key.keyLabel.length == 1 &&
        RegExp(r'[A-Za-z]').hasMatch(key.keyLabel);
  }

  String _getKeyCode(LogicalKeyboardKey key) {
    return 'Key${key.keyLabel.toUpperCase()}';
  }

  String _getHotkeyText() {
    final modifierText = _selectedModifiers
        .map((modifier) {
          switch (modifier) {
            case HotKeyModifier.meta:
              return 'Cmd';
            case HotKeyModifier.shift:
              return 'Shift';
            case HotKeyModifier.alt:
              return 'Alt';
            case HotKeyModifier.control:
              return 'Ctrl';
            default:
              return '';
          }
        })
        .join(' + ');

    final key = _selectedKey.replaceAll('Key', '');
    return '$modifierText + $key';
  }

  Future<void> _saveSettings() async {
    try {
      await _hotkeyService.saveHotkeyConfig(
        _selectedKey,
        _selectedModifiers.toList(),
      );
      _clipboardService.maxItems = _maxItems;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('设置已保存')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
    }
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有粘贴板历史记录吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _clipboardService.clearHistory();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('历史记录已清空')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _onKeyEvent,
      child: Container(
        width: 500,
        height: 600,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.settings, size: 24),
                    const SizedBox(width: 12),
                    const Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close),
                      tooltip: '关闭 (Esc)',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(
                          context,
                        ).primaryColor.withOpacity(0.1),
                        foregroundColor: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hotkey Settings
                      const Text(
                        '快捷键设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('当前快捷键:'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _isRecording
                                          ? Colors.red.withOpacity(0.1)
                                          : Theme.of(
                                              context,
                                            ).inputDecorationTheme.fillColor,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: _isRecording
                                            ? Colors.red
                                            : Theme.of(context).dividerColor,
                                      ),
                                    ),
                                    child: Text(
                                      _isRecording
                                          ? '按下新的快捷键...'
                                          : _getHotkeyText(),
                                      style: TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.bold,
                                        color: _isRecording ? Colors.red : null,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: _isRecording
                                      ? _stopRecording
                                      : _startRecording,
                                  child: Text(_isRecording ? '取消' : '更改'),
                                ),
                              ],
                            ),
                            if (_isRecording) ...[
                              const SizedBox(height: 8),
                              const Text(
                                '请按下新的快捷键组合。确保包含修饰键（Cmd/Ctrl/Alt/Shift）。',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // History Settings
                      const Text(
                        '历史记录设置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('最大保存记录数:'),
                                const Spacer(),
                                SizedBox(
                                  width: 100,
                                  child: TextFormField(
                                    initialValue: _maxItems.toString(),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      final intValue = int.tryParse(value);
                                      if (intValue != null && intValue > 0) {
                                        _maxItems = intValue;
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _clearHistory,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('清空历史记录'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.withOpacity(0.1),
                                  foregroundColor: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saveSettings,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('保存设置'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
