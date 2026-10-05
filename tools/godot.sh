#!/usr/bin/env bash
# Headless Godot helper for the Neuro drills project.
#
# Usage: tools/godot.sh <command> [args...]
#
#   version                 print the resolved Godot binary and its version
#   import                  headless import of the project (validates scenes and resources)
#   check [file.gd ...]     import, then load every .gd file (or only the given ones) in a running
#                           project: parse, analyzer and compile errors fail it, including warnings
#                           configured as errors in project.godot
#   test [args...]          run tests/run_tests.gd headless
#   docs                    dump the engine class reference (XML) for offline API lookup
#   smoke                   start every registered drill with the countdown on and verify it
#                           runs (software rendering under Xvfb when there is no display)
#   screenshot <scene> <out.png> [WxH] [frames]
#                           render a scene with software OpenGL (Xvfb when there is no display)
#                           and save the main viewport as PNG
#   icons                   render icon.svg into assets/icon/icon_{144,180,512}.png for the web manifest
#   playthrough             play every registered drill to the end with random input and check the result (tools/playthrough_drills.gd; PLAYTHROUGH_ONLY=id,id limits it)
#   theme                   build ui/theme/{dark,light}_theme.tres from the palettes in tools/make_theme.gd
#   templates               install the export templates of $GODOT_VERSION (GitHub download)
#   export <preset> [out]   release export with a preset from export_presets.cfg ("Web",
#                           "Windows Desktop"); installs the templates first; out defaults
#                           to the preset's export_path
#   exec [args...]          run the Godot binary with arbitrary arguments
#
# Binary resolution order:
#   1. $GODOT_BIN
#   2. an executable in ../godot/ next to the repository (the maintainer's layout)
#   3. a cached download of $GODOT_VERSION for Linux x86_64 (cloud sessions)
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CACHE_DIR="${NEURO_DRILLS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/neuro-drills}"

log() { printf '%s\n' "$*" >&2; }
die() { log "error: $*"; exit 1; }

