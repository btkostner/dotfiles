# bootstrap

My machine setup, declared in one file. This is the successor to my `dotfiles`
repo, which was managed with Chezmoi; everything now runs through
[mise bootstrap](https://mise.jdx.dev/bootstrap.html).

Built for macOS, but the pieces that are not macOS-specific carry an `os`
filter so it can grow a Linux path later.

## Layout

| Path | What it is |
| --- | --- |
| [`mise.toml`](mise.toml) | The whole declaration: packages, directories, removals, repos, the LaunchAgent, and the dotfile mapping |
| [`dotfiles/`](dotfiles) | The actual config files, laid out to mirror where they land in `$HOME` |

`dotfiles/` is not magic. There is no name mangling and no `dot_` prefix —
every file is listed explicitly in the `[dotfiles]` table of `mise.toml`, and
the directory is just somewhere tidy to keep the sources.

## Applying

Hello future me (and onlookers). On a new computer (congrats on the new
hardware):

1. Install [Homebrew](https://brew.sh/), which the `brew:` and `brew-cask:`
   packages need.
2. Install mise: `curl https://mise.run | sh`
3. Run it:

```bash
mise bootstrap --from git@github.com:btkostner/bootstrap.git
```

That clones this repo to `$MISE_DATA_DIR/bootstrap-repo` and applies it. To
work from a checkout you already have instead:

```bash
mise trust && mise trust dotfiles/config/mise/config.toml && mise bootstrap
```

The second `trust` is for the global mise config this repo links into
`~/.config/mise/config.toml`; without it mise warns on every run.

## Looking before you leap

```bash
mise bootstrap plan        # resource-by-resource diff of declared vs. actual
mise bootstrap status      # same thing, aggregated
mise bootstrap --dry-run   # print every command the full run would execute
```

One caveat on `--dry-run`: the `[tasks.bootstrap]` task runs for real on every
invocation, dry or not. Here that task is `mise install`, which is idempotent,
so it is harmless — but add `--skip task` if you want a genuinely inert run.

## What runs, in order

`mise bootstrap` walks its phases in a fixed order, which is what makes the
declarations above safe to write in any order:

1. **Packages** — Homebrew formulae and casks. First, so `op` exists before
   anything asks 1Password for a secret.
2. **Files and directories** — creates `~/.ssh` (0700) and the work projects
   directory, and deletes the bash/zsh leftovers.
3. **Repos** — clones AstroNvim into `~/.config/nvim`.
4. **Dotfiles** — symlinks (and renders) everything in `dotfiles/`.
5. **LaunchAgents** — installs the XDG agent.
6. **Tools** — installs `[tools]` from every loaded mise config.
7. **`[tasks.bootstrap]`** — a final `mise install`.

## Notes on the pieces

**Dotfiles are symlinks.** Editing `~/.config/starship.toml` edits the file in
this repo. `git diff` is the source of truth for what has drifted.

**Except nushell,** which is `symlink-each`: each file is linked individually
so nushell can keep writing history and plugin state into `~/.config/nushell`
without any of it landing in this repo.

**Except Zed,** which is rendered from a template because it embeds a GitHub
token from 1Password. The Tera expression shells out to `op`:

```
{{ exec(command="op item get <id> --fields credential --reveal 2>/dev/null || true") | trim }}
```

The `|| true` matters. When `op` is missing or the vault is locked the token
renders empty instead of failing the whole bootstrap run, which is the one
thing the Chezmoi version could not do.

**The LaunchAgent gets renamed.** mise namespaces every agent it writes, so
what was `io.btkostner.setXDG` is now `dev.mise.setXDG`.

**Fonts come from Homebrew** (`brew-cask:font-fira-code-nerd-font`) rather
than unzipping a GitHub release into `~/Library/Fonts`.

**AstroNvim tracks its default branch.** The Chezmoi external pinned the
latest release tag and refreshed weekly; `[bootstrap.repos]` has no
equivalent, so it follows the branch. Pin it with `ref = "v5.0.0"` if that
matters.

## Migrating off Chezmoi

On a machine that Chezmoi already set up, the real files in `$HOME` are in the
way of the symlinks. mise refuses to clobber them:

```
mise ERROR files: refusing to overwrite existing files (use --force)
```

Check what the run wants to do, then let it:

```bash
mise bootstrap --dry-run
mise bootstrap --force-dotfiles
```

Also worth doing once:

- `brew uninstall chezmoi`
- `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/io.btkostner.setXDG.plist`
  and delete that plist — the mise-managed `dev.mise.setXDG` replaces it.

## Day to day

```bash
mise bootstrap packages use brew:ripgrep      # add a package and install it
mise bootstrap packages status                # what is declared vs. installed
mise bootstrap packages prune                 # find packages no longer declared
mise bootstrap repos status
```

To add a dotfile, drop it in `dotfiles/` and add a line to `[dotfiles]`.
