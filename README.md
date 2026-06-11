# local76

> **Command, control, and compute on your own terms.**

A monorepo of local-first terminal utilities. Built for the user who wants the host machine back: no telemetry, no cloud accounts, no third-party service. Every tool runs against the kernel directly. The repos in this workspace are siblings under [`github.com/local76`](https://github.com/local76); each one is its own self-contained crate with its own release cadence.

## Fleet

| Repo | Role | One-line description |
|---|---|---|
| [`library`](https://github.com/local76/library) | shared design system | `Screensaver` trait, `ScreenPalette`, UI widgets, 10 effect implementations consolidated here. Every other crate depends on this. |
| [`toolkit`](https://github.com/local76/toolkit) | devops | Build orchestrator + release tag scripts. |
| [`screensaver-beams`](https://github.com/local76/screensaver-beams) | screensaver shim | 1-line binary: `library::screensaver_shim!(beams, Beams, "beams");` |
| [`screensaver-bounce`](https://github.com/local76/screensaver-bounce) | screensaver shim | Same pattern, for `bounce` |
| [`screensaver-bursts`](https://github.com/local76/screensaver-bursts) | screensaver shim | Same pattern, for `bursts` |
| [`screensaver-chaos`](https://github.com/local76/screensaver-chaos) | screensaver shim | Same pattern, for `chaos` |
| [`screensaver-cosmos`](https://github.com/local76/screensaver-cosmos) | screensaver shim | Same pattern, for `cosmos` |
| [`screensaver-disco`](https://github.com/local76/screensaver-disco) | screensaver shim | Same pattern, for `disco` |
| [`screensaver-flame`](https://github.com/local76/screensaver-flame) | screensaver shim | Same pattern, for `flame` |
| [`screensaver-glyphs`](https://github.com/local76/screensaver-glyphs) | screensaver shim | Same pattern, for `glyphs` |
| [`screensaver-gnats`](https://github.com/local76/screensaver-gnats) | screensaver shim | Same pattern, for `gnats` |
| [`screensaver-storm`](https://github.com/local76/screensaver-storm) | screensaver shim | Same pattern, for `storm` |
| [`app-helm`](https://github.com/local76/app-helm) | system info | `helm` is the UI dashboard, `--no-live` is the fastfetch-style one-shot, `helm doctor` is diagnostics. |
| [`app-pulse`](https://github.com/local76/app-pulse) | live monitor | Real-time CPU/GPU/mem/disk/network panel with multi-pane UI. |
| [`app-scout`](https://github.com/local76/app-scout) | wifi | SSID list, signal bars, connect/disconnect. |
| [`app-trance`](https://github.com/local76/app-trance) | screensaver host | Lists installed `.scr` files, picker UI, launches the active one. |
| [`app-ignite`](https://github.com/local76/app-ignite) | startup daemon | Lists autostart apps, doctor for log paths, registry verification. |
| [`local76`](https://github.com/local76/local76) | meta-repo | This file's long-form companion — diagram, cross-cutting conventions, roadmap. |

## How they fit together (4.2)

```
                    local76
                      |
       +--------------+--------------+--------------+
       |              |              |              |
   library       toolkit    10x screensaver-*   meta
   (5-folder     (PowerShell  (1-line shim      (docs,
   flat tree:    scripts,      binaries,        handoff)
   core/ui/      build.ps1)    one per scene)
   toolkit/
   apps/
   screensavers)
       |
       |  every consumer has a `library` dep (path
       |  for dev, git tag for release) via
       |  `[patch."https://github.com/local76/library.git"]`
       |
  +----+----+----+----+----+
  |    |    |    |    |    |
  helm pulse scout trance ignite (5 UI apps)
```

The 10 `screensaver-*` repos are sibling repos on GitHub, not a
workspace member. In library 4.0 they were a single 10-member
`screensavers` workspace; the 2026.6.9 rename split them out so each
scene's binary is a self-contained crate.

Every consumer (5 UI apps + 10 `screensaver-*`) depends on `library`
via a `[patch."https://github.com/local76/library.git"]` redirect
that points at the local `../library/` directory during development.
CI/release builds substitute a real git tag. See
[`local76/local76`](https://github.com/local76/local76) for the full
architecture, cross-cutting conventions, and roadmap.

## Local development

```pwsh
# 1. Build library first (so the [patch] resolves)
cd library; cargo build --release; cd ..

# 2. Build everything else
#    Each screensaver-*:
cd screensaver-beams; cargo build --release; cd ..
cd screensaver-bounce; cargo build --release; cd ..
# ... etc for all 10
#    Each UI app:
cd app-helm; cargo build --release; cd ..

# 3. Or use the orchestrator
pwsh ./toolkit/scripts/build.ps1
```

## Releasing

```pwsh
# Tag + push one repo
pwsh ./toolkit/scripts/release.ps1 -App helm -Version 2026.7.0

# Tag + push all repos
pwsh ./toolkit/scripts/push_all.ps1
```

Every repo is built and released from this local machine. No GitHub
Actions. Every binary is uploaded via `gh release`. Versions are CalVer
(`YYYY.MM.DD`); library at `v2026.6.9` (with unreleased 4.2 commits),
the 10 `screensaver-*` at `v2026.7.0`, the 5 UI apps at `v2026.6.9`,
toolkit at `0.1.0`. Old SemVer tags (`v3.1.3`, `v2.6.9`, `v4.2.1`) remain
in history as immutable anchors.

## Conventions

- **No telemetry, no cloud, no accounts.** Every tool reads the local
  kernel and writes to local files. That's it.
- **PowerShell only.** The toolkit scripts are `.ps1` (PowerShell Core).
  They run on Windows and Linux. No bash, no Python.
- **Commit `Cargo.lock` for app crates** (the 5 UI apps and 10
  `screensaver-*`), so the reproducible-builds story is locked in. The
  library crate keeps its `Cargo.lock` gitignored (it's a library, the
  cargo convention says don't commit the lockfile for libraries).
- **One binary per repo where possible.** The 5 UI apps each compile
  to a single `opt-level = "z"` + LTO + strip + `panic = "abort"` binary
  (~250-500 KB). The 10 `screensaver-*` shim binaries do the same.
- **Embedded icons.** Every Windows binary embeds its brand `.ico` via
  `embed-resource 2.x` in a 14-line `build.rs` that calls
  `library::core::build_resources::write_brand_rc` + `embed_resource::compile`.
  The Windows SDK ICONDIR-corruption bug is worked around via
  `split_for_rc` (4 single-size ICOs in the .rc). The previous
  `winres 0.1` pipeline (in 4.0/4.1) produced broken multi-size ICOs on
  `rc.exe 10.0+`.
- **Per-app config in `%APPDATA%\local76\app\<app_name>\config.yaml` on
  Windows and `~/.config/local76/app/<app_name>/config.yaml` on Linux.**
  (Note the `local76/app/<app_name>/` nesting — the post-rename
  realignment in 2026.6.9.) Set by `library::apps::window::*` helpers.

## License

MIT.
