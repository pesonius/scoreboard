import SwiftUI
import UIKit

// Invisible UIView that becomes first responder and captures
// hardware key events from the paired BLE clicker (or any HID keyboard).
// Routes pressesBegan / pressesEnded to InputManager.

struct KeyboardResponderView: UIViewRepresentable {
    let inputManager: InputManager

    func makeUIView(context: Context) -> ResponderView {
        let v = ResponderView()
        v.inputManager = inputManager
        v.backgroundColor = .clear
        DispatchQueue.main.async { v.becomeFirstResponder() }
        return v
    }

    func updateUIView(_ uiView: ResponderView, context: Context) {
        uiView.inputManager = inputManager
        if !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        }
    }
}

final class ResponderView: UIView {
    var inputManager: InputManager?
    override var canBecomeFirstResponder: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = pressKey(for: press) {
                inputManager?.keyDown(key)
                handled = true
            }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if let key = pressKey(for: press) {
                inputManager?.keyUp(key)
                handled = true
            }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            if let key = pressKey(for: press) { inputManager?.keyUp(key) }
        }
        super.pressesCancelled(presses, with: event)
    }

    // Maps both keyboard keys and mouse/pointer primary button
    private func pressKey(for press: UIPress) -> String? {
        // Mouse / pointer primary button — route to fixed player regardless of cursor position
        if press.type == .select {
            return "MousePrimary"
        }
        guard let key = press.key else { return nil }
        switch key.keyCode {
        case .keyboardLeftArrow:     return "ArrowLeft"
        case .keyboardRightArrow:    return "ArrowRight"
        case .keyboardUpArrow:       return "ArrowUp"
        case .keyboardDownArrow:     return "ArrowDown"
        case .keyboardSpacebar:      return "Space"
        case .keyboardReturnOrEnter: return "Enter"
        default:                     return nil
        }
    }
}

// MARK: - Key capture (for setup remapping)

struct KeyCaptureView: UIViewRepresentable {
    let onCapture: (String) -> Void

    func makeUIView(context: Context) -> KeyCaptureUIView {
        let v = KeyCaptureUIView()
        v.onCapture = onCapture
        DispatchQueue.main.async { v.becomeFirstResponder() }
        return v
    }

    func updateUIView(_ uiView: KeyCaptureUIView, context: Context) {}
}

final class KeyCaptureUIView: UIView {
    var onCapture: ((String) -> Void)?
    override var canBecomeFirstResponder: Bool { true }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first, let key = press.key else {
            super.pressesBegan(presses, with: event); return
        }
        let mapped: String?
        switch key.keyCode {
        case .keyboardLeftArrow:     mapped = "ArrowLeft"
        case .keyboardRightArrow:    mapped = "ArrowRight"
        case .keyboardUpArrow:       mapped = "ArrowUp"
        case .keyboardDownArrow:     mapped = "ArrowDown"
        case .keyboardSpacebar:      mapped = "Space"
        case .keyboardReturnOrEnter: mapped = "Enter"
        default:                     mapped = nil
        }
        if let m = mapped { onCapture?(m) }
        else { super.pressesBegan(presses, with: event) }
    }
}
