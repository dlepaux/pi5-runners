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
