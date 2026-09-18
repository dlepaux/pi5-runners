# pi5-runners — 3D-Printable Tower for Three Pi 5 CI Runners

Standalone case holding three Raspberry Pi 5s that act as self-hosted GitHub Actions
runners. **135.9 × 92 × 99.95 mm, 1.25 L**, four printed parts, one 80 mm Noctua.

## Project intent

**Standalone**, like [`lab-router`](../lab-router/) and [`naja-miner`](../naja-miner/) —
not a variant of [`hexrack-sbc`](../hexrack-sbc/), and a **single configuration**. No
variant matrix, no board-selection parameter.

The load is what makes this case different from a Pi shelf: 100% on all four cores for
30–50 minutes at a stretch, three boards at once, with NVMe traffic throughout. Every
decision below follows from sustained load rather than from idle.

## Hardware target

| Slot | Board | Storage adapter | Cooling |
|------|-------|-----------------|---------|
| 1 (bottom) | Pi 5 | Raspberry Pi M.2 HAT+ (2242) | Active Cooler |
| 2 (middle) | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230) | Active Cooler, custom standoffs |
| 3 (top) | Pi 5 | none | Active Cooler |

- **THE M.2 HAT+ COMPACT DOES NOT TAKE THE ACTIVE COOLER AS SUPPLIED.** Raspberry Pi
  say so: the standard HAT+ ships with a 16 mm stacking header "so it can be fitted to
  a Raspberry Pi 5 with the Raspberry Pi Active Cooler in place", while the Compact
  "is designed to fit around the included fan in the Raspberry Pi Case… but you can't
  fit the Active Cooler beneath it". Slot 2 raises it to the same 16 mm on custom
  standoffs. **This is not re-openable as a preference** — it is the height that
  clears the cooler, and `config.scad` asserts it
- **Case fan: one Noctua NF-A8 5V PWM.** 55.5 m³/h, 17.7 dB(A), 0.75 W at 5 V, USB
  power adaptor cable included, so it feeds from a USB port inside the case
- **THE FAN IS ON THE FRONT: the −X wall, opposite the USB/Ethernet cluster.** Air
  enters the front, runs the board's full 85 mm LENGTH over the SoC and the drive, and
  leaves at the rear where the ports are and the Ethernet PHY runs hottest. At 80 mm it
  spans the whole stack, so all three slots get a fresh-air front and there is no
  plenum. `config.scad` asserts the fan's swept height covers the stack
- **THE FRONT WALL IS 80 WIDE BECAUSE THE FAN IS.** The board is 56 but the wall
  carrying the fan must be ≥ 80, which is most of why the case is 1.25 L rather than
  the 1.085 L it was with the fan on the long side. **The board is NOT centred in that
  width**: it sits against −Y so USB-C and micro-HDMI meet their wall instead of the
  bottom of a 15 mm recess, and the spare width goes to +Y as a side air channel and
  cable route
- **EXHAUST: THE REAR WALL, WRAPPING ONTO THE REAR OF BOTH SIDES. Never the roof.**
  Rear-only was built and MEASURED: the port clusters' exclusion zones take ~43% of the
  rear, leaving 57% of the fan's throat; even venting the whole rear with no zones only
  reaches 99.7%. The rear wall alone cannot carry this fan. Side fields restore a
  matched exit — **147% of the throat** — and keep the top and front clean. The −Y side
  field is asserted to stay behind the USB-C/HDMI cutouts
- **EXCLUSION ZONES, hexrack's back-face idea.** A rounded rectangle per board is carved
  out of the vent CUTTER around its RJ45/USB cluster, so the ports sit in clean solid
  material with the pattern running round them. Sized from the MEASURED cluster
  (52.2 × 16.3), not guessed, because every mm comes out of the only exhaust there is
- **hexrack's triangle lattice, copied verbatim** — cell 14, web 1.6, corner 1.2,
  stagger 0.5 — on the rear, the sides and the filter, so the projects read as one
  family. A triangle cannot rack, so a thin wall stays stiff
- **Positive pressure.** One filtered intake; dust can only enter where the filter is,
  which is the only reason there is exactly one filter. The printed grille is a
  RETAINER for bought media (76% of throat), not the filtration itself
