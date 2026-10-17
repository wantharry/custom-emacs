#!/usr/bin/env bash
# Find every git repository on this computer: the Linux side, and (if this is WSL) every
# mounted Windows drive.  Prints one repo path per line, sorted, no trailing "/.git".
#
#   tools/find-repos.sh              Linux side only (a couple of seconds)
#   tools/find-repos.sh --windows    also every Windows drive under /mnt (much slower:
#                                    it crosses into NTFS, measured about 48s for one drive)
#
# Used by config/gitfolders.el (C-c f p inside Emacs); also fine to run on its own.
set -euo pipefail

# Folder *names* skipped everywhere they appear (checked against fd/find, not a full path).
SKIP_NAMES=(node_modules)
# Linux paths that are not worth descending into.
LINUX_SKIP=(/proc /sys /dev /run /snap /usr /var /tmp /boot /mnt)
# Windows folder names (case-insensitive) that are not real projects.
WIN_SKIP_NAMES=("Windows" "Program Files" "Program Files (x86)" "ProgramData" '$RECYCLE.BIN' "System Volume Information")

find_with_fd() {   # find_with_fd ROOT SKIP_PATH...
  local root="$1"; shift
  local args=(-H -t d -I -u '^\.git$' "$root")
  for p in "${SKIP_NAMES[@]}" "$@"; do args+=(--exclude "$p"); done
  fd "${args[@]}" 2>/dev/null
}

find_with_find() {   # a plain-find fallback if fd is not installed
  local root="$1"; shift
  local prune=()
  for p in "$@"; do prune+=(-path "$p" -o); done
  find "$root" -xdev \( "${prune[@]}" -false \) -prune -o -type d -name .git -print 2>/dev/null
}

scan() {   # scan ROOT SKIP_PATH...
  if command -v fd >/dev/null; then find_with_fd "$@"; else find_with_find "$@"; fi
}

echo "== Linux =="
scan / "${LINUX_SKIP[@]}" | sed 's#/\.git/\?$##'

if [ "${1:-}" = "--windows" ] && [ -d /mnt ]; then
  for drive in /mnt/*/; do
    drive="${drive%/}"
    case "$(basename "$drive")" in wsl|wslg) continue ;; esac
    [ -d "$drive" ] || continue
    echo "== Windows drive $drive =="
    win_args=()
    for n in "${WIN_SKIP_NAMES[@]}"; do win_args+=("$n"); done
    scan "$drive" "${win_args[@]}" | sed 's#/\.git/\?$##'
  done
fi
