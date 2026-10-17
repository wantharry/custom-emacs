# Bundled fonts

All 20 fonts `C-c F`/`C-c }`/`C-c {` ([KEYBOARD.md](../../docs/KEYBOARD.md)) can switch to are
bundled here as real font files, so a fresh install of this bundle has every one of them
available --- not just "configured," actually installable, with zero network access needed.
Each is redistributed under its own real, verified open license: see `licenses/`.

The first 12 were bundled first (see `git log` on this file for that batch); the remaining 8
--- `JetBrainsMono Nerd Font Mono`, `Fira Code`, `Cascadia Code`, `DejaVu Sans Mono`, `Hack`,
`Monaspace Neon`, `CommitMono`, `Iosevka` --- were added afterward, closing the gap the project's
own `my/fonts` comment used to call out as "deliberately not here." Notes on each, since none of
this was assumed:

- **`JetBrainsMono Nerd Font Mono.ttf`** --- from the Nerd Fonts project's own release
  (`JetBrainsMono.tar.xz`, checksum verified against GitHub's published digest). The Nerd Fonts
  patcher ships several family variants from the same source font (`...Nerd Font`, `...Nerd Font
  Mono`, `...Nerd Font Propo`); only the `Mono` one has the family name this config actually
  looks for (`JetBrainsMono Nerd Font Mono`), confirmed with `fc-scan`, not assumed from the
  filename. Two licenses apply and are both here: Nerd Fonts' own patcher license
  (`NerdFonts-LICENSE.txt`) and JetBrains Mono's own OFL (`JetBrainsMonoNerdFontMono-OFL.txt`).
- **`FiraCode.ttf`**, **`CascadiaCode.ttf`**, **`MonaspaceNeon.otf`**, **`CommitMono.ttf`**,
  **`Iosevka.ttc`** --- all OFL, fetched from each project's own GitHub release and confirmed with
  `fc-scan`. One real, caught-not-assumed gotcha: CommitMono's own font file registers its family
  as `CommitMono`, no space --- not `Commit Mono`. `config/init.el`'s `my/fonts` list used to say
  "Commit Mono" (never would have matched even with this file installed) and has been corrected
  to `"CommitMono"`.
- **`DejaVuSansMono.ttf`** --- the DejaVu project's own Bitstream-Vera-derived license, not OFL
  (see `DejaVuSansMono-LICENSE.txt`); it is public domain plus the Bitstream Vera license, not a
  SIL-licensed font.
- **`Hack.ttf`** --- also not plain OFL: Hack's own `LICENSE.md` is MIT (Source Foundry's own
  additions) plus the inherited Bitstream Vera and DejaVu licenses (see `Hack-LICENSE.md`).
- **Iosevka's real size, corrected**: the old version of this file estimated "~114 MB combined"
  for a Regular+Bold pair, based on an asset name (`ttc-iosevka`) that no longer exists in
  Iosevka's current releases. The current release's single-weight `.ttc` files are themselves
  about 57 MB EACH (a `.ttc` bundles upright, oblique, extended and other variants of that one
  weight together) --- so bundling just `Iosevka-Regular.ttc` (confirmed to register the plain
  `Iosevka` family via `fc-scan`) costs about 57 MB, not 114 MB, and matches how every other font
  here is one single Regular-weight file, not a Bold alongside it.

## Installing them (one-time, no admin rights needed)

**Windows:** select every font file in this folder (`Ctrl-A`; includes `.ttf`, `.otf` and `.ttc`
files), right-click, choose **Install** (or **Install for all users** if you are an administrator
and want every account on the PC to have them). A few seconds, then restart Emacs --- `C-c F` now
finds all 20.

**Linux:** copy this folder's font files into `~/.local/share/fonts/`, then run `fc-cache -f`.
(This project's own dev machine has these at exactly that path.)

**macOS:** double-click each font file, click **Install Font** in the preview that opens.
