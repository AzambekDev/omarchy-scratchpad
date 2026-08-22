#!/bin/bash
set -eo pipefail

ACTION="${1:-}"
PARAM="${2:-}"
PARAM2="${3:-}"

DATA_DIR="$HOME/.local/share/omarchy/scratchpad"
mkdir -p "$DATA_DIR"

case "$ACTION" in
  copy)
    if command -v wl-copy >/dev/null 2>&1; then
      printf "%s" "$PARAM" | wl-copy
    elif command -v xclip >/dev/null 2>&1; then
      printf "%s" "$PARAM" | xclip -selection clipboard
    fi
    ;;
  open-dir)
    if command -v xdg-open >/dev/null 2>&1; then
      xdg-open "$DATA_DIR" >/dev/null 2>&1 &
    fi
    ;;
  open-notes)
    TARGET="${PARAM:-$DATA_DIR/notes.md}"
    touch "$TARGET"
    if command -v omarchy >/dev/null 2>&1; then
      omarchy launch terminal -- $EDITOR "$TARGET" >/dev/null 2>&1 &
    elif command -v ghostty >/dev/null 2>&1; then
      ghostty -e ${EDITOR:-nano} "$TARGET" >/dev/null 2>&1 &
    elif command -v alacritty >/dev/null 2>&1; then
      alacritty -e ${EDITOR:-nano} "$TARGET" >/dev/null 2>&1 &
    elif command -v kitty >/dev/null 2>&1; then
      kitty ${EDITOR:-nano} "$TARGET" >/dev/null 2>&1 &
    elif command -v foot >/dev/null 2>&1; then
      foot ${EDITOR:-nano} "$TARGET" >/dev/null 2>&1 &
    fi
    ;;
  *)
    echo "Unknown action: $ACTION" >&2
    exit 1
    ;;
esac

exit 0
