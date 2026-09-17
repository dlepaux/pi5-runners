# pi5-runners CAD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the parametric OpenSCAD case for three Raspberry Pi 5 GitHub runners, with a test harness that proves nothing collides and the airflow path is not choked.

**Architecture:** Every dimension lives in `cad/config.scad`; part files read it and never hardcode. The four printed parts (`base`, `shell`, `roof`, `filter`) are cut from one shell solid. Board geometry comes from the `SBC_Model_Framework` submodule; the two M.2 HATs are project-local parametric geometry built from the official product-brief drawings. Mesh assets follow **hexrack's** pattern: prepared offline into closed manifolds by a committed generator script, normalised, with their extents declared in `config.scad` and asserted against whatever consumes them.

**Tech Stack:** OpenSCAD nightly with the Manifold backend, bash test harness, Python 3 for mesh statistics.

**Spec:** [`docs/superpowers/specs/2026-09-17-pi5-runners-design.md`](../specs/2026-09-17-pi5-runners-design.md)

## Global Constraints

- **Single configuration.** No variant matrix, no board-selection parameter.
- **Every dimension in `cad/config.scad`.** Never hardcode a number in a part file.
- mm units, never imperial. PETG.
- OpenSCAD nightly + `--backend=Manifold`. Local binary: `/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD`.
- **`--export-format=binstl` always.** The ASCII default parses as a garbage triangle count in the hundreds of millions.
- **`include` for constants, `use` for modules only.** `use` imports modules and functions but NOT variables; a constant read through `use` is `undef` and only a `WARNING:` says so.
- OpenSCAD does not hoist. A variable read above its own assignment in the same file is `undef`.
- Conventional Commits. Commit messages explain **why**.
- Case interior must hold **0–50 °C ambient**, the M.2 HAT+'s rated range.
- **Mesh assets are prepared, not quarantined** (hexrack's pattern). A committed script
  meshes or repairs each asset into a closed manifold; `config.scad` declares what was
  generated; the consumer asserts it fits. An asset that cannot be closed does not get a
  warning comment — it gets fixed or it does not land.
- Vendor CAD is not covered by this project's licence and is never published as a
  printable STL.

### Frozen constants (from the spec — copy verbatim into `config.scad`)

| Name | Value | Source |
|------|-------|--------|
| `pi5_pcb` | `[85, 56, 1.65]` | framework `rpi5` |
| `pi5_hole_pattern` | `[58, 49]`, inset `3.5`, Ø`2.7` | framework `rpi5` |
| `active_cooler_h` | `11.0` above PCB top | framework `rpi5_oem` — **unverified, see spec** |
| `hat_stack_h` | `16` | supplied stacking header |
| `hat_pcb_t` | `1.6` | standard |
| `hat_standard_size` | `[65, 56.5]` | product brief |
| `hat_compact_size` | `[71.5, 56.5]`, 65 at header edge | product brief |
| `drive_t` | `2.3` | M.2 single-sided module |
| `screw_head` | `2` | supplied knurled retaining screw |
| `slot_standoff` | `[30, 30]` | 20+10 from stock |
| `base_standoff` | `10` | microSD clearance + fan sweep + cable comb |
| `roof_air` | `8` | |
| `wall` | `3` | |
| `fan_size` | `80`, depth `25`, bolt pitch `71.5` | NF-A8 5V PWM |

---

### Task 1: Project skeleton, submodule, and the board-constants test

The first task is the one that proves the toolchain works end to end. It ends with a
green test that fails if the Pi 5 constants ever drift from the framework's model.

**Files:**
- Create: `.gitignore`, `license.md`, `readme.md`, `CLAUDE.md`
- Create: `scripts/lib/openscad-env.sh` (copied from `../naja-miner/scripts/lib/openscad-env.sh`)
- Create: `scripts/lib/stl-stats.py` (copied from `../naja-miner/scripts/lib/stl-stats.py`)
- Create: `cad/config.scad`, `cad/tests.scad`
- Create: `scripts/test-board-assets.sh`
- Submodule: `cad/SBC_Model_Framework`

**Interfaces:**
- Consumes: nothing.
- Produces: `config.scad` constants `pi5_pcb`, `pi5_hole_pattern`, `pi5_hole_inset`,
  `pi5_hole_d`, `active_cooler_h`, `EPS`, `wall`, `tolerance`.
  `tests.scad` exposes the `test_view` string parameter.
  `openscad-env.sh` exposes `expect_empty`, `expect_geometry`, `expect_volume`,
  `render`, `vol`, `bounds`, `tris`, `pass`, `fail`, `note`, `report`.

- [ ] **Step 1: Add the submodule**

```bash
cd /Users/davidlepaux/WebServer/3d-print/pi5-runners
git submodule add https://github.com/dlepaux/SBC_Model_Framework.git cad/SBC_Model_Framework
git submodule update --init --recursive
```

Expected: `cad/SBC_Model_Framework/sbc_models.scad` exists.

- [ ] **Step 2: Copy the harness verbatim**

```bash
cp ../naja-miner/scripts/lib/openscad-env.sh scripts/lib/openscad-env.sh
cp ../naja-miner/scripts/lib/stl-stats.py    scripts/lib/stl-stats.py
```

Do **not** rewrite them. Every comment in `openscad-env.sh` documents a failure that
has already been paid for in a sibling project — notably that zero volume means
*touching* and passes, while enclosed volume is interference and fails.

- [ ] **Step 3: Write `cad/config.scad` with the board block**

```openscad
// ============================================================================
// PI5-RUNNERS — CONFIGURATION
// ============================================================================
// Single source of truth for every dimension. Never hardcode in part files.
// ============================================================================

EPS       = 0.01;
OVERLAP   = 0.1;
tolerance = 0.4;
$fn       = 64;
wall      = 3;

// ----------------------------------------------------------------------------
// RASPBERRY PI 5 — mirrors SBC_Model_Framework's rpi5 entry.
// scripts/test-board-assets.sh is what notices if these drift.
// ----------------------------------------------------------------------------
pi5_pcb          = [85, 56, 1.65];
pi5_hole_pattern = [58, 49];
pi5_hole_inset   = 3.5;
pi5_hole_d       = 2.7;

// The Active Cooler's top, above the PCB's TOP face. Derived from the framework's
// rpi5_oem model, NOT measured on real hardware. It sets slot 2's custom standoff and
// therefore the whole stack, so it is the first thing to re-measure if parts fight.
active_cooler_h  = 11.0;
```

- [ ] **Step 4: Write `cad/tests.scad` with the board envelope view**

```openscad
// ============================================================================
// TESTS — geometry views for scripts/test-*.sh
// ============================================================================
// Not a part. Views render either to nothing (which is the pass for a clearance
// check) or to one solid whose volume or bounding box the shell script reads.
//
//   openscad -D 'test_view="pi5-envelope"' cad/tests.scad
// ============================================================================

include <config.scad>

test_view = "";

// The Pi 5's PCB as a bare slab, built from DECLARED CONSTANTS so the fit checks
// never depend on the framework mesh being manifold.
module pi5Pcb() {
  cube(pi5_pcb);
}

if (test_view == "pi5-envelope") pi5Pcb();
```

- [ ] **Step 5: Write the failing test `scripts/test-board-assets.sh`**

```bash
#!/bin/bash
# Ties config.scad's declared Pi 5 constants back to the framework's own rpi5 model.
# Without this, the submodule can be updated under us and every fit test stays green
# while describing a board that no longer exists.
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Board constants vs SBC_Model_Framework"

CFG="cad/SBC_Model_Framework/sbc_models.cfg"

check_cfg() {
    local label="$1" pattern="$2"
    if grep -q "$pattern" "$CFG"; then pass "$label"; else fail "$label — not found: $pattern"; fi
}

# The rpi5 pcb line declares [85,56,1.65] as its size vector.
check_cfg "rpi5 PCB is 85 x 56 x 1.65" '"pcb","rectangle",0,0,0,0,"top",\[0,0,0\],\[85,56,1.65\]'
# Mounting holes at the 58 x 49 pattern, 3.5 in from each edge.
check_cfg "mounting hole left_rear  @ 3.5, 3.5"   '0,3.5,3.5,0,.*left_rear'
check_cfg "mounting hole left_front @ 3.5, 52.5"  '0,3.5,52.5,0,.*left_front'
check_cfg "mounting hole right_rear @ 61.5, 3.5"  '0,61.5,3.5,0,.*right_rear'
check_cfg "mounting hole right_front @ 61.5, 52.5" '0,61.5,52.5,0,.*right_front'
# The Active Cooler this project sizes its stack around.
check_cfg "rpi5_oem Active Cooler present"        '"heatsink","rpi5_oem"'

# The envelope view must render, and must be the declared board volume.
expect_volume "pi5 envelope renders at declared size" pi5-envelope 7800 \
  "85 x 56 x 1.65 = 7854mm3"

report "board asset checks"
```

- [ ] **Step 6: Run it and watch it fail**

```bash
chmod +x scripts/test-board-assets.sh && ./scripts/test-board-assets.sh
```

Expected: FAIL — `cad/tests.scad` does not yet exist, or the submodule is empty.
Fix whichever it reports, then continue. A pass here means OpenSCAD, the Manifold
backend, the binstl export and the submodule are all working.

- [ ] **Step 7: Run it and watch it pass**

```bash
./scripts/test-board-assets.sh
```

Expected: `✅ board asset checks passed (7/7)`

- [ ] **Step 8: Write `.gitignore`, `license.md`, `readme.md`, `CLAUDE.md`**

`.gitignore` must exclude `stl/`, `dist/`, `node_modules/`, `.test-work.*`, `.DS_Store`.
`CLAUDE.md` follows `naja-miner`'s: project intent, hardware target, conventions,
build/test commands, and an **OpenSCAD traps** section carrying forward at minimum:
`use` does not import variables; no hoisting; `--export-format=binstl`; empty render is
the pass for a clearance check; `render()` inside panel modules or preview blows up;
test both presence and absence; two parts never render together so collisions are
invisible until a boolean is rendered.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: project skeleton, SBC framework submodule, board-constants test

The framework can be updated under us. Without a check tying config.scad's
declared Pi 5 geometry back to sbc_models.cfg, every fit test stays green while
describing a board that no longer exists."
```

---

### Task 2: M.2 HAT+ geometry, both variants

The framework has no HAT models — verified by grep across every `.scad` in it. Both
HATs are built here from the official product-brief drawings. They are **parametric,
not imported meshes**, because they take part in clearance booleans and because the
drawings give exact numbers: 65 × 56.5, the Compact's 71.5 overall, and a hole pattern
identical to the Pi 5's.

If a clean, licence-clear HAT mesh surfaces later, it slots in as *additional*
showcase geometry via `hexrack-sbc/cad/lib/pironman-base.scad`'s pattern — a
parametric base plus an imported vendor mesh for the part that is hard to draw. It
does not replace the parametric geometry, which is what the booleans need.

**Files:**
- Create: `cad/lib/m2-hat-plus.scad`
- Modify: `cad/config.scad` (HAT block)
- Modify: `cad/tests.scad` (HAT views)
- Create: `scripts/test-fit.sh`

**Interfaces:**
- Consumes: `config.scad` constants from Task 1.
- Produces:
  - `hatStandardOutline()` — 2D, 65 × 56.5, origin at the board's left-rear corner,
    aligned to the Pi's footprint.
  - `hatCompactOutline()` — 2D, the L-shape: 65 across the header edge, 71.5 overall.
  - `hatStandardSolid()` / `hatCompactSolid()` — 3D, PCB plus the M.2 module and its
    retaining screw, origin at the **Pi's** PCB top face, raised by `hat_stack_h`.
  - `config.scad` constants `hat_stack_h`, `hat_pcb_t`, `hat_standard_size`,
    `hat_compact_size`, `drive_t`, `screw_head`, `hat_slot_h`, `bare_slot_h`.

- [ ] **Step 1: Add the HAT block to `cad/config.scad`**

```openscad
// ----------------------------------------------------------------------------
// M.2 HAT+ — from the official product brief (RP-009234-MM), NOT from the
// SBC_Model_Framework, which has no HAT geometry at all.
// ----------------------------------------------------------------------------
hat_pcb_t          = 1.6;
hat_standard_size  = [65, 56.5];
hat_compact_size   = [71.5, 56.5];   // L-shaped; 65 across the header edge
hat_compact_header_w = 65;

// The supplied stacking header. This is THE number that clears the Active Cooler,
// and it is why the standard HAT+ works over the cooler and the Compact does not.
// Slot 2 raises the Compact to the same 16 with a custom standoff stack.
hat_stack_h        = 16;

drive_t            = 2.3;   // M.2 single-sided module
screw_head         = 2;     // supplied knurled double-flanged retaining screw

// Slot occupied height, measured from the board's PCB UNDERSIDE.
hat_slot_h  = pi5_pcb[2] + hat_stack_h + hat_pcb_t + drive_t + screw_head;  // 23.55
bare_slot_h = pi5_pcb[2] + active_cooler_h;                                 // 12.65

// The custom standoff for slot 2 is derived, never typed: it must clear the cooler.
compact_standoff_h = hat_stack_h;
assert(compact_standoff_h >= active_cooler_h + 3,
       "slot 2 standoff must clear the Active Cooler by at least 3mm");
```

- [ ] **Step 2: Write the failing fit test `scripts/test-fit.sh`**

```bash
#!/bin/bash
# Nothing collides, everything reaches.
# OpenSCAD has no notion of a collision: two parts never render together, so every
# interference in a project like this is invisible until a boolean is rendered.
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Fit — clearances"

expect_empty   "Active Cooler clears the standard HAT+"  cooler-vs-hat-standard
expect_empty   "Active Cooler clears the Compact HAT+"   cooler-vs-hat-compact
expect_geometry "standard HAT+ outline renders"          hat-standard-outline
expect_geometry "Compact HAT+ outline renders"           hat-compact-outline

report "fit checks"
```

- [ ] **Step 3: Run it and watch it fail**

```bash
chmod +x scripts/test-fit.sh && ./scripts/test-fit.sh
```

Expected: FAIL on all four — the views do not exist yet, so each renders empty.
Note that `expect_empty` would *pass* on a missing view; that is why the two
`expect_geometry` checks are in the same file. **Emptiness checks alone cannot see a
part that is missing.**

- [ ] **Step 4: Write `cad/lib/m2-hat-plus.scad`**

Build both outlines as 2D profiles from the product-brief numbers, then
`linear_extrude` them. The Compact's L-shape is the 71.5 × 56.5 rectangle with the
corner removed so the area above the SoC stays open. Place both at
`translate([0, 0, pi5_pcb[2] + hat_stack_h])` relative to the Pi's PCB underside, so
that the caller only ever positions the Pi.

The mounting-hole pattern is **identical to the Pi 5's** — `pi5_hole_pattern` at
`pi5_hole_inset` — which is what lets the HAT stack straight up. Read those constants
rather than retyping 58/49/3.5; two features doing their own arithmetic on the same
datum will disagree.

- [ ] **Step 5: Add the HAT views to `cad/tests.scad`**

```openscad
use <lib/m2-hat-plus.scad>

// The Active Cooler as a conservative envelope: its full footprint swept to its full
// height. Deliberately an over-estimate against the HAT above it.
module coolerEnvelope() {
  translate([pi5_hole_inset, pi5_hole_inset, pi5_pcb[2]])
    cube([58, 40, active_cooler_h]);
}

if (test_view == "cooler-vs-hat-standard")
  intersection() { coolerEnvelope(); hatStandardSolid(); }
if (test_view == "cooler-vs-hat-compact")
  intersection() { coolerEnvelope(); hatCompactSolid(); }
if (test_view == "hat-standard-outline") linear_extrude(1) hatStandardOutline();
if (test_view == "hat-compact-outline")  linear_extrude(1) hatCompactOutline();
```

- [ ] **Step 6: Run it and watch it pass**

```bash
./scripts/test-fit.sh
```

Expected: `✅ fit checks passed (4/4)`. If `cooler-vs-hat-compact` fails with an
enclosed volume, `compact_standoff_h` is too low — that is the spec's known
unresolved item surfacing, and it means the fallback roof fan is needed.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(hat): add M.2 HAT+ standard and Compact geometry

The SBC framework has no HAT models, so both are built from the official product
brief. The Compact cannot take the Active Cooler as supplied; raising it to the
standard HAT+'s 16mm stacking header is what clears it, and the assert in
config.scad is what holds that."
```

---

### Task 3: The stack — placement and z datums

**Files:**
- Create: `cad/lib/placement.scad`
- Modify: `cad/config.scad` (stack block)
- Modify: `cad/tests.scad`, `scripts/test-fit.sh`

**Interfaces:**
- Consumes: Task 2's `hat_slot_h`, `bare_slot_h`, `compact_standoff_h`.
- Produces: `board_z` (3-element vector of PCB-underside z), `stack_top`,
  `interior_h`, `interior_x`, `interior_y`; modules `onBoard(i)` placing children in
  board *i*'s frame, and `boardSlab(i)` giving slot *i*'s occupied envelope.

- [ ] **Step 1: Add the stack block to `cad/config.scad`**

```openscad
// ----------------------------------------------------------------------------
// THE STACK — derived, never typed. Changing a standoff moves everything.
// ----------------------------------------------------------------------------
base_standoff = 10;   // microSD clearance + keeps the fan's sweep off the floor
                      // + leaves the cable comb somewhere to live
slot_standoff = [30, 30];   // PCB top -> next PCB underside, for slots 1->2 and 2->3
roof_air      = 8;

board_z = [
  base_standoff,
  base_standoff + pi5_pcb[2] + slot_standoff[0],
  base_standoff + pi5_pcb[2] + slot_standoff[0] + pi5_pcb[2] + slot_standoff[1],
];

stack_top  = board_z[2] + bare_slot_h;      // 85.95 — slot 3 is the bare Pi
interior_h = stack_top + roof_air;          // 93.95

// Both HAT slots must have air above the drive, or the fan has no channel to push
// through. 8.1mm at the declared standoffs.
assert(slot_standoff[0] >= hat_slot_h - pi5_pcb[2] + 4,
       "slot 1 standoff leaves no air channel above the drive");
assert(slot_standoff[1] >= hat_slot_h - pi5_pcb[2] + 4,
       "slot 2 standoff leaves no air channel above the drive");
```

- [ ] **Step 2: Add the failing checks to `scripts/test-fit.sh`**

```bash
expect_empty "slot 1 stack clears slot 2's board"  slot1-vs-slot2
expect_empty "slot 2 stack clears slot 3's board"  slot2-vs-slot3
expect_empty "slot 3 cooler clears the roof"       slot3-vs-roof
```

- [ ] **Step 3: Run and watch the three new checks fail**

```bash
./scripts/test-fit.sh
```

Expected: 4 pass, 3 fail with "no such view".

- [ ] **Step 4: Write `cad/lib/placement.scad` and the three views**

`onBoard(i)` translates children to `[board_x, board_y, board_z[i]]`. `boardSlab(i)`
returns slot *i*'s occupied envelope — the PCB outline swept from its underside to
`hat_slot_h` for slots 0 and 1, `bare_slot_h` for slot 2.

**An envelope carries the question it was built for.** `boardSlab()` is correct for
"does slot *i* touch the shell" and useless for anything finer; do not reuse it to
test the fan's clearance, which is entitled to the air above each cooler.

- [ ] **Step 5: Run and watch all seven pass**

```bash
./scripts/test-fit.sh
```

Expected: `✅ fit checks passed (7/7)`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(placement): derive the board stack from standoff heights

interior_h is derived from the stack rather than typed, so a slot that grows
fails an assert instead of silently pushing the top board out of the airstream."
```

---

### Task 4: Noctua NF-A8 — prepared mesh asset, hexrack-style

This is the "use STL files cleanly" task. **Follow hexrack, not naja-miner.**

hexrack prepares each mesh asset offline into a closed manifold with a committed
generator script, normalises it, declares in `config.scad` what was generated, and
asserts the consumer fits inside that. `assets/gyroid-tunnels.stl` is *subtracted* to
cut the face vents — a mesh asset carrying its weight in CSG, which naja-miner's
never could. `lib/pironman-base.scad` imports a vendor adapter mesh the same way.

naja-miner's alternative — two representations of one fan plus a vertex-by-vertex
reconciliation suite — exists only because its vendor meshes were never repaired.
Do not reproduce that machinery here. Repair the mesh once, up front.

The fan bore and bolt pattern stay **parametric** regardless: you cut a bore from
declared dimensions, you do not subtract a fan. The mesh is for the showcase.

**Files:**
- Create: `cad/lib/noctua-fan.scad`, `cad/assets/noctua/readme.md`
- Create: `scripts/generate-fan-asset.py`, `scripts/test-assets.sh`
- Modify: `cad/config.scad` (fan block)

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `fanBore()`, `fanBoltPattern()`, `fanVisualization80()`; `config.scad`
  constants `fan_size = 80`, `fan_depth = 25`, `fan_bolt_pitch = 71.5`, `fan_hub_d`,
  `fan_throat_area`, `fan_asset`, `fan_asset_extent`.

- [ ] **Step 1: Add the fan block to `cad/config.scad`**

```openscad
// ----------------------------------------------------------------------------
// FAN — Noctua NF-A8 5V PWM. 55.5 m3/h, 17.7 dB(A), 0.75W at 5V, USB-powered.
// At 80mm it spans the whole board stack, which is why this case has no plenum.
// ----------------------------------------------------------------------------
fan_size       = 80;
fan_depth      = 25;
fan_bolt_pitch = 71.5;   // standard 80mm pattern. NOT the Compact HAT's 71.5 width.
fan_hub_d      = 30;

fan_throat_area = PI * pow(fan_size, 2) / 4 - PI * pow(fan_hub_d, 2) / 4;  // ~4320

// THE COMMITTED ASSET. These describe what scripts/generate-fan-asset.py actually
// produced; changing one without regenerating silently mis-places the fan, so
// lib/noctua-fan.scad asserts the declared envelope matches fan_size/fan_depth.
fan_asset        = "../assets/noctua/NF-A8.stl";
fan_asset_extent = [80, 25, 80];   // as generated: X, Y (axis), Z
```

- [ ] **Step 2: Write `scripts/generate-fan-asset.py`**

Modelled on `../hexrack-sbc/scripts/generate-gyroid-asset.py`. It takes Noctua's
published STEP from
`https://www.noctua.at/en/products/nf-a8-5v-pwm/downloads`, keeps the largest solid
(the frame), tessellates at 0.3 mm deflection, **repairs the mesh to a closed
manifold**, and rotates it into this project's convention: axis along −Y (the fan
blows from the +Y wall toward the boards), mounting face at the wall, centred on X
and Z. It writes `cad/assets/noctua/NF-A8.stl` and prints the resulting bounding box
so `fan_asset_extent` can be filled from the run, not guessed.

