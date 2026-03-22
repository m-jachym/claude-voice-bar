import Carbon
import AppKit

class HotkeyManager {
    static let shared = HotkeyManager()

    var onStartRecording: (() -> Void)?
    var onStopAndSend: ((Int) -> Void)?
    var onCancel: (() -> Void)?
    var onFocusPanel: (() -> Void)?

    var isPanelVisible: Bool = false

    private var isRecording = false
    private var lastSectionPressTime: Date?
    private var singleTapWork: DispatchWorkItem?
    private var globalMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
            return nil
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    func resetRecordingState() {
        isRecording = false
        lastSectionPressTime = nil
        singleTapWork?.cancel()
        singleTapWork = nil
    }

    private func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 10: // § key
            guard !isRecording else { return }
            if isPanelVisible {
                onFocusPanel?()
                return
            }
            let now = Date()
            if let last = lastSectionPressTime, now.timeIntervalSince(last) < 0.4 {
                singleTapWork?.cancel()
                singleTapWork = nil
                lastSectionPressTime = nil
                isRecording = true
                onStartRecording?()
            } else {
                lastSectionPressTime = now
                let work = DispatchWorkItem { [weak self] in
                    self?.lastSectionPressTime = nil
                    self?.singleTapWork = nil
                }
                singleTapWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
            }

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

        case 53:
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
