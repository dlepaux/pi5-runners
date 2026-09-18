# pi5-runners — three-Pi CI runner tower

**Date:** 2026-09-17
**Status:** implemented; revised 2026-09-18 — see *Revisions 2–4* at the end

## Goal

A single-configuration case holding three Raspberry Pi 5s that act as self-hosted
GitHub Actions runners. The load is sustained: 100% on all four cores for 30–50
minutes at a stretch, with NVMe traffic throughout. The case exists to keep the
boards at a temperature where they do not thermally throttle through a long job.

Standalone project, following the [`lab-router`](../../../../lab-router/) and
[`naja-miner`](../../../../naja-miner/) pattern — not a variant of
[`hexrack-sbc`](../../../../hexrack-sbc/), and a **single configuration**, no
variant matrix.

## Hardware target

| Slot | Board | Storage adapter | Cooling |
|------|-------|-----------------|---------|
| 1 (bottom) | Pi 5 | Raspberry Pi M.2 HAT+ (2242) | Active Cooler |
| 2 (middle) | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230) | Active Cooler, on custom standoffs |
| 3 (top) | Pi 5 | none | Active Cooler |

- **Case fan**: one Noctua **NF-A8 5V PWM**, 80 × 80 × 25 mm, 55.5 m³/h,
  17.7 dB(A), 2.37 mmH₂O, 0.75 W at 5 V. Ships with a USB power adaptor cable, so
  it feeds from a USB port inside the case — no GPIO wiring, no separate PSU.
- **Standoffs**: M2.5, stock 5/10/15/20 mm, combined where a stack is needed, plus
  one custom height for slot 2 (below).
- Two Noctua NF-A4x10 5V fans are on hand and **deliberately unused**. See
  *Known unresolved*.

### The M.2 HAT+ Compact does not take the Active Cooler as supplied

Raspberry Pi's documentation is explicit: the standard M.2 HAT+ "is supplied with a
16 mm stacking header and threaded spacers, so it can be fitted to a Raspberry Pi 5
with the Raspberry Pi Active Cooler in place," while the Compact "is designed to fit
around the included fan in the Raspberry Pi Case for Raspberry Pi 5, but **you can't
fit the Active Cooler beneath it**."

Leaving slot 2 passively cooled was rejected — it is the worst board to leave
uncooled given the load profile. **The fix is a custom standoff stack raising the
Compact to the same 16 mm the standard HAT+ uses**, which is exactly the height that
clears the Active Cooler. This makes slots 1 and 2 mechanically identical in height,
which is a convenience, not a coincidence: both are set by the same cooler.

**This carries one unverified dependency**: the Compact must also be raised on a
16 mm stacking header, not just taller standoffs. That header is a stock part, but
the combination has not been assembled on real hardware. See *Known unresolved*.

## Airflow

**One 80 mm intake on the +Y wall, exhaust through the −Y wall and the roof,
positive pressure.**

The +Y wall faces the Pi's GPIO edge. Once the HATs are fitted nothing plugs into
that edge and the HAT PCBs (56.5 mm deep) sit flush with the Pi's 56 mm edge, so the
whole wall is mechanically free. It is also the wall opposite the USB-C power inlet,
which is where the fan was asked for.

At 80 mm the fan spans the entire board stack vertically, so it presents a fresh-air
front to all three slots at once. **This is why there is no plenum and no internal
ducting** — an 80 mm fan buys the even distribution that a 40 mm fan would have
needed a side plenum and ~40 mm of extra case width to approximate.

### Why the fan was upsized

Three Pi 5s at sustained load plus two NVMe drives is ≈ 40 W of heat. Case air rise
over room temperature is `ΔT = Q / (ρ · c_p · V̇)`, with ρ = 1.2 kg/m³ and
c_p = 1005 J/(kg·K):

| Fans | V̇ realised in-case | ΔT |
|------|--------------------|-----|
| 2 × NF-A4x10 5V | ~5.5 m³/h | **≈ 22 K** |
| 1 × NF-A8 5V PWM | ~27.75 m³/h (50% of 55.5 free-air) | **≈ 4.3 K** |