**The mesh must come out closed.** That is the whole point of the hexrack pattern: a
mesh that cannot be closed is a mesh that has to be quarantined, and quarantine is
what we are avoiding. `mesh-repair.py` exists in the sibling for exactly this.

- [ ] **Step 3: Write the asset readme with the licence**

`cad/assets/noctua/readme.md`: the download URL, the generator script that produced
the file, the tessellation deflection, the orientation convention, and Noctua's
licence quote verbatim from <https://www.noctua.at/en/3d-cad-models>. State plainly
that the mesh is not covered by this project's licence, is not a printable part, and
is never included in the STLs the website publishes.

- [ ] **Step 4: Write the failing `scripts/test-assets.sh`**

```bash
#!/bin/bash
# Mesh assets are closed and are the size config.scad says they are.
# hexrack's lesson: declare what was generated, then assert the consumer fits.
# An asset whose declared extent has drifted from the file mis-places every feature
# derived from it, and nothing else in the suite can see that.
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Mesh assets"

MESH="cad/assets/noctua/NF-A8.stl"
if [ -f "$MESH" ]; then pass "NF-A8 mesh present"
else fail "NF-A8 mesh missing — run scripts/generate-fan-asset.py"; report "asset checks"; fi

# Closed manifold, or it cannot be used in CSG and the hexrack pattern is broken.
G=$(genus "$MESH")
if [ "$G" != "-1" ]; then pass "NF-A8 mesh is closed (genus $G)"
else fail "NF-A8 mesh is not a closed manifold — repair it in generate-fan-asset.py"; fi

# One body, not a shell of loose surfaces.
N=$(comps "$MESH")
if [ "$N" = "1" ]; then pass "NF-A8 mesh is one body"; else fail "NF-A8 mesh is $N bodies"; fi

# The declared extent must match the file, within a tessellation tolerance.
expect_empty    "mesh fits inside its declared fan_asset_extent" fan-asset-vs-extent
expect_geometry "fan visualization renders"                      fan-visualization

report "asset checks"
```

