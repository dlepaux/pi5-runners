// ============================================================================
// TESTS — geometry views for scripts/test-*.sh
// ============================================================================
// Not a part. This file exists so the fit checks measure the SAME geometry the
// printed parts are made of, rather than a re-derivation of it that can drift.
// Every view either renders to nothing — which is the PASS for a clearance check —
// or renders one solid whose volume or bounding box the shell script reads.
//
//   openscad -D 'test_view="pi5-envelope"' cad/tests.scad
//
// WHY SYNTHETIC ENVELOPES AND NOT THE FRAMEWORK MESH. CSG against a non-manifold
// import does not fail; it collapses the WHOLE result to empty. A clearance test
// written against sbc("rpi5") would therefore report "empty" — a PASS — no matter
// where the board actually was. Every envelope below is built from declared
// constants, and scripts/test-board-assets.sh is what ties those back to the model.
// ============================================================================

include <config.scad>
use <lib/m2-hat-plus.scad>
// include, not use: placement.scad carries board_z and the envelope constants, and
// `use` imports modules and functions but NOT variables -- they would come back undef
// and only a WARNING would say so.
include <lib/placement.scad>
use <lib/noctua-fan.scad>
include <lib/shell.scad>
include <lib/vents.scad>
use <lib/ports.scad>
use <parts/filter.scad>
use <parts/base.scad>
use <parts/roof.scad>
use <parts/walls.scad>

test_view = "";

// ----------------------------------------------------------------------------
// ENVELOPES
// ----------------------------------------------------------------------------

// The Pi 5's PCB as a bare slab, from declared constants.
module pi5Pcb() {
  cube(pi5_pcb);
}

// ----------------------------------------------------------------------------
// VIEWS
// ----------------------------------------------------------------------------

if (test_view == "pi5-envelope") pi5Pcb();

// -- HATs --------------------------------------------------------------------
if (test_view == "hat-standard-outline") linear_extrude(1) hatStandardOutline();
if (test_view == "hat-compact-outline")  linear_extrude(1) hatCompactOutline();
if (test_view == "hat-standard-solid")   hatStandardSolid();
if (test_view == "hat-compact-solid")    hatCompactSolid();

// The clearance that the whole slot-2 decision rests on. Both must be empty: the
// standard HAT+ because Raspberry Pi ship it with a 16mm header for exactly this,
// the Compact because we raise it onto the same 16mm on custom standoffs.
if (test_view == "cooler-vs-hat-standard")
  intersection() { coolerEnvelope(); hatStandardSolid(); }
if (test_view == "cooler-vs-hat-compact")
  intersection() { coolerEnvelope(); hatCompactSolid(); }

// -- the stack ---------------------------------------------------------------
if (test_view == "slot0-solid") slotSlab(0);
if (test_view == "slot1-solid") slotSlab(1);
if (test_view == "slot2-solid") slotSlab(2);

// Each slot's contents against the BARE PCB above it. Tested against the PCB and not
// against the neighbour's slab, because the neighbour's slab claims the air above its
// own cooler -- which this slot has no business reaching into anyway, but which is
// not what "do these two boards collide" is asking.
if (test_view == "slot0-vs-slot1") intersection() { slotSlab(0); boardPcb(1); }
if (test_view == "slot1-vs-slot2") intersection() { slotSlab(1); boardPcb(2); }
if (test_view == "slot2-vs-roof")  intersection() { slotSlab(2); roofPlane(); }

// -- fan asset ---------------------------------------------------------------
if (test_view == "fan-mesh-raw") import(fan_asset, center = true);

// fanVisualization() marks its import with %, the background modifier, so it must
// contribute NOTHING to a render. If it ever renders geometry, Noctua's mesh is
// shipping inside every published STL.
//
// THE MARKER CUBE IS LOad-BEARING. Asserting "this renders empty" would pass just as
// happily when the mesh file is missing, the path is wrong or the module is
// misspelled -- the first version of this check did exactly that and reported a
// green % while the import was silently failing. Rendering a known 10mm marker
// ALONGSIDE it turns the assertion into "the marker and nothing else": a missing
// file still gives 1000mm3, and a % swapped for # adds the fan on top of it.
if (test_view == "fan-visualization-export") {
  cube(10);
  fanVisualization();
}

if (test_view == "report-fan-asset") {
  echo(str("declared = ", fan_asset_extent[0], " ", fan_asset_extent[1], " ",
           fan_asset_extent[2], " tol ", fan_asset_tol));
  cube(1);
}

