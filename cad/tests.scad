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
// include, not use: these carry constants the views read, and `use` imports modules
// and functions but NOT variables -- they would come back undef, with only a WARNING.
include <lib/placement.scad>
include <lib/stacking.scad>
use <lib/noctua-fan.scad>
use <lib/ports.scad>
use <lib/vents.scad>
use <parts/module.scad>
use <parts/lid.scad>
use <parts/front.scad>
use <parts/filter.scad>

test_view = "";
part   = "";     // set with -D for the per-part views
kind   = "";     // set with -D for the per-board views: standard | compact | bare
clip_k = -1;     // set with -D for the per-joint views

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
// As they sit in the case, in the stack frame.
module partByName(n) {
  if (n == "module") modulePart();
  if (n == "lid")    lidAt() lidPart();
  if (n == "front")  frontPart();
  if (n == "filter") filterMounted();
}
// As they print: what the bed check and the printability check measure.
module printByName(n) {
  if (n == "module") modulePart();
  if (n == "lid")    lidPrint();
  if (n == "front")  frontPart();
  if (n == "filter") filterPart();
}
if (test_view == "part")  partByName(part);
if (test_view == "print") printByName(part);

// The whole case, as it stands: every module, the lid, the front face.
module wholeCase() {
  for (k = [0 : module_count - 1]) moduleAt(k) modulePart();
  lidAt() lidPart();
  frontPart();
}
module allModules() {
  for (k = [0 : module_count - 1]) moduleAt(k) modulePart();
}

// -- a board in its module --------------------------------------------------
// Module frame. Every module is the same part, so each kind of board is checked
// against the one module -- and against the module, or lid, that stacks on it.
if (test_view == "slot-solid") slotSlab(kind);
if (test_view == "slot-vs-module") intersection() { slotSlab(kind); modulePart(); }
if (test_view == "slot-vs-above")
  intersection() { slotSlab(kind); union() { moduleAt(1) modulePart(); moduleAt(1) lidPart(); } }

if (test_view == "canoes-alone")    canoes();
if (test_view == "canoes-vs-board") intersection() { canoes(); boardPcb(); }
// A pocket must be VOID in the finished part...
if (test_view == "pockets-vs-module") intersection() { insertPockets(); modulePart(); }
// ...must sit in a rail, not in the air beside one...
if (test_view == "pockets-in-rails") intersection() { insertPockets(); canoes(); }
// ...and WHOLLY in it, or in the SOLID floor under it -- the 6.7mm pocket runs 1.1mm
// into the floor, which is why the floor's vents keep clear of the rails. The check
// above only asks for some overlap, so a pocket lifted 3mm -- too shallow for the
// insert -- still passes it. Only the mask's 0.01mm mouth may stand proud.
if (test_view == "pockets-outside-rails")
  difference() {
    insertPockets();
    canoes();
    linear_extrude(floor_t)
      difference() { insetRect(spigot_inset); floorVentProfile(); }
    translate([-1, -1, board_z]) cube([module_l + 2, module_w + 2, 0.05]);
  }

// -- stacking -----------------------------------------------------------------
// Neighbours touch on the land and nowhere else.
if (test_view == "module-vs-above") intersection() { modulePart(); moduleAt(1) modulePart(); }
if (test_view == "module-vs-lid")   intersection() { modulePart(); moduleAt(1) lidPart(); }
// ...and they DO touch. "Nothing overlaps" is also true of a module floating 5mm up;
// lowered 0.2mm, the module above must bite into this one. moduleBody(), not the part:
// the dovetail rails run the full height too, and rail on rail would pass this for a
// module whose walls stop short and whose weight sits on four rail ends.
if (test_view == "module-seated")
  intersection() { moduleBody(); translate([0, 0, module_pitch - 0.2]) moduleBody(); }
if (test_view == "lid-seated")
  intersection() { moduleBody(); translate([0, 0, module_pitch - 0.2]) lidPart(); }

// -- clips -------------------------------------------------------------------
// One table of every clipped joint: [name, rib (stack frame), owner, mate].
function allJoints() = concat(
  [ for (j = spigotJoints()) [str("module-", j[0]), socketJoint(j), "module", "module"] ],
  [ for (j = spigotJoints())
      [str("lid-", j[0]),
       [j[0], j[1] + [0, 0, module_count * module_pitch], j[2], j[3]], "lid", "module"] ],
  [ for (j = filterJoints()) [j[0], j, "filter", "front"] ]);

// The mate, as it sits relative to the rib: a spigot rib of the module above, or of
// the lid, lands in the socket of the module below it.
module mateOf(row) {
  if (row[3] == "front") frontPart();
  else if (row[2] == "lid") moduleAt(module_count - 1) modulePart();
  else modulePart();
}
// The mate's own territory -- where a rib must reach to be engaged: the walls of the
// module below, or the front face's body before any cut.
module mateTerritory(row) {
  if (row[3] == "front") frontBody();
  else moduleAt(row[2] == "lid" ? module_count - 1 : 0)
    linear_extrude(module_h) difference() { square([module_l, module_w]); insetRect(wall, 1); }
}

if (test_view == "report-clips") {
  for (k = [0 : len(allJoints()) - 1])
    echo(str("CLIP ", k, " ", allJoints()[k][0], " ", allJoints()[k][2], " ", allJoints()[k][3]));
  cube(1);
}
if (test_view == "clip-rib")       clipRib(allJoints()[clip_k][1]);
if (test_view == "clip-rib-vs-mate")
  intersection() { clipRib(allJoints()[clip_k][1]); mateOf(allJoints()[clip_k]); }
