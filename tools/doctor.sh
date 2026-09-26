#!/usr/bin/env bash
# Check the things that make Emacs slow or stuck, especially on WSL.
#   tools/doctor.sh            full check (opens a graphical window for a moment)
#   tools/doctor.sh --no-gui   skip the window (used by the test suite)
# Exit status is 1 if anything FAILED; warnings do not fail. See docs/TROUBLESHOOTING.md.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUI=1; [ "${1:-}" = "--no-gui" ] && GUI=0
EMACS="${EMACS:-$ROOT/install/bin/emacs}"; [ -x "$EMACS" ] || EMACS="$ROOT/build/src/emacs"   # EMACS=/path overrides
WARNS=0; FAILS=0
ok()      { printf '  [ OK ] %s\n' "$*"; }
warn()    { printf '  [WARN] %s\n' "$*"; WARNS=$((WARNS+1)); }
fail()    { printf '  [FAIL] %s\n' "$*"; FAILS=$((FAILS+1)); }
info()    { printf '         %s\n' "$*"; }
section() { printf '\n%s\n' "$*"; }
secs()    { local s e; s=$(date +%s.%N); "$@" >/dev/null 2>&1; local rc=$?; e=$(date +%s.%N); printf '%.2f %s' "$(echo "$e - $s" | bc)" "$rc"; }
WSL=0; grep -qi microsoft /proc/version 2>/dev/null && WSL=1

section "Environment"
if [ "$WSL" = 1 ]; then ok "running under WSL ($(uname -r))"; else ok "not WSL ($(uname -s))"; fi
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then ok "display: DISPLAY=${DISPLAY:-} WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-}"
else warn "no display in this session: graphical Emacs cannot start (use emacs -nw)"; fi
if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
  sock="${DBUS_SESSION_BUS_ADDRESS#unix:path=}"; sock="${sock%%,*}"
  if [ -S "$sock" ]; then ok "D-Bus session socket exists"
  else info "D-Bus address is set but the socket is missing ($sock). Harmless when measured here;"
       info "if the window ever stalls at startup, try: NO_AT_BRIDGE=1 GSETTINGS_BACKEND=memory emacs"; fi
fi