// -- printed parts -----------------------------------------------------------
module partByName(n) {
  if (n == "base")   basePart();
  if (n == "front")  frontPart();
  if (n == "rear")   rearPart();
  if (n == "left")   leftPart();
  if (n == "right")  rightPart();
  if (n == "roof")   roofPart();
  if (n == "filter") filterPart();
}

part = "";      // set with -D for the per-part views below
clip_k = -1;    // set with -D for the per-joint views below

if (test_view == "part")  partByName(part);
if (test_view == "panel") shellPanel(part);
if (test_view == "shell-cut") shellCut();

// COMPLETE: nothing of the cut shell may be left unclaimed. A gap between two claims
// prints a case with a slot missing and passes every other check in the file.
// (DISJOINT is checked by volume in test-parts.sh: with six panels there are fifteen
// pairs, but overlapping panels always sum to MORE than the shell, so one comparison
// catches all fifteen.)
if (test_view == "shell-minus-parts")
  difference() {
    shellCut();
    for (n = shell_parts) shellPanel(n);
  }

// NOTHING PRINTED MAY TOUCH THE BOARD TOWER. Rims, flanges, rails and ribs all live
// inside the case, which is where the boards are. This also catches the frame error
// that hides from slot-vs-slot checks: the whole stack sitting a wall-thickness into
// the floor.
if (test_view == "parts-vs-stack")
  intersection() {
    union() for (n = shell_parts) partByName(n);
    union() { slotSlab(0); slotSlab(1); slotSlab(2); }
  }

// -- vents -------------------------------------------------------------------
// MEASURED, not computed: extruded 1mm, volume IS area, and it is the exact profile
// ventCuts() sweeps through the wall.
if (test_view == "rear-vent-area")     linear_extrude(1) rearVentProfile();
if (test_view == "side-vent-area")     linear_extrude(1) sideVentProfile();

// The side fields must actually cut BOTH side walls -- measured as material removed.
// An onYWall() sweep started at the wrong face runs into open air and removes nothing.
if (test_view == "side-y-neg-removed")
  difference() { intersection() { shellSolid(); wallSlab("-Y"); }
                 intersection() { shellCut();   wallSlab("-Y"); } }

// NO SPURIOUS HOLES. In the rear region both side walls carry the same field and
// nothing else, so they must lose exactly the same material. Now that the walls also
// carry clip grooves, the region's comparison still holds: both side walls get the
// same grooves, mirrored.
module rearRegion() {
  x0 = wall_front + board_x + side_port_cluster_x1 + 1;
  translate([x0, -1, -1]) cube([outer[0] - x0 + 1, outer[1] + 2, outer[2] + 2]);
}
if (test_view == "side-y-neg-rear-removed")
  intersection() {
    rearRegion();
    difference() { intersection() { shellSolid(); wallSlab("-Y"); }
                   intersection() { shellCut();   wallSlab("-Y"); } }
  }
if (test_view == "side-y-pos-rear-removed")
  intersection() {
    rearRegion();
    difference() { intersection() { shellSolid(); wallSlabYPos(); }
                   intersection() { shellCut();   wallSlabYPos(); } }
  }

// Every exclusion zone must keep the vent pattern off its port cluster.
if (test_view == "exclusion-holds")
  intersection() {
    linear_extrude(1) rearVentProfile();
    for (i = [0 : 2])
      linear_extrude(1)
        translate(exclusionCentre(i))
          square([exclusion_w - 2 * exclusion_r, exclusion_h - 2 * exclusion_r],
                 center = true);
  }

if (test_view == "report-areas") {
  echo(str("fan_throat_area = ", fan_throat_area));
  cube(1);
}

// -- ports -------------------------------------------------------------------
// NO PORT MAY BE BLIND: no printed part may stand inside a connector's probe.
if (test_view == "ports-blind")
  intersection() {
    union() for (n = shell_parts) partByName(n);
    allPortProbes();
  }

// ...and the walls must still EXIST.
if (test_view == "wall-y-remains") intersection() { shellCut(); wallSlab("-Y"); }
if (test_view == "wall-x-remains") intersection() { shellCut(); wallSlab("+X"); }

// -- intake and filter -------------------------------------------------------
// The filter ring sits in the front wall's recess touching nothing: ring outline
// clears the recess by filter_clear, and its ribs sit in their grooves.
if (test_view == "filter-vs-front") intersection() { filterMounted(); frontPart(); }

