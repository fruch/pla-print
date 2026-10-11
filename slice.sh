#!/usr/bin/env bash
# Slice every STL/3MF in model/ with the PLA profile + anti-stringing travel.
#   ./slice.sh            -> out/model/<name>.gcode
#   ./slice.sh --wall-loops 3    extra args go straight to Orca and win
#   ./slice.sh --arrange 0       keep the STL's own position (needed for bed-filling parts)
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

ORCA="${ORCA:-$HOME/Downloads/OrcaSlicer_Linux_AppImage_Ubuntu2404_V2.4.2.AppImage}"
SYS="$HOME/.config/OrcaSlicer/system"
MACHINE="$SYS/Creality/machine/Creality Ender-3 Pro 0.4 nozzle.json"
PROCESS="$SYS/Creality/process/0.20mm Standard @Creality Ender3 Pro 0.4.json"
FILAMENT="$HERE/profiles/orca/Generic PLA @Ender3Pro.json"

# Strings form during travel. Route travels inside the part instead of across
# open air, and keep travel fast so there is less time to ooze.
# slow_down_layer_time stops tiny towers from being printed onto still-soft
# plastic, which is what makes the blobby tops on thin features.
ANTI_STRING=(--reduce-crossing-wall=1 --travel-speed 150 --slow-down-layer-time 10)

[[ -x "$ORCA" ]] || { echo "OrcaSlicer not found: $ORCA (override with ORCA=...)" >&2; exit 1; }
shopt -s nullglob nocaseglob
files=(model/*.stl model/*.3mf)
(( ${#files[@]} )) || { echo "model/ is empty - drop an STL in it" >&2; exit 1; }
mkdir -p out/model

for f in "${files[@]}"; do
    job="$(basename "${f%.*}")"; work="$(mktemp -d)"
    "$ORCA" --load-settings "$MACHINE;$PROCESS" --load-filaments "$FILAMENT" \
        --layer-change-gcode $'G92 E0\n' "${ANTI_STRING[@]}" --arrange 1 "$@" \
        --slice 0 --outputdir "$work" "$f" >"$work/log" 2>&1 || { cat "$work/log" >&2; exit 1; }
    rc=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('return_code',0))" "$work/result.json")
    [[ "$rc" == "0" ]] || { cat "$work/log" >&2; echo "slice failed: $f (rc=$rc)" >&2; exit 1; }
    mv "$work"/*.gcode "out/model/$job.gcode"; rm -rf "$work"
    echo "  ok  out/model/$job.gcode  $(python3 scripts/inspect_gcode.py "out/model/$job.gcode" | grep -oE 'est\. time.*' || true)"
done
rm -f "$HERE"/[0-9]*.log