if (test_view == "clip-rib-reach")
  intersection() { clipRib(allJoints()[clip_k][1]); mateTerritory(allJoints()[clip_k]); }

// -- dovetails ---------------------------------------------------------------
// The front face touches no module and not the lid...
if (test_view == "front-vs-stack")
  intersection() { frontPart(); union() { allModules(); lidAt() lidPart(); } }
// ...every rail lies inside its channel...
module stackRails() { for (k = [0 : module_count - 1]) moduleAt(k) dovetailRails(); }
if (test_view == "rails-alone") stackRails();
if (test_view == "rails-in-channels") intersection() { stackRails(); dovetailChannels(); }
// ...and the channels CAPTURE them. A channel's mouth faces the module, so a rail
// escapes by moving TOWARD the module -- and only the dovetail's flare stops that. Each
// side is pulled on its own, 1mm out through its mouth, and must run into the face.
// (Pulled the other way a rail hits the channel floor, which any plain slot does.)
module sideRails(side) {
  intersection() {
    stackRails();
    translate([-50, side < 0 ? -50 : module_w / 2, -1])
      cube([200, module_w / 2 + 50, stack_h + 2]);
  }
}
if (test_view == "dovetail-holds-left")
  intersection() { frontPart(); translate([0,  1, 0]) sideRails(-1); }
if (test_view == "dovetail-holds-right")
  intersection() { frontPart(); translate([0, -1, 0]) sideRails(1); }
// And forward: pulled 1mm off the modules, the rails run into the channels' walls.
if (test_view == "dovetail-holds-x")
  intersection() { frontPart(); translate([-1, 0, 0]) stackRails(); }

// -- ports -------------------------------------------------------------------
// NO PORT MAY BE BLIND: nothing printed may stand in a connector's probe.
if (test_view == "ports-blind")
  intersection() { union() { modulePart(); frontPart(); } allPortProbes(); }
// ...and the walls must still EXIST.
if (test_view == "wall-y-remains") intersection() { modulePart(); wallSlab("-Y"); }
if (test_view == "wall-x-remains") intersection() { modulePart(); wallSlab("+X"); }

// -- vents -------------------------------------------------------------------
// MEASURED, not computed: extruded 1mm, volume IS area.
if (test_view == "rear-vent-area")  linear_extrude(1) rearVentProfile();
if (test_view == "side-vent-area")  linear_extrude(1) sideVentProfile();
if (test_view == "floor-vent-area") linear_extrude(1) floorVentProfile();

if (test_view == "exclusion-holds")
  intersection() {
    linear_extrude(1) rearVentProfile();
    linear_extrude(1) translate(exclusionCentre())
      square([exclusion_w - 2 * exclusion_r, exclusion_h - 2 * exclusion_r], center = true);
  }

// NO SPURIOUS HOLES. Behind the -Y connectors both side walls carry the same field and
// the same grooves, mirrored, and nothing else -- so they must lose the same material.
module rearRegion() {
  translate([side_field_x[0] - 1, -1, -1]) cube([module_l, module_w + 2, module_h + 2]);
}
module removedFrom(which) {
  intersection() {
    rearRegion();
    difference() {
      intersection() { moduleBody(); wallSlab(which); }
      intersection() { modulePart(); wallSlab(which); }
    }
  }
}
if (test_view == "side-y-neg-rear-removed") removedFrom("-Y");
if (test_view == "side-y-pos-rear-removed") removedFrom("+Y");

if (test_view == "report-areas") {
  echo(str("fan_throat_area = ", fan_throat_area, " module_count = ", module_count));
  cube(1);
}

// -- intake, fans and filter --------------------------------------------------
if (test_view == "filter-vs-front") intersection() { filterMounted(); frontPart(); }

// Only the fabric may be in the airstream: both bores must lie inside the pill's
// opening.
if (test_view == "bores-outside-pill")
  linear_extrude(1) difference() { fanBoreProfile(); pillProfile(pill_r_in); }

// THE FANS NEED SOMETHING TO SCREW INTO: a ring of plate round every pilot hole,
// through the 3mm behind the recess floor, must be solid.
module pilotAnnuli() {
  onPlate(-front_d + filter_depth)
    linear_extrude(plate_t - filter_depth)
      difference() { fanBoltProfile(fan_pilot_d + 3); fanBoltProfile(fan_pilot_d); }
}
if (test_view == "pilot-material") intersection() { frontPart(); pilotAnnuli(); }
if (test_view == "pilot-annuli")   pilotAnnuli();

// The column, on the plate's inner face.
module fanColumn() {
  translate([-front_d + plate_t, fan_col_yc, fan_col_zc])
    rotate([0, 0, -90]) fanEnvelope();
}
if (test_view == "fans-alone")    fanColumn();
if (test_view == "fans-vs-case")  intersection() { fanColumn(); wholeCase(); }
// ...and it SITS on the plate: moved 0.2mm forward, it must run into it.
if (test_view == "fans-seated")
  intersection() { translate([-0.2, 0, 0]) fanColumn(); frontPart(); }

// -- reporting ---------------------------------------------------------------
// Renders a unit cube on purpose: empty is the PASS everywhere else in this file, so a
// reporting view that rendered nothing would be indistinguishable from one that died.
if (test_view == "report-geometry") {
  echo(str("module = ", module_l, " x ", module_w, " x ", module_h, " pitch ", module_pitch));
  echo(str("stack = ", stack_h, " front = ", front_d, " x ", front_w));
  echo(str("fan_model = ", fan_model, " fan_throat_area = ", fan_throat_area));
  echo(str("board_z = ", board_z));
  echo(str("bed = ", bed));
  cube(1);
}
