import AVFoundation
import MediaPlayer
import UIKit

final class VolumeInputManager {

    var onVolumeUp:   (() -> Void)?
    var onVolumeDown: (() -> Void)?
    var onDebug: ((String) -> Void)?

    private let session   = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private let midVolume: Float = 0.5
    private var volumeView: MPVolumeView?

    private var lastEventAt: Date = .distantPast
    private let cooldown: TimeInterval = 1.0
    private var lastWasUp = true   // repeat this direction when v==mid outside cooldown

    // MARK: - Lifecycle

    func start() {
        setupVolumeView()
        do {
            try session.setCategory(.ambient, options: .mixWithOthers)
            try session.setActive(true)
        } catch {}
        resetVolume()
        observation = session.observe(\.outputVolume, options: .new) { [weak self] _, change in
            guard let self, let v = change.newValue else { return }
            DispatchQueue.main.async {
                let elapsed = Date().timeIntervalSince(self.lastEventAt)
                guard elapsed > self.cooldown else {
                    self.onDebug?("vol=\(String(format: "%.3f", v)) [cooldown \(Int(elapsed * 1000))ms]")
                    return
                }

                if v > self.midVolume {
                    self.lastWasUp = true
                    self.fire(up: true, v: v)
                } else if v < self.midVolume {
                    self.lastWasUp = false
                    self.fire(up: false, v: v)
                } else {
                    // v == midVolume: button press coalesced with reset — repeat last direction
                    self.onDebug?("vol=\(String(format: "%.3f", v)) [at mid → repeat \(self.lastWasUp ? "UP" : "DOWN")]")
                    self.fire(up: self.lastWasUp, v: v)
                }
            }
        }
    }

    func stop() {
        observation?.invalidate()
        observation = nil
        volumeView?.removeFromSuperview()
        volumeView = nil
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Private

    private func fire(up: Bool, v: Float) {
        lastEventAt = Date()
        if up {
            onDebug?("vol=\(String(format: "%.3f", v)) → VolumeUP")
            onVolumeUp?()
        } else {
            onDebug?("vol=\(String(format: "%.3f", v)) → VolumeDOWN")
            onVolumeDown?()
        }
        resetVolume()
    }

    private func setupVolumeView() {
        let v = MPVolumeView(frame: CGRect(x: -300, y: -300, width: 100, height: 100))
        v.alpha = 0.01
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.addSubview(v)
        }
        volumeView = v
    }

    private func resetVolume() {
        guard let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider else { return }
        slider.setValue(midVolume, animated: false)
        slider.sendActions(for: .valueChanged)
    }
}
