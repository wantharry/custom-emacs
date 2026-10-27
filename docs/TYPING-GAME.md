# Typing game: characters, then real Emacs keybindings

User request, explicit: "can you make a typing game in emacs with alphabets in one session, numbers
and alphabets, special characters numbers and alphabets and emacs keys special characters numbers and
alphabets in separate session."

`C-c X` starts it. Prompts for a level, then drills you one item at a time --- type what it shows, as
fast and accurately as you can --- and reports your results at the end.

## The four levels

Each level is a superset of the one before, matching the request's own cumulative shape:

1. **Alphabet only** --- lowercase `a`-`z`
2. **Alphabet + numbers** --- adds `0`-`9`
3. **Alphabet + numbers + special characters** --- adds `! @ # $ % ^ & * ( ) - _ = + [ ] { } ; : , . < > / ?`
4. **All of the above, plus real Emacs keybindings** --- the same character set as level 3, with real
   Emacs chords (`C-f`, `M-x`, `C-x C-f`, ...) shuffled in among them

Level 4's keybindings are not a freshly invented list --- they are reused directly from
[TYPING.md](TYPING.md)'s own existing four-week plan, so practicing here reinforces the same
curriculum that guide already teaches, rather than a second, possibly inconsistent one.

## A chord is never actually run

In level 4, when it is your turn to type a chord like `C-x C-f`, pressing those keys is only ever
**compared** against what was expected --- the real command (`find-file` in that example) never
actually executes. This is deliberate, not an accident: it means a level-4 round can never save a
file, kill a buffer, close a window, or quit Emacs by accident, however it is answered, including a
wrong answer.

## What you see

```
Typing Game --- Level 2

Progress: 7/20   Correct: 6   Errors: 1   Time: 4s

Type: 9
```

Characters show as themselves; a chord shows as both its keys and the command it runs, e.g. `Type: C-x
C-f  (find-file)`. At the end:

```
Done in 11.3s.
Characters: 18/20 correct (90% accuracy), 38.9 WPM
Emacs keys: 9/10 correct (90% accuracy)

q to quit, any other key to play again.
```

Levels 1-3 report only the character line (WPM = `(correct characters / 5) / minutes`, the standard
typing-test convention). Level 4 reports characters and chords **separately** --- a single blended
number across two very different kinds of input (letters vs. multi-key chords) would not mean
anything real.

## Customizing a session

- `my/typing-game-length` (default 20) --- how many characters a level 1-3 session drills, or how many
  character items level 4 mixes in
- `my/typing-game-chord-count` (default 10) --- how many Emacs chords a level 4 session adds
