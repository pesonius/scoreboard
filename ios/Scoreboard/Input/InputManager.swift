import Foundation

final class InputManager {

    static let longPressMs = 800
    static let debounceMs  = 200

    var onPoint: ((Int) -> Void)?
    var onUndo:  (() -> Void)?
    var onDebug: ((String) -> Void)?

    private(set) var keymap: MatchConfig.KeyMap
    private var keyToPlayer: [String: Int] = [:]

    private var activeKeys:  Set<String> = []
    private var timers:      [String: DispatchWorkItem] = [:]
    private var consumed:    Set<String> = []
    private var lastPointAt: Date = .distantPast

    init(keymap: MatchConfig.KeyMap) {
        self.keymap = keymap
        rebuildMap()
    }

    func update(keymap: MatchConfig.KeyMap) {
        self.keymap = keymap
        rebuildMap()
    }

    private func rebuildMap() {
        keyToPlayer = [keymap.button1: 0, keymap.button2: 1, "MousePrimary": 0]
    }

    func keyDown(_ key: String) {
        guard keyToPlayer[key] != nil else {
            onDebug?("keyDown: \(key) [unmapped]")
            return
        }
        guard !activeKeys.contains(key) else {
            onDebug?("keyDown: \(key) [repeat, ignored]")
            return
        }
        activeKeys.insert(key)
        onDebug?("keyDown: \(key) → player \(keyToPlayer[key]!)")

        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.consumed.insert(key)
            self.timers.removeValue(forKey: key)
            DispatchQueue.main.async {
                self.onDebug?("longPress: \(key) → UNDO")
                self.onUndo?()
            }
        }
        timers[key] = item
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(InputManager.longPressMs),
            execute: item
        )
    }

    func keyUp(_ key: String) {
        guard keyToPlayer[key] != nil else { return }

        timers[key]?.cancel()
        timers.removeValue(forKey: key)

        let wasConsumed = consumed.remove(key) != nil
        activeKeys.remove(key)
        guard !wasConsumed else {
            onDebug?("keyUp: \(key) [consumed by longPress]")
            return
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(lastPointAt) * 1000
        guard elapsed >= Double(InputManager.debounceMs) else {
            onDebug?("keyUp: \(key) [debounced, \(Int(elapsed))ms]")
            return
        }
        lastPointAt = now

        if let player = keyToPlayer[key] {
            onDebug?("keyUp: \(key) → POINT P\(player + 1)")
            DispatchQueue.main.async { [weak self] in self?.onPoint?(player) }
        }
    }
}
