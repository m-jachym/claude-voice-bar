# Claude Voice Bar — Plan Wdrożenia

## ✅ Krok 1: Tmux Wrapper

Sesje tmux tworzone ręcznie przez użytkownika (`tmux new -s nazwa`). Wrapper do instalacji zostaje w `install.sh`.

---

## ✅ Krok 2: Whisper Setup

- `brew install whisper-cpp` — binary: `/opt/homebrew/bin/whisper-cli` (nie `whisper-cpp`!)
- Model pobrany manualnie przez `curl` z HuggingFace → `~/.local/share/whisper/ggml-small.bin`
- Wywołanie wymaga flag `-f` (input) i `-of` (output bez rozszerzenia)

---

## ✅ Krok 3: Xcode Project

Projekt generowany przez `xcodegen` z `project.yml`. Nazwa: `ClaudeVoiceBar`, bundle ID: `com.marekjachym.ClaudeVoiceBar`.
- Hardened Runtime → Audio Input: ON
- App Sandbox: OFF
- `NSMicrophoneUsageDescription` w Info.plist

---

## ✅ Krok 4: Menu Bar App Entry Point

Zaimplementowane. `NSApp.setActivationPolicy(.accessory)`, ikona mikrofonu w status barze.

---

## ✅ Krok 5: HotkeyManager

Zaimplementowane. Dual monitor (global + local) żeby obsługiwać klawisze gdy popup ma focus. `resetRecordingState()` wywoływane po cancel/send. Klawisze 1-9 + Esc.

---

## ✅ Krok 6: TmuxSessionManager

Zaimplementowane. PATH ustawiane ręcznie (`/opt/homebrew/bin`) bo apka nie dziedziczy PATH z shella. Rekurencyjne przeszukiwanie drzewa procesów pod PID pane'a tmux.

---

## ✅ Krok 7: AudioRecorder

Zaimplementowane przez `AVAudioRecorder` (nie AVAudioEngine — blokowało main thread). Format: 16kHz mono PCM → `/tmp/voice_input.wav`.

---

## ✅ Krok 8: WhisperTranscriber

Zaimplementowane. Binary: `whisper-cli`, flagi: `--language pl --output-txt --no-timestamps -of <base> -f <input>`.

---

## ✅ Krok 9: SessionPopover UI

Zaimplementowane. Popup pojawia się natychmiast po `§`, sesje ładowane async w tle. Klikalna lista sesji + przycisk Anuluj. Auto-restart apki po przyznaniu Accessibility.

---

## ✅ Krok 10: Spinanie całości

Działa end-to-end: `§` → nagrywanie → popup z sesjami → klik sesji → transkrypcja whisper → wysłanie do tmux.

---

## Krok 11: Pakowanie i dystrybucja

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

**install.sh** (wrzucany do repo):
```bash
#!/bin/bash
if ! command -v brew &>/dev/null; then
  echo "Zainstaluj Homebrew najpierw: https://brew.sh"
  exit 1
fi

brew install tmux whisper-cpp

mkdir -p ~/.local/share/whisper
curl -L -o ~/.local/share/whisper/ggml-small.bin \
  "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"

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

echo "Gotowe! Zrestartuj terminal i używaj '$CMD_NAME' zamiast 'claude'."
```

**GitHub Release:**
- `ClaudeVoiceBar.dmg` — podpisana apka
- `install.sh` — skrypt konfiguracyjny
- README z instrukcją

---

## Status

| Krok | Co | Status |
|------|----|--------|
| 1 | tmux wrapper | ✅ |
| 2 | whisper-cpp + model | ✅ |
| 3 | Xcode project | ✅ |
| 4 | Menu bar entry point | ✅ |
| 5 | HotkeyManager | ✅ |
| 6 | TmuxSessionManager | ✅ |
| 7 | AudioRecorder | ✅ |
| 8 | WhisperTranscriber | ✅ |
| 9 | SessionPopover UI | ✅ |
| 10 | Spinanie całości | ✅ |
| 11 | Podpisanie, notaryzacja, DMG | ⬜ |
