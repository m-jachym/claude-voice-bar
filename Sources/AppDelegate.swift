import AppKit
import SwiftUI
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var panel: NSPanel!

    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private let popoverModel = PopoverModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            waitForAccessibilityAndRelaunch()
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(recording: false)

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Claude Voice Bar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu

        let hostingView = NSHostingView(rootView: SessionPopoverContentView(model: popoverModel))
        hostingView.frame = NSRect(x: 0, y: 0, width: 240, height: 200)

        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 200),
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
        stopAndSend(to: sessions[index - 1])
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

    // MARK: - Panel

    func showPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        let buttonFrame = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let panelWidth: CGFloat = 240
        let panelX = buttonFrame.midX - panelWidth / 2
        let panelY = buttonFrame.minY - 8

        panel.setFrameTopLeftPoint(NSPoint(x: panelX, y: panelY))
        panel.orderFront(nil)
    }

    func hidePanel() {
        panel.orderOut(nil)
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

    private func setIcon(recording: Bool) {
        if let image = NSImage(named: "MenuBarIcon") {
            image.isTemplate = true
            statusItem.button?.image = image
        }
        statusItem.button?.alphaValue = recording ? 1.0 : 0.7
    }
}
