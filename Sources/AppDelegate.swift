import AppKit
import SwiftUI
import ApplicationServices
import Darwin
import ServiceManagement

struct PanelRootView: View {
    @ObservedObject var model: PopoverModel
    var body: some View {
        if let p = model.permissionData {
            PermissionPopupView(data: p, model: model)
        } else if model.showTaskCompletion {
            TaskCompletionView(session: model.completionSession)
        } else {
            SessionPopoverContentView(model: model)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!

    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private let popoverModel = PopoverModel()
    private var notifyWatcher: DispatchSourceFileSystemObject?
    private var notifyFD: Int32 = -1
    private var completionTimer: DispatchWorkItem?
    private var eventTap: CFMachPort?
    private var tapRunLoopSource: CFRunLoopSource?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            waitForAccessibilityAndRelaunch()
        }

        try? SMAppService.mainApp.register()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(recording: false)

        let menu = NSMenu()
        let profiles = loadProfiles()
        if !profiles.isEmpty {
            let header = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for name in profiles {
                let item = NSMenuItem(title: "  \(name)", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }
        menu.addItem(NSMenuItem(title: "Quit Claude Voice Bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        let hostingView = NSHostingView(rootView: PanelRootView(model: popoverModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 280, height: 200)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 200),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar

        popoverModel.onSelectSession = { [weak self] session in
            self?.stopAndSend(to: session)
        }
        popoverModel.onCancel = { [weak self] in
            self?.cancelRecording()
        }
        popoverModel.onSelectPermission = { [weak self] index, data in
            DispatchQueue.main.async { self?.sendPermissionChoice(index: index, data: data) }
        }

        startNotifyWatcher()

        HotkeyManager.shared.onFocusPanel = { [weak self] in
            DispatchQueue.main.async { self?.focusPanel() }
        }
        HotkeyManager.shared.onStartRecording = { [weak self] in
            DispatchQueue.main.async { self?.startRecording() }
        }
        HotkeyManager.shared.onStopAndSend = { [weak self] index in
            DispatchQueue.main.async { self?.hotkeyStopAndSend(index: index) }
        }
        HotkeyManager.shared.onCancel = { [weak self] in
            DispatchQueue.main.async { self?.cancelRecording() }
        }
        HotkeyManager.shared.start()
    }

    // MARK: - Actions

    private func startRecording() {
        guard !popoverModel.isRecording else { return }

        popoverModel.sessions = []
        popoverModel.isRecording = true
        popoverModel.isLoadingSessions = true
        showPanel()

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.recorder.startRecording()
                DispatchQueue.main.async { self.setIcon(recording: true) }
            } catch {}

            let sessions = TmuxSessionManager.shared.getActiveSessions()
            DispatchQueue.main.async {
                self.popoverModel.sessions = sessions
                self.popoverModel.isLoadingSessions = false
            }
        }
    }

    private func stopAndSend(to session: String) {
        HotkeyManager.shared.resetRecordingState()
        popoverModel.isRecording = false
        setIcon(recording: false)
        hidePanel()

        DispatchQueue.global(qos: .userInitiated).async {
            let audioURL = self.recorder.stopRecording()
            guard let text = self.transcriber.transcribe(audioPath: audioURL), !text.isEmpty else { return }
            TmuxSessionManager.shared.send(text: text, to: session)
        }
    }

    private func hotkeyStopAndSend(index: Int) {
        let sessions = popoverModel.sessions
        guard index <= sessions.count else { return }
        stopAndSend(to: sessions[index - 1].name)
    }

    private func cancelRecording() {
        HotkeyManager.shared.resetRecordingState()
        popoverModel.isRecording = false
        setIcon(recording: false)
        hidePanel()
        DispatchQueue.global(qos: .userInitiated).async {
            _ = self.recorder.stopRecording()
        }
    }

    // MARK: - Permission notify

    private func startNotifyWatcher() {
        let path = "/tmp/claude-vb-notify"
        if !FileManager.default.fileExists(atPath: path) {
            FileManager.default.createFile(atPath: path, contents: nil)
        }
        notifyFD = open(path, O_EVTONLY)
        guard notifyFD >= 0 else { return }

        notifyWatcher = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: notifyFD,
            eventMask: .write,
            queue: .global(qos: .userInitiated)
        )
        notifyWatcher?.setEventHandler { [weak self] in self?.handlePermissionNotify() }
        notifyWatcher?.setCancelHandler { [weak self] in
            if let fd = self?.notifyFD, fd >= 0 { close(fd) }
        }
        notifyWatcher?.resume()
    }

    private func handlePermissionNotify() {
        let path = "/tmp/claude-vb-notify"
        guard let data = FileManager.default.contents(atPath: path),
              !data.isEmpty,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        try? "".write(toFile: path, atomically: false, encoding: .utf8)

        let type = json["type"] as? String ?? "permission"
        let session = json["session"] as? String ?? ""

        if type == "completion" {
            DispatchQueue.main.async { self.showTaskCompletion(session: session) }
            return
        }

        guard let title = json["title"] as? String,
              let options = json["options"] as? [String] else { return }

        let desc = json["description"] as? String ?? ""
        let perm = PermissionData(title: title, description: desc, options: options, session: session)

        DispatchQueue.main.async {
            self.popoverModel.permissionSelectedIndex = 0
            self.popoverModel.permissionData = perm
            self.showPanel()
        }
    }

    private func showTaskCompletion(session: String) {
        guard !popoverModel.isRecording, popoverModel.permissionData == nil else { return }

        completionTimer?.cancel()
        popoverModel.completionSession = session
        popoverModel.showTaskCompletion = true
        showPanel()

        let work = DispatchWorkItem { [weak self] in
            self?.popoverModel.showTaskCompletion = false
            self?.popoverModel.completionSession = ""
            self?.hidePanel()
        }
        completionTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func sendPermissionChoice(index: Int, data: PermissionData) {
        stopEventTap()
        popoverModel.permissionData = nil
        hidePanel()
        TmuxSessionManager.shared.sendKey("\(index)", to: data.session)
    }

    private func focusPanel() {
        guard popoverModel.permissionData != nil else { return }
        startEventTap()
    }

    // MARK: - CGEventTap

    private static let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard type == .keyDown, let refcon else {
            return Unmanaged.passUnretained(event)
        }
        return Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue().handleTapKey(event)
    }

    private func startEventTap() {
        guard eventTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: AppDelegate.tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        eventTap = tap
        tapRunLoopSource = src
    }

    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let src = tapRunLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
                tapRunLoopSource = nil
            }
            eventTap = nil
        }
    }

    private func handleTapKey(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard let data = popoverModel.permissionData else {
            return Unmanaged.passUnretained(event)
        }
        let kc = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let count = data.options.count
        switch kc {
        case 125: // ↓
            popoverModel.permissionSelectedIndex = min(popoverModel.permissionSelectedIndex + 1, count - 1)
            return nil
        case 126: // ↑
            popoverModel.permissionSelectedIndex = max(popoverModel.permissionSelectedIndex - 1, 0)
            return nil
        case 36: // Enter
            let idx = popoverModel.permissionSelectedIndex + 1
            stopEventTap()
            sendPermissionChoice(index: idx, data: data)
            return nil
        case 53: // Esc
            stopEventTap()
            popoverModel.permissionData = nil
            hidePanel()
            return nil
        case 18 where 1 <= count:
            stopEventTap(); sendPermissionChoice(index: 1, data: data); return nil
        case 19 where 2 <= count:
            stopEventTap(); sendPermissionChoice(index: 2, data: data); return nil
        case 20 where 3 <= count:
            stopEventTap(); sendPermissionChoice(index: 3, data: data); return nil
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    // MARK: - Panel

    func showPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelWidth: CGFloat = 280
        let panelX = buttonFrame.midX - panelWidth / 2
        let panelY = buttonFrame.minY - 8

        panel.setFrameTopLeftPoint(NSPoint(x: panelX, y: panelY))
        panel.orderFront(nil)
        HotkeyManager.shared.isPanelVisible = true
    }

    func hidePanel() {
        panel.orderOut(nil)
        HotkeyManager.shared.isPanelVisible = false
    }

    // MARK: - Accessibility

    private func waitForAccessibilityAndRelaunch() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if AXIsProcessTrusted() {
                timer.invalidate()
                self.relaunch()
            }
        }
    }

    private func relaunch() {
        let url = Bundle.main.bundleURL
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [url.path]
        try? task.run()
        NSApp.terminate(nil)
    }

    // MARK: - Helpers

    private func loadProfiles() -> [String] {
        let path = NSHomeDirectory() + "/.claude-vb-profiles"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return []
        }
        return content.components(separatedBy: "\n")
            .filter { !$0.isEmpty }
            .compactMap { line in
                let parts = line.split(separator: "=", maxSplits: 1)
                return parts.count == 2 ? String(parts[0]) : nil
            }
    }

    private func setIcon(recording: Bool) {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            statusItem.button?.image = image
        }
        statusItem.button?.alphaValue = recording ? 1.0 : 0.7
    }
}