- [ ] **Step 5: Run, generate, run again**

```bash
chmod +x scripts/test-assets.sh
./scripts/test-assets.sh          # expect FAIL: mesh missing
python3 scripts/generate-fan-asset.py
./scripts/test-assets.sh          # expect PASS
```

- [ ] **Step 6: Write `cad/lib/noctua-fan.scad`**

Three modules. `fanBore()` and `fanBoltPattern()` are **parametric** — you cut a bore
from `fan_size` and a bolt pattern from `fan_bolt_pitch`, never by subtracting a
mesh. `fanVisualization80()` imports `fan_asset`, coloured, for the showcase only,
the way `hexrack-sbc/cad/components/fan.scad` does it:

```openscad
// % is the BACKGROUND modifier: drawn in preview, dropped from the final render.
// This is what keeps Noctua's mesh out of every STL this project publishes.
// Do not use # — that is the debug modifier and it IS included in the export.
module fanVisualization80() {
  %color("SaddleBrown", 1)
    import(fan_asset, center = true);
}

assert(fan_asset_extent[0] == fan_size && fan_asset_extent[2] == fan_size,
       "fan_asset_extent disagrees with fan_size — regenerate the asset");
assert(fan_asset_extent[1] == fan_depth,
       "fan_asset_extent disagrees with fan_depth — regenerate the asset");
```

