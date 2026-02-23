import SwiftUI
import Carbon.HIToolbox

struct ShortcutRecorderView: NSViewRepresentable {
    var onRecord: (KeyboardShortcut) -> Void
    var onCancel: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderField {
        let field = ShortcutRecorderField()
        field.onRecord = onRecord
        field.onCancel = onCancel
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ nsView: ShortcutRecorderField, context: Context) {
        nsView.onRecord = onRecord
        nsView.onCancel = onCancel
    }
}

final class ShortcutRecorderField: NSView {
    var onRecord: ((KeyboardShortcut) -> Void)?
    var onCancel: (() -> Void)?

    private let label = NSTextField(labelWithString: "Press shortcut...")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.15).cgColor
        layer?.cornerRadius = 6
        layer?.borderColor = NSColor.systemBlue.cgColor
        layer?.borderWidth = 2

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 13)
        addSubview(label)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 30),
        ])
    }

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode

        if keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        let modifiers = KeyboardShortcut.ModifierFlags(
            command: event.modifierFlags.contains(.command),
            option: event.modifierFlags.contains(.option),
            control: event.modifierFlags.contains(.control),
            shift: event.modifierFlags.contains(.shift)
        )

        let shortcut = KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
        label.stringValue = shortcut.displayString
        onRecord?(shortcut)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        keyDown(with: event)
        return true
    }
}
