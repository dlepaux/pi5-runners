// ============================================================================
// FILTER — hexrack's principle
// ============================================================================
// A ring that sits FLUSH in the front wall's recess. Filter fabric is glued into a
// shallow pocket on its BACK and spans the opening; the ring only frames it. Two
// 45-degree ribs, top and bottom, click into grooves in the recess.
//
// ONE DEFINITION OF THE FITTED PART. The ribs come from lib/clips.scad in the CASE
// frame, the same table that cuts their grooves, so filterMounted() is the ring placed
// in the case plus those ribs. The printable part is that, brought back into the
// ring's own frame by the exact inverse of the placement. There is no second copy of
// the rib position to drift -- the failure hexrack's own dust clip once had.
//
// Printed front face down: the fabric pocket faces up, and the ribs stand on the
// ring's edges.
// ============================================================================

include <../config.scad>
include <../lib/clips.scad>
use <../lib/noctua-fan.scad>

module filterOuterProfile() {
  s = filterOuter();
  r = filterOuterR();
  offset(r = r, $fn = 48)
    square([s[0] - 2 * r, s[1] - 2 * r], center = true);
}

// The ring in its own frame: front face at z = 0, thickness up, fabric pocket on top.
module filterRingLocal() {
  difference() {
    linear_extrude(filter_depth) filterOuterProfile();
    translate([0, 0, -EPS])
      linear_extrude(filter_depth + 2 * EPS) fanOpeningProfile();
    translate([0, 0, filter_depth - filter_glue_d])
      linear_extrude(filter_glue_d + EPS)
        offset(delta = -filter_glue_lip) filterOuterProfile();
  }
}

// Ring frame -> case frame. Rz(90) then Ry(90): local x -> world Y, local y -> world Z,
// local z -> world X. So the ring's front face lands on x = 0, flush with the case
// front, and its back -- with the fabric -- faces the recess floor.
module filterPlace() {
  translate([0, filterCentreY(), filterCentreZ()])
    rotate([0, 90, 0]) rotate([0, 0, 90]) children();
}

module filterMounted(pull = 0) {
  translate([-pull, 0, 0])
    union() {
      filterPlace() filterRingLocal();
      ribsFor("filter");
    }
}

// The exact inverse of filterPlace(): translate back, Ry(-90), Rz(-90).
module filterPart() {
  rotate([0, 0, -90]) rotate([0, -90, 0])
    translate(-[0, filterCentreY(), filterCentreZ()])
      filterMounted();
}

filterPart();
