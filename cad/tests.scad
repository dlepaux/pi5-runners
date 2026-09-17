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
  cube(1);
}
