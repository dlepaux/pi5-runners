// ============================================================================
// DUST FILTER — the ring's profile and its clip joints, shared by module and filter
// ============================================================================
// hexrack's dust filter made round, one per module: a circular ring with four flats,
// flush in a recess in the front wall, fabric glued on its back, two 45-degree ribs on its left and right flats
// at the ring's back. The module cuts the recess and the grooves from here; the filter
// part builds the ring and the ribs from here; test-clips.sh checks every joint here.
//
// Module frame. The front wall's 2D frame is centred on the fan: profile x -> Y,
// profile y -> Z, extrusion -> +X into the wall.
// ============================================================================

include <../config.scad>
include <clips.scad>

// A circle of radius r cut by flats a from its centre left and right (profile x is
// the module's Y) and v from it top and bottom. a or v >= r leaves that side round.
module filterProfile(r, a, v) {
  intersection() {
    circle(r = r, $fn = 128);
    square([2 * a, 2 * v], center = true);
  }
}

module onFrontWall(x0) {
  translate([x0, fan_yc, fan_zc]) rotate([90, 0, 90]) children();
}

// Ribs on the left and right flats, running vertically, centred on the recess's face,
// their back vertex
// on the ring's back face -- where hexrack puts them (dust_clip_y).
function filterJoints() =
  let (x = filter_depth - rib_half)
  [ ["filter-left",  [x, fan_yc - filter_a_recess, fan_zc], "z", filter_rib_len],
    ["filter-right", [x, fan_yc + filter_a_recess, fan_zc], "z", filter_rib_len] ];

// The recess the ring sits in, from the front face.
module filterRecess() {
  onFrontWall(-EPS) linear_extrude(filter_depth + EPS) filterProfile(filter_r_recess, filter_a_recess, filter_v_recess);
}

module filterGrooves() { for (j = filterJoints()) clipGroove(j); }
