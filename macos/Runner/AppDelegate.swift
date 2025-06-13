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
    
    // 注册原生剪贴板插件
    let pluginRegistrar = controller.registrar(forPlugin: "NativeClipboardPlugin")
    NativeClipboardPlugin.register(with: pluginRegistrar)
    print("✅ NativeClipboardPlugin 注册成功")
    
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

// MARK: - Native Clipboard Plugin

public class NativeClipboardPlugin: NSObject, FlutterPlugin {
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "native_clipboard", binaryMessenger: registrar.messenger)
        let instance = NativeClipboardPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "hasImage":
            result(hasImage())
        case "hasText":
            result(hasText())
        case "getImageData":
            getImageData(result: result)
        case "getTextData":
            getTextData(result: result)
        case "getClipboardType":
            result(getClipboardType())
        case "getChangeCount":
            result(getChangeCount())
        case "getAllClipboardTypes":
            result(getAllClipboardTypes())
        case "getClipboardItemsInfo":
            getClipboardItemsInfo(result: result)
        case "setImageData":
            setImageData(call: call, result: result)
        case "getFileURLs":
            getFileURLs(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func hasImage() -> Bool {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        
        // 检查是否包含图片类型
        for type in types {
            if type == .png || type == .tiff || 
               type.rawValue == "public.jpeg" ||
               type.rawValue.hasPrefix("image/") ||
               type.rawValue.contains("image") {
                return true
            }
        }
        return false
    }
    
    private func hasText() -> Bool {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        
        return types.contains(.string)
    }
    
    private func getImageData(result: @escaping FlutterResult) {
        let pasteboard = NSPasteboard.general
        
        // 尝试获取不同格式的图片数据
        if let data = pasteboard.data(forType: .png) {
            print("📸 获取到PNG图片数据: \(data.count) 字节")
            result(FlutterStandardTypedData(bytes: data))
            return
        }
        
        if let data = pasteboard.data(forType: .tiff) {
            print("📸 获取到TIFF图片数据: \(data.count) 字节")
            // 转换TIFF为PNG
            if let image = NSImage(data: data),
               let pngData = image.pngData() {
                result(FlutterStandardTypedData(bytes: pngData))
                return
            }
        }
        
        if let data = pasteboard.data(forType: NSPasteboard.PasteboardType("public.jpeg")) {
            print("📸 获取到JPEG图片数据: \(data.count) 字节")
            result(FlutterStandardTypedData(bytes: data))
            return
        }
        
        // 尝试其他图片类型
        let types = pasteboard.types ?? []
        for type in types {
            if type.rawValue.hasPrefix("image/") || type.rawValue.contains("image") {
                if let data = pasteboard.data(forType: type) {
                    print("📸 获取到\(type.rawValue)图片数据: \(data.count) 字节")
                    result(FlutterStandardTypedData(bytes: data))
                    return
                }
            }
        }
        
        print("❌ 未找到剪贴板图片数据")
        result(nil)
    }
    
    private func getTextData(result: @escaping FlutterResult) {
        let pasteboard = NSPasteboard.general
        
        if let text = pasteboard.string(forType: .string) {
            print("📝 获取到文本数据: \(text.count) 字符")
            result(text)
        } else {
            print("❌ 未找到剪贴板文本数据")
            result(nil)
        }
    }
    
    private func getClipboardType() -> String {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        
        // 按优先级返回类型
        for type in types {
            if type == .png || type == .tiff || 
               type.rawValue == "public.jpeg" ||
               type.rawValue.hasPrefix("image/") {
                return "image"
            }
        }
        
        for type in types {
            if type == .fileURL || 
               type.rawValue.contains("file-list") ||
               type.rawValue.hasPrefix("dyn.") {
                return "file"
            }
        }
        
        for type in types {
            if type == .string {
                return "text"
            }
        }
        
        return "unknown"
    }
    
    private func getChangeCount() -> Int {
        return NSPasteboard.general.changeCount
    }
    
    private func getAllClipboardTypes() -> [String] {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        
        return types.map { $0.rawValue }
    }
    
    private func getClipboardItemsInfo(result: @escaping FlutterResult) {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        
        var itemsInfo: [[String: Any]] = []
        
        for type in types {
            var itemInfo: [String: Any] = [
                "type": type.rawValue
            ]
            
            // 尝试获取数据大小信息
            if let data = pasteboard.data(forType: type) {
                itemInfo["size"] = data.count
                
                // 对于文本类型，添加预览
                if type == .string, let text = pasteboard.string(forType: .string) {
                    let preview = text.count > 100 ? String(text.prefix(100)) + "..." : text
                    itemInfo["preview"] = preview
                    itemInfo["length"] = text.count
                }
                
                // 对于图片类型，尝试获取尺寸
                if type == .png || type == .tiff || type.rawValue == "public.jpeg" {
                    if let image = NSImage(data: data) {
                        itemInfo["width"] = Int(image.size.width)
                        itemInfo["height"] = Int(image.size.height)
                    }
                }
            }
            
            itemsInfo.append(itemInfo)
        }
        
        result(itemsInfo)
    }
    
    private func setImageData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let imageData = args["imageData"] as? FlutterStandardTypedData else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "缺少图片数据", details: nil))
            return
        }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // 尝试将数据设置为PNG格式
        if pasteboard.setData(imageData.data, forType: .png) {
            print("📸 图片数据已设置到剪贴板: \(imageData.data.count) 字节")
            result(true)
        } else {
            print("❌ 无法设置图片数据到剪贴板")
            result(false)
        }
    }
    
    private func getFileURLs(result: @escaping FlutterResult) {
        let pasteboard = NSPasteboard.general
        let types = pasteboard.types ?? []
        
        print("📁 尝试获取文件URL，可用类型: \(types.map { $0.rawValue })")
        
        // 方法1: 尝试使用readObjects
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            print("📁 方法1成功: 获取到 \(urls.count) 个URL")
            if !urls.isEmpty {
                processFileURLs(urls: urls, result: result)
                return
            }
        }
        
        // 方法2: 尝试直接从fileURL类型获取
        if let urlData = pasteboard.data(forType: .fileURL),
           let url = URL(dataRepresentation: urlData, relativeTo: nil) {
            print("📁 方法2成功: 获取到单个URL")
            processFileURLs(urls: [url], result: result)
            return
        }
        
        // 方法2.5: 尝试从特殊的动态类型获取文件路径
        for type in types {
            if type.rawValue.hasPrefix("dyn.") || type.rawValue.contains("file-list") {
                if let data = pasteboard.data(forType: type) {
                    print("📁 方法2.5: 尝试解析动态类型 \(type.rawValue), 数据大小: \(data.count)")
                    
                    // 尝试将数据转换为字符串
                    if let dataString = String(data: data, encoding: .utf8) {
                        print("📁 数据内容(UTF8): \(dataString)")
                        if let extractedURLs = extractURLsFromString(dataString) {
                            processFileURLs(urls: extractedURLs, result: result)
                            return
                        }
                    }
                    
                    // 尝试其他编码
                    if let dataString = String(data: data, encoding: .ascii) {
                        print("📁 数据内容(ASCII): \(dataString)")
                        if let extractedURLs = extractURLsFromString(dataString) {
                            processFileURLs(urls: extractedURLs, result: result)
                            return
                        }
                    }
                    
                    // 尝试作为属性列表解析
                    do {
                        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                        print("📁 成功解析为属性列表: \(plist)")
                        if let extractedURLs = extractURLsFromPlist(plist) {
                            processFileURLs(urls: extractedURLs, result: result)
                            return
                        }
                    } catch {
                        print("📁 属性列表解析失败: \(error)")
                    }
                }
            }
        }
        
        // 方法3: 尝试从字符串解析文件路径
        if let stringData = pasteboard.string(forType: .string) {
            print("📁 方法3: 尝试从字符串解析: \(stringData)")
            if stringData.hasPrefix("/") || stringData.hasPrefix("file://") {
                let cleanPath = stringData.replacingOccurrences(of: "file://", with: "")
                let url = URL(fileURLWithPath: cleanPath)
                if FileManager.default.fileExists(atPath: url.path) {
                    print("📁 方法3成功: 解析出文件路径")
                    processFileURLs(urls: [url], result: result)
                    return
                }
            }
        }
        
        print("❌ 所有方法都失败，未找到文件URL")
        result([])
    }
    
    private func processFileURLs(urls: [URL], result: @escaping FlutterResult) {
        var fileInfos: [[String: Any]] = []
        
        for url in urls {
            var fileInfo: [String: Any] = [
                "path": url.path,
                "name": url.lastPathComponent
            ]
            
            // 检查文件是否存在
            if FileManager.default.fileExists(atPath: url.path) {
                fileInfo["exists"] = true
                
                // 获取文件大小
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                    if let fileSize = attributes[.size] as? Int64 {
                        fileInfo["size"] = fileSize
                    }
                } catch {
                    print("⚠️ 无法获取文件属性: \(error)")
                }
                
                // 检查是否为图片文件
                let imageExtensions = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "tif", "webp", "heic", "heif"]
                let fileExtension = url.pathExtension.lowercased()
                fileInfo["isImage"] = imageExtensions.contains(fileExtension)
                fileInfo["extension"] = fileExtension
                
                print("📁 文件: \(url.lastPathComponent), 是图片: \(imageExtensions.contains(fileExtension))")
            } else {
                fileInfo["exists"] = false
                print("❌ 文件不存在: \(url.path)")
            }
            
            fileInfos.append(fileInfo)
        }
        
        print("📁 获取到 \(fileInfos.count) 个文件")
        result(fileInfos)
    }
    
    private func extractURLsFromString(_ string: String) -> [URL]? {
        var urls: [URL] = []
        
        // 尝试按行分割，查找文件路径
        let lines = string.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("/") && !trimmed.isEmpty {
                let url = URL(fileURLWithPath: trimmed)
                if FileManager.default.fileExists(atPath: url.path) {
                    urls.append(url)
                    print("📁 从字符串提取到文件路径: \(trimmed)")
                }
            } else if trimmed.hasPrefix("file://") {
                if let url = URL(string: trimmed) {
                    if FileManager.default.fileExists(atPath: url.path) {
                        urls.append(url)
                        print("📁 从字符串提取到文件URL: \(trimmed)")
                    }
                }
            }
        }
        
        return urls.isEmpty ? nil : urls
    }
    
    private func extractURLsFromPlist(_ plist: Any) -> [URL]? {
        var urls: [URL] = []
        
        if let array = plist as? [Any] {
            for item in array {
                if let urlString = item as? String {
                    if urlString.hasPrefix("/") {
                        let url = URL(fileURLWithPath: urlString)
                        if FileManager.default.fileExists(atPath: url.path) {
                            urls.append(url)
                            print("📁 从属性列表提取到文件路径: \(urlString)")
                        }
                    } else if urlString.hasPrefix("file://") {
                        if let url = URL(string: urlString) {
                            if FileManager.default.fileExists(atPath: url.path) {
                                urls.append(url)
                                print("📁 从属性列表提取到文件URL: \(urlString)")
                            }
                        }
                    }
                }
            }
        } else if let dict = plist as? [String: Any] {
            // 递归搜索字典中的URL
            for (_, value) in dict {
                if let extractedURLs = extractURLsFromPlist(value) {
                    urls.append(contentsOf: extractedURLs)
                }
            }
        } else if let urlString = plist as? String {
            if urlString.hasPrefix("/") {
                let url = URL(fileURLWithPath: urlString)
                if FileManager.default.fileExists(atPath: url.path) {
                    urls.append(url)
                    print("📁 从属性列表提取到文件路径: \(urlString)")
                }
            }
        }
        
        return urls.isEmpty ? nil : urls
    }
}

// 扩展NSImage以支持PNG数据导出
extension NSImage {
    func pngData() -> Data? {
        guard let tiffRepresentation = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation) else {
            return nil
        }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}
