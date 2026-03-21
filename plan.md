# Claude Voice Bar — Plan Wdrożenia

## Krok 1: Tmux Wrapper

Tworzy sesje tmux o nazwie = katalog projektu. Nazwa komendy wybierana przez użytkownika przy instalacji (domyślnie: `claude-vb`).

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/claude-voice-bar-wrapper << 'EOF'
#!/bin/bash
SESSION=$(basename "$PWD")
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach -t "$SESSION"
else
  tmux new -s "$SESSION" -c "$PWD" "claude"
fi
EOF
chmod +x ~/.local/bin/claude-voice-bar-wrapper

echo "Podaj nazwę komendy do startowania Claude (domyślnie: claude-vb):"
read -r CMD_NAME
CMD_NAME=${CMD_NAME:-claude-vb}
echo "alias $CMD_NAME='claude-voice-bar-wrapper'" >> ~/.zshrc
source ~/.zshrc
```

**Test:**
```bash
cd ~/hosepilot && claude-vb   # otwiera claude w tmux
tmux list-sessions             # powinno pokazać "hosepilot"
```

---

## Krok 2: Whisper Setup

```bash
brew install whisper-cpp
# pobierz model small (lepsza jakość PL)
whisper-cpp-download-ggml-model small
# test:
whisper-cpp --model ~/.local/share/whisper/ggml-small.bin --language pl /tmp/test.wav
```

Zanotuj ścieżkę do modelu — będzie hardkodowana w aplikacji (lub konfigurowalna).

---

## Krok 3: Xcode Project

1. Xcode → New Project → macOS → App
   - Product Name: `VoiceToClaudeCode`
   - Interface: SwiftUI, Language: Swift
2. Signing & Capabilities:
   - Hardened Runtime → **Audio Input: ON**
   - App Sandbox: **OFF**
3. Info.plist → dodaj:
   - `NSMicrophoneUsageDescription` = "Nagrywanie głosowych promptów"

Struktura plików:
```
VoiceToClaudeCode/
├── VoiceToClaudeCodeApp.swift
├── AppDelegate.swift
├── HotkeyManager.swift
├── TmuxSessionManager.swift
├── AudioRecorder.swift
├── WhisperTranscriber.swift
└── SessionPopover.swift
```

---

## Krok 4: Menu Bar App Entry Point

**VoiceToClaudeCodeApp.swift** — ukryj z Docka, pokaż tylko w menu bar:

```swift
@main
struct VoiceToClaudeCodeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
```

**AppDelegate.swift** — status bar item + ikona:

```swift
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // ukryj z Docka

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "mic", accessibilityDescription: nil)

        popover = NSPopover()
        popover.contentSize = NSSize(width: 200, height: 150)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: SessionPopoverView())
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    func hidePopover() {
        popover.performClose(nil)
    }
}
```

---

## Krok 5: HotkeyManager

Global hotkeys bez focusu apki. `§` = keyCode 10 na macOS.

```swift
import Carbon

class HotkeyManager {
    static let shared = HotkeyManager()
    var onStartRecording: (() -> Void)?
    var onStopAndSend: ((Int) -> Void)?  // 1, 2, 3...
    var onCancel: (() -> Void)?

    private var isRecording = false
    private var monitor: Any?

    func start() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKey(event)
        }
    }

    private func handleKey(_ event: NSEvent) {
        switch event.keyCode {
        case 10: // § key
            if !isRecording {
                isRecording = true
                onStartRecording?()
            }
        case 18: // 1
            if isRecording { isRecording = false; onStopAndSend?(1) }
        case 19: // 2
            if isRecording { isRecording = false; onStopAndSend?(2) }
        case 20: // 3
            if isRecording { isRecording = false; onStopAndSend?(3) }
        case 21: // 4
            if isRecording { isRecording = false; onStopAndSend?(4) }
        case 22: // 5
            if isRecording { isRecording = false; onStopAndSend?(5) }
        case 53: // Esc
            if isRecording { isRecording = false; onCancel?() }
        default:
            break
        }
    }

    func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
    }
}
```

**Test:** Dodaj `print` do callbacków, sprawdź w Console.app czy klawisze są wychwytywane.

---

## Krok 6: TmuxSessionManager

Dynamiczna lista sesji gdzie działa Claude Code.

```swift
class TmuxSessionManager {
    static let shared = TmuxSessionManager()

