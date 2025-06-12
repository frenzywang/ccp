import Cocoa
import FlutterMacOS
import CoreGraphics

@main
class AppDelegate: FlutterAppDelegate {
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
    // 检查是否已有实例在运行
    if isAnotherInstanceRunning() {
      print("🔄 检测到应用已在运行，激活已有实例并退出")
      activateExistingInstanceAndQuit()
      return
    }
    
    print("🚀 启动新的应用实例")
    
    let controller: FlutterViewController = mainFlutterWindow?.contentViewController as! FlutterViewController
    let keyboardChannel = FlutterMethodChannel(name: "com.ccp.keyboard",
                                              binaryMessenger: controller.engine.binaryMessenger)
    
    keyboardChannel.setMethodCallHandler({ [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "simulatePaste":
        self?.simulatePaste(result: result)
      case "hasAccessibilityPermission":
        self?.hasAccessibilityPermission(result: result)
      case "requestAccessibilityPermission":
        self?.requestAccessibilityPermission(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
    
    // 立即处理权限，确保应用自动添加到权限列表
    handleInitialPermissionSetup()
  }
  
  private func isAnotherInstanceRunning() -> Bool {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.example.ccp"
    let runningApps = NSWorkspace.shared.runningApplications
    
    var instanceCount = 0
    for app in runningApps {
      if app.bundleIdentifier == bundleIdentifier {
        instanceCount += 1
        // 如果找到超过1个实例（包括当前启动的），说明已有实例在运行
        if instanceCount > 1 {
          return true
        }
      }
    }
    
    return false
  }
  
  private func activateExistingInstanceAndQuit() {
    let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.example.ccp"
    let runningApps = NSWorkspace.shared.runningApplications
    
    // 找到已运行的实例并激活
    for app in runningApps {
      if app.bundleIdentifier == bundleIdentifier && app.processIdentifier != ProcessInfo.processInfo.processIdentifier {
        print("📍 找到已运行的实例 PID: \(app.processIdentifier)")
        app.activate(options: [.activateIgnoringOtherApps])
        break
      }
    }
    
    // 延迟一点再退出，确保激活操作完成
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      print("👋 退出重复启动的实例")
      NSApplication.shared.terminate(nil)
    }
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 不要在最后一个窗口关闭时自动终止应用
    // 因为我们的应用需要在后台运行（系统托盘）
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  private func handleInitialPermissionSetup() {
    print("🚀 开始处理辅助功能权限设置...")
    
    let appPath = Bundle.main.bundlePath
    let lastKnownPath = UserDefaults.standard.string(forKey: "LastKnownAppPath")
    
    print("📍 当前应用路径: \(appPath)")
    
    // 检查应用路径是否发生变化（版本不一致的标志）
    if let lastPath = lastKnownPath, lastPath != appPath {
      print("🔄 检测到应用路径变化，重新设置权限")
      print("   旧路径: \(lastPath)")
      print("   新路径: \(appPath)")
      
      // 强制重新添加到权限列表
      refreshAccessibilityPermission()
    } else if lastKnownPath == nil {
      print("🆕 首次运行，添加到辅助功能权限列表")
      ensureInAccessibilityList()
    } else {
      print("✅ 应用路径未变化，检查现有权限")
      checkExistingPermission()
    }
    
    // 保存当前路径
    UserDefaults.standard.set(appPath, forKey: "LastKnownAppPath")
  }
  
  private func refreshAccessibilityPermission() {
    print("🔄 刷新辅助功能权限...")
    
    // 使用prompt参数强制触发系统权限对话框
    // 这会让应用自动出现在权限列表中
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if hasPermission {
      print("✅ 权限刷新完成，应用已有权限")
    } else {
      print("🔄 应用已重新添加到权限列表，权限已重置为关闭状态")
      // 显示提示让用户知道需要开启权限
      showPermissionAlert(isRefresh: true)
    }
  }
  
  private func ensureInAccessibilityList() {
    print("📝 确保应用在辅助功能列表中...")
    
    // 使用prompt参数触发系统权限对话框
    // 这是让应用自动出现在权限列表的关键
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if hasPermission {
      print("✅ 应用已有辅助功能权限")
    } else {
      print("💡 应用已添加到辅助功能列表，需要手动启用权限")
      // 显示提示
      showPermissionAlert(isRefresh: false)
    }
  }
  
  private func checkExistingPermission() {
    print("🔍 检查现有权限状态...")
    
    let hasPermission = AXIsProcessTrusted()
    if hasPermission {
      print("✅ 应用已有辅助功能权限")
    } else {
      print("⚠️ 应用缺少辅助功能权限")
      // 触发一次权限检查，确保应用在列表中
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
      _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
  }
  
  private func showPermissionAlert(isRefresh: Bool) {
    // 延迟一点显示，避免和系统对话框冲突
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ccp"
      
      let alert = NSAlert()
      alert.messageText = "辅助功能权限设置"
      
      if isRefresh {
        alert.informativeText = """
应用路径已更新，权限已刷新。

应用现在应该出现在系统辅助功能权限列表中，但权限是关闭状态。
请手动开启权限以使用自动粘贴功能。
"""
      } else {
        alert.informativeText = """
应用已自动添加到系统辅助功能权限列表中。

请开启权限以使用自动粘贴功能。
"""
      }
      
      alert.addButton(withTitle: "打开设置")
      alert.addButton(withTitle: "稍后设置")
      alert.alertStyle = .informational
      
      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
        self.openAccessibilitySettings()
      }
    }
  }
  
  private func hasAccessibilityPermission(result: @escaping FlutterResult) {
    let hasPermission = AXIsProcessTrusted()
    result(hasPermission)
  }
  
  private func requestAccessibilityPermission(result: @escaping FlutterResult) {
    // 首先尝试触发系统权限对话框，确保应用出现在列表中
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if hasPermission {
      result(true)
      return
    }
    
    // 获取应用信息
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ccp"
    
    // 显示权限申请对话框
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = """
请按以下步骤操作：
1. 点击"打开设置"按钮
2. 在"隐私与安全性"页面中，点击左侧的"辅助功能"
3. 找到 \(appName) 应用（应该已在列表中）
4. 点击应用旁边的开关，将其设为开启状态

如果应用在列表中显示为灰色或路径不正确：
• 先取消勾选该应用
• 然后重新勾选，系统会自动使用新路径

完成后请重启应用。
"""
    alert.addButton(withTitle: "打开设置")
    alert.addButton(withTitle: "稍后设置")
    alert.alertStyle = .informational
    
    let response = alert.runModal()
    
    if response == .alertFirstButtonReturn {
      openAccessibilitySettings()
    }
    
    result(true)
  }
  
  private func openAccessibilitySettings() {
    // 在不同的 macOS 版本中，设置 URL 可能不同
    let urls = [
      "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
      "x-apple.systempreferences:com.apple.preference.security",
      "x-apple.systempreferences:com.apple.preferences.security.accessibility"
    ]
    
    var opened = false
    for urlString in urls {
      if let url = URL(string: urlString) {
        if NSWorkspace.shared.open(url) {
          opened = true
          print("✅ 成功打开系统设置: \(urlString)")
          break
        }
      }
    }
    
    if !opened {
      // 如果都失败了，尝试打开通用的系统偏好设置
      if let url = URL(string: "x-apple.systempreferences:") {
        NSWorkspace.shared.open(url)
        print("⚠️ 降级到通用系统设置")
      }
    }
  }
  
  private func simulatePaste(result: @escaping FlutterResult) {
    // 检查辅助功能权限
    guard AXIsProcessTrusted() else {
      // 如果没有权限，再次触发权限检查，确保应用在列表中
      let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
      _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
      
      openAccessibilitySettings()
      
      result(FlutterError(code: "NO_ACCESSIBILITY_PERMISSION",
                         message: "需要辅助功能权限来模拟按键",
                         details: nil))
      return
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      // 创建 Cmd+V 按键事件
      guard let keyVDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
            let keyVUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false) else {
        result(FlutterError(code: "EVENT_CREATION_FAILED",
                           message: "无法创建键盘事件",
                           details: nil))
        return
      }
      
      // 添加 Command 修饰键
      keyVDown.flags = .maskCommand
      keyVUp.flags = .maskCommand
      
      // 发送按键事件
      keyVDown.post(tap: .cghidEventTap)
      keyVUp.post(tap: .cghidEventTap)
      
      result(true)
    }
  }
}
