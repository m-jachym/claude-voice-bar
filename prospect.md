# Claude Voice Bar

Apka menu bar na macOS. Wciskasz `§`, mówisz po polsku, wybierasz cyfrą do której sesji Claude Code wysłać — prompt leci jak wklejony z klawiatury.

## Workflow

```
§                → start nagrywania + popup z aktywnymi sesjami
mówisz prompt    → nagrywanie w tle
1 / 2 / 3 / ... → stop + transkrypcja + wyślij do wybranej sesji
Esc              → anuluj
```

Popup pojawia się dynamicznie przy każdym `§` — lista sesji pobierana live z tmux, filtrowana do tych gdzie działa Claude Code.

```
┌─────────────────────┐
│ 🎤 Nagrywanie...    │
│                     │
│ 1 → hosepilot       │
│ 2 → columbus        │
│ 3 → zakuwanie       │
└─────────────────────┘
```

## Architektura

```
ClaudeVoiceBar/
├── HotkeyManager       § i 1/2/3/Esc jako global hotkeys
├── TmuxSessionManager  live query: które sesje mają claude
├── AudioRecorder       AVFoundation, 16kHz mono WAV → /tmp/
├── WhisperTranscriber  whisper-cpp jako subprocess, język: pl
└── SessionPopover      NSPopover nad menu bar icon
```

**Flow danych:**
```
§ → [TmuxSessionManager.getSessions()] → [AudioRecorder.start()] → popup
cyfra → [AudioRecorder.stop()] → [WhisperTranscriber.transcribe()] → [TmuxSessionManager.send()]
```

**Stack:** Swift 5.9, SwiftUI, AVFoundation, whisper.cpp, tmux

## Wymagania

- macOS 13+
- `brew install tmux whisper-cpp`
- Model whisper: `small` (lepsza jakość PL niż `base`)
- App Sandbox: wyłączony (shell access do tmux)
- Claude Code zainstalowany

## Komenda terminala (tmux wrapper)

Użytkownik wybiera nazwę komendy przy instalacji. Domyślna: `claude-vb`.

```bash
# ~/.local/bin/claude-voice-bar-wrapper
SESSION=$(basename "$PWD")
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach -t "$SESSION"
else
  tmux new -s "$SESSION" -c "$PWD" "claude"
fi
```

Nazwa komendy konfigurowalna — install.sh pyta przy instalacji, zapisuje alias do `~/.zshrc`.

## Dystrybucja

- **DMG** z podpisaną apką (Apple Developer Account) — brak problemów z Gatekeeperem
- **install.sh** ogarnia resztę: tmux, whisper-cpp, model, wrapper, alias
- Docelowo: GitHub Releases z DMG + `curl | bash` dla install.sh
- Repo: `github.com/[user]/claude-voice-bar`
