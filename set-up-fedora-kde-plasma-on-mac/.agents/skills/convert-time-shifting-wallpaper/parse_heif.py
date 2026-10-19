#!/usr/bin/env python3
"""Parse the HEIF structure of an Apple dynamic wallpaper (e.g. Mojave.heic).

Reports items, grid layout (tiles -> image), tile sizes and the XMP
`apple_desktop:solar` / `h24` / `apr` plist.

Usage: parse_heif.py [file.heic] [--json out.json]
"""
import base64
import json
import plistlib
import re
import struct
import sys
from collections import Counter

args = [a for a in sys.argv[1:] if not a.startswith("--")]
JSON_OUT = sys.argv[sys.argv.index("--json") + 1] if "--json" in sys.argv else None
if JSON_OUT in args:
    args.remove(JSON_OUT)
PATH = args[0] if args else "Mojave.heic"

with open(PATH, "rb") as fh:
    D = fh.read()


def boxes(off, end):
    """Return [(type, start, size, payload_start)] for boxes in [off, end)."""
    out = []
    while off + 8 <= end:
        size, typ = struct.unpack(">I4s", D[off:off + 8])
        hdr = 8
        if size == 1:
            size = struct.unpack(">Q", D[off + 8:off + 16])[0]
            hdr = 16
        elif size == 0:
            size = end - off
        if size < hdr or off + size > end:
            break
        out.append((typ.decode("latin1"), off, size, off + hdr))
        off += size
    return out


def find(bs, t):
    return next((b for b in bs if b[0] == t), None)


def u(n, off):
    return int.from_bytes(D[off:off + n], "big")


top = boxes(0, len(D))
meta = find(top, "meta")
mc = boxes(meta[3] + 4, meta[1] + meta[2])  # meta is a FullBox
print(f"file: {PATH}  size={len(D)}")
print("top-level:", [(t, s, z) for t, s, z, _ in top])
print("meta children:", [(t, z) for t, _, z, _ in mc])

pitm = find(mc, "pitm")
primary = u(2 if D[pitm[3]] == 0 else 4, pitm[3] + 4)

# ---- iinf / infe ----
iinf = find(mc, "iinf")
cnt_sz = 2 if D[iinf[3]] == 0 else 4
items = {}
for t, s, z, p in boxes(iinf[3] + 4 + cnt_sz, iinf[1] + iinf[2]):
    v = D[p]
    idsz = 2 if v < 3 else 4
    q = p + 4
    iid = u(idsz, q)
    q += idsz + 2  # skip item_protection_index
    itype = D[q:q + 4].decode("latin1")
    items[iid] = {"id": iid, "type": itype}
print(f"\nitems: {len(items)}  types: {dict(Counter(i['type'] for i in items.values()))}")
print(f"primary item: {primary} ({items[primary]['type']})")

# ---- iref ----
iref = find(mc, "iref")
rsz = 2 if D[iref[3]] == 0 else 4
refs = {}  # reference type -> {from_id: [to_ids]}
for t, s, z, p in boxes(iref[3] + 4, iref[1] + iref[2]):
    frm = u(rsz, p)
    n = u(2, p + rsz)
    refs.setdefault(t, {})[frm] = [u(rsz, p + rsz + 2 + i * rsz) for i in range(n)]
for t, m in refs.items():
    print(f"iref {t}: {len(m)} source item(s); targets per source: {sorted(set(len(v) for v in m.values()))}")

# ---- iprp: ispe per item ----
iprp = find(mc, "iprp")
pc = boxes(iprp[3], iprp[1] + iprp[2])
ipco = find(pc, "ipco")
props = []
for t, s, z, p in boxes(ipco[3], ipco[1] + ipco[2]):
    props.append({"type": t, "dims": (u(4, p + 4), u(4, p + 8))} if t == "ispe" else {"type": t})
ipma = find(pc, "ipma")
iv, iflags = D[ipma[3]], u(3, ipma[3] + 1)
q = ipma[3] + 4
n_entries = u(4, q)
q += 4
item_props = {}
for _ in range(n_entries):
    isz = 2 if iv < 1 else 4
    iid = u(isz, q)
    q += isz
    k = D[q]
    q += 1
    lst = []
    for _ in range(k):
        if iflags & 1:
            lst.append(u(2, q) & 0x7FFF)
            q += 2
        else:
            lst.append(D[q] & 0x7F)
            q += 1
    item_props[iid] = lst


