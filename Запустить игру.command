#!/bin/zsh
set -e
GAME_DIR="${0:A:h}"
ENGINE="$GAME_DIR/tools/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$ENGINE" ]]; then
  print 'Движок Godot не найден в tools/Godot.app. Откройте project.godot в Godot 4.'
  read '?Нажмите Enter, чтобы закрыть окно.'
  exit 1
fi
exec "$ENGINE" --path "$GAME_DIR"
