// ============================================================================
// SHELL — one solid, cut once, claimed six ways
// ============================================================================
// The case is a single hollow box. Every opening and every clip groove is cut into
// it ONCE, in shellCut(). The six printed shell parts -- base, four walls, roof -- are
// that cut solid intersected with six disjoint claims that tile it exactly. Parts
// cannot disagree about where a wall or an opening is: there is one of each.
//
// THE CLAIMS MUST BE DISJOINT AND COMPLETE. Overlapping claims print two parts that
// cannot both be in the case; claims that leave a gap print a case with a slot missing.
// Both render, export and count one body. scripts/test-parts.sh checks each direction,
// because neither implies the other.
//
// What each part ADDS beyond its claim -- rims, corner flanges, clip ribs, rails --
// lives in the part's own file. Those additions are inside the case, never on the
// shell's surface.
// ============================================================================

include <../config.scad>
use <ports.scad>
use <vents.scad>
use <noctua-fan.scad>
include <clips.scad>

// ----------------------------------------------------------------------------
// INVARIANTS
// ----------------------------------------------------------------------------

// The front wall part must keep solid wall above and below the filter recess, and the
// recess's clip grooves cut into that band. Behind each groove there must still be
// something to print.
front_band = (outer[2] - wall) - (filterCentreZ() + filterRecessHalfH());
assert(front_band - rib_half - clip_clear >= 1.5,
       str("the filter recess leaves ", front_band, "mm of front wall above it -- ",
           "too little behind its clip groove"));

// Every board's port cluster must sit wholly inside one wall part.
for (i = [0 : 2])
  assert(wall + board_z[i] + exclusion_cluster_z[1] < outer[2] - wall,
         str("board ", i, "'s port cluster runs into the roof"));

// ----------------------------------------------------------------------------
// THE SOLID
// ----------------------------------------------------------------------------

module shellSolid() {
  difference() {
    cube(outer);
    translate([wall_front, wall, wall]) cube([interior_x, interior_y, interior_h]);
  }
}

// ----------------------------------------------------------------------------
// CLAIMS
// ----------------------------------------------------------------------------
// [origin, size] in the case frame. The base and roof take the full footprint; the
// front and rear walls take the full width, corners included; the side walls fit
// between them. Returned as data so tests.scad can reason about them.
function claim(which) =
  let (mid_z = outer[2] - 2 * wall, side_x = outer[0] - wall_front - wall)
    which == "base"  ? [[0, 0, 0],                     [outer[0], outer[1], wall]]
  : which == "roof"  ? [[0, 0, outer[2] - wall],       [outer[0], outer[1], wall]]
  : which == "front" ? [[0, 0, wall],                  [wall_front, outer[1], mid_z]]
  : which == "rear"  ? [[outer[0] - wall, 0, wall],    [wall, outer[1], mid_z]]
  : which == "left"  ? [[wall_front, 0, wall],         [side_x, wall, mid_z]]
  : which == "right" ? [[wall_front, outer[1] - wall, wall], [side_x, wall, mid_z]]
  : assert(false, str("unknown shell part: ", which));

shell_parts = ["base", "front", "rear", "left", "right", "roof"];

module claimVolume(which, grow = 0) {
  c = claim(which);
  translate(c[0] - [grow, grow, grow])
    cube(c[1] + [2 * grow, 2 * grow, 2 * grow]);
}

// ----------------------------------------------------------------------------
// PANELS
// ----------------------------------------------------------------------------
// CUT ONCE, THEN CLAIM. Cutting each panel separately would let two panels disagree
// about where an opening is, and the tiling check has to compare the parts against
// what they add up to -- which is this, not the uncut box.
module shellCut() {
  difference() {
    shellSolid();
    allPortCuts();
    ventCuts();
    fanCut();
    filterRecess();
    allGrooves();
  }
}

// render() is NOT optional. Preview does not evaluate booleans -- it flattens the
// model into a sum of products, exponential in nested differences, and a panel cut by
// ports, vents and grooves blows past OpenSCAD's normalisation limit: blank window,
// perfect export.
module shellPanel(which) {
  render()
    intersection() {
      shellCut();
      claimVolume(which);
    }
}

