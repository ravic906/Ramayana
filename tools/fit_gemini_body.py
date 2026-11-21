"""Binds a generated humanoid mesh (e.g. from an image-to-3D tool) to the game skeleton.

    blender -b --python tools/fit_gemini_body.py -- <mesh.glb> <skeleton.glb> <out.glb> [height_m] [texture_px]

The skeleton file is a person exported by tools/mpfb_export.py (its armature has the game's bones,
in an A-pose). The mesh is stood on the floor, centred, scaled to `height_m`, and skinned to the
armature with automatic weights; the output keeps the armature and the single skinned mesh,
named "<person>.body" so tools/build_person.gd treats it like an MPFB body.
"""
import sys
from pathlib import Path

import bpy, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
MESH, SKEL, OUT = argv[:3]
HEIGHT = float(argv[3]) if len(argv) > 3 else 1.78
NAME = Path(OUT).stem

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SKEL)
arm = next(o for o in bpy.context.scene.objects if o.type == "ARMATURE")
# The skeleton file's own body is already weighted to the game bones: keep it as the weight donor.
donor = next((o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.endswith(".body")), None)
for o in list(bpy.context.scene.objects):
    if o.type != "ARMATURE" and o is not donor:
        bpy.data.objects.remove(o, do_unlink=True)

before = set(bpy.context.scene.objects)  # includes the donor
bpy.ops.import_scene.gltf(filepath=MESH)
meshes = [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]
for o in bpy.context.scene.objects:
    if o not in before and o.type != "MESH":
        o.select_set(False)
bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
if len(meshes) > 1:
    bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.parent = None
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

# Stand it on the floor, centred on x/y, scaled to the requested height.
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
mn = Vector((min(v[i] for v in bb) for i in range(3)))
mx = Vector((max(v[i] for v in bb) for i in range(3)))
scale = HEIGHT / (mx.z - mn.z)
body.scale = (scale, scale, scale)
bpy.ops.object.transform_apply(scale=True)
bb = [body.matrix_world @ Vector(c) for c in body.bound_box]
mn = Vector((min(v[i] for v in bb) for i in range(3)))
mx = Vector((max(v[i] for v in bb) for i in range(3)))
body.location = Vector((-(mn.x + mx.x) / 2, -(mn.y + mx.y) / 2, -mn.z))
bpy.ops.object.transform_apply(location=True)
body.name = f"{NAME}.body"
body.data.name = f"{NAME}.body"

# Keep only the base-colour picture (downscaled) so the character stays a few MB: generated models
# often carry 4096 px normal and metallic-roughness maps that a phone game does not need.
TEX = int(argv[4]) if len(argv) > 4 else 1024
for mat in body.data.materials:
    if mat and mat.use_nodes:
        nt = mat.node_tree
        bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            for name in ("Metallic", "Roughness", "Normal"):
                for l in list(bsdf.inputs[name].links):
                    nt.links.remove(l)
            bsdf.inputs["Roughness"].default_value = 0.85
            bsdf.inputs["Metallic"].default_value = 0.0
        for n in list(nt.nodes):
            nm = (n.image.name.lower() if n.type == "TEX_IMAGE" and n.image else "")
            if n.type == "NORMAL_MAP" or n.type in ("SEPARATE_COLOR", "SEPARATE_RGB") or nm.endswith("_normal.png") or "_rm" in nm or "normal" in nm:
                nt.nodes.remove(n)
for img in list(bpy.data.images):
    if img.users and img.size[0] > TEX:
        img.scale(TEX, TEX)
    if img.users and not img.packed_file:
        img.pack()

# --- Fit the arm, hand and finger bones to THIS mesh ------------------------------------------
# The skeleton file's joints are for another body: elbows, wrists and knuckles land in the wrong
# places and limbs fold in the middle of a bone. Each arm is measured on the mesh (shoulder to
# fingertip, wrist at the narrowest section, elbow by proportion), each hand split into thumb and
# four fingers, and the bones are moved there before any weight is computed.
import numpy as np
from mathutils import Vector

FINGER = ("thumb", "index", "middle", "ring", "pinky")


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.dot(ab), 1e-9)))
    return (p - (a + ab * t)).length


def seg_dist_np(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / max(ab @ ab, 1e-12), 0.0, 1.0)
    return np.linalg.norm(P - (a + np.outer(t, ab)), axis=1)