resolve_godot() {
  if [[ -n "${GODOT_BIN:-}" ]]; then
    [[ -f "$GODOT_BIN" ]] || die "GODOT_BIN=$GODOT_BIN is not a file"
    printf '%s\n' "$GODOT_BIN"
    return
  fi

  local sibling="$REPO_ROOT/../godot"
  if [[ -d "$sibling" ]]; then
    local candidate=""
    # Prefer the console build on Windows: it writes its output to the terminal.
    candidate="$(find "$sibling" -maxdepth 1 -type f -iname 'godot*console*.exe' | head -n 1 || true)"
    if [[ -z "$candidate" ]]; then
      candidate="$(find "$sibling" -maxdepth 1 -type f -iname 'godot*' \
        ! -iname '*.zip' ! -iname '*.pck' ! -iname '*.txt' ! -iname '*.sha*' | head -n 1 || true)"
    fi
    if [[ -n "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  fi

  local dir="$CACHE_DIR/godot/$GODOT_VERSION"
  local bin="$dir/Godot_v${GODOT_VERSION}_linux.x86_64"
  if [[ ! -x "$bin" ]]; then
    [[ "$(uname -s)" == "Linux" && "$(uname -m)" == "x86_64" ]] \
      || die "no Godot binary found; set GODOT_BIN to your Godot $GODOT_VERSION executable"
    local url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
    log "Downloading Godot $GODOT_VERSION to $dir ..."
    mkdir -p "$dir"
    curl -fsSL --retry 3 -o "$dir/godot.zip" "$url"
    if command -v unzip >/dev/null 2>&1; then
      unzip -oq "$dir/godot.zip" -d "$dir"
    else
      python3 -c 'import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])' "$dir/godot.zip" "$dir"
    fi
    rm -f "$dir/godot.zip"
    chmod +x "$bin"
  fi
  printf '%s\n' "$bin"
}

# Turn a repository path (relative, ./relative or absolute inside the repo) into a res:// path.
to_res_path() {
  local p="$1"
  case "$p" in
    res://*) printf '%s\n' "$p" ;;
    "$REPO_ROOT"/*) printf 'res://%s\n' "${p#"$REPO_ROOT"/}" ;;
    ./*) printf 'res://%s\n' "${p#./}" ;;
    *) printf 'res://%s\n' "$p" ;;
  esac
}

run_import() {
  "$GODOT" --headless --path "$REPO_ROOT" --import "$@"
}

cmd_version() {
  log "binary: $GODOT"
  "$GODOT" --headless --version
}

cmd_import() {
  run_import
}

cmd_check() {
  # Import first: the analyzer resolves class_name references through the global class cache.
  log "Importing project (needed for class_name resolution) ..."
  run_import >/dev/null 2>&1 || die "import failed; run 'tools/godot.sh import' to see why"
  local -a paths=()
  local f
  for f in "$@"; do
    paths+=("$(to_res_path "$f")")
  done
  # Loading inside a running SceneTree (not --check-only) also resolves autoload singletons.
  "$GODOT" --headless --path "$REPO_ROOT" -s res://tools/check_scripts.gd -- ${paths[@]+"${paths[@]}"} 2>&1 \
    | grep -vE '^Godot Engine v|^$'
  return "${PIPESTATUS[0]}"
}

cmd_test() {
  [[ -f "$REPO_ROOT/tests/run_tests.gd" ]] || die "tests/run_tests.gd not found (tests are not set up yet)"
  "$GODOT" --headless --path "$REPO_ROOT" -s res://tests/run_tests.gd "$@"
}

cmd_docs() {
  local out="$CACHE_DIR/apidocs"
  mkdir -p "$out"
  "$GODOT" --headless --doctool "$out" >/dev/null 2>&1 || die "doctool failed"
  log "class reference written to $out/doc/classes (plus modules/*/doc_classes)"
  printf '%s\n' "$out"
}

cmd_screenshot() {
  [[ $# -ge 2 ]] || die "usage: tools/godot.sh screenshot <scene.tscn> <out.png> [WxH] [frames]"
  local scene out res frames out_dir
  scene="$(to_res_path "$1")"
  res="${3:-1280x720}"
  frames="${4:-3}"
  out_dir="$(cd "$(dirname "$2")" 2>/dev/null && pwd)" || die "output directory of $2 does not exist"
  out="$out_dir/$(basename "$2")"

  local -a cmd=("$GODOT" --path "$REPO_ROOT" --rendering-driver opengl3 --audio-driver Dummy
    --resolution "$res" -s res://tools/screenshot.gd -- "$scene" "$out" "$frames")
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then
    LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 ${res}x24" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
}

cmd_smoke() {
  local -a cmd=("$GODOT" --path "$REPO_ROOT" --rendering-driver opengl3 --audio-driver Dummy
    --resolution 1280x720 -s res://tools/smoke_drills.gd)
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then
    LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" "${cmd[@]}" 2>&1 | grep -vE '^Godot Engine v|^$|vsync|gl_manager'
  else
    "${cmd[@]}" 2>&1 | grep -vE '^Godot Engine v|^$'
  fi
  return "${PIPESTATUS[0]}"
}

# Godot looks for templates in <data dir>/export_templates/<version>/ ("4.7.stable").
templates_dir() {
  local data_dir
  case "$(uname -s)" in
    Darwin) data_dir="$HOME/Library/Application Support/Godot" ;;
    MINGW*|MSYS*|CYGWIN*) data_dir="${APPDATA:-$HOME/AppData/Roaming}/Godot" ;;
    *) data_dir="${XDG_DATA_HOME:-$HOME/.local/share}/godot" ;;
  esac
  printf '%s/export_templates/%s\n' "$data_dir" "${GODOT_VERSION/-/.}"
}

cmd_playthrough() {
  local -a cmd=("$GODOT" --path "$REPO_ROOT" --rendering-driver opengl3 --audio-driver Dummy
    --resolution 1280x720 -s res://tools/playthrough_drills.gd)
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]] && command -v xvfb-run >/dev/null 2>&1; then
    LIBGL_ALWAYS_SOFTWARE=1 xvfb-run -a -s "-screen 0 1280x720x24" "${cmd[@]}" 2>&1 | grep -vE '^Godot Engine v|^$|vsync|gl_manager'
  else
    "${cmd[@]}" 2>&1 | grep -vE '^Godot Engine v|^$'
  fi
  return "${PIPESTATUS[0]}"
}

cmd_icons() {
  "$GODOT" --headless --path "$REPO_ROOT" -s res://tools/make_icons.gd 2>&1 | grep -vE '^Godot Engine v|^$'
  return "${PIPESTATUS[0]}"
}

cmd_theme() {
  cmd_import >/dev/null || return 1
  "$GODOT" --headless --path "$REPO_ROOT" -s res://tools/make_theme.gd 2>&1 | grep -vE '^Godot Engine v|^$'
  return "${PIPESTATUS[0]}"
}

cmd_templates() {
  local dir
  dir="$(templates_dir)"
  if [[ -f "$dir/web_nothreads_release.zip" && -f "$dir/windows_release_x86_64.exe" ]]; then
    log "export templates present in $dir"
    return
  fi
  local url="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_export_templates.tpz"
  local tpz="$CACHE_DIR/templates/Godot_v${GODOT_VERSION}_export_templates.tpz"
  mkdir -p "$(dirname "$tpz")" "$dir"
  if [[ ! -f "$tpz" ]]; then
    log "Downloading export templates $GODOT_VERSION (about 1 GB) ..."
    curl -fsSL --retry 3 -o "$tpz.part" "$url" && mv "$tpz.part" "$tpz"
  fi
  log "Installing export templates to $dir ..."
  # The archive holds a single "templates/" folder; unpack it into the version folder.
  python3 - "$tpz" "$dir" <<'PYEOF'
import sys, zipfile, os
tpz, dest = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(tpz) as z:
    for info in z.infolist():
        name = info.filename
        if not name.startswith("templates/") or name.endswith("/"):
            continue
        target = os.path.join(dest, name[len("templates/"):])
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with z.open(info) as src, open(target, "wb") as out:
            out.write(src.read())
PYEOF
  [[ -f "$dir/version.txt" ]] || die "templates did not unpack as expected"
}

cmd_export() {
  [[ $# -ge 1 ]] || die "usage: tools/godot.sh export <preset> [out]"
  local preset="$1"
  local out="${2:-}"
  cmd_templates
  if [[ -z "$out" ]]; then
    out="$(awk -v p="$preset" -F'"' '/^name=/ { current = $2 } /^export_path=/ && current == p { print $2; exit }' "$REPO_ROOT/export_presets.cfg")"
    [[ -n "$out" ]] || die "preset '$preset' not found in export_presets.cfg"
  fi
  case "$out" in /*) ;; *) out="$REPO_ROOT/$out" ;; esac
  mkdir -p "$(dirname "$out")"
  # Keep the editor and the exporter from importing the build output as project resources.
  touch "$REPO_ROOT/build/.gdignore"
  rm -f "$out"
  log "Importing project ..."
  run_import >/dev/null 2>&1 || die "import failed; run 'tools/godot.sh import' to see why"
  log "Exporting '$preset' to $out ..."
  # The exporter prints one progress line per packed file; keep only errors and warnings.
  "$GODOT" --headless --path "$REPO_ROOT" --export-release "$preset" "$out" 2>&1 \
    | sed 's/\x1b\[[0-9;]*m//g' | grep -vE '^Godot Engine v|^\s*$|^\[ *[0-9]+% \]|^\[ DONE \]' || true
  [[ "${PIPESTATUS[0]}" -eq 0 ]] || die "export of '$preset' failed"
  [[ -s "$out" ]] || die "export produced no file at $out"
  log "done: $out"
}

cmd_exec() {
  "$GODOT" "$@"
}

main() {
  local command="${1:-}"
  if [[ -z "$command" ]]; then
    # Print the header comment of this file as usage.
    awk 'NR > 1 && !/^#/ { exit } NR > 1 { sub(/^# ?/, ""); print }' "${BASH_SOURCE[0]}"
    exit 2
  fi
  shift
  GODOT="$(resolve_godot)"
  case "$command" in
    version) cmd_version "$@" ;;
    import) cmd_import "$@" ;;
    check) cmd_check "$@" ;;
    test) cmd_test "$@" ;;
    docs) cmd_docs "$@" ;;
    screenshot) cmd_screenshot "$@" ;;
    smoke) cmd_smoke "$@" ;;
    playthrough) cmd_playthrough "$@" ;;
    icons) cmd_icons "$@" ;;
    theme) cmd_theme "$@" ;;
    templates) cmd_templates "$@" ;;
    export) cmd_export "$@" ;;
    exec) cmd_exec "$@" ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
