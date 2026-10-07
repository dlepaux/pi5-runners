# pi5-runners

A 3D-printable stack for three Raspberry Pi 5s running as self-hosted GitHub Actions
runners. **Three modules, one Pi 5 and one 40 mm Noctua each**, a round
dust filter clipped into each module's front, and a lid, all with rounded corners.
Each Pi screws onto a **tray** on the bench, which then clicks into a window in its
module's floor.
**115.9 × 68 × 182.4 mm** with the 10 mm fans, 125.0 mm deep with the 20 mm ones. Nothing in the case is screwed
together; only the fans are.

## What it holds

| Module | Board | Storage | Cooling |
|--------|-------|---------|---------|
| Bottom | Pi 5 | Raspberry Pi M.2 HAT+ (2242 NVMe) | Active Cooler |
| Middle | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230 NVMe) | Active Cooler, on custom 16 mm standoffs |
| Top | Pi 5 | — | Active Cooler |

Every module is the same shape, sized for the tallest board, so any board fits any
module. Each is engraved on both sides with its runner's hostname, **srv-runner-1** at
the bottom to **srv-runner-3** at the top, in Grenze Gotisch. Each Pi screws straight into printed feet on its own module's floor; the boards are
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

Each board stands on four printed feet, which put it and its HAT across
the fan's flow, with air running under the board between the feet. One fan per Pi is 50% more air than the two-fan column an
earlier version shared. The
20 mm fans move 15% more again and push 27% more static pressure, which is what counts
behind a filter — about a kelvin, not a different class of cooling.

**Airflow** runs front to back along each board's full length. Each fan draws through
its module's dust filter and front wall, pushes over its own SoC and drive, and
the module exhausts through its rear wall and the rear of both side walls — never the
lid, which would drop dust onto a board. Each module's exhaust is **225% of its fan's
throat** (257% with the 20 mm fans) — louvres leaning rearward at the rear of each
side, straight louvres above and below the rear ports. The floors are solid by default; set
`floor_vents = true` for a triangle lattice that lets each module breathe into the
one above.

Around the rear port cluster the louvres stop at an **exclusion zone**, hexrack's
back-face idea, so every connector sits in clean solid wall. The Ethernet port is
flush with the outside of the case and the USB ports 1.3 mm in, so every plug seats.

## Printing

Twelve STLs, **none needing support**, in the orientation they come out of
`generate-stl.sh`. PETG. Print the modules and lid for the fans you fit.

| Part | Print | Size |
|------|-------|------|
| `module-srv-runner-{1,2,3}-NF-A4x10` or `…-NF-A4x20` | one of each, floor down | 115.9 / 125.0 × 68 × 61.3 mm |
| `lid-NF-A4x10` or `lid-NF-A4x20` | plate down | 115.9 / 125.0 × 68 × 6.0 mm |
| `tray` | ×3, floor down | 67.6 × 58.6 × 13.9 mm |
| `filter` | ×3, face down, pocket up | 50.3 × 53.8 × 4.0 mm |

**Download them** from the project's GitHub Pages site, rebuilt on every push to main
once the whole test suite passes. Or render them yourself:

```bash
./scripts/generate-stl.sh          # all twelve into stl/
./scripts/generate-stl.sh filter   # just one
./scripts/build-site.sh            # the download page, into _site/
```

How each part avoids support:

- **Module.** The floor is the first layers. Every wall steps out from it on a **45°
  chamfer that reaches the outer face** — the front too — lying on a bevel inside the
  top of the module below; each wall's clip rib is a square bar on that chamfer with
  every face at 45°. Nothing on it is printed over air: the first print's chamfer
  stopped 1.3 mm short and the roof it left sagged. The wall below rises into the
  chamfer as a lip one extrusion line wide at its top, so the joint is flush but for
  a 0.4 mm hairline. The
  filter's recess has its clips at the sides and a round crown, an arch 4 mm deep off
  the wall behind it, steeper than 45° only near its top. The rounded corners
  are vertical, so they cost nothing.
- **Tray.** Its edges are 45° chamfers, narrow at the bed, and the window's in the
  module's floor face up to meet them; its clip ribs are the lap's; the feet and the
  spring slots behind the clips run straight up.
- **Lid.** Upside down, its lap narrows as it rises and its ribs are 45° bars on it.
- **Filter.** A flat ring; the glue pocket faces up.

## Why the case is this tall

The fan sets each module's height: a 2.4 mm floor, the 40 mm fan and 2 mm above and
below it for its silicone corner pads, 46.4 mm. The tallest board (Pi, HAT and drive) needs 42.5 with
its air gap, so it fits under that.

On top of that come 12.4 mm of headroom (`module_headroom`), 58.8 mm floor to floor.
It started at 10, because a taller passive heatsink did not fit under the next module's
floor. The board stays where it was, so all of that room is above it. **The fan is
centred** on the module's front, sharing the headroom out above and below it. Centred, the
round filter needs 12.4 mm to clear the lap below and the clip groove above.

The filter is round above and below, with flats only at the sides, where its clips
are. Its window matches the 38 mm fan bore. The fan screws go in from the front, so
their heads sit under the ring, and the ring has to cover them. They sit on the
diagonals, which is why the filter is round: a circle over the heads is 53.8 mm across,
where hexrack's hexagon was 59.4 and left no room to round the front corners. While
the fan sat low the ring was cut flat top and bottom too.

## Assembly

1. **On its tray, on the bench.** The HAT's M2.5 male-female standoffs thread through
   the Pi straight into the tray's feet, cutting their own thread (a bare Pi takes
   M2.5 × 6 screws). Snug, not tight: a printed thread strips.
2. Hold each fan against the inside of its module's front wall and screw it in from
   the front with **the four self-tapping screws in the fan's own bag** (Noctua's,
   about M5) through the recess floor into the fan's corner holes. Their heads sink
   below the recess floor. Not M3s: the fan's holes are 4.3 mm, and an earlier hole
   drawn for M3 cracked round every screw.
3. **Into its module.** The Pi's rear ports come through the rear wall, so the tray
   cannot drop straight in: hold it about 2.5 mm over the floor and 3.5 mm short of the
   rear wall, slide it back until its RJ45 and USB ports sit in their holes and its edge
   in the slot under them, then press it down into the window until its four clips
   click. Its chamfered edges stop it falling through. Plug the fan into that Pi's
   GPIO: 5 V on pin 2 or 4, ground on pin 6.
4. Stand the bottom module on the desk on its floor. Stack the others: tilt each one,
   hook its front clip in first, then press its rear down until the other three click.
   Its chamfer lies on the bevel of the one below. Click the lid onto the top one.
5. Glue filter fabric into the pocket on the back of each filter and click
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
| `test-fit.sh` | every board fits its module and clears its fan; the loaded tray goes in along its path without touching the module; modules, trays, lid and filters touch only where they should and seat where they must |
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
