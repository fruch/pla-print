#!/usr/bin/env bash
# Generate PLA calibration prints for a stock Ender 3 Pro from the CLI.
#
#   ./calibrate.sh                 all tests, in print order
#   ./calibrate.sh temp retraction just those
#   FAST=1 ./calibrate.sh          coarser steps, shorter bands
#
# Output: out/calibration/NN_<test>.gcode + INDEX.md (what to look for).
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

ORCA="${ORCA:-$HOME/Downloads/OrcaSlicer_Linux_AppImage_Ubuntu2404_V2.4.2.AppImage}"
SYS="$HOME/.config/OrcaSlicer/system"
MACHINE="$SYS/Creality/machine/Creality Ender-3 Pro 0.4 nozzle.json"
PROCESS="$SYS/Creality/process/0.20mm Standard @Creality Ender3 Pro 0.4.json"
FILAMENT="$HERE/profiles/orca/Generic PLA @Ender3Pro.json"
# The Ender chain never sets use_relative_e_distances, so Orca falls back to
# relative E with an empty layer_change_gcode and refuses to slice.
G92=$'G92 E0\n'

TESTS=("$@"); [[ ${#TESTS[@]} -eq 0 ]] && TESTS=(level temp flow retraction mvs)

if [[ "${FAST:-0}" == "1" ]]; then
    : "${STEP:=10}" "${BAND:=4}" "${FLOW_STEP:=10}" "${SPD_STEP:=25}" "${RETR:=2 4 6}" "${RETR_BAND:=7}"
fi
# PLA prints 190-220 on most spools; 225 at the bottom finds the ooze ceiling.
T_START="${START:-225}"; T_END="${END:-190}"; T_STEP="${STEP:-5}"; T_BAND="${BAND:-6}"
RETR="${RETR:-2 3 4 5 6 7}"          # Bowden PLA usually lands 4-6 mm
RETR_BAND="${RETR_BAND:-10}"
FLOW_START="${FLOW_START:-90}"; FLOW_END="${FLOW_END:-110}"; FLOW_STEP="${FLOW_STEP:-5}"
SPD_START="${SPD_START:-40}";  SPD_END="${SPD_END:-160}";  SPD_STEP="${SPD_STEP:-20}"
MVS_CEIL="${MVS_CEIL:-15}"           # stock Ender hotend tops out ~10-12 mm3/s

CAL=(--wall-loops 3 --sparse-infill-density 15% --top-shell-layers 3
     --bottom-shell-layers 3 --brim-type outer_only --brim-width 5 --travel-speed 120)

bold() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die()  { printf '\033[31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

[[ -x "$ORCA" ]] || die "OrcaSlicer not found: $ORCA (override with ORCA=...)"
for f in "$MACHINE" "$PROCESS" "$FILAMENT"; do [[ -f "$f" ]] || die "missing preset: $f"; done

# slice_to <stl> <dest.gcode> <layer-change-gcode> [extra orca args...]
slice_to() {
    local stl="$1" dest="$2" lg="$3"; shift 3
    local work; work="$(mktemp -d)"
    if ! "$ORCA" --load-settings "$MACHINE;$PROCESS" --load-filaments "$FILAMENT" \
             --layer-change-gcode "$lg" "${CAL[@]}" "$@" \
             --slice 0 --arrange 1 --outputdir "$work" "$stl" >"$work/log" 2>&1; then
        cat "$work/log" >&2; rm -rf "$work"; die "slice failed -> $dest"
    fi
    # Orca exits 0 on a failed slice; result.json is the real verdict.
    local rc; rc=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1])).get('return_code',0))" "$work/result.json")
    [[ "$rc" == "0" ]] || { cat "$work/log" >&2; rm -rf "$work"; die "slice failed -> $dest (rc=$rc)"; }
    mv "$work"/*.gcode "$dest"
    rm -rf "$work"
}

OUT=out/calibration
rm -rf "$OUT"; mkdir -p "$OUT"
N=0
INDEX=("# Ender 3 Pro PLA calibration, in print order" ""
       "Dry the spool first if it has been open for weeks (PLA: 45-50 C, 4-6 h)." ""
       "| # | File | Look for |" "|---|---|---|")
add() {  # add <slug> <look-for>; sets FN
    N=$((N + 1)); FN="$(printf '%s/%02d_%s.gcode' "$OUT" "$N" "$1")"
    INDEX+=("| $N | \`$(basename "$FN")\` | $2 |")
}

for test in "${TESTS[@]}"; do
    case "$test" in
      level)
        bold "first layer"
        add level "Lines all run one way. Gaps = nozzle high, shiny/squashed = low. Adjust the knobs under each corner until uniform."
        slice_to calibration/first_layer.3mf "$FN" "$G92" \
            --infill-direction=0 --solid-infill-direction=0 \
            --sparse-infill-density 100% --bottom-shell-layers 1 ;;
      temp)
        bold "temperature tower ${T_START}->${T_END}"
        STL=calibration/temp_tower.stl
        LG="$(python3 scripts/make_temp_tower.py --start "$T_START" --end "$T_END" \
                --step "$T_STEP" --band-height "$T_BAND" --out "$STL" 2>/dev/null)"
        add "temp_${T_START}-${T_END}" "Bottom band = ${T_START}C, ${T_STEP}C cooler every ${T_BAND}mm. Pick the coolest band with clean bridges, no strings in the gap and good layer bonding (try snapping a pillar)."
        slice_to "$STL" "$FN" "$LG" ;;
      flow)
        bold "flow tower ${FLOW_START}-${FLOW_END}%"
        STL=calibration/flow_tower.stl
        LG="$(python3 scripts/make_temp_tower.py --mode flow --shape stairs \
                --start "$FLOW_START" --end "$FLOW_END" --step "$FLOW_STEP" \
                --band-height "$T_BAND" --out "$STL" 2>/dev/null)"
        add "flow_${FLOW_START}-${FLOW_END}pct" "Staircase, lowest step = ${FLOW_START}%, +${FLOW_STEP}% per step. Gaps between top lines = too little, ridges = too much. Smoothest step % / 100 = flow ratio."
        slice_to "$STL" "$FN" "$LG" --top-shell-layers 4 --wall-loops 2 --top-surface-pattern monotonic ;;
      retraction)
        bold "retraction tower ${RETR}"
        n=$(wc -w <<< "$RETR"); base=$(awk '{print $1}' <<< "$RETR")
        STL=calibration/retraction_pillars.stl
        (cd scripts && python3 make_test_shapes.py pillars --out "../$STL" --height "$((n * RETR_BAND))") 2>/dev/null
        # Slice once with wipe off (so each retraction is one rescalable move),
        # then rescale per band. Relative E (M83) is what makes that safe.
        raw="$(mktemp)"
        slice_to "$STL" "$raw" "$G92" --filament-wipe=0 --filament-retraction-length "$base" --wall-loops 2
        add retraction "Two pillars; retraction changes every ${RETR_BAND}mm going up (${RETR// /, } mm). Take the SHORTEST clean band - extra retraction only adds clogs and wear."
        python3 scripts/retraction_tower.py "$raw" "$FN" --base "$base" --values "$RETR" --band-height "$RETR_BAND" | sed 's/^/  /'
        rm -f "$raw" ;;
      mvs)
        bold "max flow tower"
        STL=calibration/speed_tower.stl
        LG="$(python3 scripts/make_temp_tower.py --mode speed --shape block \
                --start "$SPD_START" --end "$SPD_END" --step "$SPD_STEP" \
                --band-height "$T_BAND" --out "$STL" 2>/dev/null)"
        add maxflow "Speed rises ${SPD_STEP}% per ${T_BAND}mm band from ${SPD_START}%. Find where the wall first goes thin/rough; take the band below it: mm3/s = ${MVS_CEIL} x band% / 100."
        slice_to "$STL" "$FN" "$LG" --filament-max-volumetric-speed "$MVS_CEIL" --wall-loops 2 ;;
      *) die "unknown test '$test' (level temp flow retraction mvs)" ;;
    esac
    printf '  %s\n' "$(basename "$FN")"
done

INDEX+=("" "Put the numbers into \`profiles/orca/Generic PLA @Ender3Pro.json\`, drop the PENDING line, and log the change in \`photos/LOG.md\`.")
printf '%s\n' "${INDEX[@]}" > "$OUT/INDEX.md"
rm -f "$HERE"/[0-9]*.log
bold "Done -> $OUT/INDEX.md"
