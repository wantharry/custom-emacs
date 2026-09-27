# Every way to search in Emacs: built in, added here, and available

A map of the whole subject. It answers three questions for every kind of search:

1. **What does Emacs have built in?** (in *this* build, which has some parts pruned)
2. **What did we add or set up here?**
3. **What exists but is not installed**, and would it be worth adding?

For *how to use* each thing, with screenshots and measured speeds, see [SEARCHING.md](SEARCHING.md). This page is the
inventory; that page is the manual.

> **How sure each statement is.** Everything about this build (which commands exist, which keys they have, what was
> pruned) was **checked against the running Emacs** on 2026-09-26. The package versions come from the live package
> archives the same day. Descriptions of packages I have **not installed** are the archives' one-line summaries plus my own
> judgment of overlap; I have not tried any of them. Where a key is in a table, `tests/ert/keybindings.el` checks it.

## 1. The map

| Job | Built into Emacs | Added or set up here | Available, not installed |
|---|---|---|---|
| **Open a file by name** | `find-file`, project file list, recent files, Dired, `find-name-dired`, file name at cursor, bookmarks, registers | the **fast finder** (`C-c f f`, `C-c f g`), the **start screen** (`C-c h`), the **Treemacs** tree (`C-c t`), **`consult-fd`** (`C-c s f`) | `projectile`, `find-file-in-project`, `fzf`, `affe`, `dirvish`, `dired-sidebar`, `neotree`, `fd-dired` |
| **Find text in this buffer** | incremental search (5 variants), `occur`, `highlight-regexp`, `re-builder` | Evil's `/ ? n N * #` when you toggle Evil on (`C-c v`), **`consult-line`** (`C-c s l`, live preview) | `ctrlf`, `anzu`, `isearch-mb`, `swiper`, `phi-search`, `visual-regexp` |
| **Find text in many files** | project search, `rgrep`, `lgrep`, `grep`, `vc-git-grep`, Dired search, `project-search`, tags search | **ripgrep** as the engine (4 to 10 times faster than grep), **`consult-ripgrep`** (`C-c s g`, live preview) | `deadgrep`, `rg`, `ripgrep`, `ag`, `wgrep` (edit the results in place) |
| **Find code by meaning** | `xref` (definitions, references, apropos), `imenu`, Eglot (client), tags | **Eglot set up** for Java and Rust, right-click menu, Ctrl+Click, tree-sitter grammars; on Windows a bundled Java server | `lsp-mode`, `consult-eglot`, `consult-lsp` (Consult itself is installed; these two extras are not), `dumb-jump`, `imenu-list`, `symbol-overlay` |
| **Search and replace** | `query-replace` (+ regexp), project replace, Dired `Q`, `xref` results replace | the read-only lock (unlock a file first with `C-c e e`) | `visual-regexp`, `wgrep` |
| **Buffers, recent files, places** | `switch-to-buffer`, `ibuffer`, project buffers, `recentf`, minibuffer history search, bookmarks, registers | the start screen (last 5 files, folders, projects); `savehist` on; **`consult-buffer`** (`C-c s b`) | `consult-recent-file`, `consult-bookmark`, `consult-mark` (all part of the `consult` package, already installed, just not bound to a key) |
| **Commands, keys, help** | `M-x`, the `apropos` family, `describe-*`, Info, `man`, `shortdoc`, `finder-by-keyword` | `which-key` on, vertical minibuffer list with loose matching, inline completion preview | `marginalia`, `embark`, `vertico`, `orderless` (`consult` itself needs none of these), `ivy`+`counsel`, `helm` |
| **Git history** | `vc-print-log`, `vc-log-search`, `vc-git-grep`, `vc-annotate`, `vc-dir` | **Magit** (`C-x g`) | Forge (GitHub) and Magit add-ons |
| **Find every git repository on this computer** | project.el's own remembered list (`C-x p p`), `M-x magit-list-repositories` (needs `magit-repository-directories` configured first) | `C-c f p`: a real disk scan (Linux, and `C-u` for Windows drives too), async, clickable results | none needed |
| **The web and dictionaries** | `eww-search-words`, `webjump`, `eww`, `dictionary` | none | none needed |

The rest of this page fills in each cell.

## 2. Built in, in detail

Status marks: **tested** = a test or a run here exercised it; **exists** = the command is present and its key is checked, but
I did not use it in anger.

### Search inside one buffer

The five kinds of incremental search (all **tested**, all in [SEARCHING.md](SEARCHING.md)):

<!-- keymap: global -->
| Key | Command | Matches |
|---|---|---|
| `C-s` | `isearch-forward` | plain text, as you type; lowercase ignores case |
| `C-M-s` | `isearch-forward-regexp` | a regular expression |
| `M-s w` | `isearch-forward-word` | whole words |
| `M-s _` | `isearch-forward-symbol` | whole symbols (so `area` skips `areas`) |
| `M-s .` | `isearch-forward-symbol-at-point` | the symbol under the cursor |
| `M-s M-.` | `isearch-forward-thing-at-point` | the "thing" (word, symbol, URL) under the cursor |

