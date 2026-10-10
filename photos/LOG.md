# Print log

One entry per problem print: photo, what it shows, what changed. Newest first.
Drop the photo next to this file as `YYYY-MM-DD-<name>.jpg`.

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