The M.2 HAT+ is rated for **0–50 °C ambient**, and that is the number this case has
to hold. Two 40 mm fans put a 28 °C room at exactly 50 °C of case air — the rated
ceiling, with no margin. The NF-A8 puts a 25 °C room at ~29 °C. Even at half the
assumed duct efficiency it stays near 7 K.

The 50% realisation factor is an assumption, not a measurement. It is deliberately
pessimistic and the design has enough margin that halving it again still passes.

### Exhaust sizing

Exhaust free area must not choke the intake. The invariant to assert:

```
exhaust_open_area >= fan_throat_area
```

where `fan_throat_area` is the 80 mm bore less the hub, ≈ 4320 mm². The three
boards' USB-C and micro-HDMI cutouts contribute only ~222 mm² in total, so
essentially all of it comes from a vent field on the −Y wall plus a second field in
the roof. The roof field is not decoration: hot air rises, and it is free area that
costs nothing to cut.

Raspberry Pi's own warning applies and is honoured by the above: *"if used inside a
case, the case should not be covered."*

## Geometry

All dimensions in mm. Every number below is **derived in `cad/config.scad`**, never
written into a part file.

### Board and adapter constants

Pi 5 geometry comes from the `SBC_Model_Framework` submodule's `rpi5` model
(85 × 56 × 1.65 PCB; Ø2.7 holes on a 58 × 49 pattern, 3.5 from each edge; connector
positions; the `rpi5_oem` Active Cooler). The framework has **no HAT models** —
verified by grep across every `.scad` in it — so both HATs are project-local
geometry in `cad/lib/`, taken from the official product brief drawings:

| Constant | Value | Source |
|----------|-------|--------|
| `hat_standard_size` | 65 × 56.5 | product brief |
| `hat_compact_size` | 65 at header edge, 71.5 overall × 56.5 | product brief |
| `hat_hole_pattern` | 58 × 49 @ 3.5 | product brief (identical to Pi 5) |
| `hat_pcb_t` | 1.6 | standard |
| `hat_stack_h` | 16 | supplied stacking header |
| `active_cooler_h` | 11.0 above PCB top | **to be measured** — see *Known unresolved* |

### Stack

Slot occupied height, measured from the board's PCB underside:

- **HAT slot** = `pcb_t + hat_stack_h + hat_pcb_t + drive_t + screw_head`
  = 1.65 + 16 + 1.6 + 2.3 + 2 ≈ **23.55**
- **Bare slot** = `pcb_t + active_cooler_h` = 1.65 + 11 ≈ **12.65**

(`drive_t = 2.3` is an M.2 single-sided module; `screw_head = 2` is the supplied
knurled double-flanged retaining screw.)

Standoff between PCB top and the next PCB underside is **30 mm** for both HAT slots
(20 + 10 from stock), leaving ~8.1 mm of free air channel above each drive. The top
slot carries nothing above it.

| Datum | z |
|-------|---|
| floor inner face | 0 |
| board 1 PCB underside | 10 |
| board 2 PCB underside | 41.65 |
| board 3 PCB underside | 73.3 |
| board 3 Active Cooler top | 85.95 |
| interior ceiling | 94 |

The 10 mm base standoff is not just microSD clearance: it keeps the bottom of the
fan's swept area clear of the floor and gives the cable comb somewhere to live.

Interior height 94 against an 80 mm fan leaves 14 mm, so the fan centres at
z 7…87 and faces boards spanning z 10…86. **The fan's swept height must cover the
stack** — an assertable invariant, and the reason interior height is derived from
the stack rather than typed.

### Envelope

| Axis | Interior | Composition |
|------|----------|-------------|
| X | 98.5 | Compact tab 6.5 + clearance 2 + board 85 + port overhang 3 + clearance 2 |
| Y | 97.5 | exhaust gap 8 + board 56 + HAT overhang 0.5 + plenum 8 + fan 25 |
| Z | 93.95 | base standoff 10 + stack 75.95 + roof air 8 |

