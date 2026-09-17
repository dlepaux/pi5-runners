# pi5-runners — 3D-Printable Tower for Three Pi 5 CI Runners

Standalone case holding three Raspberry Pi 5s that act as self-hosted GitHub Actions
runners. **≈ 101 × 103 × 100 mm, ≈ 1.04 L**, four printed parts, one 80 mm Noctua.

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
- **THE 80 mm IS WHY THERE IS NO PLENUM.** At 80 mm the fan spans the whole board
  stack, presenting a fresh-air front to all three slots at once. A 40 mm fan needed a
  side plenum and ~40 mm of extra width to approximate that. `config.scad` asserts the
  fan's swept height covers the stack; if a slot grows, that assert is what fails
- **The fan wall is +Y, the Pi's GPIO edge.** With the HATs fitted nothing plugs into
  it and the HAT PCBs (56.5) sit flush with the Pi's 56, so the wall is free. It is
  also the wall opposite the USB-C inlet
- **Positive pressure.** One filtered intake, exhaust through the −Y wall and the
  roof. Dust can only enter where the filter is, which is the only reason there is
  exactly one filter
- **The M.2 HAT+ is rated 0–50 °C ambient**, and that is the number this case holds.
  Two 40 mm fans put a 28 °C room at exactly 50 °C — the ceiling, no margin. The
  NF-A8 puts a 25 °C room at ~29 °C
- **Six cables leave the box** — 3× Ethernet on +X, 3× USB-C on −Y — on two adjacent
  walls, because that is where the Pi puts them. The base carries a cable comb so the
  bundle cannot lever a 1 L case over

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
./scripts/test.sh                 # every suite — what CI runs
./scripts/test-board-assets.sh    # declared Pi 5 constants still match the framework
./scripts/generate-stl.sh --local # the four printed parts + showcase
```

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
17. **A datasheet dimension is not the part.** The NF-A8 is 80 × 80 × 25 on paper and
    80.1 × 80.0 × **25.4** in Noctua's own model: the AAO frame's anti-vibration pads
    stand 0.2 proud of each mounting face. A 25 mm pocket sits the fan on its pads.

## Companion

- Sibling: [`hexrack-sbc`](../hexrack-sbc/) — modular hex rack; the mesh-asset pattern
  and the `SBC_Model_Framework` submodule come from there
- Sibling: [`lab-router`](../lab-router/) — the standalone-fork pattern this follows
- Sibling: [`naja-miner`](../naja-miner/) — the test harness and the trap list