Around them:

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `M-s o` | `occur` | list every matching line of this buffer, editable in place |
| `M-s h r` | `highlight-regexp` | highlight a pattern everywhere in the buffer, until you remove it |
| `M-s h l` | `highlight-lines-matching-regexp` | highlight whole lines that match |
| `M-s h .` | `highlight-symbol-at-point` | highlight the symbol under the cursor |
| `M-s h u` | `unhighlight-regexp` | remove a highlight |
| `M-g n` | `next-error` | next match in any results list |
| `M-g p` | `previous-error` | previous match |

By name only (**exists**): `re-builder` (type a pattern and watch it match live), `how-many`, `keep-lines`, `flush-lines`,
`list-matching-lines`, `multi-occur`, `multi-occur-in-matching-buffers` (several open files at once), `highlight-phrase`, `hi-lock-mode`.

### Find text in many files

| Command | Searches | Notes |
|---|---|---|
| `C-x p g` (`project-find-regexp`) | the project's files | ripgrep here; Emacs regexp syntax; smart case. **Tested** |
| `project-search` | the project's files, one match at a time | continue with `fileloop-continue`. **Exists** |
| `rgrep`, `lgrep` | a folder tree, or one folder | uses `grep`, so slower. **Exists** |
| `grep`, `grep-find`, `zrgrep` | any `grep`/`find` command line; `zrgrep` also looks inside compressed files | **Exists** |
| `vc-git-grep` | the files git tracks | **Exists** |
| `dired-do-find-regexp` (`A` in Dired) | the marked files | **Exists**; key checked |
| `tags-search`, `tags-query-replace`, `tags-apropos` | a project via a TAGS index | needs `visit-tags-table` or `etags-regen-mode` first; the older way, largely replaced by Eglot. **Exists** |
| `find-grep-dired` | files that contain a pattern, as a Dired listing | **Exists** |

### Find files

<!-- keymap: global -->
| Key | Command | Use it for |
|---|---|---|
| `C-x C-f` | `find-file` | a path you know (completes as you type) |
| `C-x p f` | `project-find-file` | a file of this project |
| `C-x p F` | `project-or-external-find-file` | project files plus outside ones |
| `C-x p D` | `project-dired` | Dired on the project root |
| `C-x p d` | `project-find-dir` | one of the project's folders |
| `C-x p b` | `project-switch-to-buffer` | an open buffer of this project |
| `C-x p C-b` | `project-list-buffers` | the list of this project's open buffers |
| `C-x p p` | `project-switch-project` | another project you used |
| `C-x p k` | `project-kill-buffers` | close all of this project's buffers |
| `C-x d` | `dired` | browse a folder |
| `C-x C-j` | `dired-jump` | Dired on the current file's folder |
| `C-x 4 f` | `find-file-other-window` | open a file in another window |
| `C-x 5 f` | `find-file-other-frame` | open a file in a new window (frame) |
| `C-x C-r` | `find-file-read-only` | open a file read-only (every file already is here) |
| `C-c r` | `recentf-open` | the last 25 files you opened |

By name: `find-name-dired`, `find-dired`, `find-lisp-find-dired` (a pure-Lisp version that needs no `find`), `find-file-at-point`
(`ffap`, for the file name under the cursor), `ido-find-file` (an older completion style). `locate` **exists as a command but
the `locate` program is not installed on this Linux machine**, so it does nothing here.

### Find a place you saved

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `C-x r m` | `bookmark-set` | save this place under a name (survives restarts) |
| `C-x r b` | `bookmark-jump` | jump to a saved place by name |
| `C-x r l` | `bookmark-bmenu-list` | list your bookmarks |
| `C-x r SPC` | `point-to-register` | remember this position in a one-letter register |
| `C-x r j` | `jump-to-register` | jump back to a register |
| `C-x r s` | `copy-to-register` | copy the region into a register |
| `C-x r i` | `insert-register` | paste a register |

Also **built in**: the **minibuffer history** remembers what you typed in every prompt (`savehist` is on, so it survives restarts).
In any prompt, `M-p` and `M-n` step through earlier entries and `M-r` searches them.

### Find code by meaning

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `M-.` | `xref-find-definitions` | go to the definition |
| `M-?` | `xref-find-references` | list every use |
| `C-M-.` | `xref-find-apropos` | find symbols by (part of) a name |
| `M-g i` | `imenu` | list the definitions in this file |

These need a **backend**: Eglot (a running language server), or a TAGS table. With neither, they say *"No Xref backend"*. The
manual is [EGLOT.md](EGLOT.md). Also built in: `which-function-mode` (shows the current function in the mode line), and the
tree-sitter functions (`treesit-*`) that power accurate highlighting and `imenu` for Java and Rust.

### Find help