**`import()` resolves against the MAIN document, not the calling file.** A relative
path in a lib file finds a different directory depending on which `.scad` is open,
and `generate-stl.sh` renders every part standalone. Keep `fan_asset` in
`config.scad` and keep the only `import()` of it in this one module.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(fan): add NF-A8 mesh asset, prepared and asserted

Follows hexrack rather than naja-miner: the mesh is repaired to a closed manifold
by a committed generator, config.scad declares what was generated, and the asset
test holds the two together. No second representation to keep in sync."
```

---

### Task 5: Shell solid and the three structural parts

**Files:**
- Create: `cad/lib/shell.scad`, `cad/parts/base.scad`, `cad/parts/shell.scad`, `cad/parts/roof.scad`
- Modify: `cad/config.scad` (envelope block), `cad/tests.scad`
- Create: `scripts/test-parts.sh`

**Interfaces:**
- Consumes: Task 3's `interior_h`, `board_z`; Task 4's `fan_size`.
- Produces: `shellSolid()`, `shellPanel(which)` for `"base" | "shell" | "roof"`;
  `config.scad` constants `interior_x`, `interior_y`, `outer`.

- [ ] **Step 1: Add the envelope block to `cad/config.scad`**

```openscad
// ----------------------------------------------------------------------------
// ENVELOPE
// ----------------------------------------------------------------------------
port_overhang  = 3;    // RJ45 and the USB-A stacks stand proud of the PCB edge
board_clear    = 7;
fan_plenum     = 8;    // fan face to the board's +Y edge
exhaust_gap    = 8;    // board's -Y edge to the wall

