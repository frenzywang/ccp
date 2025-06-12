import Cocoa
import FlutterMacOS
import CoreGraphics

@main
class AppDelegate: FlutterAppDelegate {
  
  override func applicationDidFinishLaunching(_ notification: Notification) {
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
      case "forceRequestAccessibilityPermission":
        self?.forceRequestAccessibilityPermission(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    })
  }
  
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    // 不要在最后一个窗口关闭时自动终止应用
    // 因为我们的应用需要在后台运行（系统托盘）
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  private func hasAccessibilityPermission(result: @escaping FlutterResult) {
    let hasPermission = AXIsProcessTrusted()
    
    // 添加调试信息
    let bundleId = Bundle.main.bundleIdentifier ?? "unknown"
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "unknown"
    let appPath = Bundle.main.bundlePath
    
    print("🔍 权限检查调试信息:")
    print("   Bundle ID: \(bundleId)")
    print("   App Name: \(appName)")
    print("   App Path: \(appPath)")
    print("   Has Permission: \(hasPermission)")
    
    // 如果没有权限，尝试提示用户可能的解决方案
    if !hasPermission {
      print("❌ 没有辅助功能权限，可能的原因:")
      print("   1. 应用未添加到辅助功能列表")
      print("   2. Debug 应用路径变化导致权限失效")
      print("   3. 需要重启应用或重新添加权限")
    }
    
    result(hasPermission)
  }
  
  private func requestAccessibilityPermission(result: @escaping FlutterResult) {
    // 首先尝试触发系统权限对话框
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    if hasPermission {
      result(true)
      return
    }
    
    // 获取应用信息
    let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "ccp"
    let appPath = Bundle.main.bundlePath
    let bundleId = Bundle.main.bundleIdentifier ?? "com.example.ccp"
    
    // 显示详细的权限申请对话框
    let alert = NSAlert()
    alert.messageText = "需要辅助功能权限"
    alert.informativeText = """
为了实现自动粘贴功能，需要在系统设置中授予辅助功能权限。

应用信息：
• 应用名称：\(appName)
• Bundle ID：\(bundleId)
• 应用位置：\(appPath)

请按以下步骤操作：
1. 点击"打开设置"按钮
2. 在打开的"隐私与安全性"页面中，点击左侧的"辅助功能"
3. 如果列表中已有此应用，请先取消勾选，然后重新勾选
4. 如果列表中没有，点击右下角的"+"按钮添加应用
5. 确保应用旁边的开关是打开状态

注意：Debug 模式下可能需要重新添加权限。
"""
    alert.addButton(withTitle: "打开设置")
    alert.addButton(withTitle: "复制应用路径")
    alert.addButton(withTitle: "取消")
    alert.alertStyle = .informational
    
    let response = alert.runModal()
    
    switch response {
    case .alertFirstButtonReturn:
      // 打开系统偏好设置的辅助功能页面
      let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
      NSWorkspace.shared.open(url)
    case .alertSecondButtonReturn:
      // 复制应用路径到剪贴板
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      pasteboard.setString(appPath, forType: .string)
      
      // 显示复制成功提示
      let successAlert = NSAlert()
      successAlert.messageText = "应用路径已复制"
      successAlert.informativeText = "应用路径已复制到剪贴板，您可以在系统设置中粘贴使用。"
      successAlert.addButton(withTitle: "确定")
      successAlert.runModal()
    default:
      break
    }
    
    result(true)
  }
  
  private func simulatePaste(result: @escaping FlutterResult) {
    // 检查辅助功能权限
    guard AXIsProcessTrusted() else {
      // 如果没有权限，尝试打开系统设置
      let alert = NSAlert()
      alert.messageText = "需要辅助功能权限"
      alert.informativeText = "为了模拟按键操作，需要在系统偏好设置中授予辅助功能权限。\n\n点击\"打开设置\"将自动跳转到相关设置页面。"
      alert.addButton(withTitle: "打开设置")
      alert.addButton(withTitle: "取消")
      alert.alertStyle = .informational
      
      let response = alert.runModal()
      if response == .alertFirstButtonReturn {
        // 打开系统偏好设置的辅助功能页面
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
      }
      
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
  
  private func forceRequestAccessibilityPermission(result: @escaping FlutterResult) {
    // 使用 kAXTrustedCheckOptionPrompt 强制显示系统权限对话框
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let hasPermission = AXIsProcessTrustedWithOptions(options as CFDictionary)
    
    print("🔧 强制权限申请结果: \(hasPermission)")
    
    if hasPermission {
      print("✅ 权限申请成功")
      result(true)
    } else {
      print("❌ 权限申请失败，可能需要手动在系统设置中添加")
      
      // 延迟一下再打开系统设置，给用户时间看到系统对话框
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
      }
      
      result(false)
    }
  }
}
