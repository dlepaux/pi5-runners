# pi5-runners — 3D-Printable Stack for Three Pi 5 CI Runners

Standalone case holding three Raspberry Pi 5s that act as self-hosted GitHub Actions
runners. **A stack of three identical modules, one Pi 5 and one 40 mm Noctua each**,
a round dust filter (hexrack's, reshaped) clipped into each module's front, and a lid,
all with rounded vertical corners. 115.9 × 68 × 182.4 mm with the 10 mm fans (125.0 deep with the 20 mm ones). No screws
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
  wall, **screwed in from outside, hexrack's way**: Noctua's own self-tapping screws
  from the fan's bag (~M5), countersunk through the 3 mm web behind the filter recess
  into the fan's 4.3 mm corner holes. Powered from its own
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
- **THE FAN SCREWS ARE NOCTUA'S, NOT M3.** The first prints cut a 3.4 mm hole and a
  6.3 countersink for an M3 DIN 7991, "to confirm against the screws actually used".
  The screws were Noctua's ~M5 self-tappers (4.8 thread, 7.05 head, hexrack's
  `M5-Noctua`), which the fans' 4.3 mm holes said all along. Every one cut its own
  thread through the web and wedged its head, and the web cracked toward the bore,
  0.5 mm from the countersink. Now: **a 5.3 hole** (the thread and 0.5), **a 90°
  countersink 7.5 wide under a 0.4 counterbore** (`fan_screw_sink`), so the head sits
  ~0.35 under the recess floor and the filter lies flat, and **a boss round each
  screw**: the 38 mm bore gives up a crescent at each corner so every countersink keeps
  1.2 of web round it. The bosses stop at 17.68 from the axis, short of the blade tips
  (17.41 and 17.57, measured off Noctua's STEP, `fan_tip_r`); they take ~2.5% of the
  throat, left in the airflow figure. `test-airflow.sh` holds the thread's clearance,
  the head's sink, a cone to bear on and a millimetre of wall round every countersink.
  **Check a screw goes in clean on the next print**
- **THE FAN SETS THE MODULE'S HEIGHT, PLUS `module_headroom`.** 46.4
  (`module_pitch_min`): the 2.4 floor, 40 of fan and `fan_clear` 2 above and below, for
  its silicone corner pads. **`module_headroom` = 12.4, 58.8 floor to floor, is the
  owner's call**: 10 at first, because a taller passive heatsink did not fit on
  srv-runner-1; 12.4 once the fan was centred, because that is what the round filter
  needs over Noctua's screw heads (`filter_room` asserts it). The tallest board needs
  42.45 with its air gap
- **THE FAN IS CENTRED**, the owner's call: it sat at the bottom of the front with all
  the headroom above it. `fan_zc` is the middle of `filter_room`, the front face from
  where the front's chamfer reaches the outer face (3.0) to the floor of the lap
  groove of the module on top, less `filter_edge_wall` (0.6) at each end; that is 0.1
  above the middle between the floors. Seen from the front the ring still sits 0.8
  over the seam below and 4.2 under the seam above: the top 3.4 of each face is the
  lap's lip, where the recess cannot go
- **THE BOARD STAYS ON ITS POSTS**, wherever the fan is: the headroom is room for a
  heatsink on it. `board_lift` used to raise it onto the fan's axis when the module
  grew; it never fired until the fan was centred, and then would have eaten 5 mm of
  that room. It is gone, and the board's centre sits 5 below the fan's axis
- **THE FILTER IS ROUND ABOVE AND BELOW**, flats only at the sides (24 from the axis,
  set by the glue pocket), where the clips are. While the fan set the height and sat
  low, the ring was also cut flat top and bottom (`filter_v_out`), 1.6 wide there, and
  the recess's top was a 33 mm bridge. Round, the recess's crown is an arch again,
  ~160 mm² steeper than 45° 4 mm deep off the web, as it was before 6c9bf5f;
  `test-print.sh` budgets it. The front lap groove sits `filter_edge_wall` over that
  crown
- **SIDES: THE PI IS CENTRED ACROSS THE MODULE** — 3 mm to the −Y wall, 2.5 to +Y
  past the HAT's 0.5 overhang — so the four posts sit symmetrically; the first print
  had them 2.5 mm toward −Y and it read as a mistake. The Pi is located by its
  screws; `config.scad` asserts it stays centred. The posts are clipped to the inside
  so they cannot stand into a wall
- **THE PORT ISLAND.** Centred, the −Y USB-C and micro-HDMIs (which stand 1.0 past
  the PCB, `side_port_reach`, measured off the framework) left a plug 5 mm to reach
  from outside — too far to seat. Round the cluster the −Y wall **steps in as a
  panel**: its inner face 0.5 off the connectors (`island_gap`), 2 mm thick there
  (`island_t`), so the outer face is 2.5 in and a plug's reach halves, to 2.5. A
  rounded rectangle, 1.5 round the cluster; top and bottom step in at 45°, inside and
  out, so it reads as one sheared panel and prints; its ends are square, the rear one
  stopping short of the louvres. **The connectors cannot go into the wall** as the
  rear jacks do: the Pi goes in lowered and slid back, never sideways. The −Y port
  cuts reach through the panel (`portSlab()`); `test-fit.sh` holds the connectors clear
  of it and their measured reach to the framework. **Check a plug seats on the next
  print**
- **AIR PATH: front to back, along each board's full length.** Each fan draws through
  its dust filter and its front wall's bore, pushes over its own SoC and drive, and
  the module exhausts through its rear wall and the rear of both side walls — **225%
  of its fan's throat** with the NF-A4x10 (257% with the NF-A4x20). **Never the lid**: a lid with holes drops dust on a board.
  The floor's triangle lattice is an option, **`floor_vents`, off by default**: a
  solid floor prints whole and drops nothing from one board onto the next; on, each
  module breathes into the one above. `test-airflow.sh` checks both
- **EXCLUSION ZONE, hexrack's back-face idea.** A rounded rectangle carved out of the
  vent CUTTER around the RJ45/USB cluster, so the ports sit in clean solid wall. Sized
  from the MEASURED cluster (52.2 × 16.3), not guessed, plus the PCB-edge slot under it
- **REAR: THE PORTS COME THROUGH THE WALL, FLUSH.** The RJ45's face is on the rear
  wall's outer face (`rear_port_proud`), the USB-A stacks 1.3 mm in. The reach, 2.40 past
  the PCB edge, is MEASURED off the framework; it used to be a guessed 3 plus a 3 mm gap,
  which left the ports 6.6–7.9 mm inside the case and too deep for a USB-A plug to seat.
  The PCB's last 0.6 mm sits in a slot in the wall's inner face, its roof at 45°.
  **So the Pi slides in**: lowered short of the wall, then back into its holes, before
  its HAT; `config.scad` asserts the room ahead of it. `test-fit.sh` holds the jacks on
  the face and the PCB and jacks clear of the wall, with the framework's own model
- **VENTS.** The floor keeps hexrack's triangle lattice (copied verbatim: cell 14, web
  1.6, corner 1.2, stagger 0.5). **The sides and the rear are
  LOUVRES**: vertical 3 mm slots on a 5.5 pitch, each sheared through the wall at 45°
  toward the rear (`vent_side_angle`) — `\\\` on +Y, `///` on −Y from above — over the
  whole room behind the −Y ports (`vent_side_share` = 1), six a side. The air turns
  less to leave and there is no line of sight to the board. **Not a Venturi effect**,
  nothing outside moves air past the wall. `test-airflow.sh` counts their THROAT
  (slot × cos 45°), not their face; their flat tops are 3 mm bridges, budgeted.
  The rear's go **straight through** (the air there already heads out) in the same ten
  columns above and below the port cluster, so they read as running top to bottom
  with the ports between (the ports take 55 of the 62 mm inside, so nothing can
  run through them). **No intake louvres ahead of them**: considered and dropped — the
  module is at positive pressure, so any side opening near the fan leaks filtered air
  before it crosses the board and lets dust in when the fans stop.
  Exhaust: 225% of the throat with the NF-A4x10 (257% with the NF-A4x20)