P = np.array([tuple(body.matrix_world @ v.co) for v in body.data.vertices])
# Surface adjacency, with vertices split at UV seams welded (used to keep regions connected).
_key = {}
WELD = np.zeros(len(P), dtype=int)
for i, c in enumerate(P):
    WELD[i] = _key.setdefault(tuple(np.round(c, 5)), len(_key))
NBR = [set() for _ in range(len(_key))]
for poly in body.data.polygons:
    ids = [WELD[i] for i in poly.vertices]
    for x in ids:
        NBR[x].update(y for y in ids if y != x)


def grow(seed_mask, allow_mask):
    """Vertices reachable over the surface from the seeds without leaving the allowed region."""
    nw = len(NBR)
    allow_w = np.zeros(nw, bool)
    allow_w[WELD[allow_mask]] = True
    seen = np.zeros(nw, bool)
    stack = list(set(WELD[seed_mask].tolist()))
    for s_ in stack:
        seen[s_] = True
    while stack:
        x = stack.pop()
        for y in NBR[x]:
            if not seen[y] and allow_w[y]:
                seen[y] = True
                stack.append(y)
    return np.where(seen[WELD])[0]


AW = arm.matrix_world.copy()
AWi = AW.inverted()
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones


def wpos(v):
    return np.array(tuple(AW @ v))


def lpos(v):
    return AWi @ Vector(tuple(v))


def place(name, head, tail):
    b = eb.get(name)
    if b is not None:
        b.use_connect = False
        b.head = lpos(head)
        b.tail = lpos(tail)


# Proportions, per character: (shoulder widening as a fraction of height, arm slimming factor).
# Generated bodies tend to have narrow shoulders and heavy arms; a prince is broad-shouldered with
# lean, long arms. Sages and townsfolk get a lighter touch; rakshasas keep their bulk.
PROPORTION = {"rama": (0.024, 0.8), "rama_crowned": (0.024, 0.8), "lakshmana": (0.02, 0.84),
              "guard": (0.011, 0.9), "dasharatha": (0.008, 0.92), "janaka": (0.008, 0.92), "sumati": (0.008, 0.92),
              "townsman": (0.006, 0.93), "gautama": (0.006, 0.93), "vishvamitra": (0.006, 0.94), "vasishtha": (0.005, 0.95),
              "sita": (0.0, 0.95), "ahalya": (0.0, 0.95), "townswoman": (0.0, 0.95)}
WIDEN, SLIM = PROPORTION.get(NAME[:-2] if NAME.endswith("_t") else NAME, (0.0, 1.0))
WIDEN *= HEIGHT

ARM_SET = {}   # side suffix -> vertex indices that belong to that arm (may use arm bones)
HAND_SET = {}  # side suffix -> vertex indices of that hand (may use finger bones)
FWD = np.array([0.0, -1.0, 0.0])  # the model faces -Y
HGT = float(P[:, 2].max())
trunk = [b for b in eb if b.name.startswith(("spine", "pelvis", "neck", "Head", "thigh", "calf", "clavicle"))]
d_trunk = np.min([seg_dist_np(P, wpos(b.head), wpos(b.tail)) for b in trunk], axis=0)


