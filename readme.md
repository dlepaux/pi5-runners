# pi5-runners

A 3D-printable stack for three Raspberry Pi 5s running as self-hosted GitHub Actions
runners. **Three identical modules, one Pi 5 and one 40 mm Noctua each**, a round
dust filter clipped into each module's front, and a lid, all with rounded corners.
**122.5 × 68 × 173 mm** (176 on its base) with the 10 mm fans, 131.6 mm deep with the 20 mm ones. Nothing in the case is screwed
together; only the fans are.

## What it holds

| Module | Board | Storage | Cooling |
|--------|-------|---------|---------|
| Bottom | Pi 5 | Raspberry Pi M.2 HAT+ (2242 NVMe) | Active Cooler |
| Middle | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230 NVMe) | Active Cooler, on custom 16 mm standoffs |
| Top | Pi 5 | — | Active Cooler |

Every module is the same part, sized for the tallest board, so any board goes in any
module. Each Pi screws into heat-set inserts in its own module's floor; the boards are
never connected to each other.

Plus **three Noctua 40 mm 5V fans**, one per module, screwed in from the front and
powered from its own Pi's GPIO 5 V header: either the **NF-A4x10** or the **NF-A4x20**. Set `fan_model` in
`cad/config.scad`. The fan sits between the front wall and the board, so it sets the
module's length: switching fans means reprinting the modules and the lid.

## Why this shape

CI runners hold 100% CPU for 30–50 minutes at a stretch, three boards at once — about
40 W of heat. Case air rise over room temperature is `ΔT = Q / (ρ · c_p · V̇)`:

| Fans | Case air rise | Margin to the HAT's 50 °C, 25 °C room |
|------|---------------|---------------------------------------|
| **3 × NF-A4x10 5V** | **≈ 9.7 K** | **≈ 15 K** |
| 3 × NF-A4x20 5V | ≈ 8.5 K | ≈ 16.5 K |

Each board stands on 5 mm standoffs on rails that centre it and its HAT on the fan's axis, so the
whole flow crosses the board. One fan per Pi is 50% more air than the two-fan column an
earlier version shared. The
20 mm fans move 15% more again and push 27% more static pressure, which is what counts
behind a filter — about a kelvin, not a different class of cooling.

**Airflow** runs front to back along each board's full length. Each fan draws through
its module's dust filter and front wall, pushes over its own SoC and drive, and
the module exhausts through its rear wall and the rear of both side walls — never the
lid, which would drop dust onto a board. Each module's exhaust is **195% of its fan's
throat** (222% with the 20 mm fans) — a short grille of 45° bars at the rear of each
side, a diamond lattice round the rear ports — and every
floor is a triangle lattice, so each module also breathes into the one
above.

Around the rear port cluster the diamond lattice stops at an **exclusion zone**, hexrack's
back-face idea, so every connector sits in clean solid wall.

## Printing

Seven STLs, **none needing support**, in the orientation they come out of
`generate-stl.sh`. PETG. Print the module and lid for the fans you fit.

| Part | Print | Size |
|------|-------|------|
| `module-NF-A4x10` or `module-NF-A4x20` | ×3, floor down | 122.5 / 131.6 × 68 × 59.8 mm |
| `lid-NF-A4x10` or `lid-NF-A4x20` | plate down | 122.5 / 131.6 × 68 × 7.2 mm |
| `base-NF-A4x10` or `base-NF-A4x20` | rim down | 124.5 / 133.6 × 72 × 8.5 mm |
| `filter` | ×3, face down, pocket up | 49.8 × 52.6 × 4.0 mm |

**Download them** from the project's GitHub Pages site, rebuilt on every push to main
once the whole test suite passes. Or render them yourself:

```bash
./scripts/generate-stl.sh          # all seven into stl/
./scripts/generate-stl.sh filter   # just one
./scripts/build-site.sh            # the download page, into _site/
```

How each part avoids support:

- **Module.** The bottom is a spigot inset from the side and rear walls, no taller than
  its clip ribs; the wall steps out to full width on a **45° chamfer that reaches the
  outer face**, lying on a bevel inside the top of the module below. Nothing on it is
  printed over air: the first print's chamfer stopped 1.3 mm short and the roof it left
  sagged. The wall below rises into the chamfer as a lip one extrusion line wide at its
  top, so the joint is flush but for a 0.4 mm hairline. The floor lattice is the first layers. The
  filter's round recess has its flats and clips at the sides; its crown is a 4 mm-deep
  arc off the wall behind it. The rounded corners
  are vertical, so they cost nothing.
- **Lid.** Upside down, its lap narrows as it rises.
- **Filter.** A flat ring; the glue pocket faces up.

## Why the case is this tall

The filter sets each module's height, not the board. Its flats sit just outside the
fabric's glue pocket, 48 mm apart, and with the clip grooves and a millimetre of wall
round them that makes a 53.6 mm front per module.

The fan screws go in from the front, so their heads sit in the filter's recess and the
ring has to cover them. They sit on the diagonals, which is why the filter is round: a
circle through the heads is 52.6 mm wide, where hexrack's hexagon was 59.4 and left no
room to round the front corners.

## Assembly

1. Press M2.5 heat-set inserts into each module's rails and screw an **M2.5 × 5 mm
   male-female standoff** into each, female end up: the board stands on those, with
   air under it, not on the print. Set the Pi on them; the HAT's M2.5 male-female
   standoffs thread through the Pi into them (a bare Pi takes M2.5 screws).
2. Hold each fan against the inside of its module's front wall and screw it in from
   the front with four **M3 countersunk self-tappers** through the recess floor into
   the fan's corner holes — **M3 × 12** for the NF-A4x10, **M3 × 20** for the NF-A4x20.
   Plug it into that Pi's GPIO: 5 V on pin 2 or 4, ground on pin 6.
3. Click the bottom module into the base: a module's socket on an open rim, with a
   skirt round its sides and rear. Stack the others: each one's spigot drops into the
   one below and clicks in on hexrack's 45° rib-and-groove clip. Click the lid onto
   the top one.
4. Glue filter fabric into the pocket on the back of each filter and click
   it into its recess, over the screw heads.

## Development

```bash
git submodule update --init --recursive   # SBC_Model_Framework
./scripts/test.sh                         # all seven suites, geometry in both fan modes
```

| Suite | Holds |
|-------|-------|
| `test-board-assets.sh` | the declared Pi 5 geometry still matches the framework |
| `test-assets.sh` | both fan meshes are what `config.scad` says they are |
| `test-fit.sh` | every board fits its module and clears its fan; modules, lid and filters touch only where they should and seat where they must |
| `test-parts.sh` | one body each, in both fan modes, everything fits the bed, the showcase renders |
| `test-clips.sh` | every clip rib sits in its groove at rest and reaches into the part it holds |
| `test-airflow.sh` | no module's exhaust chokes its fan, every fan's air path is open, every fan screw has a path, a seat and a filter over its head, no port is blind, no hole exists that should not |
| `test-print.sh` | every part prints without support, as exported |

Open `cad/case.scad` for the assembly. `case_part` picks one part, `fan_model` the fans,
`assembly_space` pulls the stack apart, and the `show_*` flags toggle the boards, HATs,
standoffs, fans and filters.

Requires OpenSCAD nightly with the Manifold backend. Every dimension lives in
`cad/config.scad`.

## Licence

[CC BY-NC-SA 4.0](license.md). Vendor CAD under `cad/assets/` is **not** covered by it
— see the readme beside those files. Do not print the fans; buy them.
