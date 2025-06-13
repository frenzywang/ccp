# CCP Clipboard Manager Makefile
# 简化开发和部署流程

.PHONY: help build run kill clean release install dev logs hot-reload

# 默认目标
help:
	@echo "CCP Clipboard Manager - 可用命令:"
	@echo ""
	@echo "开发命令:"
	@echo "  make dev        - 杀死现有进程并启动开发版本"
	@echo "  make run        - 启动开发版本"
	@echo "  make build      - 构建开发版本"
	@echo "  make kill       - 杀死所有ccp进程"
	@echo "  make hot-reload - 热重载应用"
	@echo "  make logs       - 查看应用日志"
	@echo ""
	@echo "发布命令:"
	@echo "  make release    - 构建Release版本"
	@echo "  make install    - 构建并安装到Applications文件夹"
	@echo "  make deploy     - 完整部署流程(构建+安装+运行)"
	@echo ""
	@echo "清理命令:"
	@echo "  make clean      - 清理构建文件"
	@echo "  make clean-all  - 深度清理(包括pub cache)"

# 应用信息
APP_NAME = ccp
BUILD_DIR = build/macos/Build/Products
DEBUG_APP = $(BUILD_DIR)/Debug/$(APP_NAME).app
RELEASE_APP = $(BUILD_DIR)/Release/$(APP_NAME).app
APPLICATIONS_DIR = /Applications

# 开发命令
dev: kill build run

run:
	@echo "🚀 启动开发版本..."
	flutter run -d macos

build:
	@echo "🔨 构建开发版本..."
	flutter build macos --debug

kill:
	@echo "🔪 杀死所有ccp进程..."
	-killall $(APP_NAME) 2>/dev/null || true
	@sleep 2

hot-reload:
	@echo "🔥 热重载应用..."
	@echo "r" | nc -w 1 127.0.0.1 $$(lsof -ti:flutter) 2>/dev/null || echo "热重载失败，请确保应用正在运行"

logs:
	@echo "📋 查看应用日志..."
	@echo "使用 Cmd+Shift+V 打开剪贴板历史"
	@echo "或查看控制台日志: Console.app"

# 发布命令
release: clean
	@echo "🏗️ 构建Release版本..."
	flutter build macos --release
	@echo "✅ Release版本构建完成: $(RELEASE_APP)"

install: release kill
	@echo "📦 安装到Applications文件夹..."
	@if [ -d "$(APPLICATIONS_DIR)/$(APP_NAME).app" ]; then \
		echo "🗑️ 删除旧版本..."; \
		rm -rf "$(APPLICATIONS_DIR)/$(APP_NAME).app"; \
	fi
	cp -R "$(RELEASE_APP)" "$(APPLICATIONS_DIR)/"
	@echo "✅ 应用已安装到 $(APPLICATIONS_DIR)/$(APP_NAME).app"

deploy: install
	@echo "🚀 启动已安装的应用..."
	open "$(APPLICATIONS_DIR)/$(APP_NAME).app"
	@echo "✅ 部署完成！"

# 清理命令
clean:
	@echo "🧹 清理构建文件..."
	flutter clean
	rm -rf build/
	@echo "✅ 构建文件已清理"

clean-all: clean
	@echo "🧹 深度清理..."
	flutter pub cache clean
	flutter pub get
	@echo "✅ 深度清理完成"

# 实用工具
check-deps:
	@echo "🔍 检查依赖..."
	flutter doctor
	flutter pub deps

update-deps:
	@echo "📦 更新依赖..."
	flutter pub upgrade

# 调试工具
debug-build:
	@echo "🐛 调试构建..."
	flutter build macos --debug --verbose

debug-run:
	@echo "🐛 调试运行..."
	flutter run -d macos --debug --verbose

# 权限相关
check-permissions:
	@echo "🔐 检查应用权限..."
	@echo "辅助功能权限: 系统偏好设置 > 安全性与隐私 > 辅助功能"
	@echo "应用路径: $(DEBUG_APP)"

# 快速测试
test-clipboard:
	@echo "📋 测试剪贴板功能..."
	@echo "1. 复制一些文本"
	@echo "2. 截图或复制图片"
	@echo "3. 复制图片文件"
	@echo "4. 按 Cmd+Shift+V 查看历史记录"

# 版本信息
version:
	@echo "📱 应用版本信息:"
	@grep version pubspec.yaml
	@echo "Flutter版本:"
	@flutter --version | head -1

# 帮助信息
info:
	@echo "📋 CCP Clipboard Manager"
	@echo "一个强大的macOS剪贴板管理工具"
	@echo ""
	@echo "功能特性:"
	@echo "  ✅ 文本剪贴板历史记录"
	@echo "  ✅ 图片剪贴板支持(截图)"
	@echo "  ✅ 图片文件复制支持"
	@echo "  ✅ 快捷键支持 (Cmd+Shift+V)"
	@echo "  ✅ 系统托盘集成"
	@echo "  ✅ 自动粘贴功能"
	@echo ""
	@echo "使用 'make help' 查看所有可用命令" 