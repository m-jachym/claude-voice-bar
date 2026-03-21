import Carbon
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()

    var onStartRecording: (() -> Void)?
    var onStopAndSend: ((Int) -> Void)?
    var onCancel: (() -> Void)?

    private var isRecording = false
    private var monitor: Any?

    private init() {}

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }

    private func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 10: // § key
            guard !isRecording else { return }
            isRecording = true
            onStartRecording?()

        case 18: // 1
            stopAndSend(1)
        case 19: // 2
            stopAndSend(2)
        case 20: // 3
            stopAndSend(3)
        case 21: // 4
            stopAndSend(4)
        case 22: // 5
            stopAndSend(5)
        case 23: // 6
            stopAndSend(6)
        case 26: // 7
            stopAndSend(7)
        case 28: // 8
            stopAndSend(8)
        case 25: // 9
            stopAndSend(9)

        case 53: // Esc
            guard isRecording else { return }
            isRecording = false
            onCancel?()

        default:
            break
        }
    }

    private func stopAndSend(_ index: Int) {
        guard isRecording else { return }
        isRecording = false
        onStopAndSend?(index)
    }
}
