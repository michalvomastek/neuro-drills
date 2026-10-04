# Neuro drills – notes for Claude

Godot 4.7 project: a collection of short cognitive-training mini games ("drills").
Plan, architecture, roadmap and open decisions live in `docs/PLAN.md`. Read it first and keep it current.

## Working with the maintainer

- The maintainer writes in Czech. Reply in Czech. Code, identifiers, comments, commit messages and this file are in English.
- UI strings: Czech and English, keys in `assets/translations/ui.csv`, Czech is the default locale. Every user-facing text goes through a key (scene `text` properties auto-translate; code uses `tr()`).
- Work on the assigned `claude/*` branch. Do not open pull requests unless asked.
- Commit messages carry no attribution trailers: no `Co-Authored-By`, no `Claude-Session` lines (maintainer's request, 2026-10-03).
- Headless Godot cannot judge UX. Render changed scenes with `tools/godot.sh screenshot` and look at the PNG before claiming a UI change works; the maintainer does the final check in the editor.

## Engine and environments

- Godot 4.7-stable (`4.7.stable.official`), GDScript only, renderer GL Compatibility (web and mobile friendly). Do not change the renderer, `config/features` or the warning levels in `project.godot` without asking.
- Maintainer's machine (Windows): this repository, the Godot editor and a clone of godot-docs are sibling folders under `C:\Agile Fitness Coach App\`: `..\godot\` holds the editor binary, `..\godot-docs\` the manual sources.
- Cloud sessions: no Godot binary, no display, and godotengine.org / docs.godotengine.org are blocked, while GitHub release downloads work. `tools/godot.sh` downloads 4.7-stable into `~/.cache/neuro-drills/` on first use. Xvfb and Mesa (llvmpipe) are available, so software rendering works.

## tools/godot.sh

| command | what it does |
|---|---|
| `version` | resolve the binary (`$GODOT_BIN`, then `../godot/`, then cached download) and print the version |
| `import` | headless import; catches broken scenes and resources |
| `check [files]` | import, then load every `.gd` file (or the given ones) inside a running project via `tools/check_scripts.gd`; parse, analyzer and compile errors fail it, including warnings configured as errors and unknown autoload names (`--check-only` cannot see autoloads, so it is not used) |
| `test` | run `tests/run_tests.gd` headless: every `tests/test_*.gd` extending `TestCase`, methods prefixed `test_` |
| `docs` | dump the engine class reference XML to `~/.cache/neuro-drills/apidocs/`; grep it instead of guessing an API |
| `smoke` | start every registered drill with the countdown on under Xvfb and verify it is running (`tools/smoke_drills.gd`); catches start-up regressions the logic tests cannot |
| `screenshot <scene> <out.png> [WxH] [frames]` | render a scene with software OpenGL (Xvfb when there is no display) and save a PNG; `SCREENSHOT_LOCALE=cs` picks the language |
| `templates` | download and install the 4.7 export templates (about 1 GB, GitHub release) |
| `export <preset> [out]` | release export with a preset from `export_presets.cfg` (`Web`, `Windows Desktop`); output defaults to the preset's `export_path` under `build/` (ignored by git) |
| `exec [args]` | pass arbitrary arguments to the binary |

Run `import`, `check`, `test` and `smoke` before every commit. `check` is also the fastest way to find out whether an API or a member exists in 4.7.

## Architecture in one paragraph

`ui/app/app.tscn` is the main scene; it attaches itself to the `SceneRouter` autoload, which swaps one screen at a time (menu, drill, results). `DrillRegistry` (autoload) lists `DrillDefinition`s. A drill scene extends `Drill` (`core/drill.gd`), receives `setup(definition, config, autostart)` after entering the tree and reports through `finished(result)` / `aborted`. `DrillResult` carries time, errors, config, `summary_rows` for the shared `ResultsScreen` and standardised `metrics` (String -> float) that `core/benchmarks.gd` turns into an indicative level (beginner / advanced / elite, see `docs/BENCHMARKS.md`); every `build_result` must fill `metrics`. `StatsStore` (autoload) appends each result as one JSON line to `user://results.jsonl` through `StatsHistory` (`core/stats_history.gd`, pure logic: trend vs the last 10 runs of the same variant, personal best, overview per variant) and `MetricCatalog` (`core/metric_catalog.gd`: primary metric and direction per drill, variant key from the config, variability and fatigue index from the per-trial times). The results screen shows the trend, record, variability, fatigue and an optional RPE row (1-10); `ui/progress/` is the progress screen with a `Sparkline`. Schulte: `schulte_logic.gd` (rules, testable), `schulte_config.gd` (settings <-> Dictionary), `schulte_table.gd` (scene). Trial-based drills (reaction time, choice reaction, Go/No-Go, Stroop, Flanker) extend `TrialDrill` (`core/trial_drill.gd`), which builds the setup panel, play frame, countdown and cancellable `_wait()`; each has a `*_logic.gd` class and a three-line `.tscn`. `ReactionStats` summarises reaction times. The results screen shows only `summary_rows`, so every drill adds its own rows. Theme: `ui/theme/dark_theme.tres` with type variations `PrimaryButton`, `DimLabel`, `SchulteCell`, `Pad` (colours `go`, `correct`, `wrong`, `wrong_dim`).

## Code conventions (GDScript)

- Static typing everywhere: variables, parameters, return types, typed arrays. `project.godot` turns untyped declarations, unsafe method/property access, unsafe call arguments and unused variables into errors, so `check` enforces this. Use `:=` for inference and `as` for downcasts. Dictionary values are `Variant`: assign them to a typed variable first (`var n: int = dict["n"]`), do not pass them straight into `int()`/`bool()` or typed parameters.
- A button in `ACTION_MODE_BUTTON_PRESS` receives both the touch event and the mouse event emulated from it and fires `pressed` twice per tap (release mode dedupes). Create press-triggered buttons with `Drill.make_press_button()`, which swallows the touch events; never set the action mode directly.
- Mouse motion events do not reliably reach `_unhandled_input` under Controls; read the pointer per frame instead (`get_local_mouse_position()`), parking it with `Input.warp_mouse()` when relative movement is needed (compensatory tracking).
- A script started with `-s` (test runner, tools) is compiled before autoloads exist, so it must reach them through `root.get_node("SceneRouter")` and `call()`; ordinary scene scripts use the autoload names directly.
- A logic method that advances state must do so even on a wrong answer; a test looping `while not is_done()` hangs forever otherwise (seen once when a dependency failed to load). Run tests with a timeout when in doubt.
- Every drill that extends `TrialDrill` must clear its own flags, timers and highlights in `_reset_play_state()`; it runs on Back, on Start, on completion and once from `_ready()` before `_on_setup()`, so it must only touch nodes built in `_build_play_area()` or null-check them. `_wait()` only checks the run token, never `_running` (the countdown waits before `_running` is set).
- The test runner cannot detect runtime errors inside a test (GDScript has no exceptions); read the `SCRIPT ERROR` lines in the test output, and keep `check` green first.
- Naming: files and folders `snake_case`; classes `PascalCase`, with `class_name` only for shared types; constants `UPPER_SNAKE_CASE`; private members prefixed with `_`; signals in past tense (`drill_finished`).
- One folder per drill under `drills/<drill_id>/`: scene, scene script, a pure-logic class (RefCounted, no Node access, takes a `RandomNumberGenerator` or a seed) and its tests. Scene code only translates input into logic calls and renders state.
- UI: Control nodes and containers only; no hard-coded pixel positions or sizes; shared theme; mouse and touch both work.
- Timing: `Time.get_ticks_msec()` / `Time.get_ticks_usec()` for measurements, never accumulated `delta`.
- Autoloads only for app-wide state (see PLAN.md); anything a scene can own, it owns.
- Persisted numbers go through JSON, which has no NaN: store a missing number as `null` (`StatsHistory._or_null`) and read it back with `StatsHistory.number()`. Ints come back as floats, so compare config values through `MetricCatalog._value_text()` or typed variables, never with `==` against an int literal after a round trip.
- `.tscn` and `.tres` files are text: keep diffs minimal, never reformat, let the editor own UIDs. `.godot/` stays untracked.
- Commit messages: `type(scope): summary`, e.g. `feat(schulte): add grid generation`; types feat, fix, refactor, test, docs, chore.

## Decision log

- 2026-10-03: project created in Godot 4.7 (GL Compatibility). Plan, conventions, headless tooling and strict GDScript warnings added.
- 2026-10-03: maintainer accepted all defaults from PLAN.md chapter 7 except the theme, which is dark. Phase 1 delivered: app shell (menu, drill, results), Schulte table v1, CZ/EN localization, test runner, CI.
- 2026-10-03: maintainer asked for all listed drills. Batch 1 (reaction family on `TrialDrill`) delivered; menu became a scrollable two-column grid.
- 2026-10-04: export presets (`export_presets.cfg`: Web single-threaded so GitHub Pages works without COOP/COEP headers, Windows x86_64 with embedded pck) and `.github/workflows/release.yml` (push to main: Pages deploy; tag `v*`: release with both zips). Pages must be switched to "GitHub Actions" once in the repository settings.
- 2026-10-04: phase 2 (progress) delivered: `StatsStore` + `StatsHistory` + `MetricCatalog`, trend / record / variability / fatigue rows and optional RPE on the results screen, progress screen with sparkline (`MENU_PROGRESS`). Variant key = drill id + non-cosmetic config keys, switched-off flags left out.
- 2026-10-04: menu tabs per category; Trail Making order modes; Gorbov hover fix; `DrillResult.metrics` + `Benchmarks` level bands on the results screen (`docs/BENCHMARKS.md`, `docs/DRILLS.md`).
- 2026-10-03: batches 4g (3D: time to contact, Brock string, 3D rotation via `Scene3D`; optic flow with device tilt) and 4h (dual task, divided attention, peripheral pattern, peripheral reading) delivered: 43 drills, 9 categories. The smoke test covers them all.
- 2026-10-03: Schulte variants (letters, reverse, reshuffle, red-black, five-table test) and batches 4d-4f from the maintainer's neurotraining document delivered: 35 drills in 7 categories (`DrillDefinition.category_key`, menu headers). Shared: `Staircase`, `TrackingStats`, side labels, keypad. Shaders (`.gdshader`) for fog, Gabor patch, stripes and optic flow. 3D drills use `Scene3D` (SubViewport with own world); GL Compatibility has no depth of field. 3D, sensor and audio drills deliberately skipped (PLAN.md 5c).
- 2026-10-03: batch 3 (Trail Making, visual search, SART, task switching, RSVP reading, number pyramid, flashing number, arithmetic sprint) delivered. Keypad and key mapping live in TrialDrill; RSVP passages are translation keys listed in `RsvpLogic.PASSAGES`. 19 drills in total.
- 2026-10-03: batch 2 (memory family: N-back, Corsi, digit span, memory matrix, Simon) delivered. Span drills hide the trial-count row via `_uses_trial_count()` and share `SpanTracker`. Theme type `Board` holds cell/lit/selected colours.
