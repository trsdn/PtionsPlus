import SwiftUI

struct PermissionGuideView: View {
    @ObservedObject var accessibilityChecker: AccessibilityChecker
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Accessibility Permission Required")
                .font(.title2)
                .bold()

            Text("Ptions+ needs Accessibility access to intercept mouse button events and simulate keyboard shortcuts.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, text: "Click \"Open System Settings\" below")
                InstructionRow(number: 2, text: "Find Ptions+ in the list")
                InstructionRow(number: 3, text: "Toggle the switch to enable access")
                InstructionRow(number: 4, text: "You may need to unlock settings first")
            }
            .padding()
            .background(.quaternary)
            .cornerRadius(12)

            HStack(spacing: 16) {
                Button("Open System Settings") {
                    accessibilityChecker.openAccessibilitySettings()
                }
                .buttonStyle(.borderedProminent)

                if accessibilityChecker.isTrusted {
                    Button("Continue") {
                        onDismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }

            if accessibilityChecker.isTrusted {
                Label("Access Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.headline)
            }
        }
        .padding(40)
        .frame(width: 450)
        .onAppear {
            accessibilityChecker.startPolling()
        }
        .onDisappear {
            accessibilityChecker.stopPolling()
        }
    }
}

private struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .bold()
                .frame(width: 20, height: 20)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(Circle())
            Text(text)
        }
    }
}
