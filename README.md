# pla-print

Get better PLA prints out of a stock **Creality Ender 3 Pro** (Bowden, 4.2.2
board, Marlin), sliced from the CLI with OrcaSlicer - no GUI.

The workflow: print something, photograph what went wrong, log it in
[photos/LOG.md](photos/LOG.md), run the calibration print that targets that
problem, put the number in the profile, re-slice.

Inspired by [fruch/tpu-print](https://github.com/fruch/tpu-print), cut down to
one printer and one material.

## Layout

```
profiles/orca/   Generic PLA @Ender3Pro.json - the filament profile, edit this
calibration/     first_layer.3mf (+ generated towers)
model/           drop the STL you want to print here
photos/          problem prints + LOG.md diagnosis
scripts/         tower / shape generators, G-code inspector
out/             generated
```

## Use

```bash
./calibrate.sh                 # 5 calibration prints -> out/calibration/ + INDEX.md
FAST=1 ./calibrate.sh          # coarser steps, shorter towers
./calibrate.sh temp retraction # just the ones a photo points at
cp ~/Downloads/part.stl model/
./slice.sh                     # -> out/model/part.gcode
./slice.sh --wall-loops 3      # extra args go straight to Orca
```

### Print it as big as the bed allows

```bash
python3 scripts/scale_to_bed.py ~/Downloads/part.3mf model/part_big.stl
./slice.sh --arrange 0 --brim-type no_brim
```

`scale_to_bed.py` tries every Z rotation and keeps the one that allows the
biggest scale (long thin parts win on the 45 deg diagonal), centred on the
220 x 220 bed with a 5 mm edge margin. Orca's CLI `--scale` is broken in 2.4.2,
so the mesh is scaled here instead.

Both flags matter for a bed-filling part: `--arrange 1` (the default) pushes it
off the plate, and Orca's auto-brim adds a brim to tall thin parts that no
longer fits. Either one fails the slice with `return_code -102`.

Override the slicer path with `ORCA=/path/to/OrcaSlicer.AppImage`.

| # | Test | How |
|---|---|---|
| 1 | first layer | single solid layer, lines all one direction |
| 2 | temperature tower 225 -> 190 C | `M104` per band |
| 3 | flow staircase 90 -> 110 % | `M221` per step |
| 4 | retraction tower 2 -> 7 mm | sliced once, retractions rescaled per band by `scripts/retraction_tower.py` |
| 5 | max flow tower | `M220` per band, ceiling 15 mm3/s |
| - | `./calibrate.sh wipe` | A/B pair, 21 min each: 9 thin 5 mm towers (~280 gap-crossing travels), sliced with wipe on and off and nothing else different |

Pressure advance is skipped: stock Creality 4.2.2 Marlin ships with
`LIN_ADVANCE` off.

## Profile defaults and why

`profiles/orca/Generic PLA @Ender3Pro.json` inherits Orca's `Generic PLA` and
changes:

| Setting | Value | Why |
|---|---|---|
| nozzle | 205 C (210 first layer) | middle of the PLA range; temp tower decides |
| retraction | 4 mm @ 40 mm/s | Ender default length; Bowden PLA lands 4-6 mm |
| wipe | off | part of the anti-stringing set validated in tpu-print PR #4 (low temp, travel 150, z-hop off, wipe off); also matches the retraction tower, which needs wipe off |
| z-hop | 0 | z-hop on PLA leaves a string on every travel; only enable it if the nozzle hits the print |
| flow | 0.98 | typical Ender; flow staircase decides |
| max volumetric | 12 mm3/s | stock hotend ceiling; max flow tower decides |

`slice.sh` also passes, for the real model only:

- `reduce_crossing_wall=1` (Avoid crossing walls) - travels stay over the part, not open air
- `travel_speed 150` - less time to ooze mid-travel
- `slow_down_layer_time 10` - small towers cool before the next layer

Every calibration-derived value is marked `PENDING` in `filament_notes` until
measured.

## Symptom -> fix

| Symptom | First thing to try | Calibration print |
|---|---|---|
| Stringing / hairs | dry spool, lower temp, z-hop off | `02_temp`, `04_retraction` |
| Blobs on small features | min layer time up, fan 100 % | - |
| Gaps in top surface | flow up | `03_flow` |
| Rough/thin walls at speed | slow down / lower max volumetric | `05_maxflow` |
| Corners lifting / first layer gaps | re-level, bed 60 C, clean bed with IPA | `01_level` |
| Elephant foot | nozzle slightly higher, first-layer bed temp down | `01_level` |

## CLI notes (from tpu-print)

- The Ender preset chain needs `--layer-change-gcode 'G92 E0'` or Orca refuses to slice.
- Orca exits 0 on a failed slice; `result.json` `return_code` is the real verdict. Both scripts check it.
- Boolean flags need `=`: `--reduce-crossing-wall=1`, not `--reduce-crossing-wall 1`.

## Licence

MIT. `calibration/first_layer.3mf` came from elsewhere with no licence
metadata; swap it out if you'd rather not redistribute it.
