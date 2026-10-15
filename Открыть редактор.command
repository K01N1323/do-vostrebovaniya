#!/bin/zsh
set -e
GAME_DIR="${0:A:h}"
exec "$GAME_DIR/tools/Godot.app/Contents/MacOS/Godot" --editor --path "$GAME_DIR"