- **Positive pressure.** One filtered intake; dust can only enter where the filter is,
  which is the only reason there is exactly one filter
- **Six cables leave the box** — 3× Ethernet at the rear, 3× USB-C on −Y — because
  that is where the Pi puts them. The board is centred, 3 mm off the −Y wall those
  connectors meet. The HAT PCBs are 56.5 against the Pi's 56 and **overhang its +Y edge by
  0.5**, which the module carries

## The parts

| Part | Prints | Is |
|------|--------|----|
| `module` ×3 | floor-down | a floor (solid by default, `floor_vents`) with four feet, four walls; the front one carries the fan, its bore, its screw holes and the filter's recess; a 45° chamfer with four clip ribs below, a bevel with four grooves above |
| `lid` | plate-down | a module's chamfer and four ribs with a solid plate on it |
| `filter` ×3 | face-down | a round ring with two flats, fabric glued into a pocket on its back, two ribs |

- **THE BOARDS ARE NEVER CONNECTED.** Each Pi screws straight into four printed
  feet on its own module's floor, one per hole — **not hexrack's "canoes"**: the
  rails joining each row cost plastic for nothing, and the air under the board runs
  round four feet instead of along two walls. **No heat-set inserts, no bought
  standoffs**: each foot runs from the floor to the board's underside (`post_h`),
  Ø`post_d` = 6 — the Pi's mounting pad — flaring onto the floor on a 45°
  `post_chamfer`, with hexrack's `M2.5-4` pilot hole `pilot_depth` deep. The screw
  cuts its own thread. The HAT's M2.5 male-female standoffs thread through the Pi
  into the feet; a bare Pi takes M2.5 × 6 screws. `posts-seated` fails if the feet
  fall short of the board, `pilots-outside-posts` if a hole leaves its foot
