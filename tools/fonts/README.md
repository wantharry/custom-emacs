# Bundled fonts

12 of the 20 fonts `C-c F`/`C-c }`/`C-c {` ([KEYBOARD.md](../../docs/KEYBOARD.md)) can switch
to, bundled here as real font files so a fresh install of this bundle has them available ---
not just "configured," actually installable. Each is redistributed under its own real,
verified open license: see `licenses/`.

**The other 8 entries in `my/fonts` are deliberately NOT here:**

- `JetBrainsMono Nerd Font Mono`, `Fira Code`, `Cascadia Code`, `DejaVu Sans Mono` --- already
  covered by this config's own startup fallback chain (`config/init.el`); Cascadia Code in
  particular already ships with Windows 11 and recent Windows Terminal installs.
- `Iosevka` --- a real, deliberate size tradeoff: its two weights (`Regular`/`Bold`) are
  **~114 MB combined**, more than half the size of this entire bundle. Get it yourself from
  <https://github.com/be5invis/Iosevka/releases> (the `ttc-iosevka` asset) if you want it ---
  same install steps below, just with those two files instead.
- `Hack`, `Monaspace Neon`, `Commit Mono` --- not yet bundled here at all (never fetched this
  session). `C-c F` says "not installed" honestly for these until you install them yourself,
  the same as for any font this project does not manage (see `my/fonts`' own comment in
  `config/init.el`).

## Installing them (one-time, no admin rights needed)

**Windows:** select every `.ttf` file in this folder (`Ctrl-A`), right-click, choose
**Install** (or **Install for all users** if you are an administrator and want every account
on the PC to have them). A few seconds, then restart Emacs --- `C-c F` now finds them.

**Linux:** copy this folder's `.ttf` files into `~/.local/share/fonts/`, then run
`fc-cache -f`. (This project's own dev machine has these at exactly that path.)

**macOS:** double-click each `.ttf`, click **Install Font** in the preview that opens.
