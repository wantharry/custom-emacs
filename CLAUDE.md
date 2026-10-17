# For an AI assistant starting a new conversation here

**Read [docs/CONVERSATION-LOG.md](docs/CONVERSATION-LOG.md) first.** It has what was
discussed, built, tried and reverted in prior conversations, and the real reasoning
behind each decision --- things `git log` alone doesn't show (dead ends, explicit
corrections from the user, standing workflow preferences). Update that file, in the
same style, after finishing new work, so the next conversation (regardless of which LLM)
has the same continuity.

See [README.md](README.md) for what this project actually is, and every other guide in
`docs/` (indexed in README's own "Documentation" table) for how a specific feature works.

## Standing rule, most likely to matter immediately

After finishing one feature: run only that feature's own test (`./build.sh test <name>`)
and commit. Do not run the full regression suite or rebuild the Windows dist zip after
every single feature --- batch that for after 3-4 features have accumulated. Full details,
including the pre-commit-hook exception for the known/expected stale-bundle diff, are in
[docs/CONVERSATION-LOG.md](docs/CONVERSATION-LOG.md).
