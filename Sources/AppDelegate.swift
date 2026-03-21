import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    private let recorder = AudioRecorder()
    private let transcriber = WhisperTranscriber()
    private let popoverModel = PopoverModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(recording: false)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 240, height: 200)
        popover.behavior = .applicationDefined // zamykamy ręcznie
        popover.contentViewController = NSHostingController(
            rootView: SessionPopoverContentView(model: popoverModel)
        )

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

        // Pokaż popup natychmiast
        popoverModel.sessions = []
        popoverModel.isRecording = true
        popoverModel.isLoadingSessions = true
        showPopover()

        // Nagrywanie + sesje w tle
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.recorder.startRecording()
                DispatchQueue.main.async { self.setIcon(recording: true) }
            } catch {
                NSLog("AudioRecorder error: \(error)")
            }

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
        hidePopover()

        DispatchQueue.global(qos: .userInitiated).async {
            let audioURL = self.recorder.stopRecording()
            guard let text = self.transcriber.transcribe(audioPath: audioURL), !text.isEmpty else {
                NSLog("Transcription empty or failed")
                return
            }
            NSLog("Sending to '\(session)': \(text)")
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
        hidePopover()
        DispatchQueue.global(qos: .userInitiated).async {
            _ = self.recorder.stopRecording()
        }
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
