import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private var sessions: [String] = []
    private let popoverModel = SessionPopoverView()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(recording: false)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 220, height: 180)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SessionPopoverContentView(model: popoverModel))

        HotkeyManager.shared.onStartRecording = { [weak self] in
            self?.handleStartRecording()
        }
        HotkeyManager.shared.onStopAndSend = { [weak self] index in
            self?.handleStopAndSend(index: index)
        }
        HotkeyManager.shared.onCancel = { [weak self] in
            self?.handleCancel()
        }
        HotkeyManager.shared.start()
    }

    // MARK: - Handlers

    private func handleStartRecording() {
        sessions = TmuxSessionManager.shared.getActiveSessions()
        popoverModel.sessions = sessions
        popoverModel.isRecording = true

        do {
            try recorder.startRecording()
            setIcon(recording: true)
            showPopover()
        } catch {
            NSLog("AudioRecorder error: \(error)")
        }
    }

    private func handleStopAndSend(index: Int) {
        let audioURL = recorder.stopRecording()
        setIcon(recording: false)
        hidePopover()
        popoverModel.isRecording = false

        guard index <= sessions.count else { return }
        let session = sessions[index - 1]

        DispatchQueue.global(qos: .userInitiated).async {
            guard let text = self.transcriber.transcribe(audioPath: audioURL), !text.isEmpty else {
                NSLog("Transcription empty or failed")
                return
            }
            NSLog("Sending to session '\(session)': \(text)")
            TmuxSessionManager.shared.send(text: text, to: session)
        }
    }

    private func handleCancel() {
        _ = recorder.stopRecording()
        setIcon(recording: false)
        hidePopover()
        popoverModel.isRecording = false
    }

    // MARK: - Helpers

    private func setIcon(recording: Bool) {
        let name = recording ? "mic.fill" : "mic"
        statusItem.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func hidePopover() {
        popover.performClose(nil)
    }
}
