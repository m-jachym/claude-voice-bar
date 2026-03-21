# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

macOS menu bar app (Swift/SwiftUI) that captures voice via a global hotkey (`§`), transcribes it with whisper.cpp, and sends the text to a selected tmux session running Claude Code.

## Build & Run

```bash
# Open in Xcode
open VoiceToClaudeCode.xcodeproj

# Build from CLI (after Xcode project exists)
xcodebuild -project VoiceToClaudeCode.xcodeproj -scheme VoiceToClaudeCode -configuration Debug build

# Run tests
xcodebuild test -project VoiceToClaudeCode.xcodeproj -scheme VoiceToClaudeCode
```

## Dependencies (must be installed before building)

```bash
brew install tmux whisper-cpp
whisper-cpp-download-ggml-model small   # model goes to ~/.local/share/whisper/
```

## Architecture

The app has no window — only a menu bar icon and an `NSPopover`. All state lives in `AppDelegate`.

**Data flow:**
```
§ key → HotkeyManager → TmuxSessionManager.getActiveSessions()
                      → AudioRecorder.startRecording()
                      → SessionPopover (shows session list)

1/2/3 key → AudioRecorder.stopRecording() → WhisperTranscriber.transcribe()
          → TmuxSessionManager.send(text:to:)

Esc → AudioRecorder.stopRecording() → discard
```

**Key files:**
- `AppDelegate.swift` — wires all components together, owns `NSStatusItem` and `NSPopover`
- `HotkeyManager.swift` — Carbon-based global event monitor; `§` = keyCode 10
- `TmuxSessionManager.swift` — shells out to `tmux`; filters sessions by checking if `claude` process runs under each pane's PID tree
- `AudioRecorder.swift` — AVAudioEngine tap → `/tmp/voice_input.wav` (16kHz mono PCM)
- `WhisperTranscriber.swift` — subprocess: `whisper-cpp --language pl --output-txt --no-timestamps`
- `SessionPopoverView.swift` — SwiftUI view embedded in `NSHostingController`

## Xcode Project Settings

- App Sandbox: **OFF** (required for tmux shell access)
- Hardened Runtime → Microphone: **ON**
- `Info.plist`: `NSMicrophoneUsageDescription` set
- Activation policy: `.accessory` (hidden from Dock)

## Whisper binary & model paths

Hardcoded in `WhisperTranscriber.swift`:
- Binary: `/opt/homebrew/bin/whisper-cpp`
- Model: `~/.local/share/whisper/ggml-small.bin`

Update these if the user's Homebrew prefix differs (e.g. Intel Mac uses `/usr/local`).

## tmux session detection

`TmuxSessionManager` walks the process tree under each pane PID using `pgrep -P` + `ps -o comm=` to find a process whose name contains `claude`. This is intentionally loose — it matches both `claude` and `node` processes that wrap it.

## Distribution

1. Xcode Archive → Distribute → Developer ID (notarized)
2. `create-dmg` wraps the `.app`
3. `install.sh` in repo root handles dependency setup and tmux wrapper alias