- **The M.2 HAT+ is rated 0–50 °C ambient**, and that is the number this case holds.
  Two 40 mm fans put a 28 °C room at exactly 50 °C — the ceiling, no margin. The
  NF-A8 puts a 25 °C room at ~29 °C. The HAT PCBs are 56.5 against the Pi's 56 and
  **overhang its +Y edge by 0.5**, which the envelope carries
- **Six cables leave the box** — 3× Ethernet on +X, 3× USB-C on −Y — on two adjacent
  walls, because that is where the Pi puts them. **There is deliberately no cable
  comb**: the ports sit 13–30 mm up and a comb on a 9 mm base cannot reach them. If
  the bundle turns out to lever the case over, the answer is weighted feet

### The framework has no HAT models

`SBC_Model_Framework` carries a complete `rpi5` — PCB, all six holes, every connector,
and the `rpi5_oem` Active Cooler — but **zero HAT geometry**, verified by grep across
every `.scad` in it. Both M.2 HATs are project-local, built from the official product
brief (RP-009234-MM) rather than measured or guessed.

## Conventions

- OpenSCAD nightly + Manifold backend
- **Every dimension in `cad/config.scad`.** Never hardcode in a part file
- Parts in `cad/parts/`, project libs in `cad/lib/`
- mm units, never imperial
- PETG
- Conventional Commits

## Mesh assets — follow hexrack, not naja-miner

**Assets are prepared, not quarantined.** A committed script meshes or repairs each
asset into a closed manifold, `config.scad` declares what was generated, and the
consumer asserts it fits. That is why hexrack's `assets/gyroid-tunnels.stl` can be
*subtracted* to cut its face vents at all.

naja-miner's alternative — two representations of one part plus a vertex-by-vertex
reconciliation suite — exists only because its vendor meshes were never repaired. Do
not reproduce that machinery. Repair the mesh once, up front.

**`%` is the background modifier: drawn in preview, dropped from the render.** That is
what keeps Noctua's mesh out of every STL this project publishes. `#` is the *debug*
modifier and is still included in the export — it does not do this job.

## Build and test

```bash
./scripts/test.sh                 # all five suites, 57 checks — what CI runs
./scripts/generate-stl.sh         # base, shell, roof, filter into stl/
./scripts/generate-fan-asset.sh   # regenerate the NF-A8 mesh (networked, needs uv)
```

Open `cad/case.scad` to look at it: `case_part` selects a part, `assembly_space`
explodes along Z, `show_*` toggles the preview content.

## OpenSCAD traps that have actually cost time

Carried forward from `naja-miner`, where each was paid for. Every one of these renders
without error and exports a clean single body.

1. **`use` imports modules and functions but NOT variables.** A constant read through
   `use` is `undef`, the feature lands at the origin, and only a `WARNING:` says so.
   Use `include` when you need constants. The harness fails on `WARNING:` for exactly
   this reason.
2. **OpenSCAD does not hoist.** A variable read above its own assignment, in the same
   file, is `undef` — again only a warning.
3. **`--export-format=binstl`, always.** The ASCII default parses as a garbage
   triangle count in the hundreds of millions.
4. **"Current top level object is empty" exits non-zero, and for a clearance test that
   is the PASS.** The exit code alone cannot be the verdict, because a render that died
   early also produces nothing. `expect_empty` separates the two.
5. **Test both directions.** A hole that coincides with an opening in a vent pattern
   passes a present-check on its own. Check material is absent where it should be
   absent *and* present where it should be present.
6. **Two parts never render together.** OpenSCAD has no notion of a collision, so every
   interference is invisible until `test-fit.sh` renders the boolean.
7. **A volume floor is not a size check.** 85×56 and 95×50 differ by 0.2% of volume and
   by 10 mm of case. Assert extents, not volume. `test-board-assets.sh` does both and
   only the bbox check catches that one.
8. **CSG against a non-manifold import empties the WHOLE object** — which reads as a
   pass everywhere emptiness is the pass. This is why `cad/tests.scad` builds synthetic
   envelopes from declared constants and never touches a mesh.