def measure(s, sx):
    """Shoulder, elbow, wrist and fingertip of one arm, measured on the mesh (None if not found)."""
    S = wpos(eb["upperarm" + sx].head)
    cand = np.where((P[:, 0] * s > S[0] * s + 0.04) & (P[:, 2] < S[2] - 0.03) & (P[:, 2] > 0.33 * HGT))[0]
    if len(cand) < 200:
        return None
    T = P[cand[np.argmax(np.linalg.norm(P[cand] - S, axis=1))]]
    u = T - S
    Lt = np.linalg.norm(u)
    u = u / Lt
    rel = P[cand] - S
    along = rel @ u
    rad = np.linalg.norm(rel - np.outer(along, u), axis=1)
    nb = 48
    bins = np.clip((along / Lt * nb).astype(int), 0, nb - 1)
    radius = np.full(nb, 1.0)
    centre = np.array([S + u * Lt * (k + 0.5) / nb for k in range(nb)])
    for k in range(nb):
        m = bins == k
        if m.sum() >= 6:
            r = rad[m]
            keep = r <= np.percentile(r, 70)  # the limb's own section, not cloth or hair nearby
            radius[k] = np.median(r[keep])
            centre[k] = P[cand][m][keep].mean(axis=0)
    lo, hi = int(0.55 * nb), int(0.82 * nb)
    kw = lo + int(np.argmin(radius[lo:hi]))
    if 1.0 - (kw + 0.5) / nb > 0.32:
        # Too long a hand: a bracelet or wrist band made the forearm look thinner than the wrist.
        # Look near the usual wrist (a hand is about a quarter of shoulder-to-fingertip).
        c = int(0.74 * nb)
        lo, hi = c - 3, min(c + 4, nb - 1)
        kw = lo + int(np.argmin(radius[lo:hi]))
    Wr = centre[kw]
    tw = (Wr - S) @ u
    E = centre[min(max(int(round(0.56 * tw / Lt * nb)), 1), nb - 1)]
    mid = radius[int(0.3 * nb):int(0.9 * nb)]
    limb_r = float(np.median(mid[mid < 1.0])) if (mid < 1.0).any() else 0.05
    hand = np.linalg.norm(T - Wr)
    ok = 0.36 * HGT < Lt < 0.52 * HGT and 0.14 < hand / Lt < 0.34
    print("ARMFIT measure", sx, "arm %.2f (height %.2f) hand %.2f" % (Lt, HGT, hand))
    return {"S": S, "E": E, "W": Wr, "T": T, "r": limb_r, "ok": ok, "L": Lt, "hand": hand, "radius": radius, "nb": nb}


def mirror(m, S):
    f = np.array([-1.0, 1.0, 1.0])
    return {"S": S, "E": m["E"] * f, "W": m["W"] * f, "T": m["T"] * f, "r": m["r"], "ok": True, "L": m["L"], "hand": m["hand"],
            "radius": m["radius"], "nb": m["nb"]}


meas = {}
for s, sx in ((1.0, "_l"), (-1.0, "_r")):
    if eb.get("upperarm" + sx) is not None:
        meas[sx] = measure(s, sx)
for sx, other in (("_l", "_r"), ("_r", "_l")):
    m, o = meas.get(sx), meas.get(other)
    if (m is None or not m["ok"]) and o is not None and o["ok"]:
        meas[sx] = mirror(o, wpos(eb["upperarm" + sx].head))  # generated bodies are near-symmetric
        print("ARMFIT", sx, "mirrored from", other)

