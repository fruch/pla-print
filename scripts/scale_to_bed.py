#!/usr/bin/env python3
"""Scale a 3mf model as big as the Ender 3 Pro bed allows, written out as an STL.

Orca 2.4.2's CLI --scale is broken (return_code -100 even on a cube), so the
mesh is scaled here instead. Tries every Z rotation 0-90 deg and keeps the one
that allows the biggest scale - a long thin part usually wins on the diagonal.

    python3 scripts/scale_to_bed.py model/skyline.3mf model/skyline_big.stl
    python3 scripts/scale_to_bed.py in.3mf out.stl --scale 2   # fixed scale, best rotation
"""
import argparse
import math
import re
import struct
import zipfile

BED, HEIGHT = 220.0, 250.0


def load_3mf(path):
    """Every build item's mesh in world coordinates (3MF: p' = p * M + T)."""
    z = zipfile.ZipFile(path)
    tris = []
    root = z.read("3D/3dmodel.model").decode()
    for item in re.finditer(r'<item [^>]*?transform="([^"]+)"', root):
        t = list(map(float, item.group(1).split()))
        for name in z.namelist():
            if not (name.startswith("3D/Objects/") and name.endswith(".model")):
                continue
            m = z.read(name).decode()
            v = [tuple(map(float, p)) for p in
                 re.findall(r'<vertex x="([^"]+)" y="([^"]+)" z="([^"]+)"', m)]
            w = [(x*t[0] + y*t[3] + z_*t[6] + t[9],
                  x*t[1] + y*t[4] + z_*t[7] + t[10],
                  x*t[2] + y*t[5] + z_*t[8] + t[11]) for x, y, z_ in v]
            tris += [(w[int(a)], w[int(b)], w[int(c)]) for a, b, c in
                     re.findall(r'<triangle v1="(\d+)" v2="(\d+)" v3="(\d+)"', m)]
    # ponytail: assumes a single-object 3mf with components in 3D/Objects/; multi-object
    # plates would apply every item's transform to every mesh.
    if not tris:
        raise SystemExit(f"no mesh found in {path}")
    return tris


def fit(pts, margin):
    """(scale, degrees) that make the XY footprint as big as fits inside the bed."""
    usable = BED - 2 * margin
    zs = [p[2] for p in pts]
    best = (0.0, 0)
    for deg in range(91):
        r = math.radians(deg)
        xs = [x*math.cos(r) - y*math.sin(r) for x, y, _ in pts]
        ys = [x*math.sin(r) + y*math.cos(r) for x, y, _ in pts]
        s = min(usable / (max(xs) - min(xs)), usable / (max(ys) - min(ys)),
                HEIGHT / (max(zs) - min(zs)))
        if s > best[0]:
            best = (s, deg)
    return best


def transform(tris, scale, deg):
    r = math.radians(deg)
    c, s = math.cos(r), math.sin(r)
    out = [tuple(((x*c - y*s) * scale, (x*s + y*c) * scale, z * scale) for x, y, z in t)
           for t in tris]
    pts = [p for t in out for p in t]
    mn = [min(p[i] for p in pts) for i in range(3)]
    mx = [max(p[i] for p in pts) for i in range(3)]
    off = ((BED - mx[0] - mn[0]) / 2, (BED - mx[1] - mn[1]) / 2, -mn[2])
    out = [tuple((x + off[0], y + off[1], z + off[2]) for x, y, z in t) for t in out]
    return out, [mx[i] - mn[i] for i in range(3)]


def write_stl(path, tris):
    with open(path, "wb") as f:
        f.write(b"\0" * 80 + struct.pack("<I", len(tris)))
        for t in tris:
            f.write(struct.pack("<12fH", 0, 0, 0, *t[0], *t[1], *t[2], 0))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--margin", type=float, default=5, help="mm kept clear at each bed edge (skirt/brim)")
    ap.add_argument("--scale", type=float, help="fixed scale instead of the maximum")
    a = ap.parse_args()

    tris = load_3mf(a.src)
    smax, deg = fit([p for t in tris for p in t], a.margin)
    scale = a.scale or smax
    if scale > smax + 1e-9:
        raise SystemExit(f"--scale {scale} does not fit; max is {smax:.3f}")
    out, size = transform(tris, scale, deg)
    write_stl(a.out, out)
    print(f"scale {scale:.3f}x, rotated {deg} deg -> "
          f"{size[0]:.1f} x {size[1]:.1f} x {size[2]:.1f} mm, {len(out)} triangles -> {a.out}")


if __name__ == "__main__":
    main()
