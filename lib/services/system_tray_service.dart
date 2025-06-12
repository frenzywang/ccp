import 'dart:io';
import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';

class SystemTrayService {
  static final SystemTrayService _instance = SystemTrayService._internal();
  factory SystemTrayService() => _instance;
  SystemTrayService._internal();

  final SystemTray _systemTray = SystemTray();
  final Menu _menu = Menu();

  void Function()? onShowHistory;
  void Function()? onSettings;
  void Function()? onQuit;

  Future<void> initialize() async {
    try {
      // Try to initialize with icon
      try {
        await _systemTray.initSystemTray(
          title: "CCP",
          iconPath: _getIconPath(),
        );
        debugPrint('System tray initialized with icon');
      } catch (iconError) {
        debugPrint('Warning: Could not initialize with icon: $iconError');
        // Try without specific icon path - use default
        await _systemTray.initSystemTray(
          title: "CCP",
          iconPath: '', // Empty icon path
        );
        debugPrint('System tray initialized without icon');
      }

      await _buildMenu();
      debugPrint('System tray menu built successfully');
    } catch (e) {
      debugPrint('Error initializing system tray: $e');
      rethrow; // Re-throw to let caller handle
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
        label: '显示历史记录',
        onClicked: (menuItem) => onShowHistory?.call(),
      ),
      MenuSeparator(),
      MenuItemLabel(label: '设置', onClicked: (menuItem) => onSettings?.call()),
      MenuSeparator(),
      MenuItemLabel(label: '退出', onClicked: (menuItem) => onQuit?.call()),
    ]);

    await _systemTray.setContextMenu(_menu);
  }

  Future<void> updateIcon({bool isActive = false}) async {
    try {
      await _systemTray.setImage(
        isActive ? _getActiveIconPath() : _getIconPath(),
      );
    } catch (e) {
      debugPrint('Error updating tray icon: $e');
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
