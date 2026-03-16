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
    private var pendingModifierOnlyShortcut: KeyboardShortcut?

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

    private func modifiers(from event: NSEvent) -> KeyboardShortcut.ModifierFlags {
        KeyboardShortcut.ModifierFlags(
            command: event.modifierFlags.contains(.command),
            option: event.modifierFlags.contains(.option),
            control: event.modifierFlags.contains(.control),
            shift: event.modifierFlags.contains(.shift),
            function: event.modifierFlags.contains(.function)
        )
    }

    override func keyDown(with event: NSEvent) {
        let keyCode = event.keyCode

        if keyCode == UInt16(kVK_Escape) {
            onCancel?()
            return
        }

        pendingModifierOnlyShortcut = nil
        let modifiers = modifiers(from: event)

        let shortcut = KeyboardShortcut(keyCode: keyCode, modifiers: modifiers)
        label.stringValue = shortcut.displayString
        onRecord?(shortcut)
    }

    override func flagsChanged(with event: NSEvent) {
        let modifiers = modifiers(from: event)
        if modifiers.isEmpty {
            if let shortcut = pendingModifierOnlyShortcut {
                label.stringValue = shortcut.displayString
                pendingModifierOnlyShortcut = nil
                onRecord?(shortcut)
                return
            }

            label.stringValue = "Press shortcut..."
            return
        }

        if modifiers.function && !modifiers.command && !modifiers.option && !modifiers.control && !modifiers.shift {
            let shortcut = KeyboardShortcut(keyCode: UInt16(kVK_Function), modifiers: .init())
            pendingModifierOnlyShortcut = shortcut
            label.stringValue = shortcut.displayString
            return
        }

        pendingModifierOnlyShortcut = nil
        label.stringValue = modifiers.displayComponents.joined()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        keyDown(with: event)
        return true
    }
}
