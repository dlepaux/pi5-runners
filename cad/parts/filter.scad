// ============================================================================
// DUST FILTER — hexrack's, made round, one per module
// ============================================================================
// A round ring with four flats that sits FLUSH in the recess in a module's front wall, over its
// fan. Filter fabric is glued into a 0.32mm pocket on its BACK, reaching 4mm out from
// the window, and spans the window; the ring only frames it. The window is a 45-degree
// funnel from the front face down to the fabric, so dust wipes out of it. Two 45-degree ribs on its
// left and right flats, at its back, click into grooves in the recess -- hexrack's
// sectionDust(), sized for a 40mm fan. The ring also covers the fan's four screw heads.
//
// ONE DEFINITION OF THE FITTED PART. The ribs come from filterJoints() in the MODULE
// frame -- the same rows that cut the grooves -- so filterMounted() is the ring placed
// in the recess plus those ribs, and the printable part is that brought back by the
// exact inverse of the placement. No second copy of the rib position to drift.
//
// Printed front face down: the fabric pocket faces up, the ribs stand on its edges.
// Print one per module.
// ============================================================================

include <../lib/dust-filter.scad>

// The ring in its own frame: front face at z = 0, thickness up, fabric pocket on top.
module filterRingLocal() {
  difference() {
    linear_extrude(filter_depth) filterProfile(filter_r_out, filter_a_out, filter_v_out);
    translate([0, 0, -EPS]) linear_extrude(filter_depth + 2 * EPS) circle(r = filter_r_in, $fn = 128);
    // The funnel: a 45-degree cone, clipped to the ring's outline less its land.
    intersection() {
      translate([0, 0, -EPS])
        cylinder(r1 = filter_r_in + filter_funnel + EPS, r2 = filter_r_in,
                 h = filter_funnel + EPS, $fn = 128);
      translate([0, 0, -EPS]) linear_extrude(filter_funnel + 2 * EPS)
        filterProfile(filter_r_out - filter_land, filter_a_out - filter_land,
                      filter_v_out - filter_land);
    }
    translate([0, 0, filter_depth - filter_glue_d])
      linear_extrude(filter_glue_d + EPS) circle(r = filter_r_in + filter_glue_band, $fn = 128);
  }
}

// Ring frame -> module frame. Rz(90) then Ry(90): local x -> Y, local y -> Z, local
// z -> +X. The ring's front face lands on the module's front face.
function filterOrigin() = [0, fan_yc, fan_zc];

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
