#!/bin/bash

set -e

echo ""
echo "Claude Voice Bar — Installing dependencies"
echo "==========================================="
echo ""

# 1. Homebrew
if ! command -v brew &>/dev/null; then
  echo "ERROR: Homebrew not found."
  echo "Install it first: https://brew.sh"
  exit 1
fi

# 2. tmux
if ! command -v tmux &>/dev/null; then
  echo "→ Installing tmux..."
  brew install tmux
else
  echo "✓ tmux already installed"
fi

# 3. whisper-cpp
if ! command -v whisper-cli &>/dev/null; then
  echo "→ Installing whisper-cpp..."
  brew install whisper-cpp
else
  echo "✓ whisper-cpp already installed"
fi

# 4. Whisper model
MODEL_PATH="$HOME/.local/share/whisper/ggml-small.bin"
if [ ! -f "$MODEL_PATH" ]; then
  echo "→ Downloading Whisper model (~466MB)..."
  mkdir -p "$HOME/.local/share/whisper"
  curl -L --progress-bar -o "$MODEL_PATH" \
    "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"
  echo "✓ Model downloaded"
else
  echo "✓ Whisper model already present"
fi

# 5. tmux wrapper
WRAPPER="$HOME/.local/bin/claude-voice-bar-wrapper"
mkdir -p "$HOME/.local/bin"
cat > "$WRAPPER" << 'EOF'
#!/bin/bash
SESSION=$(basename "$PWD")
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach -t "$SESSION"
else
  tmux new -s "$SESSION" -c "$PWD" "claude"
fi
EOF
chmod +x "$WRAPPER"
echo "✓ tmux wrapper installed"

# 6. Alias
echo ""
echo "Choose a command name to start Claude in tmux (default: claude-vb):"
read -r CMD_NAME
CMD_NAME=${CMD_NAME:-claude-vb}

SHELL_RC="$HOME/.zshrc"
if ! grep -q "alias $CMD_NAME=" "$SHELL_RC" 2>/dev/null; then
  echo "alias $CMD_NAME='$WRAPPER'" >> "$SHELL_RC"
  echo "✓ Added alias '$CMD_NAME' to $SHELL_RC"
else
  echo "✓ Alias '$CMD_NAME' already exists"
fi

# 7. claude-vb-notify script
NOTIFY_SCRIPT="$HOME/.local/bin/claude-vb-notify"
cp "$(dirname "$0")/claude-vb-notify" "$NOTIFY_SCRIPT"
chmod +x "$NOTIFY_SCRIPT"
echo "✓ claude-vb-notify installed"

# 8. Claude Code permission hook
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
if [ -f "$CLAUDE_SETTINGS" ]; then
  python3 - "$CLAUDE_SETTINGS" "$NOTIFY_SCRIPT" << 'PYEOF'
import json, sys

path = sys.argv[1]
notify_path = sys.argv[2]

with open(path) as f:
    s = json.load(f)

s.setdefault('hooks', {}).setdefault('Notification', [])

if not any('claude-vb-notify' in str(h) for h in s['hooks']['Notification']):
    s['hooks']['Notification'].append({
        "matcher": "",
        "hooks": [{"type": "command", "command": notify_path}]
    })

with open(path, 'w') as f:
    json.dump(s, f, indent=2)
PYEOF
  echo "✓ Claude Code permission hook added"
else
  echo "⚠ ~/.claude/settings.json not found — skipping hook setup (Claude Code not installed?)"
fi

echo ""
echo "==========================================="
echo "Done! Restart your terminal and use '$CMD_NAME' instead of 'claude'."
echo ""
