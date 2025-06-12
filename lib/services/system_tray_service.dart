import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

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
    try {
      await _systemTray.initSystemTray(title: "", iconPath: _getIconPath());
      print('System tray initialized with icon');
    } catch (iconError) {
      print('Warning: Could not initialize with icon: $iconError');
      await _systemTray.initSystemTray(title: "", iconPath: '');
      print('System tray initialized without icon');
    }
    await _buildMenu();
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
    await _menu.buildFrom([
      MenuItemLabel(
        label: '📋 显示剪贴板历史',
        onClicked: (menuItem) {
          onShowHistory?.call();
          _refreshMenu();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(
        label: '⚙️ 设置',
        onClicked: (menuItem) {
          onSettings?.call();
          _refreshMenu();
        },
      ),
      MenuItemLabel(
        label: 'ℹ️ 关于 $_appName',
        onClicked: (menuItem) {
          _showAboutDialog();
          _refreshMenu();
        },
      ),
      MenuSeparator(),
      MenuItemLabel(label: '❌ 退出', onClicked: (menuItem) => onQuit?.call()),
    ]);
    await _systemTray.setContextMenu(_menu);
  }

  void _refreshMenu() async {
    // 重新加载应用信息并刷新菜单
    await _loadAppInfo();
    await _buildMenu();
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
    // macOS原生About Panel
    final DynamicLibrary appKit = DynamicLibrary.open(
      '/System/Library/Frameworks/AppKit.framework/AppKit',
    );
    final void Function() orderFrontStandardAboutPanel = appKit
        .lookup<NativeFunction<Void Function()>>(
          'NSApplication_orderFrontStandardAboutPanel_',
        )
        .asFunction();
    orderFrontStandardAboutPanel();
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
  }

  Future<void> dispose() async {
    await _systemTray.destroy();
  }
}