- **STACKING: ONE 45° LAP ON ALL FOUR WALLS, NO SPIGOT.** A module's walls end below
  in a 45° chamfer across their whole thickness, low at the inner face, high at the
  outer; the module below ends its walls in a bevel of the same slope (`lap_gap`,
  0.05, keeps the CAD faces from coinciding). The chamfer lies on the bevel **on all
  four sides, the front included** — it carries the weight and centres the stack.
  The lower wall rises into the V as a **lip, `lip_t` = 0.4 wide at its top** — one
  extrusion line, not a knife edge the slicer would drop — so the outer faces meet
  flush but for a hairline. **A step would be a ledge printed over air; a chamfer
  stopping short of the outer face leaves a roof — the first print's 1.3 mm one
  sagged. Nothing on the lap prints over air**, and `test-print.sh`'s flat budget has
  no room for a roof. The front wall is solid `front_wall_t` deep for the filter's
  recess and the fan, but **stops 0.4 short of the next module's floor** (`front_top`,
  the groove's floor); above that only its outer 3 mm rises, as a lap. The module above
  bears on its lap alone, on all four walls
- **THE CLIP IS ON THE LAP — HALF OF THE OLD `>`.** One rib per wall (`lapJoints()`,
  four in all). Seen end-on, the old rib stood out of its wall as a `>`; on the lap
  it keeps that `>` as the world sees it, **only its upper half**: a flat underside
  on the bed, a face falling outward (the `>`'s upper stroke, the face that holds) at
  **`lap_clip_angle` = 60°**, steeper than the old 45° so a module lets go more
  easily (and a gentler overhang in the groove); `lap_rib` (1.0) tall, 1.58 wide on
  the bed, and its third side on the chamfer. The groove in the bevel below
  is the same triangle grown `clip_clear` (0.4) — **except on the holding face, which
  fits at `lap_hold_clear` (0.1)**. At 0.4 all round a module lifted 0.8 mm before its
  clips took it, and the walls had only ~0.3 to spring to let go; at 0.1 it is 0.2 of
  play and ~0.5 of spring. `test-clips.sh` lifts every lap rib 0.3 mm and requires it
  to bite. If a printed module will not seat flush, suspect elephant's foot on the
  rib's bed-side corner before opening `lap_hold_clear` to 0.15. Pushed down, the flat underside rides the
  bevel and spreads the walls; pulled up, the holding face resists. Every face lies
  on the bed or at 45° or steeper, so rib and groove both print. **Not a square bar on the
  chamfer**: that was a first version, and read as a clip turned 45°. The groove
  runs 2.0 out from the rib's inner corner; `lap_z0` is how far that corner must sit
  in from the wall's inner face to leave `lap_clip_wall` (0.7) outside the groove —
  0 now, so the rib starts on the inner edge, on the bed. **So the female is OPEN
  INWARD**: a floor 0.4 under the bevel's inner edge, running out to the inside, under
  the 60° face that holds — at the front too, now its inner part stops at that floor, so
  a rib hooks in from the inside. Not a mistake — a closed pocket would need the rib moved
  out, and the wall only has 0.3 to spare, a sliver. Were `lap_z0` > 0, the chamfer
  is carried on down to the bed so the floor narrows to the rib with no step. A lap joint is a 5-field row (the outward direction);
  `clipRib()`/`clipGroove()` build it from `lapClipProfile()`. This replaced a 5.2 mm
  spigot band that only carried the clips
- **THE FRONT LIP DOES NOT SPRING; THE FRONT CLIP IS HOOKED IN FIRST.** A rib passes
  the lip below by pushing it 0.48 mm out. The side and rear walls give; the front is
  7 mm solid under its lip, so a module goes on tilted, its front clip hooked in first,
  then its rear pressed down. **A thinned band above the fan was tried** (4b24efa,
  `frontFlexCut()`): the front wall cut to 1.2 from the inside, between the corners.
  The two corners it left solid clamped the lip at both ends, and on the print they
  kept the lid from clipping properly; it also made the front's inside a clutter of
  pillars and corbels for nothing. With the fan centred the band has no room anyway.
  It is gone
- **THE FRONT WALL'S INNER PART STOPS SHORT OF THE MODULE ABOVE.** It rose flush with
  the next module's floor: a second seat beside the lap (whichever prints high bears,
  and the clips stop short of seating), and a wall closing the front groove's inner
  side, so the rib slid in over it at zero clearance, where a first layer's squish
  catches.
  Its top is now `front_top`, the groove's floor, 0.4 under the next floor, level over
  the filter's recess. Behind the recess it **falls steeply to the fan's top**, the
  owner's call: ~73°, from 4.6 mm into the wall down to 50.7 on the inside face, so the
  inside face ends where the fan's frame does. Straight from the recess's back it left
  0.24 of web behind the recess's crown, under one extrusion line, and a pinhole there
  lets unfiltered air round the ring; it passes `front_web_min` (0.8) behind it.
  Lower over the recess it cannot go: the round recess's crown is 0.6 under
  `front_top`. `test-fit.sh` sinks the module above 0.3 mm and slides the front rib in
  from the inside 0.2 mm low, and holds the wall over and behind the crown
