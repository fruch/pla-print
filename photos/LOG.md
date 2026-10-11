# Print log

One entry per problem print: photo, what it shows, what changed. Newest first.
Drop the photo next to this file as `YYYY-MM-DD-<name>.jpg`.

---

## 2026-10-11 - skyline 1x at 195 C / 5 mm

Text and base are clean now ("fruch" is readable). Stringing is **as bad as
before**, worst at the top where the towers are far apart.

Checked the G-code: 195 C applied, every tower-to-tower travel retracts
~5 mm (4 mm + 1 mm during wipe); the only unretracted travels are short hops
inside infill. So this is not a slicer setting. The retraction tower already
left a fine hair per travel at 4-6 mm; this model makes thousands of travels.

Remaining causes, most likely first:
1. **Wet filament.** Fine hairs at every temperature and retraction value is
   the signature. Check: bend a 10 cm piece - wet PLA snaps instead of
   bending; listen for crackle/pop and watch for steam when extruding by hand.
   Dry 45-50 C for 4-6 h.
2. **PTFE tube not seated against the nozzle** (classic Ender 3). Molten PLA
   pools in the gap, so retraction pulls back the tube contents but the nozzle
   keeps oozing. Check: tube end burnt/brown or not cut square; re-seat it hard
   against the nozzle with the hotend at temperature and clip the coupler.
3. Then 190 C (clean on the temp tower too).

**Next print:** after drying, `out/calibration/01_retraction.gcode`
(4 / 5 / 6 mm at 195 C, 23 min). Clean -> re-print the 1x skyline.
Whatever fine hairs survive: a quick pass with a heat gun removes them.

---

## 2026-10-11 - temperature + retraction towers (FAST mode)

| Print | Bands, bottom -> top | Result |
|---|---|---|
| temp tower | 225 / 215 / 205 / 195 / 190 C | 225 and 215 string and blob on the inner faces, 205 still has zits, **195 and 190 clean** |
| retraction tower (at 205 C) | 2 / 4 / 6 mm | 2 mm thick blobby zigzags; 4 and 6 mm fine hairs only - retraction alone does not get it clean at 205 C, temperature is the bigger lever |

Profile now: **nozzle 195 C** (205 C first layer), **retraction 5 mm @ 40 mm/s**.
If the top band snaps easily by hand, go to 200 C. If 195 C still leaves fine
hairs, dry the spool before touching retraction again.

**Next print:** `out/model/skyline_1x_0.20.gcode` (1h 39m) as the full check,
then `skyline_big_0.20.gcode` (13h 45m).

---

## 2026-10-10 - GitHub contribution skyline (light blue PLA)

Model: `github-fruch-Oct 2025 - Oct 2026.3mf`, sliced in Bambu Studio 2.6 with
`Creality Generic PLA - Cyan` on the stock Ender 3 Pro machine/process presets.
Settings read from the 3mf's `project_settings.config`:

| Setting | Was | Now (`slice.sh`) |
|---|---|---|
| nozzle | **180 C** | 205 C |
| retraction | **1.6 mm @ 30 mm/s** (filament override of the 4 mm machine value) | 4 mm @ 40 mm/s |
| wipe | on | on |
| z-hop | 0 | 0 |
| avoid crossing walls | off | on |
| min layer time | 8 s | 10 s |

| What the photo shows | Cause, most likely first | Fix |
|---|---|---|
| **Heavy stringing** - long horizontal strings between all the towers, worst at the top where travels are longest | 1. **Retraction 1.6 mm** - fine for direct drive, far too short for the Bowden tube, so the nozzle keeps oozing through every travel. 2. Travels cross open air between the towers. 3. Possibly wet filament (fine curly hairs) | Retraction 4 mm (then `04_retraction`), **Avoid crossing walls** on. Dry the spool if it still strings |
| **Blobs / zits on the tops of the tall thin towers** | Tiny layers finish in seconds, so the next layer goes onto soft plastic. Also strings collecting into blobs | `slice.sh` raises minimum layer time to 10 s. If it persists, print a second copy or a sacrificial tower next to the part |
| **Side text on the base melted and unreadable** | Text is vertical, sub-millimetre detail for a 0.4 nozzle; stringing piles onto it | Make the text bigger/deeper, or put it on top of the base instead of the side |
| **Diagonal hatch visible through tower walls** | **180 C is cold** for PLA on the stock hotend: under-extrusion, so walls come out thin and the infill shows through | 205 C, then confirm with `02_temp` and `03_flow`. Still visible -> `./slice.sh --wall-loops 3` |
| Base edges and bottom look good | First layer is fine | Keep current leveling |

**Next print:** `out/model/skyline.gcode` (`./slice.sh`, 1h 33m) as-is - the
retraction fix alone should remove most strings. If it still strings, print
`02_temp` and `04_retraction` and re-slice with the measured values.
