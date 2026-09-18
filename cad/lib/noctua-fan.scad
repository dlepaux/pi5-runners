// ============================================================================
// NOCTUA 40mm FANS — two, stacked; NF-A4x10 or NF-A4x20 (config.scad fan_model)
// ============================================================================
// Two things live here and they do different jobs.
//
// PARAMETRIC (pillProfile, fanBoreProfile, fanBoltProfile) takes every boolean. You cut an opening from
// fan_size and a bolt circle from fan_bolt_pitch. You do NOT subtract a fan: a mesh
// is a tessellation, and a bore cut from one is a polygon pretending to be a circle.
//
// THE MESH (fanVisualization) is for showing the real build, and nothing else.
// Noctua's own README says the impeller and internal frame structures have been
// deliberately altered; the mounting dimensions and outer envelope are the parts they
// stand behind, which is exactly what a case needs. See assets/noctua/readme.md.
//
// ORIENTATION. Airflow runs along +X: the fans sit on the front face's plate and push
// into the plenum, into every module, and out through the rear. The cutting profiles are 2D, so the
// wall decides the orientation; only the mesh carries a rotation.
// ============================================================================

include <../config.scad>

// The declared extent must describe the file on disk. scripts/test-assets.sh measures
// the file; these asserts catch the cheaper case where someone edits a number in
// config.scad without regenerating anything. Compared WITH A TOLERANCE: the mesh is a
// tessellation of a vendor model, not the nominal part.
assert(abs(fan_asset_extent[0] - fan_size) <= fan_asset_tol
    && abs(fan_asset_extent[2] - fan_size) <= fan_asset_tol,
       "fan_asset_extent disagrees with fan_size — regenerate the asset");
assert(abs(fan_asset_extent[1] - fan_depth) <= fan_asset_tol,
       "fan_asset_extent disagrees with fan_depth — regenerate the asset");

// ----------------------------------------------------------------------------
// PARAMETRIC — everything that cuts
// ----------------------------------------------------------------------------
// All in the WALL's 2D frame, centred on the column: profile x is across the wall,
// profile y is UP. The wall that carries them decides the orientation -- the fans
// have moved walls once already, and a module with a baked-in rotate() is one that
// has to be rewritten when they do.

// THE PILL: two half-circles of radius r on the two fans' axes, joined by straight
// sides. The filter ring, its opening and its recess are all this shape at different
// radii, so the filter follows both fan circles.
module pillProfile(r) {
  hull()
    for (k = [0 : fan_count - 1])
      translate([0, (k - (fan_count - 1) / 2) * fan_size]) circle(r = r, $fn = 96);
}

// One round bore per fan.
module fanBoreProfile() {
  for (k = [0 : fan_count - 1])
    translate([0, (k - (fan_count - 1) / 2) * fan_size]) circle(d = fan_bore_d, $fn = 96);
}

// Four holes per fan on the standard 32mm pattern, each set centred on its own fan.
module fanBoltProfile(d) {
  for (k = [0 : fan_count - 1])
    translate([0, (k - (fan_count - 1) / 2) * fan_size])
      for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * fan_bolt_pitch / 2, sy * fan_bolt_pitch / 2])
          circle(d = d, $fn = 32);
}

// The column's outer envelope, axis along +Y here: what nothing printed may grow into.
module fanEnvelope() {
  translate([-fan_size / 2, 0, -fan_col_h / 2])
    cube([fan_size, fan_depth, fan_col_h]);
}

// ----------------------------------------------------------------------------
// MESH — showcase only
// ----------------------------------------------------------------------------

// % is the BACKGROUND modifier: drawn in preview, dropped from the final render.
// This is what keeps Noctua's geometry out of every STL this project publishes.
// Do NOT use # — that is the debug modifier and it IS included in the export.
//
// This model's native axis is +Y. rotate([0,0,-90]) is Rz(-90), which sends +Y to +X:
// the column sits on the front wall and pushes toward the rear. Noctua's STEPs do not
// agree on an axis -- the NF-A8 had its axis on Z -- which is why this is stated here
// rather than assumed. Centred on the column; each fan offset by its own index.
module fanVisualization() {
  for (k = [0 : fan_count - 1])
    translate([0, 0, (k - (fan_count - 1) / 2) * fan_size])
      %rotate([0, 0, -90])
        color("SaddleBrown", 1)
          import(fan_asset, center = true);
}
