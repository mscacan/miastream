import Flutter
import UIKit
import AVKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "OutsideWindow") else {
      return
    }
    let channel = FlutterMethodChannel(name: "mias/outside", binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { call, result in
      OutsideHost.shared.handle(call, result: result)
    }
  }
}

final class OutsideHost: NSObject, AVPictureInPictureControllerDelegate {
  static let shared = OutsideHost()
  private var player: AVPlayer?
  private var layer: AVPlayerLayer?
  private var pip: AVPictureInPictureController?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "exit" {
      pip?.stopPictureInPicture()
      player?.pause()
      layer?.removeFromSuperlayer()
      result(nil)
      return
    }
    guard call.method == "enter" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let args = call.arguments as? [String: Any]
    let raw = args?["url"] as? String
    guard let raw, let url = URL(string: raw) else {
      result("none")
      return
    }
    DispatchQueue.main.async {
      guard let view = self.hostView() else {
        result("none")
        return
      }
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
      try? AVAudioSession.sharedInstance().setActive(true)
      let item = AVPlayerItem(url: url)
      let player = AVPlayer(playerItem: item)
      player.allowsExternalPlayback = true
      let layer = AVPlayerLayer(player: player)
      layer.frame = CGRect(x: 0, y: 0, width: 2, height: 2)
      view.layer.addSublayer(layer)
      self.player = player
      self.layer = layer
      if AVPictureInPictureController.isPictureInPictureSupported() {
        self.pip = AVPictureInPictureController(playerLayer: layer)
        self.pip?.delegate = self
      }
      player.play()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
        if self.pip?.isPictureInPicturePossible == true {
          self.pip?.startPictureInPicture()
          result("pip")
        } else {
          result("none")
        }
      }
    }
  }

  private func hostView() -> UIView? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      if let view = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController?.view {
        return view
      }
    }
    return scenes.first?.windows.first?.rootViewController?.view
  }
}

