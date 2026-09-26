# pi5-runners — 3D-Printable Stack for Three Pi 5 CI Runners

Standalone case holding three Raspberry Pi 5s that act as self-hosted GitHub Actions
runners. **A stack of three identical modules, one Pi 5 and one 40 mm Noctua each**,
a round dust filter (hexrack's, reshaped) clipped into each module's front, and a lid,
all with rounded vertical corners. 122.5 × 68 × 173 mm with the 10 mm fans (131.6 deep with the 20 mm ones). No screws
hold the case together; only the fans are screwed.

## Project intent

**Standalone**, like [`lab-router`](../lab-router/) and [`naja-miner`](../naja-miner/) —
not a variant of [`hexrack-sbc`](../hexrack-sbc/), and a **single configuration**. The
one switch is `fan_model`; it changes the module and the lid, never the filter.

The load is what makes this case different from a Pi shelf: 100% on all four cores for
30–50 minutes at a stretch, three boards at once, with NVMe traffic throughout. Every
decision below follows from sustained load rather than from idle.

**HOW IT PRINTS IS THE DESIGN.** Every part prints without support in the orientation
`case.scad` exports it, and `test-print.sh` holds that: modules floor-down, the lid
plate-down, the filters face-down. A feature that cannot print
that way is redesigned, not supported.

## Hardware target

| Slot | Board | Storage adapter | Cooling |
|------|-------|-----------------|---------|
| 1 (bottom) | Pi 5 | Raspberry Pi M.2 HAT+ (2242) | Active Cooler |
| 2 (middle) | Pi 5 | Raspberry Pi M.2 HAT+ Compact (2230) | Active Cooler, custom standoffs |
| 3 (top) | Pi 5 | none | Active Cooler |

The slots are a preview choice only: every module is the same part, sized for the
tallest board, so any board goes in any module.

- **THE M.2 HAT+ COMPACT DOES NOT TAKE THE ACTIVE COOLER AS SUPPLIED.** Raspberry Pi
  say so: the standard HAT+ ships with a 16 mm stacking header "so it can be fitted to
  a Raspberry Pi 5 with the Raspberry Pi Active Cooler in place", while the Compact
  "is designed to fit around the included fan in the Raspberry Pi Case… but you can't
  fit the Active Cooler beneath it". Its Pi raises it to the same 16 mm on custom
  standoffs. **This is not re-openable as a preference** — it is the height that
  clears the cooler, and `config.scad` asserts it
- **ONE FAN PER MODULE.** Each module carries a 40 mm Noctua on the inside of its front
  wall, **screwed in from outside, hexrack's way**: M3 countersunk through the 3 mm web
  behind the filter recess into the fan's standard corner holes. Powered from its own
  Pi's GPIO 5 V (pins 2 or 4, ground on 6): a module is a complete unit. Three fans against the two a shared column had is **+50% airflow**:
  ~9.7 K case-air rise, ~15 K under the M.2 HAT's 50 °C rating in a 25 °C room.
  **The owner has two NF-A4x10s; the third is bought**
- **`fan_model`: NF-A4x10 5V (owned) or NF-A4x20 5V**; both meshes are committed.
  Depths are **measured off Noctua's STEP — 12.0 and 21.1**, not the datasheets' 10
  and 20. The fan sits between the front wall and the board, so **it sets the module's
  length and the lid's** — switching fans means reprinting both; the filter is common.
  3-pin, no USB adaptor. **The NF-A4x10's airflow is 8.2 m³/h, not 4.85** — an earlier
  revision read its CFM figure as m³/h and wrongly ruled it out
- **WHAT THE 20 mm FANS BUY.** +15% free airflow (9.4 against 8.2 m³/h) and +27%
  static pressure (2.26 against 1.78 mmH₂O) — the figure that counts behind a filter.
  About 1 K more margin with three of them, not a different class of cooling
- **THE FILTER SETS THE MODULE'S HEIGHT; THE SCREWS SET ITS WIDTH.** The screw heads
  sit in the recess floor, so the ring must lie over all four. They are on the
  diagonals, 22.6 out, and their countersinks reach 3.15 further: a ring of radius
  26.3. Its flats sit just outside the glue pocket, 24 from the centre, at the SIDES
  (the clips read as part of the ring there); so the full circle, 2 × (26.5 + 1), sets
  a 55 mm front per module — 2.4 more than flats top and bottom did. The tallest board needs
  36.45. Screwing the fans from inside would now only narrow the ring, not shorten it
- **THE BOARD IS LIFTED ONTO THE FAN'S AXIS.** The filter leaves ~20 mm spare above
  the board, so `board_lift` (default: centre the tallest board on the fan) raises it
  and the rails grow with it — the whole flow crosses the board and the HAT instead of
  its top half passing over the drive. `-D board_lift=0` puts it back on the floor
- **SIDES: THE PI IS CENTRED ACROSS THE MODULE** — 3 mm to the −Y wall, 2.5 to +Y
  past the HAT's 0.5 overhang — so the two rails sit symmetrically; the first print
  had them 2.5 mm toward −Y and it read as a mistake. The cost: the −Y USB-C and
  micro-HDMI sockets sit 3 mm behind the wall, not 0.5, and a USB-C plug's shell is
  ~6.5 mm, so **check a plug seats on the next print**. The Pi is located by its
  screws; `config.scad` asserts it stays centred. The rails are clipped to the spigot
  so they cannot stand out past it
- **AIR PATH: front to back, along each board's full length.** Each fan draws through
  its dust filter and its front wall's bore, pushes over its own SoC and drive, and
  the module exhausts through its rear wall and the rear of both side walls — **195%
  of its fan's throat** with the NF-A4x10 (222% with the NF-A4x20). **Never the lid**: a lid with holes drops dust on a board.
  Each floor is a lattice too, so a module breathes into the one above
- **EXCLUSION ZONE, hexrack's back-face idea.** A rounded rectangle carved out of the
  vent CUTTER around the RJ45/USB cluster, so the ports sit in clean solid wall. Sized
  from the MEASURED cluster (52.2 × 16.3), not guessed
- **VENTS: every wall edge at 45°.** The floor keeps hexrack's triangle lattice
  (copied verbatim: cell 14, web 1.6, corner 1.2, stagger 0.5). The sides are a
  grille of 45° slots, 3 wide on a 5.5 pitch, clipped by the field (their tops are
  4.2 mm bridges, budgeted), over only the rear half (`vent_side_share`) of the room
  behind the −Y ports; the rear is a 45° diamond lattice (side 5, web 1.6) over the
  whole field, CLIPPED by it and by the port exclusion as the triangles were — whole
  diamonds only fitted one thin row above the ports and read as a strip, not a
  pattern. The triangles on the walls read busy; the simpler, smaller openings cost
  exhaust, 353% → 195% of the throat
- **Positive pressure.** One filtered intake; dust can only enter where the filter is,
  which is the only reason there is exactly one filter
- **Six cables leave the box** — 3× Ethernet at the rear, 3× USB-C on −Y — because
  that is where the Pi puts them. The board is centred, 3 mm off the −Y wall those
  connectors meet. The HAT PCBs are 56.5 against the Pi's 56 and **overhang its +Y edge by
  0.5**, which the module carries

## The parts

| Part | Prints | Is |
|------|--------|----|
| `module` ×3 | floor-down | vented floor with two insert rails, four walls; the front one carries the fan, its bore, its screw holes and the filter's round recess; spigot below, socket above |
| `lid` | plate-down | a spigot with a solid plate on it, and the last few mm of front wall |
| `base` | rim-down | the bottom module's feet: a module's socket (module −1's top slice, cut from `moduleBody()` itself) on an open rim, a 2 mm skirt round the sides and rear, front flush so the filter still comes out |
| `filter` ×3 | face-down | a round ring with two flats, fabric glued into a pocket on its back, two ribs |

- **THE BOARDS ARE NEVER CONNECTED.** Each Pi screws into M2.5 heat-set inserts in
  two rails on its own module's floor — hexrack's "canoes", running along X with the
  airflow. **The board stands on M2.5 × 5 male-female standoffs** (`board_standoff_h`)
  screwed into the inserts, not on the print: the rails stop at `rail_top`, the board
  keeps its height on the fan's axis, and air runs under it. The HAT's M2.5
  male-female standoffs thread through the Pi into those. `standoffs-seated` fails if
  the rails fall short of them
- **STACKING: SPIGOT, SOCKET, 45° LAP ON THE SIDES AND REAR.** A module's bottom band
  is a spigot inset `wall + stack_gap` that drops inside the walls of the module below.
  The walls meet on a lap: the lower wall's top is bevelled inside, and the upper
  wall's underside is a 45° chamfer lying on that bevel (`lap_gap`, 0.05,
  keeps the CAD faces from coinciding) and **running on out to the outer face**. The
  bevel and the front butt joint carry the weight. The lower wall rises into the V as
  a **lip, `lip_t` = 0.4 wide at its top** — one extrusion line, not a knife edge the
  slicer would drop — so the outer faces meet flush but for a hairline. `socket_z` is
  the bevel's reference height; `module_h`, the part's top, is the lip's
  **A step would be a 3 mm ledge printed over air; a chamfer stopping short of the
  outer face leaves a roof — the first print's 1.3 mm one sagged. Nothing on the lap
  prints over air now**, and `test-print.sh`'s flat budget has no room for a roof
- **THE SPIGOT IS NO TALLER THAN ITS CLIP.** Three ribs — one per side, one on the rear
  — and each rib's lowest vertex is the spigot's bottom edge. `spigot_h` is derived:
  the groove below has to sit under the lower module's bevel, and that is all
- **THE FRONT IS A BUTT JOINT.** Each module's front wall runs its full height, full
  width, and stands on the one below, so each filter lies wholly in its own module and
  the stack's front is one face. The lower module's side walls stop behind that front
  wall above their socket; the lid carries the top module's last few millimetres
- **THE DUST FILTER IS hexrack's `sectionDust()`, MADE ROUND, sized for a 40 mm fan**:
  a circular ring cut by flats LEFT AND RIGHT, flush in a 4 mm recess; a 0.32 mm glue
  pocket reaching 4 mm out from the window; two 45° ribs running vertically on the
  flats at the ring's back. **One table** — `filterJoints()` in `lib/dust-filter.scad`
  — cuts the grooves, builds the ribs and feeds `test-clips.sh`. Standing, the
  recess's crown is a 4 mm-deep arc off the web behind it, steeper than 45° near the
  top, which `test-print.sh` budgets. **Round, not hexrack's hexagon, for the rounded
  corners**: the hexagon's side points left 2 mm of front face, the flats 7.5
- **ROUNDED VERTICAL CORNERS, `corner_r`**, from one footprint, `outline()` in
  `lib/stacking.scad`. `insetRect()` offsets it at the rear (the lap stays concentric)
  and only clips it at the front (the front wall is solid full width there). An assert
  keeps 1 mm of wall between a front corner and the filter recess's flats: 4 now, up
  to 6.5 possible
- **CLIPS: hexrack's 45° rib into a groove**, everywhere, **at hexrack's size** (rib 1.7
  square, 18 long on the modules). A 40% smaller rib (1.0 × 11) was printed and came out too
  small; `spigot_h` is derived from the rib and grew back with it. hexrack's `snap-fit.scad` is
  **dead code**; do not port it
- **Assembly**: screw each Pi into its module and each fan in from the front; stack the
  modules and click them together; click the lid on; glue fabric into each filter and
  click it into its recess

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
./scripts/test.sh                   # all seven suites, geometry in both fan modes
./scripts/generate-stl.sh           # module and lid in both fan modes, filter, into stl/
./scripts/generate-fan-asset.sh [m] # regenerate a fan mesh (networked, needs uv)
./scripts/build-site.sh             # STLs + a static download page into _site/
```

**CI** (`.github/workflows/deploy.yml`): on every push to main it runs `test.sh`, then
`build-site.sh`, and publishes `_site/` to GitHub Pages. The page is plain HTML written
by that script — no Node — and its part sizes are measured off the STLs it links.

Open `cad/case.scad` to look at it: `case_part` selects a part, `fan_model` the fans,
`assembly_space` pulls the stack apart, `show_*` toggles the preview content.

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
12. **What a relative `import()` path is relative to CHANGED between OpenSCAD builds.**
    2026.01 resolves it against the MAIN document; the 2026.09 snap CI installs
    resolves it against the file the statement is written in. The fan mesh imported
    in `lib/noctua-fan.scad` passed every local run and failed its first CI run —
    `cad/lib/assets/…` does not exist. **Write every `import()` in a file that lives in
    `cad/`** (`case.scad`, `tests.scad`), where both rules agree; lib modules take the
    mesh as a child. A local toolchain is one data point: CI is the second.
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
21. **Symmetry hides orientation errors.** The filter's placement used a single
    rotate() that turned it 90° to the opening. With a square fan every rotation fits,
    so it was wrong from the start and invisible; the 40 × 80 column made the part
    oblong and the lip landed on solid wall. The placement was also written out twice.
    It is one module now (`filterMounted()`), used by the test and the showcase alike.
22. **"The first line of --bboxes" is the largest BODY, not the mesh.** For the NF-A8 the
    frame happened to be the whole envelope. For the NF-A4x20 the frame is 20.1 deep and
    the mesh 21.1. Both the generator and `test-assets.sh` measure the union now.
23. **"Some overlap" is not "inside".** `pockets-in-rails` asked whether the insert
    pockets overlap the rails at all, and a pocket lifted 3 mm — too shallow for the
    insert, its mouth in the air — still passed. Found by perturbing the geometry to
    see which check fails. `pockets-outside-rails` now demands the pocket be WHOLLY in
    the rail. **Break every new check on purpose once**; one that nothing fails is
    decoration.
24. **A volume sum sees overlap, not a shifted claim.** Panels that overlap sum to more
    than the shell — but a claim SHIFTED 1 mm overlaps its neighbour and leaves a gap
    of almost the same volume, and the sum moved by 3 mm³. Tiling needs both checks:
    the sum for overlap, `shell-minus-parts` for the gap.
25. **A check must push the way only the feature resists.** The first dovetail check
    pulled every rail 1 mm outward and required a collision — which the channel's
    FLOOR provides for any plain slot. A rail escapes through the channel's MOUTH,
    toward the module, and only the flare stops that. Straight rails passed the first
    check and fail the second.
26. **Test the load path, not the part.** "The module above sits on this one" was
    measured on the whole part, and the full-height dovetail rails touched rail-on-rail
    — so a module whose walls stopped 1 mm short still "sat". It is measured on
    `moduleBody()` now: spigot, walls and lap, the things that carry the weight.
27. **Moving a joint's table row moves the rib AND the groove.** That is the design
    working, not a test passing. To prove a clip check, break ONE side of the joint.
28. **An overhang metric cannot tell a bridge from a ledge.** Both are flat downward
    faces. A square-ended rail printed over air adds only flat area, so
    `test-print.sh` budgets flat area too, a few percent above the bridges it has
    accounted for.
29. **When a face closes, re-check what ran out through it.** The floor lattice started
    3 mm from the module's front edge because the front was open. Closing it with a
    wall put the spigot's new front band on top of the lattice's first row: a ledge
    over the vent holes. The flat-overhang total rose by 600 mm² where ~550 was
    expected; grouping the flat faces by height named the 59 mm² that was not a bridge.
30. **A perturbation that trips an assert tests the assert.** Shrinking the filter ring
    by 3.5 mm to prove the "heads under the ring" check fired the glue-pocket assert
    first, and every suite errored — which looks like success. Break a check with the
    smallest change that still reaches it: 1 mm did, and the check failed on its own.
31. **A joint with two bearing faces can hide one.** Once the lap bore on its bevel
    instead of the land, `module-seated` still passed on the front butt joint alone. A
    lap standing 0.2 mm off would have let the rear hang on the clips. `*-seated-on-lap`
    looks behind the front wall only, and fails with `lap_gap = 0.2`.



## Companion

- Sibling: [`hexrack-sbc`](../hexrack-sbc/) — modular hex rack; the mesh-asset pattern
  and the `SBC_Model_Framework` submodule come from there
- Sibling: [`lab-router`](../lab-router/) — the standalone-fork pattern this follows
- Sibling: [`naja-miner`](../naja-miner/) — the test harness and the trap list
