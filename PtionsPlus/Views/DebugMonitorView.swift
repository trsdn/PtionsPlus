import SwiftUI

struct DebugMonitorView: View {
    @ObservedObject var eventTapService: EventTapService
    @State private var events: [DebugEvent] = []

    struct DebugEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let buttonNumber: Int64
        let isDown: Bool

        var displayString: String {
            let direction = isDown ? "DOWN" : "UP"
            let buttonName = MouseButton(rawValue: Int(buttonNumber))?.displayName ?? "Button \(buttonNumber)"
            return "[\(timeString)] \(buttonName) \(direction)"
        }

        private var timeString: String {
            let f = DateFormatter()
            f.dateFormat = "HH:mm:ss.SSS"
            return f.string(from: timestamp)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(eventTapService.isRunning ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(eventTapService.isRunning ? "Event Tap Active" : "Event Tap Inactive")
                    .font(.caption)
                Spacer()
                Button("Clear") { events.removeAll() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            ScrollViewReader { proxy in
                List(events) { event in
                    Text(event.displayString)
                        .font(.system(.body, design: .monospaced))
                        .id(event.id)
                }
                .onChange(of: events.count) { _ in
                    if let last = events.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            eventTapService.onEvent = { mouseEvent in
                events.append(DebugEvent(
                    timestamp: mouseEvent.timestamp,
                    buttonNumber: mouseEvent.buttonNumber,
                    isDown: mouseEvent.isDown
                ))
            }
        }
    }
}