<!-- keymap: global -->
| Key | Command | Finds |
|---|---|---|
| `C-h a` | `apropos-command` | commands whose **name** contains a word |
| `C-h d` | `apropos-documentation` | commands and variables whose **documentation** mentions a word |
| `C-h u` | `apropos-user-option` | settings you can change |
| `C-h o` | `describe-symbol` | everything about one symbol |
| `C-h f` | `describe-function` | a function |
| `C-h v` | `describe-variable` | a variable |
| `C-h k` | `describe-key` | what a key does |
| `C-h c` | `describe-key-briefly` | the same, in one line |
| `C-h w` | `where-is` | which key runs a command |
| `C-h x` | `describe-command` | a command |
| `C-h b` | `describe-bindings` | every key in this buffer |
| `C-h m` | `describe-mode` | the current mode |
| `C-h P` | `describe-package` | a package |
| `C-h p` | `finder-by-keyword` | built-in packages by topic |
| `C-h i` | `info` | the manuals |
| `C-h r` | `info-emacs-manual` | the Emacs manual |
| `C-h S` | `info-lookup-symbol` | a symbol in the manuals |
| `C-h F` | `Info-goto-emacs-command-node` | a command's page in the manual |
| `C-h K` | `Info-goto-emacs-key-command-node` | a key's page in the manual |
| `C-h l` | `view-lossage` | the last 300 keys you pressed |
| `C-h e` | `view-echo-area-messages` | messages that flashed by |
| `M-x` | `execute-extended-command` | any command by name |

By name: `apropos` (symbols), `apropos-variable`, `apropos-value`, `apropos-library`, `info-apropos` (search all manuals), `man` and
`woman` (Unix manual pages), `shortdoc` (short reference tables for groups of functions), `help-quick`.

### The web and dictionaries