    func getActiveSessions() -> [String] {
        let sessions = shell("tmux list-sessions -F '#{session_name}' 2>/dev/null")
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        return sessions.filter { hasClaudeRunning(in: $0) }
    }

    private func hasClaudeRunning(in session: String) -> Bool {
        let pids = shell("tmux list-panes -t '\(session)' -F '#{pane_pid}' 2>/dev/null")
            .components(separatedBy: "\n")
            .filter { !$0.isEmpty }

        for pid in pids {
            let tree = shell("pgrep -P \(pid) 2>/dev/null")
            for childPid in tree.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
                let name = shell("ps -o comm= -p \(childPid) 2>/dev/null")
                if name.contains("claude") { return true }
            }
        }
        return false
    }

    func send(text: String, to session: String) {
        // Escape cudzysłowów
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        shell("tmux send-keys -t '\(session)' \"\(escaped)\" Enter")
    }

    @discardableResult
    private func shell(_ command: String) -> String {
        let task = Process()
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        task.launchPath = "/bin/bash"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
```

**Test:**
```bash
# Odpal dwie sesje pikus, potem w Console.app sprawdź czy getActiveSessions() je zwraca
```

---

## Krok 7: AudioRecorder

```swift
import AVFoundation

class AudioRecorder: NSObject {
    private var engine = AVAudioEngine()
    private var file: AVAudioFile?
    private let outputURL = URL(fileURLWithPath: "/tmp/voice_input.wav")

    func startRecording() throws {
        let input = engine.inputNode
        let format = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                   sampleRate: 16000,
                                   channels: 1,
                                   interleaved: true)!

        file = try AVAudioFile(forWriting: outputURL, settings: format.settings)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            try? self?.file?.write(from: buffer)
        }

        try engine.start()
    }

    func stopRecording() -> URL {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        file = nil
        return outputURL
    }
}
```

**Test:** Nagraj 3s, sprawdź `/tmp/voice_input.wav` — czy da się odtworzyć w QuickTime.

---

## Krok 8: WhisperTranscriber

```swift
class WhisperTranscriber {
    // Zaktualizuj ścieżkę po `brew install whisper-cpp`
    private let whisperBin = "/opt/homebrew/bin/whisper-cpp"
    private let model = "\(NSHomeDirectory())/.local/share/whisper/ggml-small.bin"

    func transcribe(audioPath: URL) -> String? {
        let txtPath = audioPath.deletingPathExtension().appendingPathExtension("txt")
        try? FileManager.default.removeItem(at: txtPath)

        let task = Process()
        task.launchPath = whisperBin
        task.arguments = [
            "--model", model,
            "--language", "pl",
            "--output-txt",
            "--no-timestamps",
            audioPath.path
        ]
        task.launch()
        task.waitUntilExit()

        return try? String(contentsOf: txtPath, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
```

---

## Krok 9: SessionPopover UI

```swift
struct SessionPopoverView: View {
    @State var sessions: [String] = []
    @State var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: isRecording ? "mic.fill" : "mic")
                    .foregroundColor(isRecording ? .red : .secondary)
                Text(isRecording ? "Nagrywanie..." : "Gotowy")
                    .font(.headline)
            }
            Divider()
            if sessions.isEmpty {
                Text("Brak aktywnych sesji Claude")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(Array(sessions.enumerated()), id: \.offset) { i, session in
                    Text("\(i + 1)  →  \(session)")
                        .font(.system(.body, design: .monospaced))
                }
            }
        }
        .padding()
        .frame(width: 220)
    }
}
```

---

## Krok 10: Spinanie całości w AppDelegate

```swift
// W AppDelegate, po inicjalizacji statusItem:

let recorder = AudioRecorder()
let transcriber = WhisperTranscriber()
var sessions: [String] = []