for s, sx in ((1.0, "_l"), (-1.0, "_r")):
    m = meas.get(sx)
    if m is None or not m["ok"]:
        print("ARMFIT", sx, "skipped (no plausible arm found)")
        continue
    S, E, Wr, T, limb_r = m["S"], m["E"], m["W"], m["T"], m["r"]
    u = (T - S) / np.linalg.norm(T - S)
    poly = [S, E, Wr, T]
    d_up = seg_dist_np(P, S, E)
    d_low = np.minimum(seg_dist_np(P, E, Wr), seg_dist_np(P, Wr, T))
    d_line = np.minimum(d_up, d_low)
    # Upper arm: room for armlets and shoulder pads; forearm and hand: tight, so a skirt or a
    # cloth hanging beside the hand is not carried along with it.
    # Local limb radius along the arm, and which side of the arm a vertex is on: on the inner side
    # (toward the chest or hip, which the arm may touch) only the arm's own skin is taken.
    rr = m["radius"].copy()
    rr[rr >= 1.0] = limb_r
    tt = np.clip(((P - S) @ u) / m["L"], 0.0, 0.999)
    rk = rr[(tt * m["nb"]).astype(int)]
    near_pt = np.where((d_up <= d_low)[:, None], 0.0, 0.0)  # placeholder for shape
    ab = E - S
    ta = np.clip(((P - S) @ ab) / (ab @ ab), 0, 1)
    cu = S + np.outer(ta, ab)
    ab2 = Wr - E
    tb = np.clip(((P - E) @ ab2) / (ab2 @ ab2), 0, 1)
    cl = E + np.outer(tb, ab2)
    closest = np.where((d_up <= d_low)[:, None], cu, cl)
    radial = P - closest
    medial = (radial[:, 0] * -s) / np.maximum(np.linalg.norm(radial, axis=1), 1e-6) > 0.35
    tight = 1.2 * rk + 0.008
    near = np.where(medial, d_line < tight, (d_up < 2.4 * limb_r + 0.015) | (d_low < 1.6 * limb_r + 0.01))
    allow = near & (d_line < d_trunk) & (P[:, 0] * s > S[0] * s - 0.01) & (P[:, 2] < S[2] + 0.08)
    seeds = allow & ((d_low < 0.9 * limb_r) | (d_up < 1.1 * limb_r))
    arm_set = grow(seeds, allow)  # only what is joined to the arm itself (not a skirt beside the hand)
    if WIDEN > 0.0 or SLIM < 1.0:
        # Reshape: slim the arm toward its centre line (not at the shoulder or the hand), and move
        # the whole arm outward, stretching the shoulder muscles over a short distance.
        sel = arm_set
        q = P[sel]
        ab = E - S
        ta = np.clip(((q - S) @ ab) / (ab @ ab), 0, 1)
        ab2 = Wr - E
        tb = np.clip(((q - E) @ ab2) / (ab2 @ ab2), 0, 1)
        cu, cl = S + np.outer(ta, ab), E + np.outer(tb, ab2)
        dd = np.linalg.norm(q - cu, axis=1) <= np.linalg.norm(q - cl, axis=1)
        closest = np.where(dd[:, None], cu, cl)
        tt = np.clip(((q - S) @ u) / m["L"], 0, 1)
        sm = lambda e0, e1, x: np.clip((x - e0) / (e1 - e0), 0, 1) ** 2 * (3 - 2 * np.clip((x - e0) / (e1 - e0), 0, 1))
        wgt = sm(0.06, 0.22, tt) * (1.0 - sm(0.66, 0.74, tt))
        q = closest + (q - closest) * (1.0 - (1.0 - SLIM) * wgt)[:, None]
        q[:, 0] += s * WIDEN
        P[sel] = q
        # Shoulder and upper chest beside the arm follow part of the way.
        rest = np.setdiff1d(np.arange(len(P)), sel)
        dsh = np.linalg.norm(P[rest] - S, axis=1)
        fall = np.clip(1.0 - dsh / (0.09 * HEIGHT), 0, 1) ** 2 * (P[rest][:, 0] * s > 0.02)
        P[rest, 0] += s * WIDEN * fall
        S, E, Wr, T = S + [s * WIDEN, 0, 0], E + [s * WIDEN, 0, 0], Wr + [s * WIDEN, 0, 0], T + [s * WIDEN, 0, 0]
        place("clavicle" + sx, wpos(eb["clavicle" + sx].head), S)
    ARM_SET[sx] = set(arm_set.tolist())
    hv = arm_set[((P[arm_set] - Wr) @ u) > -0.004]
    h = T - Wr
    hl = np.linalg.norm(h)
    h = h / hl
    w = FWD - h * (FWD @ h)
    w = w / np.linalg.norm(w)
    ah = (P[hv] - Wr) @ h
    cw = (P[hv] - Wr) @ w
    HAND_SET[sx] = set(hv.tolist())
    distal = ah > 0.7 * hl
    front = np.percentile(cw[distal], 96) if distal.sum() > 10 else 0.0
    thumb = hv[(ah < 0.8 * hl) & (ah > 0.12 * hl) & (cw > front + 0.004)]
    fing = (ah > 0.55 * hl) & ~np.isin(hv, thumb)
    knuckles = []
    if fing.sum() > 40:
        c_lo, c_hi = np.percentile(cw[fing], 2), np.percentile(cw[fing], 98)
        span = max(c_hi - c_lo, 1e-4)
        for i, f in enumerate(("index", "middle", "ring", "pinky")):
            top = c_hi - span * i / 4.0
            mm = fing & (cw <= top + 1e-6) & (cw >= top - span / 4.0)
            if mm.sum() < 5:
                continue
            fp, fa = P[hv][mm], ah[mm]
            tip = fp[np.argmax(fa)]
            kn_m = fa < 0.64 * hl
            K = fp[kn_m].mean(axis=0) if kn_m.sum() >= 3 else Wr + h * 0.55 * hl + w * (top - span / 8.0)
            knuckles.append(K)
            place(f + "_01" + sx, K, K + (tip - K) * 0.42)
            place(f + "_02" + sx, K + (tip - K) * 0.42, K + (tip - K) * 0.72)
            place(f + "_03" + sx, K + (tip - K) * 0.72, tip)
    if len(thumb) >= 15:
        tp = P[thumb]
        ta = (tp - Wr) @ h
        base = tp[ta <= np.percentile(ta, 15)].mean(axis=0)
        tip = tp[np.argmax(np.linalg.norm(tp - base, axis=1))]
        place("thumb_01" + sx, base, base + (tip - base) * 0.4)
        place("thumb_02" + sx, base + (tip - base) * 0.4, base + (tip - base) * 0.7)
        place("thumb_03" + sx, base + (tip - base) * 0.7, tip)
    K = np.mean(knuckles, axis=0) if knuckles else Wr + h * 0.5 * hl
    place("upperarm" + sx, S, E)
    place("lowerarm" + sx, E, Wr)
    place("hand" + sx, Wr, K)
    print("ARMFIT", sx, "len %.2f elbow %.2f wrist %.2f hand %.2f fingers %d thumb %d arm-verts %d" % (
        m["L"], np.linalg.norm(E - S), np.linalg.norm(Wr - S), hl, len(knuckles), len(thumb), len(arm_set)))
