// ============================================================================
// FILTER — hexrack's principle, as a vertical pill
// ============================================================================
// A ring that sits FLUSH in the front face's pill recess. Filter fabric is glued into
// a shallow pocket on its BACK and spans the opening; the ring only frames it. Two
// 45-degree ribs on its straight sides click into grooves in the recess walls.
//
// ONE DEFINITION OF THE FITTED PART. The ribs come from filterJoints() in the STACK
// frame -- the same rows that cut their grooves -- so filterMounted() is the ring placed
// on the front face plus those ribs, and the printable part is that brought back by
// the exact inverse of the placement. No second copy of the rib position to drift.
//
// Printed front face down: the fabric pocket faces up, the ribs stand on the edges.
// ============================================================================

include <../config.scad>
include <../lib/clips.scad>
use <../lib/noctua-fan.scad>
use <front.scad>

// The ring in its own frame: front face at z = 0, thickness up, fabric pocket on top.
module filterRingLocal() {
  difference() {
    linear_extrude(filter_depth) pillProfile(pill_r_out);
    translate([0, 0, -EPS])
      linear_extrude(filter_depth + 2 * EPS) pillProfile(pill_r_in);
    translate([0, 0, filter_depth - filter_glue_d])
      linear_extrude(filter_glue_d + EPS)
        offset(delta = -filter_glue_lip) pillProfile(pill_r_out);
  }
}

// Ring frame -> stack frame. Rz(90) then Ry(90): local x -> Y, local y -> Z, local
// z -> +X. The ring's front face lands on the plate's outer face.
function filterOrigin() = [-front_d, fan_col_yc, fan_col_zc];

module filterPlace() {
  translate(filterOrigin()) rotate([0, 90, 0]) rotate([0, 0, 90]) children();
}

module filterMounted(pull = 0) {
  translate([-pull, 0, 0])
    union() {
      filterPlace() filterRingLocal();
      for (j = filterJoints()) clipRib(j);
    }
}

// The exact inverse of filterPlace(): translate back, Ry(-90), Rz(-90).
module filterPart() {
  rotate([0, 0, -90]) rotate([0, -90, 0])
    translate(-filterOrigin())
      filterMounted();
}

filterPart();
