---
name: mise-setup
description: "Use when creating, changing, or reviewing mise project setup, task graphs, local task caching, package-manager dependency tracking, hk hooks, or monorepo workflows. Defines the preferred setup, build, check, fix, and test task contracts."
---

# mise project setup

Use mise for project tools, dependency installation, and task orchestration.
Use hk for quick checks and fixes. Keep the language's native build system;
do not create a second build system in shell scripts.

## Files and tools

Use `mise.toml`, `mise.lock`, and `hk.pkl` as the canonical filenames. Do not
create `.mise.toml`, `.tool-versions`, or alternate config paths. Read these
files, package manifests, package-manager settings, and CI workflows first.

Keep sections in `mise.toml` in alphabetical order by full table name. Sort
task tables and tool entries too. Put top-level scalar keys before tables.
Check examples and generated config for this order, not only TOML validity.

Enable `[settings] lockfile = true` and commit `mise.lock`. In monorepos,
also set `[monorepo] lockfile = true` for one root tool lockfile. Declare
`experimental = true` for features that require it. Set `min_version` to a
version that supports the features in use; do not rely on global settings.

Declare every required tool in `[tools]` or file-task tool metadata. Use
explicit versions, consistent with the lockfile and CI. Put shared tools at
the root and package-only tools or overrides in the owning package. Keep
application libraries in their package manifests, not in mise's tool list.

## Local environment

Load local environment files through mise's `[env]` configuration. The key
is `_.file`, not `_.env`. Use the files the project supports, usually `.env`
or `.env.local`. If both apply, load `.env.local` last so it overrides `.env`.
Keep local secrets out of version control.

When the project installs Node package binaries, add its `node_modules/.bin`
directory with `_.path`. Resolve paths from `config_root`, not the caller's
working directory. For a project that uses both environment files:

```toml
[env]
_.file = [".env", ".env.local"]
_.path = ["{{ config_root }}/node_modules/.bin"]
```

Put these settings at the owning workspace or package root. Do not add paths
for unrelated packages or load environment files manually in each task.

## Standard tasks

| Task | Contract |
| --- | --- |
| `setup` | Run `mise install`; use `mise install --monorepo` at a monorepo root. Do not call hk directly. |
| `build` | Build deliverables with declared generation and upstream build prerequisites. |
| `check` | Run `hk check --all` after required builds and generation. No unit tests. |
| `fix` | Run `hk fix --all`. Do not stage changes on a manual run. |
| `test` | Run unit tests, with required builds and generation as dependencies. Separate from `check` and hk. |

Prefer `generate`, `dev`, and `e2e` for code generation, development servers,
and end-to-end tests. Type checking belongs in hk; do not add a separate
`typecheck` task. Do not add successful no-op tasks for missing operations.
Keep interactive authentication separate from setup.

## Install hooks and dependencies

Install repository-local hk hooks from mise's `postinstall` hook. Skip it
when `CI` is set, including when the variable is set to an empty string.
Do not change global Git configuration. A single-project config includes:

```toml
[env]
HK_MISE = "1"

[hooks]
postinstall = 'if [ "${CI+x}" != x ]; then hk install --mise; fi'

[settings]
experimental = true
lockfile = true

[tasks.setup]
description = "Install project tools"
run = "mise install"
```

Use `mise install --monorepo` for root setup in a monorepo. Include
`--include-task-tools` when setup must preinstall tools declared only on tasks.
Keep hook installation out of build, check, fix, and test commands.

Use `[deps.<provider>]` with `auto = true` for the actual package manager.
`[tools]` installs the manager; `[deps]` installs project packages when their
tracked inputs change or required outputs disappear. Automatic providers run
before `mise run` and `mise exec`; shell activation alone does not install
packages. Do not add an install command to every task or directory-change hook.

```toml
[deps.pnpm]
auto = true
```

Prefer package-manager configuration files for install policy instead of
adding flags to mise commands. pnpm defaults `preferFrozenLockfile` to `true`;
do not repeat that default or add `--frozen-lockfile` to every install.
Preference for a frozen lockfile is not strict enforcement: it can update an
outdated lockfile outside CI. If strict enforcement is required, use the
manager's supported project setting, such as `frozenLockfile`, in its config.

Commit package lockfiles. Most built-in providers need a lockfile before they
become active. Use their defaults unless project inputs or output locations
require overrides. An override of `sources` or `outputs` replaces the defaults,
so preserve all required paths and include package-manager configuration.

