import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'window_service.dart';

class SystemTrayService {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();

  void Function()? onShowHistory;
  void Function()? onSettings;
  void Function()? onQuit;

  String _appVersion = '';
  String _appName = '';

  Future<void> initialize() async {
    try {
      // 获取应用信息后再buildMenu
      await _loadAppInfo();
      await _initTrayAndMenu();
      print('System tray menu built successfully');
    } catch (e) {
      print('Error initializing system tray: $e');
      rethrow; // Re-throw to let caller handle
    }
  }

  Future<void> _initTrayAndMenu() async {
    print('📱 开始初始化系统托盘...');
    print('📱 平台信息: ${Platform.operatingSystem}');

    try {
      // 恢复原来的初始化方式，带图标
      String iconPath = _getIconPath();
      await _systemTray.initSystemTray(
        title: "",
        iconPath: iconPath,
        toolTip: "剪贴板历史管理",
      );
      print('✅ 系统托盘基础初始化成功');

      // 设置事件监听，修复事件名称
      _systemTray.registerSystemTrayEventHandler((eventName) {
        print('📱 系统托盘事件: $eventName');
        if (eventName == 'click' || eventName == 'right-click') {
          print('📱 系统托盘被点击，尝试显示菜单');
          _systemTray.popUpContextMenu();
        }
      });

      await _buildMenu();
    } catch (e) {
      print('❌ 系统托盘初始化失败: $e');
      rethrow;
    }
  }

  Future<void> _loadAppInfo() async {
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      _appName = packageInfo.appName.isNotEmpty ? packageInfo.appName : 'CCP';
      _appVersion = packageInfo.version.isNotEmpty
          ? packageInfo.version
          : '1.0.0';
      print('📱 应用信息已加载: $_appName v$_appVersion');
    } catch (e) {
      print('⚠️ 无法获取应用信息: $e');
      _appName = 'CCP';
      _appVersion = '1.0.0';
    }
  }

  String _getIconPath() {
    if (Platform.isMacOS) {
      return 'assets/icons/logo.png';
    }
    return 'assets/icons/logo.png';
  }

  Future<void> _buildMenu() async {
    print('📱 构建菜单项...');

    try {
      await _menu.buildFrom([
        MenuItemLabel(
          label: '📋 显示剪贴板历史',
          onClicked: (menuItem) {
            _closeAllDialogs();

            print('📱 点击了：显示剪贴板历史');
            if (onShowHistory != null) {
              onShowHistory!.call();
            } else {
              WindowService().showClipboardHistory();
            }
            _refreshMenu();
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '⚙️ 设置',
          onClicked: (menuItem) {
            print('📱 点击了：设置');
            if (onSettings != null) {
              onSettings!.call();
            } else {
              _showSettings();
            }
          },
        ),
        MenuItemLabel(
          label: 'ℹ️ 关于 $_appName',
          onClicked: (menuItem) {
            print('📱 点击了：关于');
            _showAbout();
          },
        ),
        MenuSeparator(),
        MenuItemLabel(
          label: '❌ 退出',
          onClicked: (menuItem) {
            print('📱 点击了：退出');
            if (onQuit != null) {
              onQuit!.call();
            } else {
              exit(0);
            }
          },
        ),
      ]);
      print('📱 菜单项构建成功，设置到系统托盘...');

      await _systemTray.setContextMenu(_menu);
      print('✅ 菜单已成功设置到系统托盘');
    } catch (e) {
      print('❌ 菜单构建或设置失败: $e');
      rethrow;
    }
  }

  void _refreshMenu() async {
    // 重新加载应用信息并刷新菜单
    await _loadAppInfo();
    await _rebuildMenuOnly();
  }

  Future<void> _rebuildMenuOnly() async {
    await _menu.buildFrom([
      MenuItemLabel(
        label: '📋 显示剪贴板历史',
        onClicked: (menuItem) {
          _closeAllDialogs();

          if (onShowHistory != null) {
            onShowHistory!.call();
          } else {
            WindowService().showClipboardHistory();
          }
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '⚙️ 设置',
        onClicked: (menuItem) {
          print('📱 _rebuildMenuOnly: 点击了设置');
          if (onSettings != null) {
            onSettings!.call();
          } else {
            _showSettings();
          }
        },
      ),
      MenuItemLabel(
        label: 'ℹ️ 关于 $_appName',
        onClicked: (menuItem) {
          _showAbout();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '❌ 退出',
        onClicked: (menuItem) {
          if (onQuit != null) {
            onQuit!.call();
          } else {
            exit(0);
          }
        },
      ),
    ]);
    await _systemTray.setContextMenu(_menu);
  }

  void _showSettings() async {
    print('📱 显示设置对话框，先显示窗口');
    // 关闭所有现有弹窗
    _closeAllDialogs();
    // 先显示窗口，确保有context
    await WindowService().showClipboardHistory();
    // 延迟一下确保窗口已显示
    await Future.delayed(Duration(milliseconds: 10));
    // 然后显示设置对话框
    WindowService().showSettingsDialog();
  }

  void _showAbout() async {
    print('📱 显示关于对话框，先显示窗口');
    // 关闭所有现有弹窗
    _closeAllDialogs();
    // 先显示窗口，确保有context
    await WindowService().showClipboardHistory();
    // 延迟一下确保窗口已显示
    await Future.delayed(Duration(milliseconds: 10));
    // 然后显示关于对话框
    _showAboutDialog();
  }

  void _closeAllDialogs() {
    final context = Get.context;
    if (context != null) {
      // 关闭所有现有的对话框
      Navigator.of(context, rootNavigator: true).popUntil((route) {
        return route.isFirst || !route.hasActiveRouteBelow;
      });
      print('📱 已关闭所有现有弹窗');
    }
  }

  void _showAboutDialog() {
    final context = Get.context;
    if (context != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 24),
              const SizedBox(width: 8),
              Text('关于 $_appName'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '版本：',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_appVersion),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text('描述：', style: TextStyle(fontWeight: FontWeight.bold)),
                  Expanded(child: Text('macOS 剪贴板历史管理工具')),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text('技术：', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('Flutter + Dart'),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '✨ 主要功能：',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text('• 自动监听剪贴板变化'),
                    Text('• 快捷键快速调用 (Cmd+Shift+V)'),
                    Text('• 数字键快速粘贴 (Cmd+1~9)'),
                    Text('• 自动粘贴到当前应用'),
                    Text('• 历史记录持久化存储'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    } else {
      // 如果没有Flutter context，使用macOS原生About Panel
      if (Platform.isMacOS) {
        _showNativeAboutPanel();
      }
    }
  }

  void _showNativeAboutPanel() {
    // 当没有Flutter context时，调用Flutter的aboutDialog
    _showAboutDialog();
  }

  Future<void> updateIcon({bool isActive = false}) async {
    try {
      await _systemTray.setImage(
        isActive ? _getActiveIconPath() : _getIconPath(),
      );
    } catch (e) {
      print('Error updating tray icon: $e');
    }
  }

  String _getActiveIconPath() {
    if (Platform.isMacOS) {
      return 'assets/icons/logo.png';
    }
    return 'assets/icons/logo.png';
  }

  void setCallbacks({
    void Function()? onShowHistory,
    void Function()? onSettings,
    void Function()? onQuit,
  }) {
    this.onShowHistory = onShowHistory;
    this.onSettings = onSettings;
    this.onQuit = onQuit;

    _rebuildMenuOnly();
  }

  Future<void> dispose() async {
    await _systemTray.destroy();
  }
}