// ----------------------------------------------------------------------------
// WALL FRAMES
// ----------------------------------------------------------------------------
// rotate([90,0,90]) is Rz(90) . Rx(90): profile x -> world Y, profile y -> world Z,
// extrusion -> +X. Derived, not guessed: a rotate() with the wrong sign lands the cut
// behind the wall, renders nothing, and passes every emptiness check in the suite.
module onXWall(x0) {
  translate([x0, 0, 0]) rotate([90, 0, 90]) children();
}

// rotate([90,0,0]) is Rx(90): profile x -> X, profile y -> +Z, extrusion -> -Y. So a
// sweep through a Y wall has to START at its HIGH-Y face.
module onYWall(y_high) {
  translate([0, y_high, 0]) rotate([90, 0, 0]) children();
}

// ----------------------------------------------------------------------------
// INTAKE — the -X front wall
// ----------------------------------------------------------------------------
function fanCentreYZ() = [filterCentreY(), filterCentreZ()];

// One ROUND bore per fan, through the full front wall, and a pilot hole at each of
// the fans' screw positions. The fans screw in from inside, self-tapping into the
// 3mm behind the recess floor -- see fan_bore_d in config.scad for why the opening is
// no longer one rounded rectangle.
module fanBoreProfile() {
  for (k = [0 : fan_count - 1])
    translate([0, (k - (fan_count - 1) / 2) * fan_size])
      circle(d = fan_bore_d, $fn = 96);
}

module fanCut() {
  onXWall(-EPS)
    linear_extrude(wall_front + 4 * EPS)
      translate(fanCentreYZ()) {
        fanBoreProfile();
        fanBoltProfile(fan_pilot_d);
      }
}

// The filter's recess: the ring's outline grown by filter_clear, filter_depth deep
// from the front face. The ring sits flush in it.
module filterRecessProfile() {
  s = filterOuter() + 2 * [filter_clear, filter_clear];
  r = filterOuterR() + filter_clear;
  offset(r = r, $fn = 48)
    square([s[0] - 2 * r, s[1] - 2 * r], center = true);
}

module filterRecess() {
  onXWall(-EPS)
    linear_extrude(filter_depth + EPS)
      translate(fanCentreYZ())
        filterRecessProfile();
}

// ----------------------------------------------------------------------------
// EXHAUST — the rear wall, wrapping onto the rear of both side walls
// ----------------------------------------------------------------------------
// hexrack's back face: a triangle field with an EXCLUSION ZONE per board carved out
// of the CUTTER around its port cluster, so every connector sits in clean solid wall.
// Centred on the MEASURED cluster, which is not symmetric about the board.
function exclusionCentre(i) =
  [wall + board_y + (exclusion_cluster_y[0] + exclusion_cluster_y[1]) / 2,
   wall + board_z[i] + (exclusion_cluster_z[0] + exclusion_cluster_z[1]) / 2];

module exclusionZone(i) {
  translate(exclusionCentre(i))
    offset(r = exclusion_r, $fn = 30)
      square([exclusion_w - 2 * exclusion_r, exclusion_h - 2 * exclusion_r], center = true);
}

// Every field stays clear of the RIM BANDS at the bottom and top of the walls, where
// the base and roof clip grooves are, and of the corner flanges' lap.
function ventBandZ0() = wall + rim_h + vent_margin;
function ventBandZ1() = outer[2] - wall - rim_h - vent_margin;
function ventBandH()  = ventBandZ1() - ventBandZ0();

// The rear cutter in (Y, Z): the field, less the three zones. Its own module so
// test-airflow.sh measures EXACTLY what is cut.
module rearVentProfile() {
  difference() {
    translate([wall + vent_margin, ventBandZ0()])
      ventField(vent_rear_w, ventBandH());
    for (i = [0 : 2]) exclusionZone(i);
  }
}

// A side field in (X, Z), at the rear of the side wall, stopping before the rear
// corner flange. config.scad asserts it also stays behind the -Y ports.
module sideVentProfile() {
  translate([wall_front + side_field_x0, ventBandZ0()])
    ventField(vent_side_depth, ventBandH());
}

module ventCuts() {
  onXWall(outer[0] - wall - EPS)
    linear_extrude(wall + 4 * EPS)
      rearVentProfile();
  onYWall(wall + EPS)
    linear_extrude(wall + 4 * EPS)
      sideVentProfile();
  onYWall(outer[1] + EPS)
    linear_extrude(wall + 4 * EPS)
      sideVentProfile();
}