With 3 mm walls: **104.5 × 103.5 × 99.95 mm, 1.081 L**. Prints comfortably on the
Bambu A1's 256³.

> **Revised during implementation (2026-09-17).** X grew 95 → 98.5 and Y 97 → 97.5
> after reading the product-brief drawings closely for Task 2. Two facts the spec had
> wrong: the **M.2 HAT+ Compact is 6.5 mm wider than the standard**, and that
> difference is a tab hanging off the board's −X edge where the PCIe ribbon lands, so
> the −X wall clears the tab rather than the PCB; and a **56.5 mm HAT over a 56 mm Pi
> overhangs its +Y edge by 0.5 mm**, so the fan plenum is measured from the HAT, not
> the board. Volume 1.04 → 1.081 L. The Compact tab's exact position is not resolvable
> from the drawing, so the envelope claims the worst case — see *Known unresolved*.

### Wall assignment

| Wall | Carries |
|------|---------|
| +Y | 80 mm fan bore, mount pattern, filter clips |
| −Y | 3 × (USB-C + 2 micro-HDMI) cutouts, exhaust vent field |
| +X | 3 × (RJ45 + USB-A stack) cutouts |
| −X | microSD access, power buttons |
| roof | exhaust vent field, top-board retainer |
| base | four M2.5 bosses for board 1, cable comb, feet |

Six cables leave the box — 3 × Ethernet on +X, 3 × USB-C on −Y — on two adjacent
walls, because that is where the Pi puts them. The base carries a **cable comb** so
the bundle cannot lever the case over.

## Printed parts

Four parts, none needing support:

1. **`base`** — floor, four M2.5 insert bosses for board 1, cable comb, feet.
2. **`shell`** — the four walls as one tube, printed standing. Every opening is a
   vertical-wall feature, bridged at the top.
3. **`roof`** — lid, vent field, interlock lip, top-board retainer.
4. **`filter`** — clip-on dust filter frame over the intake. Positive pressure means
   this is the only place dust can enter, so it is the only place that needs one.

The board stack is self-supporting from the base: board 1 bolts to the base bosses,
boards 2 and 3 stack on standoffs from board 1. The roof retainer only stops the top
board flexing.

## Repository

Structure follows `naja-miner`:

```
cad/config.scad        every dimension, nothing hardcoded in parts
cad/case.scad          assembly / showcase entry point
cad/tests.scad         synthetic envelopes for fit tests
cad/lib/               m2-hat-plus.scad (both variants), noctua-fan.scad,
                       placement.scad, shell.scad, vents.scad, ports.scad,
                       screws.scad
cad/parts/             base.scad, shell.scad, roof.scad, filter.scad
cad/SBC_Model_Framework/   git submodule, as lab-router consumes it
scripts/               generate-stl.sh, test*.sh
website/               React + Three.js STL viewer, as siblings
```

`CLAUDE.md` carries forward the relevant OpenSCAD traps already paid for in
`naja-miner` — `use` not importing variables, no hoisting, `--export-format=binstl`,
empty-render-is-a-pass, `render()` inside panel modules, and testing both presence
and absence.

**Repository is private** (GitHub Pro, so Pages still deploys from private).

### Test suites

| Suite | Asserts |
|-------|---------|
| `test-fit.sh` | Active Cooler clears each HAT; HAT clears the next board; fan clears the stack; every port lines up with its cutout; standoffs reach |
| `test-parts.sh` | one body per part, holes cut in both directions, no stray bodies |
| `test-airflow.sh` | `exhaust_open_area >= fan_throat_area`; fan swept height covers the stack |
| `test-board-assets.sh` | declared Pi 5 constants still match the framework's `rpi5` model |
| `test-assets.sh` | mesh assets are closed manifolds, one body, matching their declared extents |

## Known unresolved