interior_x = pi5_pcb[0] + port_overhang + board_clear;              // 95
interior_y = fan_depth + fan_plenum + pi5_pcb[1] + exhaust_gap;     // 97
outer      = [interior_x + 2 * wall, interior_y + 2 * wall, interior_h + 2 * wall];

// THE FAN MUST FACE THE WHOLE STACK. This is the invariant that let the side plenum
// be deleted: an 80mm bore centred in a 94mm interior spans z 7..87, and the boards
// span z 10..85.95. If a slot ever grows, this fails rather than quietly leaving the
// top board out of the airstream.
fan_z0 = (interior_h - fan_size) / 2;
assert(fan_z0 <= board_z[0], "fan does not reach the bottom board");
assert(fan_z0 + fan_size >= stack_top, "fan does not reach the top of the stack");
```

- [ ] **Step 2: Write the failing `scripts/test-parts.sh`**

```bash
#!/bin/bash
# One body per part, holes cut in both directions, no stray bodies.
# A cylinder tangent to a plane is NOT attached to it: a boss centred exactly half a
# boss off the panel it stands on meets it along a LINE, renders fine, previews fine,
# and exports as a plate plus loose pucks. Counting bodies is what catches it.
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Parts — one body each"

one_body() {
    local label="$1" view="$2"
    local out="$WORK/$view.stl"
    render "$view" "$out"
    if grep -qE "ERROR:|WARNING:" "$out.log"; then
        fail "$label — errors during render"
        grep -E "ERROR:|WARNING:" "$out.log" | head -3 | sed 's/^/       /'
        return 1
    fi
    local n; n=$(comps "$out")
    if [ "$n" = "1" ]; then pass "$label (1 body)"; else fail "$label — $n bodies, expected 1"; fi
}