// The ring must not restrict the air: both round bores behind it must lie inside its
// opening. Only the fabric is allowed in the airstream.
if (test_view == "bores-outside-ring")
  linear_extrude(1) difference() { fanBoreProfile(); fanOpeningProfile(); }

// THE FANS NEED SOMETHING TO SCREW INTO. This is the check that was missing while
// every screw hole sat inside a square opening over empty air: a ring of wall round
// each pilot hole, through the 3mm behind the recess floor, must be solid.
module pilotAnnuli() {
  onXWall(filter_depth)
    linear_extrude(wall_front - filter_depth)
      translate(fanCentreYZ())
        difference() { fanBoltProfile(fan_pilot_d + 3); fanBoltProfile(fan_pilot_d); }
}
if (test_view == "pilot-material") intersection() { frontPart(); pilotAnnuli(); }
if (test_view == "pilot-annuli")   pilotAnnuli();

// -- base rails and inserts --------------------------------------------------
if (test_view == "canoes-alone")    canoes();
if (test_view == "canoes-vs-board") intersection() { canoes(); boardPcb(0); }
// A pocket must be VOID in the finished part...
if (test_view == "pockets-vs-base") intersection() { insertPockets(); basePart(); }
// ...and must sit INSIDE a rail, not in open air beside it. Both directions.
if (test_view == "pockets-in-rails") intersection() { insertPockets(); canoes(); }
// ...and WHOLLY inside. The check above only asks for some overlap, so a pocket lifted
// 3mm -- too shallow to take the insert, its mouth in the air -- still passes it. Only
// the mask's 0.01mm mouth sliver may stand proud of the rail top.
if (test_view == "pockets-outside-rails")
  difference() {
    insertPockets();
    canoes();
    translate([-1, -1, wall + base_standoff]) cube([outer[0] + 2, outer[1] + 2, 0.05]);
  }

// -- clips -------------------------------------------------------------------
// One joint at a time, by index into clipJoints(): -D clip_k=N.
if (test_view == "report-clips") {
  for (k = [0 : len(clipJoints()) - 1])
    echo(str("CLIP ", k, " ", clipJoints()[k][0], " ", clipJoints()[k][4],
             " ", clipJoints()[k][5]));
  cube(1);
}
// At rest the rib touches nothing of the part it clips into: it is in its groove.
if (test_view == "clip-rib-vs-mate")
  intersection() { clipRib(clipJoints()[clip_k]); partByName(clipJoints()[clip_k][5]); }
// ...and it actually reaches INTO that part's territory, so it is engaged, not just
// clear. Emptiness above would pass for a rib that stops short of its groove.
if (test_view == "clip-rib-reach")
  intersection() { clipRib(clipJoints()[clip_k]); claimVolume(clipJoints()[clip_k][5]); }
if (test_view == "clip-rib")
  clipRib(clipJoints()[clip_k]);

// -- fans --------------------------------------------------------------------
// The fan column's body must clear every slot -- in particular slot 1's Compact tab,
// which hangs 6.5 off the board TOWARD the fans -- and every printed part.
module fanColumn() {
  interiorOrigin()
    translate([0, interior_y / 2, fan_col_zc])
      rotate([0, 0, -90])
        fanEnvelope();
}
if (test_view == "fans-vs-stack")
  intersection() { fanColumn(); union() { slotSlab(0); slotSlab(1); slotSlab(2); } }
if (test_view == "fans-vs-case")
  intersection() { fanColumn(); union() for (n = shell_parts) partByName(n); }
if (test_view == "fans-alone") fanColumn();

// -- reporting ---------------------------------------------------------------
// Echoes the derived geometry so a human (or a test) reads the numbers the parts are
// actually built from, rather than the numbers a document claims. Renders a unit cube
// on purpose: empty is the PASS everywhere else in this file, so a reporting view
// that rendered nothing would be indistinguishable from one that died.
if (test_view == "report-geometry") {
  echo(str("interior = ", interior_x, " x ", interior_y, " x ", interior_h));
  echo(str("outer = ", outer[0], " x ", outer[1], " x ", outer[2]));
  echo(str("volume_L = ", outer[0] * outer[1] * outer[2] / 1e6));
  echo(str("board_z = ", board_z, " stack_top = ", stack_top));
  echo(str("fan_span_z = ", fan_z0, " .. ", fan_z0 + fan_col_h));
  echo(str("fan_throat_area = ", fan_throat_area));
  echo(str("board0_underside = ", wall + board_z[0]));
  echo(str("bed = ", bed));
  cube(1);
}