- **`active_cooler_h = 11.0` is derived from the framework's `rpi5_oem` model, not
  measured.** It sets the slot 2 custom standoff and therefore the whole stack. One
  caliper reading on a real assembled board replaces it, and `test-fit.sh` is what
  notices if it is wrong.
- **The 16 mm stacking header for the M.2 HAT+ Compact is assumed, not verified.**
  If the Compact cannot be raised, slot 2 loses its Active Cooler and needs directed
  air instead: one of the two spare NF-A4x10 5V fans mounts in the roof over that
  board's exposed SoC, which is what the Compact's L-shaped cutout is designed for.
  **This is the documented fallback and the reason the spare fans are kept.**
- **The 50% duct-efficiency assumption is not measured.** The design passes at 25%,
  so this is recorded rather than resolved.
- **Slot order is a preference, not a constraint.** The Compact sits in the middle
  because both HAT slots are the same height; if the fallback above is ever needed,
  it moves to the top so its spot fan can mount in the roof.
- **The M.2 HAT+ Compact's tab position is claimed, not measured.** The brief gives
  65 across the header edge and 71.5 overall, but its drawing does not resolve where
  the extra 6.5 mm sits. `hat_compact_overhang_x` claims all of it on −X, which is the
  direction that costs case width, so the envelope is conservative rather than right.
  Measuring the real part can only make the case smaller.
- **The side-plenum layout is the documented thermal upgrade** if a real print runs
  hot: one interior wall and a fan relocation. It is deliberately not built now.


---

## Revision 2 — front intake, rear exhaust (2026-09-18)

Requested after the first implementation. **The sections above describe the original
layout and are kept as the record of it**; where they conflict, this section wins.

| | Original | Revision 2 |
|---|---|---|
| Intake + filter | +Y wall (GPIO long edge) | **−X front** (short edge, opposite USB/Ethernet) |
| Exhaust | −Y wall + roof | **Rear wall + rear portion of both sides. No roof.** |
| Air path | across the board's 56 mm width | **along its full 85 mm length** |
| Vent lattice | project's own triangles | **hexrack's, verbatim**: cell 14, web 1.6, corner 1.2, stagger 0.5 |
| Rear treatment | plain vent field | **hexrack-style exclusion zones** around each port cluster |
| Envelope | 104.5 × 103.9 × 99.95, 1.085 L | **135.9 × 92 × 99.95, 1.25 L** |
| Seams | 6 mm skirts | **2 mm skirts** |

**Why the case grew.** The front wall carries the fan, so it must be ≥ 80 wide while the
board is 56. The board sits against −Y (USB-C and HDMI meet their wall) and the spare
width is a side channel on +Y.

**Why the exhaust is not rear-only**, which was the request. Built and measured: the
three exclusion zones take ~43% of the rear wall, leaving **57%** of the fan's 4320 mm²
throat. Venting the entire rear with no zones reaches only 99.7%. The rear wall cannot
carry this fan. Offered three options — accept 57%, wrap onto the sides, or drop the
zones — and **wrapping onto the rear of the sides was chosen**: 6337 mm², 147%.

**Why the seams moved to 2 mm.** With 6 mm skirts the intake left the shell part under
1 mm of wall above and below it. Found by rendering the part on its own; the assembled
case hid it.

**Two defects found by rendering, not by the suite**, both now covered by tests:
spurious notches cut into the −Y wall by port masks dragged sideways, and the severed
front wall above. See CLAUDE.md traps 18–20.


---

## Revision 3 — two stacked NF-A4x20 5V PWM (2026-09-18)

The 80 mm fan set the front wall, and so the case, to 92 mm wide around a 56 mm board.
Options were compared on datasheet figures (NF-A6x25 5V PWM sheet; NF-A4x20 from its
12 V PWM sheet, to be confirmed against the 5 V PWM one):