one_body "base is one body"  part-base
one_body "shell is one body" part-shell
one_body "roof is one body"  part-roof

report "part checks"
```

- [ ] **Step 3: Run and watch all three fail**

```bash
chmod +x scripts/test-parts.sh && ./scripts/test-parts.sh
```

Expected: FAIL ×3, "0 bodies".

- [ ] **Step 4: Write `cad/lib/shell.scad` and the three part files**

```openscad
// One solid, cut three ways. Each part is the shell intersected with its own claim.
module shellSolid() {
  difference() {
    cube(outer);
    translate([wall, wall, wall]) cube([interior_x, interior_y, interior_h]);
  }
}

// A claim asks for a volume slightly LARGER than the part in both directions; a
// subtraction whose faces are exactly coincident with what it subtracts leaves a
// zero-volume skin that reads as one body with the right genus and a bounding box
// a fraction too wide.
function claim(which) =
  which == "base"  ? [[0, 0, 0],                       [outer[0], outer[1], wall]] :
  which == "roof"  ? [[0, 0, outer[2] - wall],         [outer[0], outer[1], wall]] :
                     [[0, 0, wall],                    [outer[0], outer[1], outer[2] - 2*wall]];

module shellPanel(which) {
  c = claim(which);
  render()                 // see below — NOT optional
    intersection() {
      shellSolid();
      translate(c[0] - [EPS, EPS, EPS]) cube(c[1] + [2*EPS, 2*EPS, 2*EPS]);
    }
}
```

`shellSolid()` is the whole outer box, hollowed to the interior. `shellPanel(which)`
intersects it with that panel's claim. **Put `render()` inside `shellPanel()`.**
OpenSCAD's preview does not evaluate booleans; it flattens the model into a sum of
products, which is exponential in nested differences, and a panel that is a shell
intersected with its claim and cut by its neighbours' can pass 100,000 elements — at
which point OpenSCAD aborts and shows a blank window while exporting perfectly the
whole time.

A claim asks for a boss slightly **larger** than the boss, in both directions. A
subtraction whose faces are exactly coincident with what it subtracts leaves a
zero-volume skin: one body, right genus, bounding box wrong.

- [ ] **Step 5: Run and watch all three pass**

```bash
./scripts/test-parts.sh
```

Expected: `✅ part checks passed (3/3)`

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(shell): add base, shell and roof cut from one shell solid

render() lives inside shellPanel() because preview does not evaluate booleans and
a panel cut by its neighbours' claims blows past OpenSCAD's normalisation limit —
blank window, perfect export, green suite."
```