HotkeyManager.shared.onStartRecording = { [weak self] in
    guard let self else { return }
    self.sessions = TmuxSessionManager.shared.getActiveSessions()
    // aktualizuj widok popovera i pokaż go
    try? recorder.startRecording()
    self.statusItem.button?.image = NSImage(systemSymbolName: "mic.fill", ...)
    self.showPopover()
}

HotkeyManager.shared.onStopAndSend = { [weak self] index in
    guard let self else { return }
    let audioURL = recorder.stopRecording()
    self.hidePopover()
    self.statusItem.button?.image = NSImage(systemSymbolName: "mic", ...)

    guard index <= self.sessions.count else { return }
    let session = self.sessions[index - 1]

    DispatchQueue.global().async {
        if let text = transcriber.transcribe(audioPath: audioURL), !text.isEmpty {
            TmuxSessionManager.shared.send(text: text, to: session)
        }
    }
}

HotkeyManager.shared.onCancel = { [weak self] in
    _ = recorder.stopRecording()
    self?.hidePopover()
    self?.statusItem.button?.image = NSImage(systemSymbolName: "mic", ...)
}

HotkeyManager.shared.start()
```

---

## Krok 10: Pakowanie i dystrybucja

Masz Apple Developer Account — apka będzie poprawnie podpisana, bez problemów z Gatekeeperem.

**Podpisanie i notaryzacja:**
```
Xcode → Product → Archive
→ Distribute App → Developer ID → Upload (notaryzacja przez Apple)
→ Export → .app
```

**DMG:**
```bash
brew install create-dmg
create-dmg \
  --volname "Claude Voice Bar" \
  --window-size 600 400 \
  --icon-size 128 \
  --app-drop-link 400 200 \
  "ClaudeVoiceBar.dmg" \
  "ClaudeVoiceBar.app"
```

**install.sh** (wrzucany do repo, uruchamiany przez użytkownika po zamontowaniu DMG):
```bash
#!/bin/bash
# Instaluje zależności i konfiguruje komendę terminala

# 1. Sprawdź brew
if ! command -v brew &>/dev/null; then
  echo "Zainstaluj Homebrew najpierw: https://brew.sh"
  exit 1
fi

# 2. Zależności
brew install tmux whisper-cpp

# 3. Model whisper small
whisper-cpp-download-ggml-model small

# 4. Wrapper
mkdir -p ~/.local/bin
cat > ~/.local/bin/claude-voice-bar-wrapper << 'EOF'
#!/bin/bash
SESSION=$(basename "$PWD")
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach -t "$SESSION"
else
  tmux new -s "$SESSION" -c "$PWD" "claude"
fi
EOF
chmod +x ~/.local/bin/claude-voice-bar-wrapper

# 5. Alias — użytkownik wybiera nazwę
echo "Podaj nazwę komendy do startowania Claude (domyślnie: claude-vb):"
read -r CMD_NAME
CMD_NAME=${CMD_NAME:-claude-vb}
echo "alias $CMD_NAME='claude-voice-bar-wrapper'" >> ~/.zshrc

echo "✓ Gotowe! Zrestartuj terminal i używaj '$CMD_NAME' zamiast 'claude'."
```

**GitHub Release:**
- `ClaudeVoiceBar.dmg` — podpisana apka
- `install.sh` — skrypt konfiguracyjny
- README z instrukcją: pobierz DMG → zainstaluj apkę → uruchom `install.sh`

---

## Kolejność budowania

| Krok | Co budujesz | Jak testujesz |
|------|-------------|---------------|
| 1 | tmux wrapper + alias `claude-vb` | `claude-vb` w katalogu projektu |
| 2 | whisper-cpp + model small | transkrypcja test.wav z CLI |
| 3 | Xcode project + menu bar icon | apka pojawia się w menu bar |
| 4 | HotkeyManager | print w Console po wciśnięciu § |
| 5 | TmuxSessionManager | lista sesji w logach |
| 6 | AudioRecorder | plik WAV w /tmp/ |
| 7 | WhisperTranscriber | tekst w logach po nagraniu |
| 8 | SessionPopover UI | popup z sesjami |
| 9 | Spinanie całości | pełny flow end-to-end |
| 10 | Podpisanie, notaryzacja, DMG | instalacja na czystym Macu |
