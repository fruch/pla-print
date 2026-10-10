# Print log

One entry per problem print: photo, what it shows, what changed. Newest first.
Drop the photo next to this file as `YYYY-MM-DD-<name>.jpg`.

---

## 2026-10-10 - GitHub contribution skyline (light blue PLA)

Photo: `2026-10-10-skyline.jpg` (add it)

Profile at print time: stock Orca `Generic PLA` + Ender 3 Pro defaults
(4 mm retraction, wipe off, 0.4 mm z-hop, no travel avoidance).

| What the photo shows | Cause, most likely first | Fix |
|---|---|---|
| **Heavy stringing** - long horizontal strings between all the towers, worst at the top where travels are longest | 1. Nozzle too hot. 2. Wet filament (fine curly hairs + long strands is the usual sign). 3. Retraction too short for a Bowden tube. 4. Z-hop lifts the nozzle and leaves a trail on every travel. 5. Travels cross open air instead of staying inside the part | Dry the spool (45-50 C, 4-6 h). Print `02_temp` and `04_retraction` to find the real numbers. Profile now ships with z-hop **0**, wipe **on**, and `slice.sh` turns on **Avoid crossing walls** |
| **Blobs / zits on the tops of the tall thin towers** | Tiny layers finish in seconds, so the next layer goes onto soft plastic. Also strings collecting into blobs | `slice.sh` raises minimum layer time to 10 s. If it persists, print a second copy or a sacrificial tower next to the part |
| **Side text on the base melted and unreadable** | Text is vertical, sub-millimetre detail; 0.4 nozzle + too hot | Make the text bigger/deeper, or put it on top of the base instead of the side |
| **Diagonal hatch visible through tower walls** | Infill showing through thin walls in a pastel PLA - mild under-extrusion or just 2 walls | Print `03_flow`. If flow is fine, `./slice.sh --wall-loops 3` |
| Base edges and bottom look good | First layer is fine | Keep current leveling |

**Next print:** dry the spool, then `./calibrate.sh temp retraction` and print
`02` and `04`. Re-slice the skyline with `./slice.sh` once those numbers are in
the profile.