---

### Task 6: Ports, vent fields, and the airflow invariant

**Files:**
- Create: `cad/lib/vents.scad`, `cad/lib/ports.scad`
- Modify: `cad/parts/shell.scad`, `cad/parts/roof.scad`, `cad/tests.scad`
- Create: `scripts/test-airflow.sh`

**Interfaces:**
- Consumes: Task 4's `fan_throat_area`; Task 3's `board_z`.
- Produces: `ventField(w, h)` and `ventOpenArea(w, h)` — the second returns the open
  area of the first in mm², so the test measures the same pattern the part is cut
  with rather than a re-derivation of it.

- [ ] **Step 1: Write the failing `scripts/test-airflow.sh`**

```bash
#!/bin/bash
# The intake must not be choked by the exhaust, and every port must line up with a
# cutout. Test BOTH directions: a hole that coincides with an opening in a vent
# pattern passes a present-check on its own. Check material is absent where it
# should be absent AND present where it should be present.
. "$(dirname "${BASH_SOURCE[0]}")/lib/openscad-env.sh"

echo "Airflow and ports"

AREA=$("$OPENSCAD" $BACKEND -o /dev/null \
        -D 'test_view="report-areas"' cad/tests.scad 2>&1 \
      | grep -oE 'exhaust_open_area = [0-9.]+' | grep -oE '[0-9.]+')
THROAT=$("$OPENSCAD" $BACKEND -o /dev/null \
        -D 'test_view="report-areas"' cad/tests.scad 2>&1 \
      | grep -oE 'fan_throat_area = [0-9.]+' | grep -oE '[0-9.]+')

if awk -v a="$AREA" -v t="$THROAT" 'BEGIN { exit !(a >= t) }'; then
    pass "$(printf 'exhaust %.0fmm2 >= fan throat %.0fmm2' "$AREA" "$THROAT")"
else
    fail "$(printf 'exhaust %.0fmm2 CHOKES the %.0fmm2 throat' "$AREA" "$THROAT")"
    note "widen the -Y vent field or the roof field; both feed the same budget"
fi

# Each board's ports must find open air, and the wall must still exist around them.
expect_empty    "slot 1 ports clear the -Y wall" ports-slot1-vs-wall
expect_empty    "slot 2 ports clear the -Y wall" ports-slot2-vs-wall
expect_empty    "slot 3 ports clear the -Y wall" ports-slot3-vs-wall
expect_empty    "slot 1 RJ45/USB clear the +X wall" rj45-slot1-vs-wall
expect_empty    "slot 2 RJ45/USB clear the +X wall" rj45-slot2-vs-wall
expect_empty    "slot 3 RJ45/USB clear the +X wall" rj45-slot3-vs-wall
expect_geometry "-Y wall still has material between the port cutouts" wall-y-remains
expect_geometry "+X wall still has material between the port cutouts" wall-x-remains

report "airflow and port checks"
```

- [ ] **Step 2: Run and watch it fail**

```bash
chmod +x scripts/test-airflow.sh && ./scripts/test-airflow.sh
```

Expected: FAIL — no `report-areas` view, no port views.

- [ ] **Step 3: Add the `report-areas` view to `cad/tests.scad`**

```openscad
if (test_view == "report-areas") {
  echo(str("fan_throat_area = ", fan_throat_area));
  echo(str("exhaust_open_area = ",
           ventOpenArea(vent_y_w, vent_y_h) + ventOpenArea(vent_roof_w, vent_roof_h)));
  cube(1);   // never let a reporting view render empty; empty is the pass elsewhere
}
```

- [ ] **Step 4: Add the vent block to `cad/config.scad`**

The `report-areas` view above reads these four; they do not exist yet.

```openscad
// ----------------------------------------------------------------------------
// VENTS — the exhaust budget. The -Y field and the roof field feed the same
// number, so either can be widened when test-airflow.sh says the intake chokes.
// ----------------------------------------------------------------------------
vent_cell    = 6;     // honeycomb across-flats
vent_wall    = 1.2;   // web between neighbouring cells

// The -Y field must dodge the three rows of USB-C/micro-HDMI cutouts, so it is
// sized to what is left of that wall rather than to the wall.
vent_y_w     = interior_x - 2 * vent_cell;
vent_y_h     = interior_h - 2 * vent_cell;
vent_roof_w  = interior_x - 2 * vent_cell;
vent_roof_h  = interior_y - 2 * vent_cell;
```

- [ ] **Step 5: Write `cad/lib/vents.scad` and `cad/lib/ports.scad`, cut them into the parts**

`ventField(w, h)` draws the honeycomb. `ventOpenArea(w, h)` returns its open area in
mm² **computed from the same cell count the field draws**, not from a closed-form
approximation of it — two features doing their own arithmetic on one datum will
disagree, and here the disagreement would be an airflow budget that is not real.

Port positions are read from the framework's `rpi5` connector entries, not retyped:
USB-C at x 6.75 and micro-HDMI at x 22.5 / 35.85 on the −Y wall; RJ45 and the two
USB-A stacks on the +X wall. Size each cutout from the connector plus `tolerance`.

