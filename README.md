# dotfiles

My machine setup, declared in one file. This repo used to be a Chezmoi source
tree; everything now runs through
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
| [`scripts/`](scripts) | The bootstrap hooks, as shell rather than TOML so they get linted |
| [`fnox.toml`](fnox.toml) | Where a declared secret would come from — references only, no values, none declared today |

`dotfiles/` is not magic. There is no name mangling and no `dot_` prefix —
every file is listed explicitly in the `[dotfiles]` table of `mise.toml`, and
the directory is just somewhere tidy to keep the sources. It is a directory
inside this repo, not the repo itself.

## Applying

Hello future me (and onlookers). On a new computer (congrats on the new
hardware):

1. Install [Homebrew](https://brew.sh/), which the `brew:` and `brew-cask:`
   packages need.
2. Install mise — from [mise.run](https://mise.run), **not** from Homebrew:

   ```bash
   curl https://mise.run | sh
   ```

3. Run it:

```bash
mise bootstrap --from git@github.com:btkostner/dotfiles.git
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

1. **Packages** — Homebrew formulae and casks. First, so the binaries the
   templates bake in by absolute path exist before they are rendered.
2. **Files and directories** — creates `~/.ssh` (0700) and the work projects
   directory, and deletes the bash/zsh leftovers.
3. **Repos** — clones AstroNvim into `~/.config/nvim`.
4. **Dotfiles** — clears nushell's stub configs and installs omp, then
   symlinks (and renders) everything in `dotfiles/`.
5. **macOS defaults** — Dock, keyboard and trackpad preferences, then
   `killall Dock` so they take effect.
6. **LaunchAgents** — installs the XDG agent.
7. **User** — `chsh` to nushell.
8. **Tools** — installs `[tools]` from every loaded mise config.
9. **`[tasks.bootstrap]`** — `mise install` and `hk install`.

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

**Rendered files are copies, not links.** Editing the deployed file does not
edit this repo — edit the `.tmpl` and re-apply, or use `mise dot edit`.

**Ghostty is installed on macOS** from Homebrew's `ghostty` cask. The cask
repackages Ghostty's official signed and notarized `.dmg`; Linux intentionally
does not install it because the Ghostty project only distributes prebuilt
binaries for macOS.

## Secrets

None are declared right now. The Zed GitHub PAT was the only one, and the MCP
server that needed it is gone — so nothing under `dotfiles/` asks 1Password
for a value while rendering, and a plain `mise bootstrap` needs no fnox
wrapper. 1Password is still a package here; it is the *agent* that `ssh/config`
and the work `gitconfig` point at, which is a path, not a secret.

The wiring stays for the next one. [`mise.toml`](mise.toml) declares *what* a
template needs; [`fnox.toml`](fnox.toml) says *where* it comes from. Neither
holds a value, so both are safe to commit:

```toml
# mise.toml
[bootstrap.secrets]
some_token = { env = "SOME_TOKEN", allow_empty = true }

# fnox.toml
SOME_TOKEN = { provider = "onepassword", value = "op://...", default = "", if_missing = "warn" }
```

Run bootstrap through fnox so the values are in the environment:

```bash
fnox exec -- mise bootstrap
```

An interactive nushell already has them — `scripts/fnox.nu` activates fnox
per-directory — so a plain `mise bootstrap` works there too.

### Why the empty defaults

`allow_empty` and fnox's `default = ""` are two halves of one bargain, and it
is worth being precise about what each covers, because the failure modes are
not the same:

| State | Result |
| --- | --- |
| fnox resolves the secret | real value rendered |
| fnox runs, 1Password unreachable or `op` missing | fnox warns, substitutes `""`, **bootstrap completes** |
| bootstrap run without fnox at all | hard error, nothing rendered |

The middle row is the point: a machine with no 1Password still gets a
complete, valid file — just without the value in it. mise refuses to leave a
file half-rendered, so without `allow_empty` that row would be a failed run.

The last row is a genuine gap on a brand-new machine, because fnox installs
during the tools phase, which is *after* dotfiles. For that one first run,
either set the variable empty (`SOME_TOKEN= mise bootstrap`) or use
`mise bootstrap --prompt-secrets`, which asks for the value. Every run after
that picks fnox up automatically.

`mise bootstrap secrets status` lists what is declared and whether it
resolves, without printing any of it.

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

**Tapped Homebrew casks are not declared here,** and the reason is worth
recording. mise resolves cask metadata from formulae.brew.sh, which only knows
homebrew-core, so a tapped cask falls back to evaluating the tap's
`Casks/*.rb` — which needs Ruby 3, while macOS still ships 2.6:

```text
mise ERROR evaluating the tap definition for entire requires Ruby 3 or newer
```

That is not a warning. It fails `mise bootstrap plan` outright, so a single
tapped cask takes the whole preview down. `entire` and `docker-desktop` are
therefore installed but unmanaged. Declaring one would mean putting a Ruby 3
on `PATH` purely so mise can read a `.rb` file.

**mise is not in `[bootstrap.packages]`.** It installs itself from
[mise.run](https://mise.run) and stays outside every package manager, which is the whole
point: Homebrew's build has self-update compiled out, so a brew-installed mise
answers `mise self-update` with *"self-update is disabled for this install"*.
Keeping it unmanaged is what lets `auto_update = true` in the global config do
anything. The check is throttled by `auto_update_check_duration`, default 7d.

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

### Moving mise off Homebrew

Worth checking before anything else, because a brew-installed mise cannot
update itself:

```bash
brew list mise
```

If it is there, `~/.local/bin/mise` is most likely a symlink pointing into the
Cellar rather than a real binary. Replace both:

```bash
rm -f ~/.local/bin/mise
brew uninstall mise
curl https://mise.run | sh
mise --version
```

`mise bootstrap packages prune` will also flag the brew install now that it is
no longer declared.

Do this first, not last. `mise.toml` sets `min_version = "2026.9.8"`, which is
the release that understands `auto_update` — so an older mise refuses to run
anything in this repo and says so. That is deliberate: on 2026.8.8 the setting
is an unknown field, and mise warns about it on every single prompt.

### Other one-time cleanup

Also worth doing once:

- `brew uninstall chezmoi`
- `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/io.btkostner.setXDG.plist`
  and delete that plist — the mise-managed `dev.mise.setXDG` replaces it.

## macOS preferences

Read off this machine rather than invented. Apart from the Dock tile list,
every value here is one that actually differs from Apple's default — the rest
is left alone deliberately, so this file stays a record of decisions rather
than a wall of settings.

| Section | What it covers |
| --- | --- |
| `[bootstrap.macos.dock]` | autohide, no recents, and the eleven pinned tiles in order |
| `[bootstrap.macos.keyboard]` | autocapitalise on, autocorrect off |
| `[bootstrap.macos.trackpad]` | tap-to-click off, three-finger drag off |
| `[bootstrap.macos.defaults]` | dark mode, which has no curated section |

The curated sections compile down to `defaults write`; the raw
`[bootstrap.macos.defaults]` table is the escape hatch for anything they do
not cover. `mise bootstrap macos defaults apply --dry-run` prints the exact
commands.

Because the Dock tile list is managed, rearranging it by hand now counts as
drift and gets reverted on the next apply. Drop `apps` if that becomes
annoying — the rest of the section works without it.

## Login shell

`[bootstrap.user]` runs `chsh`, and mise appends the shell to `/etc/shells`
first, so no separate registration is needed.

What it does need is one absolute path that is right on every machine, and
nushell has none — Homebrew installs to `/opt/homebrew/bin`, apt to
`/usr/bin`, and `login_shell` neither templates nor filters by OS. So
[`scripts/register-shell.sh`](scripts/register-shell.sh) keeps
`/usr/local/bin/nu` pointed at whichever install is real, and the config names
that. Terminals launch `nu` directly regardless; this is what fixes ssh
sessions and anything that shells out to `$SHELL`.

## AI harness

[omp](https://omp.sh) (oh-my-pi) is the coding agent everything here drives AI
work through, in the terminal and in the editor both. It is installed from
upstream's script rather than from a package manager, because it updates
itself — the same argument that keeps mise off Homebrew:

```bash
curl -fsSL https://omp.sh/install | sh -s -- --binary
```

[`scripts/install-omp.sh`](scripts/install-omp.sh) runs that from
`[bootstrap.hooks.pre-dotfiles]`, ahead of the Zed settings that name the
binary. `--binary` rather than the default, which builds from source through
bun when bun happens to be on PATH: nothing here installs bun, and pinning the
mode keeps the binary in one known place.

The binary lands in `~/.local/bin`, which is on PATH and writable, so
`omp update` can replace it without sudo. `/usr/local/bin/omp` is symlinked at
it — the same arrangement as `/usr/local/bin/nu`, and for the same reason. One
absolute path that is right on every machine, and one that an app launched
from the Dock can actually find, since launchd hands it a PATH with neither
`~/.local/bin` nor `/opt/homebrew/bin` in it. The symlink is the only part
that needs sudo.

### Zed

Zed drives omp over [ACP](https://agentclientprotocol.com), so the models, the
subscriptions, the tools and the rules are all omp's. The `agent` block in
`settings.json` is not dead config, but it only covers Zed's own agent and the
inline assistant:

```json
"agent_servers": {
  "omp": {
    "type": "custom",
    "command": "/usr/local/bin/omp",
    "args": ["acp"],
    "env": {}
  }
}
```

Zed has no setting that picks a default agent — the panel reopens whichever
one was used last, and falls back to its own on a fresh project. So
[`dotfiles/config/zed/keymap.json`](dotfiles/config/zed/keymap.json) binds the
agent panel's new-thread key to omp instead. `cmd-alt-shift-n` still opens the
menu with every other agent in it.

### Subscriptions

omp keeps its own credential store at `~/.omp/agent/agent.db`, and does not
read Claude Code's or Codex's. Both logins are OAuth flows answered in a
browser, which is why they are a task rather than part of the bootstrap run:

```bash
mise run omp-login   # anthropic, then openai-codex
omp usage            # which accounts are signed in, and what is left of them
```

`/login anthropic` and `/login openai-codex` inside a session do the same
thing. The first omp thread in Zed offers *Use existing local credentials*,
which is this store — there is no second login to do there.

## History

A watcher service checkpoints tracked files into a local git history, so an
accidental edit can be diffed or rolled back. It is a LaunchAgent on macOS and
a systemd user service on Linux, neither needing root:

```toml
# dotfiles/config/mise/config.toml
[bootstrap.services.mise-history]
builtin = "history-watch"
```

```bash
mise dot status              # what is tracked, and whether the watcher runs
mise dot paths               # the exact file list
mise dot save -d "message"   # checkpoint now
mise dot history             # list checkpoints
mise dot history diff 11 12 --patch --path ~/.config/gh/config.yml
mise dot rollback ~/.config/gh/config.yml --dry-run
```

### Why this lives in the global config

Both the service and the tracked entries are declared in the *global* mise
config rather than this repo's `mise.toml`, because mise rejects the latter:

```text
[dotfiles]."~/.trackme": tracking is enrolled from the global configuration
only (ignored: project config), ignoring entry
```

Since `~/.config/mise/config.toml` is itself a dotfile this repo deploys, the
declaration still lives in version control — it just has to arrive by that
route. One consequence: on a first run the services phase happens *before* the
global config exists, so `[tasks.bootstrap]` re-runs `mise bootstrap services
apply` at the end.

### What is tracked, and what cannot be

An entry is either deployed or tracked, never both — so nothing this repo
symlinks or renders appears here. That costs nothing: those files already live
in this repo's git history. What gets tracked is the config *around* them.

| Tracked | Why |
| --- | --- |
| `gh/config.yml` | small, hand-edited, nothing else backs it up |
| `git/ignore` | same |
| `.omp/agent/config.yml` | the harness settings, tuned by hand through omp itself |

Each names a file rather than the directory around it, which is what
`388f4d1` tightened: a directory entry sweeps up whatever lands beside it
later, and the sibling is usually the credential store.

Deliberately excluded, and worth keeping excluded:

| Left out | Reason |
| --- | --- |
| `github-copilot` | `auth.db` is an OAuth token store |
| `1Password`, `op` | credentials and session state |
| `raycast`, `raycast-x` | ~450 MB of binary state, not config |
| `gh/hosts.yml` | the GitHub auth token — out of reach now that only `config.yml` is named |
| `**/node_modules/**` | `opencode`'s alone was 57 MB, 3,400 files |
| `.omp/agent/agent.db` | the OAuth store both subscriptions log in to |
| `.omp/agent/{models,history}.db`, `sessions` | megabytes of churn, rewritten every session |

History commits are plaintext, which is why the credential paths are excluded
rather than merely untidy, and why the origin is a private repo. `mise dot
paths` prints the resolved list — worth a look after adding anything, since it
counts files per entry and makes an over-broad glob obvious. Adding more is
one line each, or `mise dot track ~/.config/whatever`.

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
