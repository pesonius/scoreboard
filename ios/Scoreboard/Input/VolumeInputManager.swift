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

    private var debounceUntil: Date = .distantPast
    private let debounce: TimeInterval = 0.5

    // Set to true while we are resetting the slider so the resulting
    // KVO notification is ignored.
    private var isResetting = false

    // MARK: - Lifecycle

    func start() {
        setupVolumeView()
        do {
            try session.setCategory(.ambient, options: .mixWithOthers)
            try session.setActive(true)
        } catch {}
        resetVolume()
        observation = session.observe(\.outputVolume, options: [.new, .old]) { [weak self] _, change in
            guard let self,
                  let newV = change.newValue,
                  let oldV = change.oldValue else { return }
            DispatchQueue.main.async {
                // Ignore the KVO fired by our own reset call
                if self.isResetting {
                    self.onDebug?("vol=\(String(format: "%.3f", newV)) [reset, ignored]")
                    return
                }

                let delta = newV - oldV
                guard abs(delta) > 0.01 else { return }  // ignore rounding noise

                let now = Date()
                guard now >= self.debounceUntil else {
                    self.onDebug?("vol=\(String(format: "%.3f", newV)) [debounce]")
                    return
                }

                self.fire(up: delta > 0, v: newV)
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
        debounceUntil = Date().addingTimeInterval(debounce)
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
        isResetting = true
        slider.setValue(midVolume, animated: false)
        slider.sendActions(for: .valueChanged)
        // Clear the flag after the KVO has had a chance to fire on the main queue
        DispatchQueue.main.async { self.isResetting = false }
    }
}
