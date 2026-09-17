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

// fanVisualization80() marks its import with %, the background modifier, so it must
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
  fanVisualization80();
}

if (test_view == "report-fan-asset") {
  echo(str("declared = ", fan_asset_extent[0], " ", fan_asset_extent[1], " ",
           fan_asset_extent[2], " tol ", fan_asset_tol));
  cube(1);
}

// -- printed parts -----------------------------------------------------------
if (test_view == "part-base")  basePart();
if (test_view == "part-shell") shellPanel("shell");
if (test_view == "part-roof")  roofPart();

// Disjoint: no two parts may claim the same material.
if (test_view == "part-base-vs-shell")
  intersection() { shellPanel("base");  shellPanel("shell"); }
if (test_view == "part-roof-vs-shell")
  intersection() { shellPanel("roof");  shellPanel("shell"); }
if (test_view == "part-base-vs-roof")
  intersection() { shellPanel("base");  shellPanel("roof"); }

// Complete: nothing of the shell may be left unclaimed. Disjointness alone would be
// satisfied by three parts with a gap between them, which prints a case with a band
// missing and passes every other check in the file.
if (test_view == "shell-minus-parts")
  difference() {
    shellCut();
    shellPanel("base");
    shellPanel("shell");
    shellPanel("roof");
  }

// Every slot must be inside the shell, not embedded in its walls. This is the check
// that a frame error hides from: slot-vs-slot and slot-vs-roof all pass while the
// entire stack sits one wall-thickness into the floor.
if (test_view == "stack-vs-shell")
  intersection() { shellSolid(); union() { slotSlab(0); slotSlab(1); slotSlab(2); } }

// -- vents -------------------------------------------------------------------
// THE DRAWN AREA AGAINST THE COMPUTED ONE. Extruded 1mm, so volume IS area. If
// ventOpenArea() ever stops describing what ventField() draws, the exhaust budget
// becomes a number with no physical meaning and nothing else would notice.
if (test_view == "vent-field-area") linear_extrude(1) ventField(vent_y_w, vent_y_h);
if (test_view == "vent-roof-area")  linear_extrude(1) ventField(vent_roof_w, vent_roof_h);

if (test_view == "report-areas") {
  echo(str("fan_throat_area = ", fan_throat_area));
  echo(str("vent_y_area = ", ventOpenArea(vent_y_w, vent_y_h)));
  echo(str("vent_roof_area = ", ventOpenArea(vent_roof_w, vent_roof_h)));
  echo(str("exhaust_open_area = ", ventOpenArea(vent_y_w, vent_y_h)
                                 + ventOpenArea(vent_roof_w, vent_roof_h)));
  echo(str("filter_open_area = ", filterOpenArea()));
  cube(1);
}

// -- ports -------------------------------------------------------------------
// NO PORT MAY BE BLIND. Any wall material left standing inside a connector's mask is
// a port you cannot plug into -- and it renders, exports and previews perfectly. The
// finished panels are cut by the same allPortCuts() the parts use, so this measures
// the real thing rather than a re-derivation of it.
if (test_view == "ports-blind")
  intersection() {
    union() { basePart(); shellPanel("shell"); roofPart(); }
    allPortProbes();
  }

// ...and the other direction: the walls must still EXIST. A cut that swallowed a
// whole wall passes the check above perfectly.
if (test_view == "wall-y-remains")
  intersection() { shellPanel("shell"); wallSlab("-Y"); }
if (test_view == "wall-x-remains")
  intersection() { shellPanel("shell"); wallSlab("+X"); }

// -- filter ------------------------------------------------------------------
if (test_view == "part-filter") filterPart();

// The lip must actually enter the opening. Modelled as the filter placed at the wall
// and intersected with the SHELL: the flange sits proud and only the lip goes in, so
// any collision here is a lip that is too fat to fit.
if (test_view == "filter-vs-shell")
  intersection() {
    shellCut();
    // rotate([90,0,0]) maps the filter's local +Z to world -Y, so the lip points INTO
    // the opening. rotate([-90,0,0]) maps it to +Y and stands the lip off into open
    // air with the plate buried in the wall -- which is what this first did, and the
    // check caught as 2577mm3 of plate inside the shell.
    translate([wall + interior_x / 2, outer[1] + filter_t,
               wall + fan_z0 + fan_size / 2])
      rotate([90, 0, 0])
        filterPart();
  }

if (test_view == "filter-grille-area")
  linear_extrude(1) ventField(fan_opening - 2 * filter_frame,
                              fan_opening - 2 * filter_frame, filter_cell, filter_web);

if (test_view == "report-filter") {
  echo(str("filter_open_area = ", filterOpenArea()));
  echo(str("filter_frac = ", filterOpenArea() / fan_throat_area));
  echo(str("filter_plate = ", filterPlateSize()));
  cube(1);
}

// The retainer must not touch the top board's cooler. Two posts clear it by
// derivation; this is what notices if the cooler or the hole list ever changes.
if (test_view == "retainer-vs-cooler")
  intersection() {
    roofRetainer();
    onBoard(2) coolerEnvelope();
  }

// The bosses must reach the bottom board and carry an insert.
// The bosses must MEET the board, not pass through it: their top face is the board's
// underside, so the correct relationship is contact and the correct volume is zero.
// "reach" is therefore a measurement, not an intersection -- test-fit.sh reads the
// boss bbox's top against board 0's underside.
if (test_view == "bosses-alone")     baseBosses();
if (test_view == "bosses-vs-board")  intersection() { baseBosses(); boardPcb(0); }

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
  echo(str("fan_span_z = ", fan_z0, " .. ", fan_z0 + fan_size));
  echo(str("fan_throat_area = ", fan_throat_area));
  echo(str("board0_underside = ", wall + board_z[0]));
  echo(str("bed = ", bed));
  cube(1);
}