def dims_of(iid):
    return [props[i - 1]["dims"] for i in item_props.get(iid, []) if i and "dims" in props[i - 1]]


# ---- iloc ----
iloc = find(mc, "iloc")
lv = D[iloc[3]]
q = iloc[3] + 4
osz, lsz = D[q] >> 4, D[q] & 15
bosz, ixsz = D[q + 1] >> 4, D[q + 1] & 15
q += 2
idsz = 2 if lv < 2 else 4
icount = u(idsz, q)
q += idsz
locs = {}
for _ in range(icount):
    iid = u(idsz, q)
    q += idsz
    cm = 0
    if lv in (1, 2):
        cm = u(2, q) & 15
        q += 2
    q += 2 + bosz  # data_reference_index, base_offset
    ec = u(2, q)
    q += 2
    exts = []
    for _ in range(ec):
        if lv in (1, 2):
            q += ixsz
        off, ln = u(osz, q), u(lsz, q + osz)
        q += osz + lsz
        exts.append((off, ln))
    locs[iid] = (cm, exts)

# ---- grid descriptors (stored in idat) ----
idat = find(mc, "idat")
grids = {}
for iid, it in items.items():
    if it["type"] != "grid":
        continue
    cm, exts = locs[iid]
    off, ln = exts[0]
    g = D[(idat[3] if cm == 1 else 0) + off:][:ln]
    rows, cols = g[2] + 1, g[3] + 1
    w, h = struct.unpack(">HH", g[4:8]) if not g[1] & 1 else struct.unpack(">II", g[4:12])
    grids[iid] = {"rows": rows, "cols": cols, "width": w, "height": h,
                  "tiles": refs.get("dimg", {}).get(iid, [])}

print(f"\ngrid items (= full images): {len(grids)}")
for iid, g in list(grids.items())[:2]:
    print(f"  grid #{iid}: {g['cols']}x{g['rows']} tiles -> {g['width']}x{g['height']}, "
          f"{len(g['tiles'])} tiles (ids {g['tiles'][0]}..{g['tiles'][-1]}, row-major)")
print("  distinct layouts (cols, rows, w, h):",
      dict(Counter((g["cols"], g["rows"], g["width"], g["height"]) for g in grids.values())))
print("  tile ispe:", dict(Counter(d for g in grids.values() for t in g["tiles"] for d in dims_of(t)[:1])))
g0 = next(iter(grids.values()))
print(f"  padding in last tile row/col (px): bottom={g0['rows'] * 512 - g0['height']} "
      f"right={g0['cols'] * 512 - g0['width']}")

# ---- XMP: Apple dynamic-wallpaper plists ----
xmp = {}
for m in re.finditer(rb"<\?xpacket begin.*?<\?xpacket end[^>]*\?>", D, re.S):
    txt = m.group(0).decode("utf8", "replace")
    for key in ("solar", "h24", "apr"):
        mm = re.search(rf'apple_desktop:{key}="([^"]+)"', txt)
        if mm:
            xmp[key] = plistlib.loads(base64.b64decode(mm.group(1)))
print(f"\nXMP apple_desktop plists: {list(xmp)}")
for key, val in xmp.items():
    print(f"  [{key}] ap (light/dark image indices): {val.get('ap')}")
    for e in val.get("si", []):
        print(f"    image {e['i']:2d}: altitude={e['a']:8.2f}  azimuth={e['z']:7.2f}")
    for e in val.get("ti", []):
        print(f"    image {e['i']:2d}: time fraction={e['t']:.4f}")

if JSON_OUT:
    def tile_size(iid):
        tiles = grids[iid]["tiles"]
        if tiles:
            d = dims_of(tiles[0])
            return d[0] if d else None
        return None
    with open(JSON_OUT, "w") as fh:
        json.dump({"file": PATH, "primaryItem": primary,
                   "grids": [dict(id=i, tileSize=tile_size(i), **g) for i, g in grids.items()],
                   "xmp": xmp}, fh, indent=1, default=str)
    print(f"\nwrote {JSON_OUT}")
