# Clipboard Manager (CCP)

一个现代化的 macOS 粘贴板历史管理工具，使用 Flutter 开发。

## ✨ 功能特色

- 🔄 **自动监听粘贴板** - 实时监听并保存粘贴板变化
- ⌨️ **全局快捷键** - 默认 `Cmd+Shift+V` 快速调出历史记录
- 🔍 **智能搜索** - 快速搜索历史记录
- 🎯 **键盘导航** - 支持上下键选择，Enter 确认，Esc 退出
- 🗂️ **本地存储** - 历史记录持久化保存
- 🎨 **现代界面** - 支持亮色/暗色主题
- ⚙️ **灵活配置** - 自定义快捷键和保存数量
- 📋 **文本过滤** - 粘贴时只保留纯文本，去除格式
- 🔧 **系统托盘** - 在状态栏显示图标和菜单

## 🚀 快速开始

### 环境要求

- macOS 10.14 或更新版本
- Flutter SDK 3.8.1 或更新版本

### 安装依赖

```bash
flutter pub get
```

### 构建应用

```bash
# 调试版本
flutter build macos --debug

# 发布版本
flutter build macos --release
```

### 运行应用

```bash
# 推荐：使用启动脚本（会自动构建并启动）
./launch_app.sh

# 或者手动构建后启动
flutter build macos --release
open build/macos/Build/Products/Release/ccp.app

# 开发模式
./run_app.sh
```

## 🎮 使用方法

### 基本操作

1. **启动应用** - 运行后应用会在系统托盘显示图标
2. **查看历史** - 按 `Cmd+Shift+V` 或点击托盘图标选择"显示历史记录"
3. **搜索记录** - 在弹出窗口中直接输入搜索关键词
4. **选择记录** - 使用鼠标点击或键盘上下键选择
5. **粘贴内容** - 按 Enter 键或双击选中项目

### 快捷键

- `Cmd+Shift+V` - 显示粘贴板历史记录
- `↑/↓` - 选择记录
- `Enter` - 粘贴选中的记录
- `Esc` - 关闭历史窗口

### 系统托盘菜单

- **显示历史记录** - 打开历史记录窗口
- **设置** - 打开设置界面
- **退出** - 退出应用

## ⚙️ 设置选项

### 快捷键配置

1. 点击托盘图标选择"设置"
2. 在快捷键设置区域点击"更改"
3. 按下新的快捷键组合
4. 点击"保存设置"

### 历史记录设置

- **最大保存记录数** - 设置保存的历史记录数量（默认 50 条）
- **清空历史记录** - 一键清空所有历史记录

## 📁 项目结构

```
lib/
├── main.dart                    # 应用入口
├── models/
│   └── clipboard_item.dart     # 粘贴板项数据模型
├── services/
│   ├── clipboard_service.dart  # 粘贴板监听服务
│   ├── hotkey_service.dart     # 快捷键管理服务
│   └── system_tray_service.dart # 系统托盘服务
└── widgets/
    ├── clipboard_history_window.dart # 历史记录窗口
    └── settings_window.dart     # 设置窗口
```

## 🔧 技术栈

- **Flutter** - 跨平台 UI 框架
- **clipboard_watcher** - 粘贴板监听
- **hotkey_manager** - 全局快捷键
- **system_tray** - 系统托盘
- **window_manager** - 窗口管理
- **shared_preferences** - 本地存储

## 📝 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## ⚠️ 重要提示

### macOS 权限

首次运行时，macOS 可能会提示以下权限：

1. **辅助功能权限** - 用于监听全局快捷键
   - 系统偏好设置 → 安全性与隐私 → 隐私 → 辅助功能
   - 添加并勾选 "ccp.app"

2. **输入监控权限** - 用于全局快捷键
   - 系统偏好设置 → 安全性与隐私 → 隐私 → 输入监控
   - 添加并勾选 "ccp.app"

### 故障排除

**问题：应用无法启动或系统托盘不显示**
- 确保已授予必要的 macOS 权限
- 尝试重新构建：`flutter clean && flutter build macos --release`

**问题：快捷键不工作**
- 检查系统偏好设置中的辅助功能和输入监控权限
- 确保快捷键没有与其他应用冲突

**问题：粘贴板监听不工作**
- 重启应用
- 检查是否有其他粘贴板管理工具冲突

## 📞 联系

如有问题或建议，请提交 Issue。
