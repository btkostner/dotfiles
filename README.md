# bootstrap

My machine setup, declared in one file. This is the successor to my `dotfiles`
repo, which was managed with Chezmoi; everything now runs through
[mise bootstrap](https://mise.jdx.dev/bootstrap.html).

Built for macOS. Linux is a second-class but real target: packages carry `os`
filters and pick up apt equivalents, and CI runs the whole thing on both.
See [Linux](#linux) for what still does not work there.

## Layout

| Path | What it is |
| --- | --- |
| [`mise.toml`](mise.toml) | The whole declaration: packages, directories, removals, repos, the LaunchAgent, and the dotfile mapping |
| [`dotfiles/`](dotfiles) | The actual config files, laid out to mirror where they land in `$HOME` |
| [`hk.pkl`](hk.pkl) | Lint and format steps, and which git hooks run them |
| [`scripts/`](scripts) | The two bootstrap hooks, as shell rather than TOML so they get linted |

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

**Most dotfiles are symlinks.** Editing `~/.config/starship.toml` edits the
file in this repo, and `git diff` is the source of truth for what has drifted.

**Nushell is `symlink-each`,** so each file is linked individually and nushell
can keep writing history and plugin state into `~/.config/nushell` without any
of it landing here.

**Some files are rendered instead,** because they either branch on the OS or
bake in an absolute path. Those are the `.tmpl` sources, listed one by one
under `[dotfiles]`:

| Rendered | Why |
| --- | --- |
| `ssh/config` | 1Password's agent socket is somewhere else on Linux |
| `projects/hiivemarkets/gitconfig` | so is `op-ssh-sign` |
| `config/nushell/env.nu` | Homebrew paths, the Zed and Postgres.app aliases, and the Erlang build flags are all macOS-only |
| `config/nushell/scripts/{mise,starship,gh-npm}.nu` | each calls a binary by absolute path |
| `config/zed/settings.json` | pulls a token out of 1Password |

**Rendered files are copies, not links.** Editing the deployed file does not
edit this repo — edit the `.tmpl` and re-apply, or use `mise dot edit`.

Templates get `exec()` and `env`, but no `os` variable, so the branch comes
from `uname`:

```text
{%- set uname = exec(command="uname -s") | trim -%}
{% if uname == "Darwin" %}...{% else %}...{% endif %}
```

Binaries resolve the same way, once, at apply time:

```text
{%- set mise_bin = exec(command="command -v mise || echo mise") | trim -%}
```

The absolute path is baked into the rendered file, so the prompt never pays
for a `PATH` lookup — which is the reason these paths were hardcoded in the
first place. The `|| echo` fallback covers the case where the binary is not
installed yet, and a later re-apply upgrades it to the real path. It also
means the Homebrew prefix no longer has to be guessed: this already corrected
`mise.nu`, which was pointing at `/opt/homebrew/bin/mise` on a machine where
mise actually lives in `~/.local/bin`.

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

## Linux

`mise bootstrap` applies cleanly on Ubuntu — files, directories, repos and
dotfiles all land, and the LaunchAgent is skipped with a note. CI asserts
that on every push.

Ubuntu's own repositories cover `curl`, `gnupg`, `zoxide` and
`fonts-firacode` — the last standing in for the Nerd Font, which nobody
packages, and costing nothing because the starship config uses text symbols
rather than glyphs.

Everything else needs a repository added first, which is what
[`scripts/linux-repos.sh`](scripts/linux-repos.sh) does from
`[bootstrap.hooks.pre-packages]`:

| Package | Repository |
| --- | --- |
| `nushell` | `apt.fury.io/nushell` |
| `gh` | `cli.github.com` — universe has 2.45, this has 2.100 |
| `1password-cli` | `downloads.1password.com`, plus the debsig policy dpkg demands |

The script installs its own `curl` and `gnupg` first, since those are declared
in `[bootstrap.packages]` and so do not exist yet on the first run, and it
needs sudo. Re-running adds nothing: a repository with both its keyring and
its list file present is skipped.

Starship is the one thing not installed from a package. It reached apt in
Debian 13 but Ubuntu does not carry it, and a missing apt package is a hard
error in `[bootstrap.packages]` — so the same script installs it from
`starship.rs`, preferring apt where apt has it.

The macOS-specific dotfiles are templates now, so a Linux box gets the
1Password socket at `~/.1password/agent.sock`, `op-ssh-sign` out of
`/opt/1Password`, and an `env.nu` with no Homebrew, Zed.app or Postgres.app in
it. CI greps for exactly that on both runners.

One asymmetry worth knowing: the XDG base directories come from the setXDG
LaunchAgent on macOS, and nothing plays that role on Linux — so `env.nu` fills
in the spec defaults when they are unset. On macOS the LaunchAgent still wins.

Installing nushell has a side effect worth knowing about: its postinst seeds
stub `config.nu` and `env.nu` files in `~/.config/nushell`, exactly where the
dotfiles phase wants to write, and the run stops dead on them.
[`scripts/clear-nushell-stubs.sh`](scripts/clear-nushell-stubs.sh) clears them
from `[bootstrap.hooks.pre-dotfiles]`. It matches on the `# Installed by:`
header nushell generates, so it will never delete a file this repo put there.

One ordering note: starship installs during the packages phase, which is
before dotfiles, so `starship.nu` gets the real `/usr/local/bin/starship`
baked in on the very first run.

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
hk check --all     # everything, what CI runs on both OSes
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

**mise manages languages, not machine software.** The global config carries
only `fnox`, `node` and `npm`; the shell, the prompt and the CLI tools all
come from Homebrew or apt through `[bootstrap.packages]`. The `[tools]` in
this repo's own `mise.toml` are a separate thing — hk's linters, dependencies
of this repo rather than of the machine, and not packaged for apt anyway.

**`editorconfig-checker` is pinned to 3.4.0 and invoked as `ec`.** The 4.x aqua
package has no working darwin asset, and the binary has never been named after
the project.

**`pinact` calls the GitHub API** to map a SHA back to its version comment,
and unauthenticated that is 60 requests an hour. It only matches files under
`.github/workflows/`, so it stays quiet until one of them changes — but export
`GITHUB_TOKEN` (`export GITHUB_TOKEN=$(gh auth token)`) before `hk check --all`
if you hit the limit. CI passes one in already.

**`mise fmt` and `taplo` both format TOML,** so `taplo-format` excludes
mise's own files and lets `mise fmt` own them.

**Three tool configs exist only to stop a builtin from being wrong:**
[`.yamllint`](.yamllint) (workflows have no `---`, and `on:` is a key not a
boolean), [`.rumdl.toml`](.rumdl.toml) (code fences may run long), and
[`.yamlfmt`](.yamlfmt) (keep the blank lines). The repo's own
[`.editorconfig`](.editorconfig) exempts markdown list indentation and the
tab-indented ssh config.
