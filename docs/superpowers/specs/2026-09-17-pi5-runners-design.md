# pi5-runners — three-Pi CI runner tower

**Date:** 2026-09-17
**Status:** approved design, pending implementation plan

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
| X | 95 | board 85 + port overhang 3 + clearance |
| Y | 97 | fan 25 + plenum 8 + board 56 + exhaust gap 8 |
| Z | 94 | base standoff 10 + stack 76 + roof air 8 |

With 3 mm walls: **≈ 101 × 103 × 100 mm, ≈ 1.04 L**. Prints comfortably on the
Bambu A1's 256³.

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
cad/lib/               m2-hat-plus.scad, m2-hat-compact.scad, noctua-fan.scad,
                       placement.scad, shell.scad, screws.scad
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
- **The side-plenum layout is the documented thermal upgrade** if a real print runs
  hot: one interior wall and a fan relocation. It is deliberately not built now.