bpy.ops.object.mode_set(mode="OBJECT")
inv = body.matrix_world.inverted()
for v in body.data.vertices:
    v.co = inv @ Vector(tuple(P[v.index]))
body.data.update()

# Skin: weights from distance to the (fitted) bone segments, each vertex choosing only among the
# bones its region may use: arm bones for arm vertices, finger bones for hand vertices.
body.parent = None
for g in list(body.vertex_groups):
    body.vertex_groups.remove(g)
names = [vg.name for vg in donor.vertex_groups if vg.name in arm.data.bones]
segs = []
for n in names:
    b = arm.data.bones[n]
    segs.append((n, arm.matrix_world @ b.head_local, arm.matrix_world @ b.tail_local))
for n in names:
    body.vertex_groups.new(name=n)


def allowed(n, vi):
    side = n[-2:]
    if n.startswith(FINGER):
        return vi in HAND_SET.get(side, ())
    if n.startswith(("upperarm", "lowerarm", "hand")):
        return side not in ARM_SET or vi in ARM_SET[side]
    return True


nv = len(body.data.vertices)
W = np.zeros((nv, len(names)))
col = {n: i for i, n in enumerate(names)}
for v in body.data.vertices:
    p = body.matrix_world @ v.co
    ds = sorted(((seg_dist(p, a, b), n) for n, a, b in segs if allowed(n, v.index)))[:4]
    d0 = ds[0][0]  # only bones about as near as the nearest one count (no pull from far limbs)
    for d, n in ds:
        if d - d0 < 0.12:
            W[v.index, col[n]] = 1.0 / (d + 0.05) ** 1.5
W /= W.sum(axis=1, keepdims=True)

# Smooth the weights over the surface so they change gradually (no strips along limbs). Vertices that
# sit at the same place (split at UV seams) are welded for this, so they keep identical weights.
weld, nbr, nw = WELD, NBR, len(NBR)
Wk = np.zeros((nw, len(names)))
Wk[weld] = W
for _ in range(12):
    nxt = Wk.copy()
    for i in range(nw):
        if nbr[i]:
            nxt[i] = 0.5 * Wk[i] + 0.5 * np.mean([Wk[j] for j in nbr[i]], axis=0)
    Wk = nxt
W = Wk[weld]
for vi in range(nv):
    for n, i in col.items():
        if W[vi, i] > 0.01:
            body.vertex_groups[n].add([vi], float(W[vi, i]), "REPLACE")
bpy.data.objects.remove(donor, do_unlink=True)
body.parent = arm
body.matrix_parent_inverse = arm.matrix_world.inverted()
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm
unweighted = sum(1 for v in body.data.vertices if not any(g.weight > 0.001 for g in v.groups))
print("SKIN groups", len(body.vertex_groups), "verts", len(body.data.vertices), "unweighted", unweighted)
# Weights are a pure function of position, so vertices split at UV seams stay together (smoothing
# over mesh connectivity would pull them apart and tear the mesh when posed).
bpy.context.view_layer.objects.active = body
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)

bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_skins=True, export_apply=False, export_yup=True,
                          export_image_format="JPEG", export_image_quality=88)
print("wrote", OUT)