section "Where the files live"
fs="$(stat -f -c %T "$ROOT" 2>/dev/null)"
case "$fs:$ROOT" in
  v9fs:*|drvfs:*|*:/mnt/*) fail "project is on a Windows drive ($fs). File access there is ~200x slower; move it to the Linux disk" ;;
  *) ok "project is on the Linux disk ($fs)" ;;
esac

section "PATH (every program lookup walks it)"
total=$(echo "$PATH" | tr ':' '\n' | wc -l); win=$(echo "$PATH" | tr ':' '\n' | grep -c '^/mnt/')
if [ "$win" -gt 10 ]; then
  warn "$win of $total PATH entries are Windows folders; each miss costs ~0.09 s (package.el once took 0.7 s because of this)"
  info "fix for all programs: add  [interop] appendWindowsPath=false  to /etc/wsl.conf, then wsl --shutdown"
else ok "PATH has $total entries, $win on Windows drives"; fi

section "Emacs"
if [ ! -x "$EMACS" ]; then fail "no Emacs binary found (run ./build.sh)"; else
  ok "$("$EMACS" --version | head -1) ($EMACS)"
  T="$(mktemp -d)"; cp "$ROOT/config/early-init.el" "$ROOT/config/init.el" "$T/"
  for d in elpa tree-sitter; do [ -d "$ROOT/config/$d" ] && ln -s "$ROOT/config/$d" "$T/$d"; done
  read -r t rc < <(secs "$EMACS" --batch --init-directory="$T" -l "$T/early-init.el" -l "$T/init.el" --eval '(kill-emacs)')
  if [ "$rc" != 0 ]; then fail "loading config/init.el failed (exit $rc)"
  elif [ "$(echo "$t < 0.5" | bc)" = 1 ]; then ok "config loads headless in ${t}s"
  else warn "config took ${t}s to load headless (normally about 0.05 s)"; fi
  if [ "$GUI" = 1 ] && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    read -r t rc < <(secs timeout 60 "$EMACS" --init-directory="$T" -l "$T/early-init.el" -l "$T/init.el" --eval '(kill-emacs)')
    if [ "$rc" = 124 ]; then fail "opening a graphical window did not finish in 60 s (WSLg or a prompt is stuck)"
    elif [ "$(echo "$t < 2" | bc)" = 1 ]; then ok "a real window opens and closes in ${t}s"
    else warn "opening a window took ${t}s (normally about 0.2 s)"; fi
    fam="$T/family.txt"
    timeout 60 "$EMACS" --init-directory="$T" -l "$T/early-init.el" -l "$T/init.el" \
      --eval "(progn (write-region (face-attribute 'default :family) nil \"$fam\") (kill-emacs))" >/dev/null 2>&1
    if [ -s "$fam" ]; then
      f="$(cat "$fam")"
      if [ "$f" = "JetBrains Mono" ]; then ok "window font: $f"
      else warn "window font is '$f', not the preferred JetBrains Mono"
           info "installed JetBrains names: $(fc-list : family 2>/dev/null | grep -i jetbrains | head -1)"
           info "put the exact installed family name first in the font list in config/init.el"; fi
    fi
  elif [ "$GUI" = 1 ]; then info "window check skipped (no display)"; fi
  rm -rf "$T"
fi

section "Fonts"
n=$(fc-list : file 2>/dev/null | wc -l); w=$(fc-list : file 2>/dev/null | grep -c '^/mnt/')
read -r t rc < <(secs fc-list)
if [ "$w" -gt 0 ]; then warn "$w of $n fonts come from the Windows drive; scanning them can stall a window start"
elif [ "$(echo "$t < 1" | bc)" = 1 ]; then ok "$n fonts, none on Windows drives, fc-list ${t}s"
else warn "fc-list took ${t}s (font cache stale? run: fc-cache -f)"; fi

section "Emacs processes running now"
ps -o pid=,etime=,stat=,pcpu=,rss=,args= -C emacs 2>/dev/null > /tmp/doctor-ps.$$
if [ ! -s /tmp/doctor-ps.$$ ]; then ok "none"; else
  workers=$(grep -c 'no-comp-spawn\|emacs-async-comp' /tmp/doctor-ps.$$)
  [ "$workers" -gt 0 ] && info "$workers are native-compilation workers (busy for a while after first using a package)"
  while read -r pid age stat cpu rss rest; do
    case "$rest" in *no-comp-spawn*|*emacs-async-comp*) continue ;; esac
    line="pid $pid age $age state $stat cpu ${cpu}% $((rss/1024)) MB"
    case "$stat" in
      D*) warn "$line: stuck on disk I/O (a /mnt/c path?)" ;;
      R*) if [ "$(echo "$cpu > 80" | bc)" = 1 ]; then warn "$line: busy; run kill -USR2 $pid to see where"; else ok "$line"; fi ;;
      *)  ok "$line (waiting for input)" ;;
    esac
  done < /tmp/doctor-ps.$$
fi
rm -f /tmp/doctor-ps.$$

section "Tools"
for c in java javac cargo rustc rustup jdtls tmux git; do
  if command -v $c >/dev/null 2>&1; then ok "$c"; else warn "$c not found"; fi
done
if command -v rust-analyzer >/dev/null 2>&1; then
  if rust-analyzer --version >/dev/null 2>&1; then ok "rust-analyzer works"
  else warn "rust-analyzer is only a stub; run: rustup component add rust-analyzer"; fi
fi
[ -f "$ROOT/config/tree-sitter/libtree-sitter-java.so" ] && [ -f "$ROOT/config/tree-sitter/libtree-sitter-rust.so" ] \
  && ok "tree-sitter grammars installed (java, rust)" || warn "grammars missing; run: ./build.sh grammars"
[ -d "$ROOT/config/elpa" ] && ls "$ROOT"/config/elpa | grep -q '^evil' && ok "Evil installed" || warn "Evil missing; run: ./build.sh packages"

section "Repository"
if [ "$(git -C "$ROOT" config core.hooksPath 2>/dev/null)" = ".githooks" ]; then ok "pre-commit test hook is enabled"
else warn "pre-commit hook not enabled; run: git config core.hooksPath .githooks"; fi

printf '\n%d warning(s), %d failure(s)\n' "$WARNS" "$FAILS"
[ "$FAILS" = 0 ]