- **THE SEATING CHECKS MEASURE BODIES, NOT PARTS.** `moduleBody()` and `lidBody()`
  carry no ribs: with the ribs on, a rib biting the ungrooved bevel passes for a lap
  that bears. The lid's check did exactly that until the lid got its own body; all
  three `*-seated-on-lap` checks fail with `lap_gap = 0.3`
- **THE DUST FILTER IS hexrack's `sectionDust()`, MADE ROUND, sized for a 40 mm fan**:
  a circular ring cut by flats left and right (the clips), flush in a 4 mm recess; a
  0.32 mm glue
  pocket reaching 4 mm out from the window; two 45° ribs running vertically on the
  flats at the ring's back. **One table** — `filterJoints()` in `lib/dust-filter.scad`
  — cuts the grooves, builds the ribs and feeds `test-clips.sh`. Standing, the
  recess's crown is an arch 4 mm deep off the web behind it, which `test-print.sh`
  budgets. **Round, not hexrack's hexagon, for the rounded
  corners**: the hexagon's side points left 2 mm of front face, the flats 7.5
- **ROUNDED VERTICAL CORNERS, `corner_r`**, from one footprint, `outline()` in
  `lib/stacking.scad`. `insetRect()` offsets it at the rear (the lap stays concentric)
  and only clips it at the front (the front wall is solid full width there). An assert
  keeps 1 mm of wall between a front corner and the filter recess's flats: 4 now, up
  to 6.5 possible
- **CLIPS: hexrack's 45° rib into a groove.** The dust filter keeps the full diamond,
  **20% under hexrack's size** (rib 1.36 square, `clip_rib`), the owner's call; the
  modules' lap clips are half of it (above). A 40% smaller rib (1.0 × 11) was once
  printed on the module joints and came out too small. hexrack's `snap-fit.scad` is
  **dead code**; do not port it
- **NO BASE.** There were feet — a module's bevel on an open rim with a skirt — and
  they were dropped as useless: the bottom module stands on its own floor, flat on
  the bed side, the lap ribs' flat undersides flush with it
- **Assembly**: slide each Pi back into its rear wall's holes, fit its HAT and screw it into its module and each fan in from the front, with
  the screws in the fan's bag; stack the modules, each tilted with its front clip
  hooked in first, then pressed down at the rear until the other three lap clips click;
  click the lid on; glue fabric into each filter and click it into its recess

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

**Pre-push hook** (`.githooks/pre-push`) runs `test.sh`; enable it once per clone with
`git config core.hooksPath .githooks`. It runs the local OpenSCAD, so it cannot catch
what only CI's newer snap sees — the red build it was added for was one of those
(`show_boards = true` pulled in the framework's cooler DXF by a relative path).

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
23. **"Some overlap" is not "inside".** `pockets-in-rails` asked whether the (then)
    insert pockets overlap the rails at all, and a pocket lifted 3 mm — too shallow for the
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
    looks behind the front wall only, and fails with `lap_gap = 0.2`. The butt joint
    was also the seat — the lap stood `lap_gap` off it — so on a print whichever face
    came out high bore. It is gone (`front_top`); `front-wall-clear` keeps it gone.
32. **A placeholder that gets printed is no longer a placeholder.** The fan screws were
    drawn as an M3 DIN 7991, "confirm against the screws actually used before
    printing". Nobody did, and the fans' own 4.3 mm corner holes, in Noctua's STEP all
    along, said M5. Every one of Noctua's self-tappers cut its own thread through the
    3.4 mm hole and cracked the web. **Measure what goes in a hole, or read it off the
    part it goes into, before the first print.** The suite could not have caught it:
    every check read the same wrong spec.



## Companion

- Sibling: [`hexrack-sbc`](../hexrack-sbc/) — modular hex rack; the mesh-asset pattern
  and the `SBC_Model_Framework` submodule come from there
- Sibling: [`lab-router`](../lab-router/) — the standalone-fork pattern this follows
- Sibling: [`naja-miner`](../naja-miner/) — the test harness and the trap list
