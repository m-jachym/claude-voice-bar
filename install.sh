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

echo ""
echo "==========================================="
echo "Done! Restart your terminal and use '$CMD_NAME' instead of 'claude'."
echo ""