`M-s M-w` is `eww-search-words` (a web search inside Emacs's own browser), and `M-x webjump`, `M-x eww`, `M-x dictionary`
exist. All **exist**; none tested. `M-s M-w` is easy to press by accident when you meant `M-s w`.

### How the candidate list itself finds things (completion)

When you type in `M-x`, `C-x C-f` and similar, matching is done by **completion styles**. Set here: `basic`, `partial-completion` and
`flex` (letters in order: `fndfl` finds `find-file`), ignoring case, shown as a **vertical list** (`fido-vertical-mode`).
Also built in and switched on: **inline completion preview** (a grey suggestion as you type in code) and **which-key** (press
`C-x`, wait, and it lists the keys that can follow). Also built in and available: `icomplete-mode` (the base of the vertical list) and `ido-mode` (an older style).

## 3. What we added

| Added | Key | Where it lives | Guide |
|---|---|---|---|
| **The fast finder**: fuzzy file names over an index of the project or the disk, live fallback | `C-c f f`, `C-c f g`, `C-c f r` | `config/fastfind.el` (our own code, no package) | [SEARCHING.md](SEARCHING.md), [NAVIGATING-CODE.md](NAVIGATING-CODE.md) |
| **The start screen**: last 5 files, folders, projects | `C-c h` | `config/startpage.el` (no package) | [START-SCREEN.md](START-SCREEN.md) |
| **ripgrep as the text-search engine** | `C-x p g` | `init.el` (`xref-search-program`); the program itself is `rg` | [SEARCHING.md](SEARCHING.md) |
| **Treemacs**: the project as a tree | `C-c t`, `C-c T` | package | [TREEMACS.md](TREEMACS.md) |
| **Magit**: git, with its log and status | `C-x g` | package | [MAGIT.md](MAGIT.md) |
| **Consult**: one search box, live preview (this buffer, project text, file names, buffers) | `C-c s l/g/f/b` | package (needs `rg`, `fd`) | [SEARCHING.md](SEARCHING.md#10-consult-one-search-box-for-several-of-the-above) |
| **Find every git repository on this computer**: an async disk scan, clickable results | `C-c f p` (`C-u` also scans Windows drives) | `config/gitfolders.el` + `tools/find-repos.sh` (our own code, no package; needs `fd`, falls back to `find`) | this page |
| **Eglot set up** for Java and Rust; right-click menu; Ctrl+Click | `M-x eglot` | `init.el` | [EGLOT.md](EGLOT.md) |
| **Evil**: vi keys, with vi's search (below) | `C-c v` | package, optional | [KEYBOARD.md](KEYBOARD.md) |
| **Tree-sitter grammars** for Java and Rust (accurate `imenu`, highlighting) | | `config/tree-sitter/` | [LANGUAGES.md](LANGUAGES.md) |
| **Windows only**: bundled ripgrep, Git, Java 21 and the Java language server | | `tools\` in the zip | [DISTRIBUTION.md](DISTRIBUTION.md) |
| **fd**: a fast file-name finder, the engine behind `consult-fd` | | Linux: downloaded (checksum verified) to `~/.local/bin/fd`, not from `apt` (no `sudo` here). Windows: bundled in the zip (`tools\fd`, checksum verified against GitHub's release API) | [below](#9-setting-up-rg-and-fd-again) |
| Vertical minibuffer list, loose matching, which-key, completion preview | | `init.el` | [CUSTOMIZING.md](CUSTOMIZING.md) |

Evil's search keys, checked in this build (only when Evil is toggled on with `C-c v`, in normal state):

<!-- keymap: evil-normal -->
| Key | Command | What it does |
|---|---|---|
| `/` | `evil-search-forward` | search forward |
| `?` | `evil-search-backward` | search backward |
| `n` | `evil-search-next` | next match |
| `N` | `evil-search-previous` | previous match |
| `*` | `evil-search-word-forward` | search for the word under the cursor |
| `#` | `evil-search-word-backward` | the same, backward |
| `g d` | `evil-goto-definition` | go to the definition |
| `:` | `evil-ex` | the command line: `:%s/old/new/g` replaces, `:g/pattern/` acts on matching lines |
<!-- keymap: global -->

## 4. What was pruned, and what that removes from search

To keep the install small, whole parts of Emacs were removed ([PRUNING.md](PRUNING.md)). Checked by loading them:

| Removed | Search features lost |
|---|---|
| **Org** (does not load) | Org's agenda and text search (`org-agenda`, `org-search-view`). Their commands still show in `M-x` but fail with "Cannot open load file" |
| **Rmail, MH-E** (do not load) | searching mail folders |
| **ERC** (does not load) | searching IRC logs |
| Gnus, CEDET (Semantic, EDE, SRecode) | **partly kept** (they still load, because other parts of Emacs need pieces of them); Gnus's mail and news searching is not something this setup uses |

Nothing on the list above is a way of searching *files or code*; those are all intact.

## 5. Everything available but not installed

You said **no packages you do not use**, so none of these is installed. This list was built from the live GNU ELPA, NonGNU ELPA and MELPA
archives on 2026-09-26: I looked up **128 well-known packages** for searching, jumping, completion, code navigation and help. **9 of them
are not in any of the three archives**; they are listed at the end. "What it does" is the archive's own one-line summary. "Versus what we have" is
my judgment against this setup; **I have not installed or tried any of these**. **In the tables, a version like 2026-06-29 means the archive
numbers releases by date (MELPA).**

### How the candidate list works (completion frameworks)

<!-- keymap: none -->
| Package | Archive, version | What it does (the archive's words) | Versus what we have |
|---|---|---|---|
| `helm` | nongnu 4.0.7 | Helm is an Emacs incremental and narrowing framework | All-in-one framework: replaces the completion list, `M-x`, buffer and file switching. Heaviest of the three families; pick one family |
| `helm-projectile` | melpa 2026-07-24 | Helm integration for Projectile | Needs helm and projectile |
| `helm-rg` | melpa 2020-07-21 | A helm interface to ripgrep | Needs helm |
| `helm-descbinds` | melpa 2025-07-05 | A convenient `describe-bindings' with `helm' | Needs helm |
| `ivy` | gnu 0.15.1 | Incremental Vertical completYon | The lighter all-in-one family; alternative to consult+vertico |
| `counsel` | gnu 0.15.1 | Various completion functions using Ivy | Ivy's search and file commands; needs ivy |
| `swiper` | gnu 0.15.1 | Isearch with an overview.  Oh, man! | Live in-buffer search list (like `consult-line`); needs ivy |
| `counsel-projectile` | melpa 2026-09-18 | Ivy integration for Projectile | Needs ivy and projectile |
| `ivy-rich` | melpa 2023-04-25 | More friendly display transformer for ivy | Needs ivy |
| `ivy-posframe` | gnu 0.6.4 | Using posframe to show Ivy | Needs ivy; popup placement |
| `selectrum` | melpa 2022-05-13 | Easily select item from list | Older vertical list, superseded by vertico; we already have a vertical list |
| `vertico` | gnu 2.15 | VERTical Interactive COmpletion | We already have a vertical list built in (`fido-vertical-mode`) |
| `orderless` | gnu 1.7 | Completion style for matching regexps in any order | We have `flex` (letters in order); this matches **words in any order** |
| `prescient` | melpa 2026-09-06 | Better sorting and filtering | Sorts candidates by how often you choose them; we do not do frequency sorting |
| `ivy-prescient` | melpa 2026-09-06 | Prescient.el + Ivy | Needs ivy and prescient |
| `hotfuzz` | melpa 2024-11-25 | Fuzzy completion style | A faster fuzzy matcher; we use built-in `flex` |
| `fussy` | melpa 2026-09-16 | Fuzzy completion style using `flx' and/or `fzf-native' | Fuzzy matching style; alternative to `flex` |
| `flx` | nongnu 0.6.3 | fuzzy matching with good sorting | Fuzzy scoring library |
| `ido-completing-read+` | melpa 2024-01-30 | A completing-read-function using ido | For the built-in Ido style, which we do not use |
| `ido-vertical-mode` | melpa 2026-04-20 | Makes ido-mode display vertically | For Ido, which we do not use |
| `smex` | melpa 2015-12-12 | M-x interface with Ido-style fuzzy matching | Old `M-x` history sorting; our `M-x` uses the vertical list |
| `amx` | melpa 2023-04-13 | Alternative M-x with extra features | `M-x` with recent-first ordering; a small nicety |
| `historian` | melpa 2020-02-03 | Persistently store selected minibuffer candidates | Remembers choices for sorting |
| `mct` | gnu 1.1.1 | Minibuffer Confines Transcended | Minibuffer completion tweaks; overlaps what is built in |
| `consult-dir` | melpa 2025-10-20 | Insert paths into the minibuffer prompt | **`consult` itself is installed** (`C-c s l/g/f/b`, section 3); this is an unused extra for it |
| `consult-projectile` | melpa 2023-08-21 | Consult integration for projectile | Needs consult and projectile |
| `consult-flycheck` | nongnu 1.2 | Provides the command `consult-flycheck' | Needs consult and flycheck (we use Flymake) |
| `consult-notes` | melpa 2026-07-31 | Manage notes with consult | Needs consult |
| `consult-eglot` | melpa 2026-06-13 | A consulting-read interface for eglot | Needs consult; searches a language server's symbols |
| `consult-lsp` | melpa 2026-06-19 | LSP-mode Consult integration | Needs consult and lsp-mode |
| `marginalia` | gnu 2.13 | Enrich existing commands with completion annotations | Adds annotations beside candidates (cosmetic) |
| `embark` | gnu 1.2 | Conveniently act on minibuffer completions | Act on a candidate: open elsewhere, copy, delete. Not present here |
| `embark-consult` | gnu 1.2 | Consult integration for Embark | Needs embark and consult |
| `which-key` | gnu 3.6.1 | Display available keybindings in popup | **Already built in and switched on** |
| `corfu` | gnu 2.16 | COmpletion in Region FUnction | A popup for code completion; we have the built-in inline preview |
| `cape` | gnu 2.9 | Completion At Point Extensions | Extra completion sources for corfu |
| `company` | gnu 1.1.0 | Modular text completion framework | The older popup for code completion |

### Text search and jumping

<!-- keymap: none -->
| Package | Archive, version | What it does (the archive's words) | Versus what we have |
|---|---|---|---|
| `ripgrep` | melpa 2022-05-20 | Front-end for ripgrep, a command line search tool | Old, plain command; `C-x p g` already uses ripgrep |
| `rg` | melpa 2026-08-23 | A search tool based on ripgrep | A full ripgrep front-end with saved searches and options; overlaps `C-x p g` |
| `deadgrep` | melpa 2026-06-29 | Fast, friendly searching with ripgrep | A friendly dedicated ripgrep results buffer; overlaps `C-x p g` with a nicer view |
| `ag` | melpa 2020-10-31 | A front-end for ag ('the silver searcher'), the C ack replacement | Silver searcher front-end; ripgrep replaced it |
| `ack` | gnu 1.11 | interface to ack-like tools | Old grep alternative |
| `pt` | melpa 2016-12-26 | A front-end for pt, The Platinum Searcher | Old grep alternative |
| `wgrep` | nongnu 3.0.0 | Writable grep buffer and apply the changes to files | **Not present here**: edit a search-results list directly and save the changes to every file |
| `wgrep-ag` | melpa 2023-02-02 | Writable ag buffer | Needs ag |
| `wgrep-helm` | melpa 2023-02-02 | Writable helm-grep-mode buffer | Needs helm |
| `visual-regexp` | melpa 2021-05-02 | A regexp/replace command for Emacs with interactive visual feedback | Preview a regexp replace as you type; overlaps `re-builder` + `M-%` |
| `visual-regexp-steroids` | melpa 2017-02-22 | Extends visual-regexp to support other regexp engines | Same, with more regexp flavours |
| `pcre2el` | nongnu 1.12 | regexp syntax converter | Convert between regexp syntaxes (Emacs, PCRE); helps when patterns differ from ripgrep |
| `anzu` | nongnu 0.66 | Show number of matches in mode-line while searching | "3 of 12" counter while searching; cosmetic |
| `isearch-mb` | gnu 0.8 | Control isearch from the minibuffer | Edit the search text like a normal prompt; overlaps `M-e` inside `C-s` |
| `ctrlf` | melpa 2026-02-21 | Emacs finally learns how to ctrl+F | A modern take on `C-s`; a matter of taste |
| `phi-search` | melpa 2025-06-11 | Another incremental search & replace, compatible with "multiple-cursors" | Only useful with multiple cursors |
| `avy` | gnu 0.5.0 | Jump to arbitrary positions in visible text and select text quickly. | **Already on disk** (a Treemacs helper) but not bound to a key: jump to any visible spot by typing 2 characters |
| `ace-jump-mode` | melpa 2014-06-16 | A quick cursor location minor mode for emacs | The old avy |
| `ace-link` | melpa 2024-11-01 | Quickly follow links | Jump to links in help and Info buffers; needs avy |
| `ace-window` | gnu 0.10.0 | Quickly switch windows. | **Already on disk** (Treemacs helper): jump to a window by letter |
| `link-hint` | melpa 2025-09-11 | Use avy to open, copy, etc. visible links | Follow any link on screen by a letter; uses avy |
| `jump-char` | melpa 2025-12-05 | Navigation by char | Jump to a character |
| `evil-easymotion` | melpa 2026-06-02 | A port of vim's easymotion to emacs | Avy-style jumping for Evil |
| `evil-snipe` | melpa 2025-05-05 | Emulate vim-sneak & vim-seek | 2-character search in Evil |
| `evil-visualstar` | nongnu 0.2.1 | Starts a * or # search from the visual selection | `*` on a selection in Evil |
| `evil-anzu` | nongnu 0.2 | anzu for evil-mode | Match counter in Evil |
| `casual` | nongnu 3.0.2 | Transient user interfaces for various modes | Menus (transient) for common Emacs tasks incl. isearch and dired |

### Files, projects and trees

<!-- keymap: none -->
| Package | Archive, version | What it does (the archive's words) | Versus what we have |
|---|---|---|---|
| `projectile` | nongnu 3.4.0 | Manage and navigate projects in Emacs easily | Project management with caching; overlaps `project.el` + the fast finder |
| `find-file-in-project` | melpa 2025-06-12 | Find file/directory and review Diff/Patch/Commit efficiently | Project file lists; overlaps the fast finder |
| `fzf` | melpa 2026-05-05 | A front-end for fzf | Front-end for the `fzf` program (not installed); overlaps the fast finder |
| `affe` | melpa 2026-05-19 | Asynchronous Fuzzy Finder for Emacs | Asynchronous fuzzy finder (needs consult); overlaps the fast finder |
| `fd-dired` | melpa 2026-01-04 | Find-dired alternative using fd | `find-dired` using `fd`; not needed with ripgrep |
| `recentf-ext` | melpa 2017-09-26 | Recentf extensions | Extras for the recent-files list |
| `dired-narrow` | melpa 2025-05-11 | Live-narrowing of search results for dired | Filter a Dired listing as you type; small and useful |
| `dired-subtree` | melpa 2024-06-29 | Insert subdirectories in a tree-like fashion | Expand folders inside Dired like a tree; overlaps Treemacs |
| `dirvish` | nongnu 2.3.0 | A modern file manager based on dired mode | A modern file manager on Dired; overlaps Dired and Treemacs |
| `dired-sidebar` | gnu 2.0.1 | Tree browser leveraging dired | A tree sidebar from Dired; alternative to Treemacs |
| `neotree` | melpa 2025-07-03 | A tree plugin like NerdTree for Vim | A tree sidebar like NERDTree; alternative to Treemacs |
| `treemacs` | melpa 2025-12-26 | A tree style file explorer package | **Installed** |
| `ranger` | melpa 2026-05-27 | Make dired more like ranger | A Ranger-style file manager in Dired |
| `diredfl` | melpa 2024-12-01 | Extra font lock rules for a more colourful dired | More colors in Dired (cosmetic) |
| `bufler` | melpa 2025-03-27 | Group buffers into workspaces with programmable rules | Groups and searches buffers by workspace |
| `perspective` | melpa 2026-07-17 | Switch between named "perspectives" of the editor | Named groups of buffers per project |
| `project-x` | melpa 2026-08-28 | Extra convenience features for project.el | Extras for `project.el` |
| `zoxide` | melpa 2024-10-03 | Find file by zoxide | Jump to frequently used folders (needs the `zoxide` program) |

### Code navigation

<!-- keymap: none -->
| Package | Archive, version | What it does (the archive's words) | Versus what we have |
|---|---|---|---|
| `lsp-mode` | melpa 2026-09-05 | LSP mode | A bigger language-server client than Eglot; **alternative to Eglot**, use one |
| `lsp-ui` | melpa 2026-05-12 | UI modules for lsp-mode | Peek and side-line UI for lsp-mode (not for Eglot) |
| `lsp-treemacs` | melpa 2026-05-15 | LSP treemacs | Tree views of symbols and references for lsp-mode |
| `lsp-java` | melpa 2026-05-10 | Java support for lsp-mode | Java support for lsp-mode; we use Eglot + jdtls |
| `dap-mode` | melpa 2026-06-16 | Debug Adapter Protocol mode | A debugger (DAP) client; **we have no debugger** |
| `eglot-java` | melpa 2025-05-27 | Java extension for the eglot LSP client | Java helpers for Eglot |
| `citre` | melpa 2026-05-30 | Superior code reading & auto-completion tool with pluggable backends | Code navigation from a **ctags** index; a way to find definitions without a language server |
| `ggtags` | gnu 0.9.0 | emacs frontend to GNU Global source code tagging system | GNU Global tags navigation |
| `xref-js2` | melpa 2024-05-04 | Jump to references/definitions using ag & js2-mode's AST | JavaScript references; not for our languages |
| `dumb-jump` | melpa 2026-06-03 | Jump to definition for 60+ languages without configuration | Go to definition for 60+ languages with **no server**, by pattern matching; fills the gap when `M-.` says "No Xref backend" |
| `smart-jump` | melpa 2021-03-04 | Smart go to definition | Tries several jump methods in turn |
| `imenu-list` | melpa 2021-04-20 | Show imenu entries in a separate buffer | The `imenu` outline in a side window; overlaps `M-g i` |
| `imenu-anywhere` | melpa 2021-02-01 | Ido/ivy/helm imenu across same mode/project/etc buffers | `imenu` across all open buffers of a project |
| `symbol-overlay` | nongnu 4.3 | Highlight symbols with keymap-enabled overlays | Highlight every use of a symbol with one key; overlaps `M-s h .` |
| `highlight-symbol` | melpa 2016-01-02 | Automatic and manual symbol highlighting | Old version of the same |
| `idle-highlight-mode` | nongnu 1.1.5 | Highlight the word the point is on | Highlight the symbol under the cursor automatically |
| `expreg` | gnu 1.4.1 | Simple expand region | Expand the selection by syntax (uses tree-sitter); selection, not search |

### Help and documentation

<!-- keymap: none -->
| Package | Archive, version | What it does (the archive's words) | Versus what we have |
|---|---|---|---|
| `helpful` | melpa 2025-04-08 | A better *help* buffer | Richer `C-h f`/`v`/`k` pages with source and callers |
| `elisp-demos` | melpa 2026-08-26 | Elisp API Demos | Examples inside help pages |
| `discover-my-major` | melpa 2018-06-06 | Discover key bindings and their meaning for the current Emacs major mode | Cheat sheet for the current mode |
| `devdocs` | gnu 0.7 | Emacs viewer for DevDocs | Browse DevDocs.io documentation inside Emacs |
| `dash-docs` | melpa 2021-08-30 | Offline documentation browser using Dash docsets | Offline docsets (Dash format) |
| `counsel-dash` | melpa 2022-12-17 | Browse dash docsets using Ivy | Needs ivy |
| `zeal-at-point` | melpa 2018-01-31 | Search the word at point with Zeal | Look up in the Zeal app |
| `eldoc-box` | melpa 2026-09-03 | Display documentation in childframe | Show ElDoc text in a popup box |
| `marginalia` | gnu 2.13 | Enrich existing commands with completion annotations | Adds annotations beside candidates (cosmetic) |
| `tldr` | melpa 2023-03-01 | Tldr client for Emacs | Short command-line examples |

### Git history and changes

<!-- keymap: none -->
| Package | Archive, version | What it does (the archive's words) | Versus what we have |
|---|---|---|---|
| `forge` | melpa 2026-09-26 | Access Git forges from Magit | GitHub/GitLab issues and pull requests inside Magit |
| `magit-todos` | melpa 2025-09-28 | Show source file TODOs in Magit | List TODO comments in a project inside Magit |
| `git-timemachine` | melpa 2025-01-28 | Walk through git revisions of a file | Step through a file's history commit by commit |
| `git-link` | melpa 2026-07-23 | Get the GitHub/Bitbucket/GitLab URL for a buffer location | Copy a link to the current line on GitHub |
| `consult-git-log-grep` | melpa 2025-03-17 | Consult integration for git log grep | Search commit messages through consult |
| `diff-hl` | gnu 1.11.2 | Highlight uncommitted changes using VC | Mark changed lines in the margin |
| `blamer` | melpa 2025-10-01 | Show git blame info about current line | Show who last changed the current line |
| `vc-msg` | melpa 2025-02-18 | Show commit information of current line | Show the commit message for the current line |

### Notes and documents

<!-- keymap: none -->
| Package | Archive, version | What it does (the archive's words) | Versus what we have |
|---|---|---|---|
| `deft` | melpa 2024-05-24 | Quickly browse, filter, and edit plain text notes | Search and browse a folder of plain-text notes |
| `denote` | gnu 4.2.3 | Simple notes with an efficient file-naming scheme | A notes system with simple file names (in GNU ELPA); its search leans on Org, which is pruned here |
| `consult-notes` | melpa 2026-07-31 | Manage notes with consult | Needs consult |

### Not found in GNU ELPA, NonGNU ELPA or MELPA

These names I looked up and the three archives do not list them (they may exist elsewhere, under another name, or have been
folded into another package): `bookmark-plus`, `combobulate`, `consult-flymake`, `dired-hacks`, `eglot-booster`, `helm-ag`, `helm-swoop`, `notdeft`, `recoll`.

### The three families, in one paragraph

Most of the completion packages above belong to one of **three families**, and you use **one** of them, not several:

| Family | Packages | Character |
|---|---|---|
| **Built in** (what you have) | `fido-vertical-mode`, `flex` matching, `completion-preview` | nothing to install; a vertical list with loose matching |
| **Consult stack** | `consult` (**installed**, section 3) + `vertico` + `orderless` + `marginalia` + `embark` | small, modular pieces that build on Emacs's own completion; the current favourite |
| **Ivy family** | `ivy` + `counsel` + `swiper` | one framework with its own commands; lighter than Helm |
| **Helm** | `helm` and its add-ons | the largest and oldest all-in-one framework |

## 6. The top 3, then, and now

**Update, 2026-09-27: `consult` was installed** (`C-c s l/g/f/b`, section 3), along with `fd`. What follows is the
original ranking from before that, kept so you can see the reasoning, plus what is left of it now.

This was my judgment for this setup, not a test result: I had tried none of them. The current set already covers
finding files, text and code on both platforms, so I ranked by **what it adds that you do not have**, not by
popularity.

| # | Package | Archive | What it gave that was lacking | Status |
|---|---|---|---|---|
| **1** | **`consult`** (best with `vertico` and `orderless`) | GNU ELPA, 3.10 | One search box for **lines in this file** (`consult-line`, with a live preview as you move through the matches), **text across the project** (`consult-ripgrep`), **files**, and **open or recent buffers**, with the list narrowing as you type | **Installed.** Not paired with `vertico`/`orderless`: it runs fine over the built-in vertical list (`fido-vertical-mode`), confirmed by 2 real-window tests and 14 offline ones (`tests/ert/consult.el`) |
| **2** | **`wgrep`** | NonGNU ELPA, 3.0.0 | **Edit the results** of a search and save the change to every file at once. This is the one capability that is still **missing**, not duplicated | Not installed. Still the natural next step if you want it |
| **3** | **`avy`** | GNU ELPA, 0.5.0 | Jump the cursor to **any visible text** by typing 2 characters and a letter | Still **on disk** (a Treemacs helper) but not bound to a key |

**What changed by installing `consult`:** `C-c s l/g/f/b` now exist (section 3, and [SEARCHING.md](SEARCHING.md#10-consult-one-search-box-for-several-of-the-above)).
They sit **beside** `C-s`, `C-x p g`, the fast finder and `C-x b`, not in place of them; nothing that worked before changed.
`consult-ripgrep` and `consult-fd` needed `rg` and `fd` on `PATH`: `rg` was already installed; `fd` was not (see
[section 9](#9-setting-up-rg-and-fd-again)).

**Still true:** `dumb-jump` (gives `M-.` for languages with no language server, which today says "No Xref backend") and
`deadgrep` (a nicer ripgrep results page) remain reasonable next additions if you want them; `orderless` would only
matter if the built-in vertical list's `flex` matching starts to feel limiting, and nothing so far suggests it does.

**What I still would not add:** a second completion family (`helm` or `ivy`) alongside `consult`, or a second ripgrep
front-end next to `consult-ripgrep`. They overlap almost entirely.

**To add one:** put its name in `my/packages` in `tools/install-packages.el` (MELPA is already listed as a source), run `./build.sh packages`,
add a key in `init.el` and a test, then run `./build.sh dist windows` so the Windows zip carries it. I can do that for any of the three; nothing is
added until you choose.

## 7. Is all of this documented?

| Way of searching | Where it is documented | How fully |
|---|---|---|
| The five incremental searches, `occur`, replace | [SEARCHING.md](SEARCHING.md) sections 3, 5 | full, with screenshots |
| Project text search, `rgrep`/`grep`, Dired search | SEARCHING.md section 4 | full |
| The fast finder | SEARCHING.md section 2, [NAVIGATING-CODE.md](NAVIGATING-CODE.md) | full |
| Recent files, start screen, tree, Dired, buffers, bookmarks | SEARCHING.md section 2, START-SCREEN.md, TREEMACS.md | full (registers and `find-lisp-find-dired`: **this page only**) |
| Code navigation and Eglot | SEARCHING.md section 6, [EGLOT.md](EGLOT.md) | full |
| Help and commands | SEARCHING.md section 7 | the main ones; the rest are **listed on this page only** |
| Regular expressions | SEARCHING.md section 8 | a summary and a live tool (`re-builder`) |
| Registers, tags, `hi-lock`, `zrgrep`, `multi-occur`, `webjump`, `dictionary` | **this page only** | listed, not explained |
| Evil's search | this page (section 3), KEYBOARD.md | keys only |
| Packages that are available | **this page only** | a table |
| Magit's own log and history search | [MAGIT.md](MAGIT.md) | the log screen; its search options are not exercised or documented |
| Consult (`C-c s l/g/f/b`) | SEARCHING.md section 10, this page (sections 1, 3, 6) | full, with screenshots and tests |

**Not documented anywhere yet, honestly:** Magit's commit-search options; how to use the built-in tags system; a tour of `info-apropos`
and `man`; and anything about packages I have not tried.

## 8. On Windows

Same built-in features. Differences: ripgrep, Git and Java come in the zip; `locate` is absent as on Linux; `find-name-dired` and
`grep`-based commands use the `find` and `grep` in the bundled Git; the whole-disk index covers the drive of your home folder.
See [DISTRIBUTION.md](DISTRIBUTION.md).

**`consult` and `fd` are now in the Windows bundle too** (added 2026-09-27, the same day as on Linux): the same four keys work
there with nothing to install, checked with a real window screenshot and 14 of 14 offline tests. See [DISTRIBUTION.md](DISTRIBUTION.md).

## 9. Setting up `rg` and `fd` again

Both are plain external programs Emacs calls; neither is an Emacs package. Reproducing this setup on a new Linux machine:

```sh
# ripgrep: usually already packaged
sudo apt-get install -y ripgrep      # gives /usr/bin/rg

# fd: Ubuntu's apt package is named fd-find and installs the binary as `fdfind`, and apt needs
# sudo either way, so here it was instead downloaded straight from the project's GitHub releases
# and checked against the SHA-256 GitHub itself publishes for the asset, with no root needed:
V=10.5.0
curl -fsSL -o /tmp/fd.tar.gz "https://github.com/sharkdp/fd/releases/download/v$V/fd-v$V-x86_64-unknown-linux-musl.tar.gz"
echo "761c72dc8e120d85b22292063be8a796e2eeb20eb3e4f38b8fa2343ccf3514a7  /tmp/fd.tar.gz" | sha256sum -c -
mkdir -p ~/.local/share/fd/$V && tar -xzf /tmp/fd.tar.gz -C ~/.local/share/fd/$V --strip-components=1
ln -sf ~/.local/share/fd/$V/fd ~/.local/bin/fd   # ~/.local/bin must be on PATH
```

This is the same pattern as `jdtls` in [LANGUAGES.md](LANGUAGES.md#setting-it-up-again-from-scratch): a checksummed release binary
into `~/.local/bin`, no `sudo`, nothing added to this repository (`fd` is a system tool, like `rg`; only the Emacs **packages** in
`config/elpa/` are something `./build.sh packages` reproduces from `tools/install-packages.el`).
