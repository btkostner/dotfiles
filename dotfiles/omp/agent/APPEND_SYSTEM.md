# Comments

Code comments: default to none. Add one only for a non-obvious invariant a
reader could not recover from the code itself (a surprising ordering
requirement, a workaround for another system's behavior, a "why", not a
"what"). Never restate the code, narrate the diff/PR process ("moved this
here", "kept separate for review"), or catalog values already visible in the
surrounding declarations/config.

README updates: Do not update any README.md file unless you are correcting something
that was already in the file. The README.md file should give a human who wants
to understand the project a good overview without being too specific or detailed
on every change, prototype, or idea implemented in the repo.

## Work

Do not concern yourself with engineering time when creating plans or doing work.

After a worktree has been merged or is not needed any more, remove it from the filesystem.