Size the two vent fields so their combined open area clears `fan_throat_area`. The
roof field is not decoration — hot air rises and it is free area.

- [ ] **Step 6: Run and watch all nine pass**

```bash
./scripts/test-airflow.sh
```

Expected: `✅ airflow and port checks passed (9/9)`

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(vents): cut ports and vent fields, assert the exhaust budget

exhaust_open_area >= fan_throat_area is asserted against the same ventField() the
parts are cut with, not a re-derivation, so the two cannot drift."
```

---

### Task 7: Filter, cable comb, and board mounting

**Files:**
- Create: `cad/parts/filter.scad`, `cad/lib/screws.scad`
- Modify: `cad/parts/base.scad` (bosses, cable comb, feet), `cad/parts/roof.scad` (retainer)
- Modify: `scripts/test-fit.sh`, `scripts/test-parts.sh`

**Interfaces:**
- Consumes: Task 5's `shellPanel()`, Task 3's `board_z`.
- Produces: `filterFrame()`; base bosses on `pi5_hole_pattern` at `board_z[0]`.

- [ ] **Step 1: Add the failing checks**

```bash
# in scripts/test-fit.sh
expect_geometry "base bosses reach the bottom board"  bosses-reach-board
expect_empty    "filter clears the fan's blades"      filter-vs-fan
expect_geometry "cable comb renders"                  cable-comb

# in scripts/test-parts.sh
one_body "filter is one body" part-filter
```

- [ ] **Step 2: Run and watch them fail**

```bash
./scripts/test-fit.sh && ./scripts/test-parts.sh
```

- [ ] **Step 3: Implement**

Bosses `hull()` onto a wafer on the floor rather than standing tangent on it. Four
M2.5 inserts carry board 1; boards 2 and 3 stack on standoffs from it, so the base
carries the whole stack's weight through four points — check the boss diameter
against `pi5_hole_inset`, since a boss centred 3.5 mm from a corner can overhang the
wall.

The cable comb takes 3× Ethernet on +X and 3× USB-C on −Y. It exists so the bundle
cannot lever a 1 L case over.

- [ ] **Step 4: Run and watch them pass**

```bash
./scripts/test-fit.sh && ./scripts/test-parts.sh
```

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat(base): add board bosses, cable comb and the intake filter

Positive pressure means the intake is the only way dust enters, so it is the only
place that needs a filter."
```

---

### Task 8: Build pipeline, showcase, and the aggregate suite

**Files:**
- Create: `scripts/generate-stl.sh`, `scripts/test.sh`
- Create: `cad/case.scad` (assembly / showcase entry point)

**Interfaces:**
- Consumes: every part module.
- Produces: `stl/{base,shell,roof,filter}.stl` and `stl/showcase.stl`.

- [ ] **Step 1: Write `cad/case.scad`**

The assembly: three Pi 5s from the framework with their Active Coolers, both HATs,
`fanVisualization80()`, and the four printed parts. The showcase exists so the
website shows the real build, so use the framework's `sbc("rpi5")` with its
`rpi5_oem` heatsink rather than the bare envelopes `tests.scad` uses — the envelopes
are deliberate over-estimates and would make the render look wrong.

- [ ] **Step 2: Write `scripts/generate-stl.sh`**

Adapt `../naja-miner/scripts/generate-stl.sh`. Renders the four printed parts plus a
showcase. **`--export-format=binstl` on every invocation.**

Noctua's mesh must not be redistributed inside a published STL. Mark
`fanVisualization80()`'s import with OpenSCAD's **`%` background modifier**, which
draws it in preview and drops it from the final render — `#` is the *debug* modifier
and is still included in the export, so it does not do this job. Then assert it:
the showcase's triangle count with the fan module called must equal the count with it
commented out.

- [ ] **Step 3: Write `scripts/test.sh`**

Runs all five suites in order and fails if any does:

```bash
#!/bin/bash
# What CI runs.
set -uo pipefail
FAILED=0
for suite in board-assets assets fit parts airflow; do
    echo "=== $suite ==="
    "./scripts/test-$suite.sh" || FAILED=1
done
exit "$FAILED"
```

- [ ] **Step 4: Run the whole thing**

```bash
chmod +x scripts/generate-stl.sh scripts/test.sh
./scripts/test.sh
./scripts/generate-stl.sh --local
```

Expected: every suite green; `stl/` contains `base.stl`, `shell.stl`, `roof.stl`,
`filter.stl`, `showcase.stl`.

- [ ] **Step 5: Verify the parts actually fit the bed**

```bash
for f in stl/base.stl stl/shell.stl stl/roof.stl stl/filter.stl; do
  echo -n "$f: "; python3 scripts/lib/stl-stats.py "$f" --bboxes | head -1
done
```

Expected: every bounding box under 256 × 256 × 256. The shell is the tall one at
roughly 101 × 103 × 100.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: add STL pipeline, showcase assembly and the aggregate suite

case.scad is the only file permitted to touch the vendor fan mesh; every other
consumer takes the parametric proxy, because CSG against a non-manifold import
empties the whole object rather than failing."
```

---

## Out of scope for this plan

The website and CI/CD deploy are **deliberately deferred to a second plan**, to be
written once a real print proves the case. They add nothing the geometry can be
checked against, and the spec's known-unresolved items (`active_cooler_h`, the
Compact's stacking header) are settled by a print, not by a viewer.