| Setup | Case | Air rise | Margin, 25 °C room | Faces all 3 slots |
|---|---|---|---|---|
| NF-A8 | 1.25 L | 4.3 K | 21 K | yes |
| 1 × NF-A6x25 | ~0.98 L | 8.2 K | 17 K | no |
| **2 × NF-A4x20 stacked** | **0.875 L** | **12.7 K** | **12 K** | **yes** |
| 2 × NF-A6x25 stacked | ~1.3 L | 4.1 K | 21 K | yes (taller case) |
| 2 × NF-A4x10 | ~0.85 L | 25 K | ≈ 0 | yes |

**Chosen: 2 × NF-A4x20, stacked** — the smallest option that keeps every guarantee,
including the column facing the whole stack. The cost is cooling margin, accepted.

Result: **131.6 × 66.5 × 99.95 mm, 0.875 L**; width now set by the board (60.5 inside)
rather than the fan. One 40 × 80 opening and one filter for the column. Exhaust
5051 mm² against a 1885 mm² throat (268%); filter grille 80%. The fan depth is the
measured 21.1, not the datasheet's 20.

Found on the way: the filter's placement had been rotated 90° all along, hidden by a
square fan; and the asset tooling measured the largest body rather than the mesh.
Both fixed and covered — CLAUDE.md traps 21–22.


---

## Revision 4 — owned NF-A4x10s, four clipped walls, a real filter (2026-09-18)

Requested after Revision 3. Where it conflicts with anything above, this section wins.

**The fans are the owned NF-A4x10 5V, and Revision 3's table was wrong about them.**
It used 4.85 — the CFM figure — as m³/h. Noctua's sheet gives **8.2 m³/h**, which puts
the pair at **≈ 14.6 K** of case-air rise and **≈ 10 K** of margin under the HAT's
50 °C in a 25 °C room, against 12 K for the NF-A4x20s. Close enough that buying new
fans is not justified. They are 3-pin with no USB adaptor, so they run from a Pi's GPIO
5 V. Measured depth 12.0, not the datasheet's 10.

| | Revision 3 | Revision 4 |
|---|---|---|
| Fans | 2 × NF-A4x20 5V PWM | **2 × NF-A4x10 5V, owned** |
| Shell | one printed tube | **front, rear, left, right — four walls** |
| Joints | lip and seams | **hexrack's 45° rib-into-groove clip, 23 joints, no screws** |
| Filter | clip-on grille frame | **hexrack's ring: flush in a 4 mm recess, fabric glued behind** |
| Intake | one 40 × 80 rounded opening | **two Ø38 bores, fans screwed from inside** |
| Board fixing | four bosses, roof retainer | **two rails with heat-set inserts; no retainer** |
| Feet | printed | **none — bumpons on a flat underside** |
| Envelope | 131.6 × 66.5 × 99.95 | **127.5 × 68.5 × 99.95, 0.87 L** |
| Exhaust | 268% of throat | **206%** (3844 mm² against 1866) |

**Why four walls.** The single shell printed standing as a 94 mm tube with every
opening on a vertical face — hard to print well. Four walls print flat or on a face.
The front and rear own the corners and carry corner flanges; the sides slide down
between them; everything stands on the base's rim; the roof clips onto the side walls.

**Why hexrack's filter clip and not its `snap-fit.scad`.** The latter is dead code in
hexrack — never included, its dimensions undefined. The 45° rib is the live, printed,
proven one. Every joint is one row of `clipJoints()`, read by the rib's owner, by the
shell that cuts the groove, and by `test-clips.sh`.

**Why two round bores.** The square intake had removed the material every fan screw
needed: the screw holes sat over air. Found while adding the filter; now tested
(`pilot-material`).

**Why no printed feet.** Feet below the floor meant the floor printed over air, and
the other face carries the rim and rails, so the base needed support either way up —
a defect since the first implementation.

**The front wall, printed on its outer face, has one bridge**: the recess floor across
the web between the bores, ~52 mm at its longest.

**Why the sides grew 2 → 3 mm of clearance, and the side vent field shrank 40 → 32.**
The rear corner flanges would otherwise pass 0.2 mm from the PCB, and the shorter case
pulled the −Y side field onto the USB-C/HDMI cutouts. The assert caught the second one.
