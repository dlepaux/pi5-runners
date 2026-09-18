// ============================================================================
// DUST FILTER — the hexagon and its clip joints, shared by the module and the filter
// ============================================================================
// hexrack's dust filter, one per module: a hexagonal ring flush in a recess in the
// front wall, fabric glued on its back, two 45-degree ribs on its top and bottom flats
// at the ring's back. The module cuts the recess and the grooves from here; the filter
// part builds the ring and the ribs from here; test-clips.sh checks every joint here.
//
// Module frame. The front wall's 2D frame is centred on the fan: profile x -> Y,
// profile y -> Z, extrusion -> +X into the wall.
// ============================================================================

include <../config.scad>
include <clips.scad>

// A hexagon of apothem a, flats top and bottom: circle($fn=6) puts a vertex on +x.
module hexProfile(a) {
  circle(r = a / cos(30), $fn = 6);
}

module onFrontWall(x0) {
  translate([x0, fan_yc, fan_zc]) rotate([90, 0, 90]) children();
}

// Ribs on the top and bottom flats, centred on the recess's face, their back vertex
// on the ring's back face -- where hexrack puts them (dust_clip_y).
function filterJoints() =
  let (x = filter_depth - rib_half)
  [ ["filter-top",    [x, fan_yc, fan_zc + filter_a_recess], "y", filter_rib_len],
    ["filter-bottom", [x, fan_yc, fan_zc - filter_a_recess], "y", filter_rib_len] ];

// The recess the ring sits in, from the front face.
module filterRecess() {
  onFrontWall(-EPS) linear_extrude(filter_depth + EPS) hexProfile(filter_a_recess);
}

module filterGrooves() { for (j = filterJoints()) clipGroove(j); }