9. **`render()` inside panel modules.** Preview does not evaluate booleans; it flattens
   the model into a sum of products, exponential in nested differences. A panel cut by
   its neighbours' claims passes 100,000 elements, at which point OpenSCAD aborts and
   shows a BLANK WINDOW while exporting perfectly the whole time.
10. **A cylinder tangent to a plane is not attached to it.** A boss centred exactly half
    a boss off the panel it stands on meets it along a LINE — zero contact area. The
    union renders, the preview looks right, and the part exports as a plate plus loose
    pucks. `hull()` onto a wafer, and let `test-parts.sh` count the bodies.
11. **A claim asks for a volume slightly LARGER than the part, in both directions.** A
    subtraction whose faces are exactly coincident with what it subtracts leaves a
    zero-volume skin: one body, right genus, bounding box a fraction too wide.
12. **`import()` resolves against the MAIN document, `include` against the calling
    file.** A relative asset path in a lib file finds a different directory depending on
    which `.scad` is open — and `generate-stl.sh` renders every part standalone.
13. **An envelope carries the question it was built for.** Ask it a different question
    and you need a different envelope. A deliberate over-estimate is correct for "does
    this touch the shell" and lies about everything finer.
14. **A check that asserts emptiness passes when the thing under test is missing.** The
    `%`-modifier check in `test-assets.sh` was written as "this view renders nothing",
    which is the correct expectation — and it reported green while the mesh import was
    silently failing on a bad path, because a missing file also renders nothing. It now
    renders a 10 mm marker cube *beside* the fan and brackets the volume on both sides:
    the floor catches a broken view, the ceiling catches the mesh leaking into the
    export. **Anywhere "pass" and "broken" produce the same output, add a witness.**
15. **OpenCASCADE's bounding box over an un-tessellated shape is not a measurement.**
    `step-to-stl.py --list` reports the NF-A8's frame as 88.38 mm across; the fan is
    80. OCC computes a conservative box for curved faces before triangulation. Mesh
    first, then measure the mesh — which is what `generate-fan-asset.sh` prints.
16. **Do not assert a belief about a part as if it were a property of the file.**
    `test-assets.sh` first demanded the fan mesh be one body. A fan is legitimately
    eleven — frame, eight corner pads, impeller, hub — so the check was encoding a
    wrong assumption, and "fixing" the asset to satisfy it would have been the real bug.
18. **A test suite that only asks "is it blocked?" cannot see holes that should not
    exist.** `portCuts()` swept the WHOLE IO mask along −Y and confined it to the −Y
    wall's thickness — but the wall spans the case's length, so the RJ45 and USB masks
    dragged sideways landed in it at their own x: three notches in the side wall's rear
    corner, one per board. Every check passed, because every check asked whether a port
    was blocked. **A render found it.** `test-airflow.sh` now compares the two side
    walls' rear regions, which carry identical fields and nothing else, so an extra hole
    on one side shows up as extra volume. Each wall now sweeps only its own connectors.
19. **An assembled case can hide a part that cannot be printed.** With 6 mm seam skirts
    the 80 mm intake left the SHELL part under 1 mm of wall above and below it — two
    posts joined by strips. Assembled, the base and roof skirts filled that band, so
    every fit and tiling check passed. **A render of the part on its own found it.**
    `shell.scad` now asserts a minimum strip, and that no port cluster straddles a seam.
20. **Look at it.** 18 and 19 were both invisible to 58 passing checks and obvious in
    the first rendered image. A suite proves the geometry satisfies the assertions
    someone thought to write; it says nothing about the ones nobody did. Render the
    parts and the assembly before calling a layout change done.
17. **A datasheet dimension is not the part.** The NF-A8 is 80 × 80 × 25 on paper and
    80.1 × 80.0 × **25.4** in Noctua's own model: the AAO frame's anti-vibration pads
    stand 0.2 proud of each mounting face. A 25 mm pocket sits the fan on its pads.

## Companion

- Sibling: [`hexrack-sbc`](../hexrack-sbc/) — modular hex rack; the mesh-asset pattern
  and the `SBC_Model_Framework` submodule come from there
- Sibling: [`lab-router`](../lab-router/) — the standalone-fork pattern this follows
- Sibling: [`naja-miner`](../naja-miner/) — the test harness and the trap list
