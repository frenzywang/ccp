#!/bin/bash

echo "🚀 启动 Clipboard Manager..."

# 检查是否已构建
if [ ! -d "build/macos/Build/Products/Release/ccp.app" ]; then
    echo "📦 首次运行，正在构建应用..."
    flutter build macos --release
fi

# 启动应用
echo "🔧 启动应用..."
open build/macos/Build/Products/Release/ccp.app

echo "✅ Clipboard Manager 已启动！"
echo "💡 应用将在系统托盘显示，使用 Cmd+Shift+V 调出粘贴板历史。" 