For managers without a built-in provider, define explicit sources and a
command. `cargo` and `swiftpm` are custom provider names, not built-in presets.
For example:

```toml
[deps.cargo]
auto = true
run = "cargo fetch --locked"
sources = ["Cargo.toml", "Cargo.lock"]
```

Track local dependency manifests that affect resolution. Declare outputs only
when the project owns a stable path; do not invent one for a shared external
package cache. Use provider `depends` for provider ordering. Do not call
`mise run` from an automatic provider and cause recursive installation.

A workspace with one manifest/lockfile boundary uses one provider at that
boundary. Independent packages use their own providers. Automatic tracking
handles package installation separately from the install-only `setup` task.
Use `mise deps --monorepo` when an explicit all-package dependency install is
needed; do not add hk commands to setup.

## Task files

Keep short commands in `mise.toml`. Put file tasks in `scripts/`, not
`mise-tasks/` or `.mise/tasks/`. Configure discovery:

```toml
[task_config]
includes = ["scripts"]
```

Make file tasks executable and give them a shebang. Use `#MISE` metadata for
descriptions, task-specific tools, dependencies, sources, outputs, caching,
and environment settings. Use `#USAGE` for arguments, flags, defaults,
validation, and help. Read parsed `usage_*` variables instead of implementing
an argument parser. For example, `scripts/generate` can contain:

```bash
#!/usr/bin/env bash
#MISE description="Generate contract bindings"
#MISE tools={buf="1.71.0"}
#USAGE flag "--template <path>" help="Generation template" default="buf.gen.yaml"
set -euo pipefail
buf generate --template "${usage_template?}"
```

Select a tool version appropriate for the project. Add generation sources,
outputs, and cache metadata for its actual files. Do not duplicate script
metadata in a TOML wrapper or use shell parsing where mise supplies it.

## Task graph and local caching

Use `depends` for prerequisites, not nested `mise run` calls. Dependencies can
run in parallel; their list order does not specify execution order. If B needs
A, declare that edge on B. Use sequential `run` entries for ordered steps of
one operation. Use `wait_for` only for ordering tasks already selected.

A direct package `check` must work after checkout without a manual build or
generation step. Declare build links and generated-code prerequisites on each
consumer's task, not only on the root aggregate. A unit test that consumes
build output needs that edge on `test` too. Never make hk call `test`, and
never make `check` depend on `test` or `e2e`.

Cache reproducible builds, generators, and deterministic tests so required
prerequisites do not slow down unchanged checks:

- Declare narrow `sources`: code, manifests, lockfiles, tool configuration,
  schemas, and relevant upstream inputs. Do not scan `node_modules` or all
  of `target` when manifests and lockfiles express the dependencies.
- Declare real `outputs` for builds and generators. Missing outputs must
  cause restoration or a rebuild. Keep parallel tasks' outputs separate.
- Enable `cache = { enabled = true }` for eligible tasks. Use `outputs = []`
  for tasks that produce no files. Automatic freshness markers do not restore
  deleted artifacts and are not eligible for artifact caching.
- Enable `[settings] task.source_freshness_hash_contents = true` so freshness
  uses contents rather than timestamps.
- Use `[task_config.input_groups]` and `@group:<name>` to share input sets.
  Include transitive local dependency inputs and generated sources. Set
  `[task_config] cascade = true` when root groups must reach package tasks.
- Do not cache setup, fixes, deployments, watch tasks, or operations that
  depend on live services or other untracked state.

Mise automatically keys artifact caches on resolved tool versions, OS,
architecture, task definitions and arguments, task-level environment values,
visible mise variables, source contents, and cached dependency keys. Do not
add `node --version` or similar redundant `command_inputs`. List relevant
inherited or config-level environment variables in `cache.env`; mise does not
include all ambient environment values automatically.

Use `command_inputs` only for necessary external state not already captured,
such as an unmanaged compiler wrapper. These commands run on every cache-key
calculation, even on hits. Confirm the missing input before adding one.

## Monorepos

Discover apps and packages explicitly. Use wildcard task dependencies for root
aggregates, not lists that must change for every new package. Use supported
`...` path patterns; shell-style `*` is for `config_roots`, not task paths.
For example, these root sections are in alphabetical order:

