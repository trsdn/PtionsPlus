import SwiftUI

struct DebugEvent: Identifiable {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    let id = UUID()
    let timestamp: Date
    let buttonNumber: Int64
    let isDown: Bool

    var displayString: String {
        let direction = isDown ? "DOWN" : "UP"
        let buttonName = MouseButton(rawValue: Int(buttonNumber))?.displayName
            ?? "Button \(buttonNumber)"
        return "[\(Self.formatter.string(from: timestamp))] \(buttonName) \(direction)"
    }
}

final class DebugMonitorModel: ObservableObject {
    static let capacity = 500

    @Published private(set) var events: [DebugEvent] = []

    private let eventTapService: EventTapService
    private var subscription: EventDiagnosticsSubscription?

    init(eventTapService: EventTapService) {
        self.eventTapService = eventTapService
    }

    func start() {
        guard subscription == nil else {
            return
        }
        subscription = eventTapService.subscribeToDiagnostics { [weak self] mouseEvent in
            self?.append(mouseEvent)
        }
    }

    func stop() {
        subscription?.cancel()
        subscription = nil
    }

    func clear() {
        events.removeAll()
    }

    private func append(_ mouseEvent: MouseButtonEvent) {
        events.append(DebugEvent(
            timestamp: mouseEvent.timestamp,
            buttonNumber: mouseEvent.buttonNumber,
            isDown: mouseEvent.isDown
        ))
        if events.count > Self.capacity {
            events.removeFirst(events.count - Self.capacity)
        }
    }
}

struct DebugMonitorView: View {
    @ObservedObject private var eventTapService: EventTapService
    @StateObject private var model: DebugMonitorModel

    init(eventTapService: EventTapService) {
        self.eventTapService = eventTapService
        _model = StateObject(wrappedValue: DebugMonitorModel(eventTapService: eventTapService))
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
                Button("Clear") { model.clear() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            ScrollViewReader { proxy in
                List(model.events) { event in
                    Text(event.displayString)
                        .font(.system(.body, design: .monospaced))
                        .id(event.id)
                }
                .onChange(of: model.events.count) { _ in
                    if let last = model.events.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
        .padding()
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }
}
