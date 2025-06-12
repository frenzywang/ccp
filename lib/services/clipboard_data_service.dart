import 'dart:async';
import 'package:flutter/material.dart';

import '../models/clipboard_item.dart';
import 'storage_service.dart';

/// 剪贴板数据服务
/// 简化版本：只负责存储服务初始化
/// 数据管理完全由 ClipboardController 负责
class ClipboardDataService {
  static final ClipboardDataService _instance =
      ClipboardDataService._internal();
  factory ClipboardDataService() => _instance;
  ClipboardDataService._internal();

  final StorageService _storageService = StorageService();
  bool _isInitialized = false;

  /// 初始化服务（只在主进程中调用）
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('📦 ClipboardDataService 已初始化，跳过');
      return;
    }

    try {
      debugPrint('🚀 初始化 ClipboardDataService...');

      // 只初始化存储服务，数据管理由 ClipboardController 负责
      await _storageService.initialize();
      debugPrint('✅ 存储服务初始化完成');

      _isInitialized = true;
      debugPrint('✅ ClipboardDataService 初始化完成');
    } catch (e) {
      debugPrint('❌ ClipboardDataService 初始化失败: $e');
      _isInitialized = true; // 即使失败也标记为已初始化
    }
  }

  /// 获取存储服务（供其他服务使用）
  StorageService get storageService => _storageService;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 获取统计信息
  Map<String, dynamic> getStats() {
    return {
      'initialized': _isInitialized,
      'storageInitialized': _storageService.isInitialized,
    };
  }

  /// 关闭服务
  Future<void> dispose() async {
    try {
      debugPrint('🚪 关闭 ClipboardDataService...');

      // 关闭存储服务
      await _storageService.dispose();

      // 重置状态
      _isInitialized = false;

      debugPrint('✅ ClipboardDataService 已关闭');
    } catch (e) {
      debugPrint('⚠️ 关闭服务时出错: $e');
    }
  }
}