```toml
monorepo_root = true

[monorepo]
config_roots = ["apps/*", "packages/*"]
lockfile = true

[monorepo.path_aliases]
api = "apps/api"
shared = "packages/shared"

[settings]
experimental = true
lockfile = true
task.source_freshness_hash_contents = true

[tasks.build]
depends = ["//...:build"]
description = "Build apps and packages"

[tasks.generate]
depends = [{ task = "//...:generate", optional = true }]
description = "Generate code across the repository"

[tasks.setup]
description = "Install all project tools"
run = "mise install --monorepo"

[tasks.test]
depends = [{ task = "//...:test", optional = true }]
description = "Run unit tests across the repository"
```

Add short, unique `[monorepo.path_aliases]` entries for apps and packages so
`mise run //api:check` works alongside `//apps/api:check`. Each alias names a
configured project, not an arbitrary directory. Do not use reserved aliases
that collide with the first segment of a configured project path.

Keep package task implementations and language tools in the package. Keep
shared tools and orchestration at the root. Use `:build` for the current
package and qualified paths or aliases for cross-package dependencies.
Where supported, `[monorepo.task_defaults.build] depends = ["^build"]` uses
the native workspace dependency graph. Keep explicit generation edges that
this graph does not express. Do not duplicate a native build system's graph.

Use `//...:<task>` for repository-wide aggregates, including deeply nested
projects, instead of separate patterns for apps and packages. Use optional
patterns where operations legitimately do not exist; do not hide a missing
required prerequisite. Apply platform conditions for
host-specific packages without silently dropping supported checks.

## hk and CI

Use standard hk built-in rules. Put tool options in the tool's own config,
not custom hk command strings. For example, configure oxlint type-aware
checking in its supported configuration file instead of overriding its hk
command with `--type-aware`. Verify the tool version supports the setting.
Do not create a separate mise typecheck command.

Set root hk `subprojects = List("apps/*", "packages/*")`. Keep common rules
at the root and language-specific rules in package `hk.pkl` files. Exclude
generated files and build output. Match hk's Pkl schema and built-in package
versions to the installed hk tool.

Have one `check` task run `hk check --all`, composing package rules through
hk. Do not also run every child's hk check from the same root invocation.
Root `check` must depend on the cached builds and generators required by
those checks. Use wildcard prerequisites for repository-wide preparation;
keep precise consumer edges in package tasks. For a repository where all
checks need built packages, root configuration can use:

```toml
[tasks.check]
depends = ["build", "generate"]
description = "Run quick checks across the repository"
run = "hk check --all"

[tasks.fix]
description = "Apply lint and format fixes"
run = "hk fix --all"
```

Use narrower prerequisite patterns if only some packages need build output.
Do not rely on root `generate` to order generation before consumers: consumer
build tasks still need their own generation edges.

hk runs quick type, lint, and format checks only. Never run unit tests from
hk, including commit hooks. Use staged file selection for commit hooks and
`--all` for a complete manual or CI check. Preserve unstaged work when hooks
apply fixes; use hk staging controls instead of shell `git add` commands.

CI installs declared tools and calls the same `mise run check` and
`mise run test` commands as local development, separately. Run `e2e` when
required. Do not duplicate checks in workflow YAML. With `CI` set, the
postinstall hook must not install Git hooks.

## Audit and verification

After changing project setup:

1. Inspect `mise tasks --all`, `mise tasks deps`, and `mise tasks graph`.
   Check ordering, wildcard coverage, alias resolution, and absence of cycles.
2. Run top-level `mise run check` without manual generation or builds first.
   Run an affected package check directly too. Confirm automatic dependency
   installation and all build/generation prerequisites work.
3. Run `mise run test` separately. Confirm neither hk nor `check` runs it.
4. Verify a first cached run, an unchanged run, a changed source, and a deleted
   output. Confirm restoration or rebuilding, and that failures are not cached.
5. Verify setup installs hk locally, skips it when `CI` is set, and does not
   modify global Git settings. Check alphabetical sections and canonical files.

References:

- [mise task caching](https://mise.jdx.dev/tasks/caching.html)
- [mise project dependencies](https://mise.jdx.dev/dev-tools/deps.html)
- [mise file tasks](https://mise.jdx.dev/tasks/file-tasks.html)
- [mise monorepo tasks and aliases](https://mise.jdx.dev/tasks/monorepo.html)
- [hk configuration](https://hk.jdx.dev/configuration.html)
