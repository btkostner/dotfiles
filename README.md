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
| [`hk.pkl`](hk.pkl) | Lint and format steps, and which git hooks run them |

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

```text
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

```text
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

## Linting

[hk](https://hk.jdx.dev) runs the checks, and every step in
[`hk.pkl`](hk.pkl) is one of its [builtins](https://hk.jdx.dev/builtins.html).

```bash
hk check --all     # everything, what CI runs
hk fix --all       # everything, and rewrite what can be rewritten
hk check           # just what changed
hk check --plan    # which steps would run against which files
```

Hooks are installed by `mise run bootstrap`, or on their own with `hk install`.
On git 2.54+ that writes `hook.hk-*.command` entries into `.git/config` and
leaves `.git/hooks/` alone.

| Hook | What it does |
| --- | --- |
| `pre-commit` | Runs the fixers, stages what they changed |
| `pre-push` | Check-only, plus `lychee` on the links in this file |
| `commit-msg` | `check_conventional_commit` |

`HK=0 git commit` skips them.

hk recommends `hk install --global` instead, which turns hooks on for every
repo on the machine and no-ops wherever there is no `hk.pkl`. That writes to
`~/.gitconfig` — a file this repo tracks — so the setting would end up in
`dotfiles/gitconfig` and follow you to the next machine. Repo-local is the
default here only because it keeps the blast radius to this repo.

### Things worth knowing

**Linters are `[tools]`, not `[bootstrap.packages]`.** They are dependencies of
this repo, not of the machine, so they install into the repo's mise
environment.

**`editorconfig-checker` is pinned to 3.4.0 and invoked as `ec`.** The 4.x aqua
package has no working darwin asset, and the binary has never been named after
the project.

**`mise fmt` and `taplo` both format TOML,** so `taplo-format` excludes
mise's own files and lets `mise fmt` own them.

**Three tool configs exist only to stop a builtin from being wrong:**
[`.yamllint`](.yamllint) (workflows have no `---`, and `on:` is a key not a
boolean), [`.rumdl.toml`](.rumdl.toml) (code fences may run long), and
[`.yamlfmt`](.yamlfmt) (keep the blank lines). The repo's own
[`.editorconfig`](.editorconfig) exempts markdown list indentation and the
tab-indented ssh config.
