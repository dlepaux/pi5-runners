# pi5-runners

A 3D-printable stack for three Raspberry Pi 5s running as self-hosted GitHub Actions
runners. **Three identical modules, one Pi each**, a lid, and a front face carrying two
stacked 40 mm Noctuas behind a dust filter. **124.5 × 78.2 × 120.35 mm** with the
10 mm fans, 133.6 mm deep with the 20 mm ones. Nothing in the case is screwed together.

## What it holds

| Module | Board | Storage | Cooling |
|--------|-------|---------|---------|
| Bottom | Pi 5 | Raspberry Pi M.2 HAT+ (2242 NVMe) | Active Cooler |
| Middle | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230 NVMe) | Active Cooler, on custom 16 mm standoffs |
| Top | Pi 5 | — | Active Cooler |

Every module is the same part, sized for the tallest board, so any board goes in any
module. Each Pi screws into heat-set inserts in its own module's floor; the boards are
never connected to each other.

Plus two **Noctua 40 mm 5V fans**, stacked into a 40 × 80 mm column and powered from a
Pi's GPIO 5 V header: either the **NF-A4x10** or the **NF-A4x20**. Set `fan_model` in
`cad/config.scad`; it only changes the front face.

## Why this shape

CI runners hold 100% CPU for 30–50 minutes at a stretch, three boards at once — about
40 W of heat. Case air rise over room temperature is `ΔT = Q / (ρ · c_p · V̇)`:

| Fans | Case air rise | Margin to the HAT's 50 °C, 25 °C room |
|------|---------------|---------------------------------------|
| **2 × NF-A4x10 5V** | **≈ 14.6 K** | **≈ 10 K** |
| 2 × NF-A4x20 5V | ≈ 12.7 K | ≈ 12 K |

The 20 mm fans move 15% more air and push 27% more static pressure, which is what
counts behind a filter. That buys a couple of kelvin, not a different class of cooling.

**Airflow** runs front to back along each board's full length. The fans blow into a
plenum between the front face and the modules' open fronts; each module draws from it
and exhausts through its rear wall and the rear of both side walls — never the lid,
which would drop dust onto a board. Total exhaust is **249% of the fans' throat**, and
every floor is a lattice too, so each module also breathes into the one above.

Around the rear port cluster the vent pattern stops at an **exclusion zone**, hexrack's
back-face idea, so every connector sits in clean solid wall.

## Printing

Five STLs, **none needing support**, in the orientation they come out of
`generate-stl.sh`. PETG.

| Part | Print | Size |
|------|-------|------|
| `module` | ×3, floor down | 102.5 × 73.5 × 44.5 mm |
| `lid` | plate down | 102.5 × 68.5 × 11.0 mm |
| `front-NF-A4x10` or `front-NF-A4x20` | standing, as it sits | 34.0 / 43.1 × 78.2 × 120.3 mm |
| `filter` | face down, pocket up | 49.0 × 86.0 × 4.0 mm |

```bash
./scripts/generate-stl.sh          # all five into stl/
./scripts/generate-stl.sh module   # just one
```

How each part avoids support:

- **Module.** The bottom is a spigot inset from the walls; the wall steps out to full
  width on a **45° lap** that matches a bevel inside the top of the module below. The
  dovetail rails' feet are chamfered 45°. The floor lattice is the first layers.
- **Lid.** Upside down, its lap narrows as it rises.
- **Front face.** The dovetail channels and filter grooves run up the print. The
  plenum's floor is on the bed and its ceiling rises at 45°. The fan bores and the pill
  recess are arches in a vertical face — their crowns print as short bridges, and all
  of them are behind the filter.

## Assembly

1. Press M2.5 heat-set inserts into each module's rails. Screw each Pi in; the HAT's
   M2.5 male-female standoffs thread through the Pi into the inserts.
2. Stack the modules. Each one's spigot drops into the one below and clicks in on
   hexrack's 45° rib-and-groove clip. Click the lid onto the top one.
3. Screw the fans to the inside of the front face, from the plenum side, with M3
   self-tappers through each fan's corner holes: **M3 × 14** for the NF-A4x10, **M3 ×
   24** for the NF-A4x20. That bites the full 3 mm of plate and stops short of the filter.
4. Slide the front face down over the dovetails on the modules' sides.
5. Glue filter fabric into the pocket on the back of the filter ring and push the ring
   into the pill-shaped recess until it clicks.

## Development

```bash
git submodule update --init --recursive   # SBC_Model_Framework
./scripts/test.sh                         # all seven suites
```

| Suite | Holds |
|-------|-------|
| `test-board-assets.sh` | the declared Pi 5 geometry still matches the framework |
| `test-assets.sh` | both fan meshes are what `config.scad` says they are |
| `test-fit.sh` | every board fits its module; modules, lid and front face touch only where they should and seat where they must; the dovetails hold |
| `test-parts.sh` | one body each, both front faces, everything fits the bed, the showcase renders |
| `test-clips.sh` | every clip rib sits in its groove at rest and reaches into the part it holds |
| `test-airflow.sh` | the exhaust does not choke the fans, no port is blind, no hole exists that should not |
| `test-print.sh` | every part prints without support, as exported |

Open `cad/case.scad` for the assembly. `case_part` picks one part, `fan_model` the fans,
`assembly_space` pulls the stack apart, and the `show_*` flags toggle the boards, HATs,
standoffs, fans, filter and front face.

Requires OpenSCAD nightly with the Manifold backend. Every dimension lives in
`cad/config.scad`.

## Licence

[CC BY-NC-SA 4.0](license.md). Vendor CAD under `cad/assets/` is **not** covered by it
— see the readme beside those files. Do not print the fans; buy them.
