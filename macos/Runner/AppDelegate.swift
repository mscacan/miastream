import Cocoa
import FlutterMacOS
import AVKit
import AVFoundation

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    DispatchQueue.main.async {
      if let controller = self.mainFlutterWindow?.contentViewController as? FlutterViewController {
        self.bind(controller: controller)
      }
    }
  }

  private var outside: FlutterMethodChannel?
  private var escMonitor: Any?
  private var cursorHidden = false

  func bind(controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "mias/outside",
      binaryMessenger: controller.engine.binaryMessenger
    )
    outside = channel
    if escMonitor == nil {
      escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
        guard let self, event.keyCode == 53 else {
          return event
        }
        guard let window = self.playerWindow() else {
          return event
        }
        let filled = self.savedFrame != nil || window.styleMask.contains(.fullScreen)
        if !filled {
          return event
        }
        self.applyFill(window, leaving: true)
        self.setCursorHidden(false)
        self.outside?.invokeMethod("left", arguments: nil)
        return nil
      }
    }
    channel.setMethodCallHandler { call, result in
      if call.method == "enter" {
        let args = call.arguments as? [String: Any]
        let raw = args?["url"] as? String
        guard let raw, let url = URL(string: raw), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "file" else {
          result("none")
          return
        }
        FloatHost.shared.open(url: url)
        result("panel")
        return
      }
      if call.method == "exit" {
        FloatHost.shared.close()
        result(nil)
        return
      }
      if call.method == "full" {
        result(self.toggleFill())
        return
      }
      if call.method == "cursor" {
        let hide = (call.arguments as? [String: Any])?["hide"] as? Bool ?? false
        self.setCursorHidden(hide)
        result(nil)
        return
      }
      result(FlutterMethodNotImplemented)
    }
  }

  private var savedFrame: NSRect?

  private func playerWindow() -> NSWindow? {
    if let key = NSApp.keyWindow, key.contentViewController is FlutterViewController {
      return key
    }
    if let main = mainFlutterWindow, main.contentViewController is FlutterViewController {
      return main
    }
    return NSApp.windows.first { $0.contentViewController is FlutterViewController }
  }

  private func toggleFill() -> Bool {
    guard let window = playerWindow() else {
      return false
    }
    let leaving = window.styleMask.contains(.fullScreen) || savedFrame != nil
    DispatchQueue.main.async { [weak self, weak window] in
      guard let self, let window else {
        return
      }
      self.applyFill(window, leaving: leaving)
    }
    return !leaving
  }

  private func applyFill(_ window: NSWindow, leaving: Bool) {
    window.makeKeyAndOrderFront(nil)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    if leaving {
      if window.styleMask.contains(.fullScreen) {
        window.toggleFullScreen(nil)
      }
      traffic(window, hidden: false)
      window.titleVisibility = .visible
      window.titlebarAppearsTransparent = false
      if let frame = savedFrame {
        window.setFrame(frame, display: true, animate: false)
      }
      savedFrame = nil
      NSApp.presentationOptions = []
      setCursorHidden(false)
      return
    }
    guard let screen = window.screen ?? NSScreen.main else {
      return
    }
    savedFrame = window.frame
    window.styleMask.formUnion([.resizable, .fullSizeContentView])
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    traffic(window, hidden: true)
    NSApp.presentationOptions = [.hideDock, .hideMenuBar]
    window.setFrame(screen.frame, display: true, animate: false)
  }

  private func traffic(_ window: NSWindow, hidden: Bool) {
    for kind in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
      window.standardWindowButton(kind)?.isHidden = hidden
    }
    window.standardWindowButton(.closeButton)?.superview?.isHidden = hidden
  }

  private func setCursorHidden(_ hidden: Bool) {
    if hidden == cursorHidden {
      return
    }
    cursorHidden = hidden
    if hidden {
      NSCursor.hide()
    } else {
      NSCursor.unhide()
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

final class FloatHost: NSObject {
  static let shared = FloatHost()
  private var panel: NSPanel?
  private var player: AVPlayer?

  func open(url: URL) {
    close()
    let view = AVPlayerView()
    view.controlsStyle = .floating
    view.showsFullScreenToggleButton = true
    let player = AVPlayer(url: url)
    player.allowsExternalPlayback = true
    view.player = player
    self.player = player
    let panel = NSPanel(
      contentRect: NSRect(x: 80, y: 80, width: 420, height: 236),
      styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
      backing: .buffered,
      defer: false
    )
    panel.title = "Mia Stream"
    panel.level = .floating
    panel.isFloatingPanel = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isReleasedWhenClosed = false
    panel.isMovableByWindowBackground = true
    panel.contentView = view
    panel.orderFrontRegardless()
    player.play()
    self.panel = panel
  }

  func close() {
    player?.pause()
    panel?.close()
    panel = nil
    player = nil
  }
}
