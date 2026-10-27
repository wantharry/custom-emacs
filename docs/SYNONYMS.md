# Synonym suggestions while writing prose

User request, explicit: "when I start typing it should suggest me words like synonyms so that I can
pick the best possible word ... useful for emails or letters or novel writing" --- then two direct
follow-up corrections: "it shouldnt be a keybound it should be automatically shows up as i type," and
then "a writing buffer is not same as untitiled buffer, i want writing buffer to show up only when i
press some command and not on all the buffers."

Bound to `C-c B`, not the more obvious `C-c N`: this feature is also merged onto the `lsp-java`/`main`
branches, where `C-c N` is already a real, different, earlier feature (`my/new-empty-buffer`, a
Notepad++-style blank buffer every press) --- `B` avoids colliding with it.

| Key | Command | What it does |
|---|---|---|
| `C-c B` | `my/writing` | open a new, PLAIN `untitled` buffer --- no suggestions yet |
| `C-c S` | `my/synonyms-mode` | turn suggestions ON in the buffer you are in --- renames an `untitled` buffer to `writing` as visual confirmation; toggles OFF again on a second press |
| `F7` (once suggestions are on) | `my/synonyms-lookup` | look up synonyms for the word at point RIGHT NOW, without waiting for the automatic pause-trigger |

## How it actually works

`C-c B` only ever opens a plain, inert `untitled` buffer --- nothing special happens in it yet, same as
opening any new document. Suggestions only turn on, in THAT buffer or any other, once you explicitly ask
for them with `C-c S` --- and the moment they do, an `untitled` buffer renames itself to `writing`, a
clear visual sign suggestions are now live in it. A buffer that was already something else (a real email
draft, an existing `.org` chapter) keeps its own real name when `C-c S` turns suggestions on in it ---
only a still-`untitled` buffer gets renamed.

Once suggestions are on, they pop up **automatically** a short moment after you pause while typing a
word --- no key needed. Finish typing a word, pause briefly, and a popup of synonyms for it appears; pick
one (arrow keys + `RET`, or type to filter) and it replaces the word you typed.

`F7` looks up the word at point immediately, without waiting for that pause --- useful if you want a
synonym for a word you typed a while ago, without re-touching it. `C-M-i` (plain `completion-at-point`)
does the exact same immediate lookup, but **on Windows, `Ctrl+Alt` pressed together is very often
intercepted by Windows itself as `AltGr`** (used for typing accented/special characters) before the
keystroke ever reaches Emacs at all --- a real, confirmed case: pressing what should have been `C-M-i`
instead reached Emacs as plain `TAB` (confirmed via `C-h k`, which showed `indent-for-tab-command`, the
stock Tab binding, running). `F7` exists specifically so this feature does not depend on that
combination working.

## Why this is a real, scoped exception in this config

This config has an established, deliberate preference AGAINST automatic completion popups --- `corfu-
auto` (the global setting controlling this for CODE completion) is `nil`, turned off after a real
complaint that it popped up after nearly every keystroke. `my/synonyms-mode` does not change that global
setting at all; it turns Corfu's auto-popup on **buffer-locally**, only in buffers where this mode is
explicitly on, by direct, later, explicit user request for this feature specifically. Code completion
elsewhere stays exactly as before.

A real implementation detail, confirmed the hard way while building this: simply setting the `corfu-
auto` variable to `t` in a buffer does **not** by itself turn auto-popup on. `corfu-mode` (already
active everywhere via `global-corfu-mode`) only wires up its real auto-trigger hook once, at the moment
it itself turns on for a buffer --- which already happened, with `corfu-auto` still `nil`, before
`my/synonyms-mode` ever runs. `my/synonyms-mode` adds that hook by hand instead.

## A real bug this caught, and how it is avoided

Synonyms do not share a common prefix with each other (or with the word you looked them up from) the
way normal code-completion candidates do. `completion-in-region`'s usual first step --- auto-inserting
whatever prefix is common to every matching candidate --- collapses to an EMPTY string when candidates
share nothing, and a naive implementation lets that empty string silently REPLACE the whole word just
looked up, deleting it before a single suggestion is ever shown. This was a real, confirmed bug hit
while testing `F7` for the first time. Fixed by making that specific step return the word unchanged
instead of a collapsed prefix, so nothing is ever auto-replaced before you actually pick a candidate.

## Why caching matters now

Since suggestions can trigger more than once while you are still typing one word (each pause after a
new letter is a fresh, slightly longer attempt at the same real word), already-looked-up words are
cached for the rest of the session --- typing "h", pausing, then continuing to "ha", "hap", "happ",
"happy" does not cost a separate network request for each pause on the same growing word once a given
exact spelling has already been looked up once.

## Why an online API, not a bundled dictionary

Candidates come from the [Datamuse API](https://www.datamuse.com/api/) --- free, no API key, one small
JSON request per lookup. This needed only Emacs's own built-in `url`/`json`, no new package
(`./build.sh packages` does not need to install anything for this feature at all).

The alternative --- a bundled offline word list, the approach older Emacs thesaurus packages take (Moby
Thesaurus II, a ~10 MB flat file with no real ongoing maintenance) --- was a real option, not
overlooked, but a deliberate tradeoff against it: it would need its own install/bundling step on every
platform this project already ships for real, Windows included (the dist zip is built and tested on a
real Windows machine, repeatedly), for a feature that does not need to work with no network at all the
way, say, local LLM chat or local dictation does here. If this ever needs to work fully offline, that
remains a real, addable option later --- this is a deliberate first choice, not a permanent one.

## What happens with no network, or an obscure word

Looking up a word simply reports no completions --- never an error. A failed lookup (no network, the
API is down, or a word genuinely has no listed synonyms) is treated the same as "nothing to suggest,"
cached the same as a successful one so a genuinely obscure word is not retried on every pause, the same
"never let a failed lookup break what you were doing" reasoning this config's other cached/networked
features (`my/disk-usage`'s own cache file, for one) already use.
