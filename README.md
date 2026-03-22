# Claude Voice Bar

macOS menu bar app. Press `§`, speak your prompt, pick which Claude Code session to send it to.

```
§                → start recording + show active sessions
speak            → recording in background
1 / 2 / 3 / ... → stop + transcribe + send to selected session
Esc              → cancel
```

## Requirements

- macOS 13+
- [Homebrew](https://brew.sh)
- Claude Code installed

## Installation

1. Download `ClaudeVoiceBar.dmg` from [Releases](https://github.com/m-jachym/claude-voice-bar/releases)
2. Drag `ClaudeVoiceBar` to Applications
3. Double-click `Install Dependencies` — installs tmux, whisper-cpp, and the `claude-vb` command
4. Launch Claude Voice Bar from Applications
5. Grant Accessibility and Microphone permissions when prompted — the app restarts automatically

## Usage

Use `claude-vb` instead of `claude` to start sessions:

```bash
cd ~/your-project
claude-vb
```

This opens Claude Code in a tmux session. Claude Voice Bar detects all open sessions and lets you send voice prompts to any of them.

## How it works

```
§ key → detect active Claude sessions via tmux
      → start recording (AVAudioRecorder, 16kHz mono WAV)

number key / click → stop recording
                   → transcribe via whisper-cpp (small model, Polish + English)
                   → send text to selected tmux session via tmux send-keys
```

## Stack

Swift 5.9, SwiftUI, AVFoundation, whisper.cpp, tmux
