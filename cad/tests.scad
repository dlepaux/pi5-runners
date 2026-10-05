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
  fanVisualization() import(fan_asset, center = true);
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
  if (n == "filter") filterMounted();
}
// As they print: what the bed check and the printability check measure.
module printByName(n) {
  if (n == "module") modulePart();
  if (n == "lid")    lidPrint();
  if (n == "filter") filterPart();
}
if (test_view == "part")  partByName(part);
if (test_view == "print") printByName(part);

// The whole case, as it stands: every module with its filter, and the lid.
module wholeCase() {
  for (k = [0 : module_count - 1]) moduleAt(k) { modulePart(); filterMounted(); }
  lidAt() lidPart();
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

if (test_view == "posts-alone")    posts();
if (test_view == "posts-vs-board") intersection() { posts(); boardPcb(); }
// The feet reach the board: raised 0.2mm, they bite it.
if (test_view == "posts-seated")
  intersection() { translate([0, 0, 0.2]) posts(); boardPcb(); }
// A pilot hole must be VOID in the finished part...
if (test_view == "pilots-vs-module") intersection() { pilotHoles(); modulePart(); }
// ...must sit in a foot, not in the air beside one...
if (test_view == "pilots-in-posts") intersection() { pilotHoles(); posts(); }
// ...and WHOLLY in it. The check above only asks for some overlap, so a hole slid
// off its foot's axis still passes it. Only the mask's 0.01mm mouth may stand proud.
if (test_view == "pilots-outside-posts")
  difference() {
    pilotHoles();
    posts();
    translate([-1, -1, board_z]) cube([module_l + 2, module_w + 2, 0.05]);
  }

// -- the port islands ---------------------------------------------------------
// A probe 0.6 into the -Y wall's outer face, 1mm past each end of the island: open
// if the end steps at 45 like the top and bottom, solid if it is square.
module islandProbe(x, y0, y1) {
  translate([x - 0.3, y0, (island_z[0] + island_z[1]) / 2 - 0.3])
    cube([0.6, y1 - y0, 0.6]);
}
if (test_view == "island-ends-open")
  intersection() {
    modulePart();
    union() {
      islandProbe(island_x[0] - 1, 0.1, 0.7);
      islandProbe(island_x[1] + 1, 0.1, 0.7);
    }
  }
// +Y carries the same island, uncut: its bulge stands inside the wall, its recess is
// open outside, at the middle of the panel, where -Y has its connectors.
if (test_view == "island-pos-bulge")
  intersection() {
    modulePart();
    islandProbe((island_x[0] + island_x[1]) / 2,
                module_w - island_inner + 0.1, module_w - wall - 0.1);
  }
if (test_view == "island-pos-open")
  intersection() {
    modulePart();
    islandProbe((island_x[0] + island_x[1]) / 2, module_w - island_outer + 0.1, module_w + 1);
  }

// -- the label ----------------------------------------------------------------
// What the name takes out of the walls...
module labelRemoved() { intersection() { labelCuts(runner); moduleBody(); } }
if (test_view == "label-cuts") labelRemoved();
// ...WHOLLY inside its clear face, on both walls, for every runner's name.
if (test_view == "label-outside-region")
  difference() {
    labelRemoved();
    translate([label_region_x[0], -1, label_region_z[0]])
      cube([label_region_x[1] - label_region_x[0], module_w + 2,
            label_region_z[1] - label_region_z[0]]);
  }
// OpenSCAD swaps a font it cannot find for its default, silently. Set against a
// name no font has -- which gets that same default -- the label must differ.
if (test_view == "label-font")
  difference() {
    linear_extrude(1) labelText(runner);
    linear_extrude(1) labelText(runner, "no such font");
  }

// -- stacking -----------------------------------------------------------------
// Neighbours touch on the lap, and the floor on the front wall below, and nowhere else.
if (test_view == "module-vs-above") intersection() { modulePart(); moduleAt(1) modulePart(); }
if (test_view == "module-vs-lid")   intersection() { modulePart(); moduleAt(1) lidPart(); }
// ...and they DO touch. "Nothing overlaps" is also true of a module floating 5mm up;
// lowered 0.2mm, the module above must bite into this one. moduleBody(), not the part:
// anything else running the full height -- rails, once -- would pass this for a
// module whose walls stop short and whose weight sits on four rail ends.
if (test_view == "module-seated")
  intersection() { moduleBody(); translate([0, 0, module_pitch - 0.2]) moduleBody(); }
if (test_view == "lid-seated")
  intersection() { moduleBody(); translate([0, 0, module_pitch - 0.2]) lidBody(); }
// ...and the LAP bears, not only the front butt joint: behind the front wall, lowered
// 0.2mm, the chamfer must bite into the bevel below. A chamfer standing off the bevel
// would let the rear of the stack hang on the clips.
module behindFrontWall() {
  translate([front_wall_t + 1, -1, 0]) cube([module_l, module_w + 2, 2 * module_h]);
}
if (test_view == "module-seated-on-lap")
  intersection() {
    moduleBody(); translate([0, 0, module_pitch - 0.2]) moduleBody(); behindFrontWall();
  }
if (test_view == "lid-seated-on-lap")
  intersection() {
    moduleBody(); translate([0, 0, module_pitch - 0.2]) lidBody(); behindFrontWall();
  }

// THE MODULE ABOVE BEARS ON ITS LAP ALONE, not on the front wall's inner part as well:
// sunk 0.3mm, its floor still clears the front wall behind the lap. A second bearing
// face there is the one a print's tolerances pick, and the clips stop short of seating.
if (test_view == "front-wall-clear")
  intersection() {
    modulePart();
    translate([0, 0, module_pitch - 0.3]) modulePart();
    translate([wall + 0.5, wall + 0.5, 0]) cube([front_wall_t - wall, module_w - 2 * wall - 1, 2 * module_h]);
  }
// ...AND ITS FRONT CLIP HOOKS IN FROM THE INSIDE, as on the other three walls: the rib,
// 0.2mm low for a first layer's squish, slides out from the module's inside to its
// groove without touching the module below.
function frontJoint() = [for (j = lapJoints()) if (j[0] == "front") j][0];
if (test_view == "front-rib-hooks-in")
  intersection() {
    modulePart();
    hull() for (dx = [0, front_wall_t - wall])
      translate([dx, 0, -0.2]) clipRib(bevelJoint(frontJoint()));
  }
// The front wall still closes over the filter recess's crown, filter_edge_wall thick...
module crownProbe(x, dz) {
  translate([x, fan_yc, fan_zc + filter_r_recess + dz]) cube(0.1, center = true);
}
if (test_view == "front-wall-over-crown")
  intersection() { modulePart(); crownProbe((wall + filter_depth) / 2, filter_edge_wall / 2); }
// ...and behind the crown its web keeps two perimeters, however steep the top falls:
// there is wall 0.75 behind the recess, just under its crown. 0.6 of web fails it.
if (test_view == "front-web-behind-crown")
  intersection() { modulePart(); crownProbe(filter_depth + 0.75, -0.1); }

// -- clips -------------------------------------------------------------------
// One table of every clipped joint: [name, rib (stack frame), owner, mate].
function allJoints() = concat(
  [ for (j = lapJoints()) [str("module-", j[0]), bevelJoint(j), "module", "module"] ],
  [ for (j = lapJoints())
      [str("lid-", j[0]),
       [j[0], j[1] + [0, 0, module_count * module_pitch], j[2], j[3], j[4]], "lid", "module"] ],
  [ for (j = filterJoints()) [j[0], j, "filter", "module"] ]);

// The mate, as it sits relative to the rib: a lap rib of the module above, or of
// the lid, lands in the socket of the module below it.
module mateOf(row) {
  moduleAt(row[2] == "lid" ? module_count - 1 : 0) modulePart();
}
// The mate's own territory -- where a rib must reach to be engaged: the walls of the
// module below, or for a filter, the front wall it clips into.
module mateTerritory(row) {
  if (row[2] == "filter")
    cube([front_wall_t, module_w, module_pitch]);
  else moduleAt(row[2] == "lid" ? module_count - 1 : 0)
    linear_extrude(module_h) difference() { square([module_l, module_w]); inset(wall); }
}

if (test_view == "report-clips") {
  for (k = [0 : len(allJoints()) - 1])
    echo(str("CLIP ", k, " ", allJoints()[k][0], " ", allJoints()[k][2], " ", allJoints()[k][3]));
  cube(1);
}
if (test_view == "clip-rib")       clipRib(allJoints()[clip_k][1]);
if (test_view == "clip-rib-vs-mate")
  intersection() { clipRib(allJoints()[clip_k][1]); mateOf(allJoints()[clip_k]); }
// HOLD, NOT RATTLE: lifted clip_lift, a rib must already bite the groove it sits in --
// the play before a clip takes the load is under that.
clip_lift = 0.3;
if (test_view == "clip-rib-lifted")
  intersection() { translate([0, 0, clip_lift]) clipRib(allJoints()[clip_k][1]); mateOf(allJoints()[clip_k]); }
if (test_view == "clip-rib-reach")
  intersection() { clipRib(allJoints()[clip_k][1]); mateTerritory(allJoints()[clip_k]); }

// -- ports -------------------------------------------------------------------
// NO PORT MAY BE BLIND: nothing printed may stand in a connector's probe.
if (test_view == "ports-blind")
  intersection() { modulePart(); allPortProbes(); }
// THE REAR EDGE SITS IN THE WALL: the PCB in its slot, the jacks in their holes. It
// must clear them, and the jacks must reach the outer face -- test-fit.sh reads this
// view's bounds for that. The edge rendering at all is the witness for the clearance.
if (test_view == "rear-edge") onBoard() rearEdge();
// THE PORT ISLAND stands just off the -Y connectors: they must clear it, and they must
// stand side_port_reach past the PCB -- test-fit.sh reads this view's bounds for that.
if (test_view == "side-edge")            onBoard() sideEdge();
if (test_view == "side-edge-vs-module")  intersection() { modulePart(); onBoard() sideEdge(); }
if (test_view == "rear-edge-vs-module") intersection() { modulePart(); onBoard() rearEdge(); }
// ...and the walls must still EXIST.
if (test_view == "wall-y-remains") intersection() { modulePart(); wallSlab("-Y"); }
if (test_view == "wall-x-remains") intersection() { modulePart(); wallSlab("+X"); }

// -- vents -------------------------------------------------------------------
// MEASURED, not computed: extruded 1mm, volume IS area.
if (test_view == "rear-vent-area")  linear_extrude(1) rearVentProfile();
if (test_view == "side-vent-area")  linear_extrude(1) sideVentProfile();
// A louvre leans, so what the air passes is its slot square to the channel.
if (test_view == "side-vent-throat")
  linear_extrude(1) scale([cos(vent_side_angle), 1]) sideVentProfile();
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

// -- fans and intake --------------------------------------------------------
// Each module's fan, on the inside of its front wall. Stack frame.
module fanAt(k) {
  moduleAt(k) translate([front_wall_t, fan_yc, fan_zc]) rotate([0, 0, -90]) fanEnvelope();
}
module allFans() { for (k = [0 : module_count - 1]) fanAt(k); }

if (test_view == "fans-alone")   allFans();
// One fan on its own, so test-fit.sh can read where it sits in its module.
if (test_view == "fan-0")        fanAt(0);
if (test_view == "fans-vs-case") intersection() { allFans(); wholeCase(); }
// Every kind of board must clear the fan -- the Compact's tab hangs toward it.
if (test_view == "fan-vs-boards")
  intersection() { fanAt(0); union() { slotSlab("standard"); slotSlab("compact"); slotSlab("bare"); } }
// ...and the fan SITS on the wall: moved 0.2mm forward, it must run into it.
if (test_view == "fans-seated")
  intersection() { translate([-0.2, 0, 0]) fanAt(0); modulePart(); }

// THE AIR PATH MUST BE OPEN, from outside to each fan: through the filter's window
// and the front wall's bore. A probe as wide as the blades sweep, through the whole
// case with every filter in place -- the screw bosses close in on the bore's corners,
// short of the blade tips.
if (test_view == "bores-open")
  intersection() {
    wholeCase();
    for (k = [0 : module_count - 1])
      moduleAt(k) translate([-1, fan_yc, fan_zc])
        rotate([0, 90, 0]) cylinder(r = fan_tip_r, h = front_wall_t + 2, $fn = 96);
  }

// -- the dust filter ---------------------------------------------------------
// It sits in its recess touching nothing...
if (test_view == "filter-vs-module") intersection() { filterMounted(); modulePart(); }
// ...and it SITS there: pushed 0.2mm further in, it runs into the recess floor.
if (test_view == "filter-seated")
  intersection() { translate([0.2, 0, 0]) filterMounted(); modulePart(); }

// THE WINDOW IS A FUNNEL, in the printed part's own frame: front face at z = 0, x across
// the side flats, y across the top and bottom ones. Probes sit half-way down the slope,
// a hair either side of where its surface must be.
module funnelProbe(r, at = 0) {
  rotate(at) translate([r, 0, filter_funnel / 2]) cube(0.1, center = true);
}
// At the sides it is a full 45-degree slope: air just inside it...
if (test_view == "funnel-open-at-side")
  intersection() { filterPart(); funnelProbe(filter_r_in + filter_funnel / 2 - 0.2); }
// ...and ring just outside it.
if (test_view == "funnel-ring-at-side")
  intersection() { filterPart(); funnelProbe(filter_r_in + filter_funnel / 2 + 0.2); }
// Beside it, at the side flats, the front face keeps its land.
if (test_view == "funnel-land-at-flat")
  intersection() {
    filterPart();
    translate([filter_a_out - filter_land / 2, 0, 0.1]) cube(0.1, center = true);
  }
// ROUND ABOVE AND BELOW THE WINDOW: the ring's only flats are the side ones, which
// carry the clips. Just inside its radius, straight up and straight down, there is ring.
module ringEdgeProbe(at) {
  rotate(at) translate([0, filter_r_out - 0.3, filter_depth / 2]) cube(0.1, center = true);
}
if (test_view == "ring-round-above") intersection() { filterPart(); ringEdgeProbe(0); }
if (test_view == "ring-round-below") intersection() { filterPart(); ringEdgeProbe(180); }
// It stops at the fabric: the window there is still the fan's bore, no wider.
if (test_view == "funnel-ends-at-fabric")
  intersection() {
    filterPart();
    for (at = [0, 90])
      rotate(at) translate([filter_r_in + 0.2, 0, filter_funnel - 0.1]) cube(0.1, center = true);
  }

// -- fan screws --------------------------------------------------------------
// hexrack's way round: in from outside, heads countersunk into the recess floor.
module screwAxes() {
  for (sy = [-1, 1], sz = [-1, 1])
    translate([0, fan_yc + sy * fan_bolt_pitch / 2, fan_zc + sz * fan_bolt_pitch / 2])
      children();
}
module seatRings() {
  screwAxes() translate([filter_depth, 0, 0]) rotate([0, 90, 0])
    linear_extrude(0.5)
      difference() { circle(d = fan_csink_d + 2, $fn = 32); circle(d = fan_csink_d, $fn = 32); }
}
// Every head lies under the ring. A countersink outside it would sit in the gap round
// the ring, or cut the recess wall.
if (test_view == "screw-heads-outside-ring")
  difference() {
    screwAxes() translate([filter_depth - 0.2, 0, 0]) rotate([0, 90, 0])
      cylinder(d = fan_csink_d, h = 0.2, $fn = 32);
    onFrontWall(-1) linear_extrude(filter_depth + 2) filterProfile(filter_r_out, filter_a_out);
  }
// Every shank has a clear path from the recess floor, through the wall, to the fan --
// room for its THREAD, not for a probe the hole's own size: a printed hole comes out
// up to 0.3 under size, and a self-tapping thread that bites the print splits it.
if (test_view == "screw-paths")
  intersection() {
    modulePart();
    screwAxes() translate([filter_depth, 0, 0]) rotate([0, 90, 0])
      cylinder(d = get_screw_spec(fan_screw, "thread_diameter") + 0.3,
               h = fan_web + 1, $fn = 24);
  }
// Every head SINKS: 0.3mm under the recess floor the cut is already as wide as the
// head, so the filter lies flat over it...
module headDiscs(depth) {
  screwAxes() translate([filter_depth + depth, 0, 0]) rotate([0, 90, 0])
    cylinder(d = get_screw_spec(fan_screw, "head_diameter"), h = 0.1, center = true, $fn = 48);
}
if (test_view == "screw-heads-sunk") intersection() { modulePart(); headDiscs(0.3); }
// ...and has a cone to bear on: a millimetre deeper, the cut is narrower than the head.
if (test_view == "screw-heads-bear") intersection() { modulePart(); headDiscs(1.3); }
// ...and every head has a SEAT: a ring round each countersink's mouth, in the recess
// floor, is solid. The corner holes sit 3.6mm outside the bore; this is what notices
// a countersink breaking into it.
if (test_view == "screw-seat-annuli") seatRings();
if (test_view == "screw-seats") intersection() { modulePart(); seatRings(); }

// -- reporting ---------------------------------------------------------------
// Renders a unit cube on purpose: empty is the PASS everywhere else in this file, so a
// reporting view that rendered nothing would be indistinguishable from one that died.
if (test_view == "report-geometry") {
  echo(str("module = ", module_l, " x ", module_w, " x ", module_h, " pitch ", module_pitch));
  echo(str("stack = ", stack_h, " filter r = ", filter_r_out, " flats = ", filter_a_out));
  echo(str("fan_model = ", fan_model, " fan_throat_area = ", fan_throat_area));
  echo(str("board_z = ", board_z));
  echo(str("fan_room = ", floor_t, " ", module_pitch));
  echo(str("rear_port_face = ", module_l + rear_port_proud));
  echo(str("side_port_face = ", board_y - side_port_reach));
  echo(str("bed = ", bed));
  cube(1);
}
