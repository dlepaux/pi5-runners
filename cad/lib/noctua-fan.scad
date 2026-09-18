// ============================================================================
// NOCTUA 40mm FAN — one per module; NF-A4x10 or NF-A4x20 (config.scad fan_model)
// ============================================================================
// Two things live here and they do different jobs.
//
// PARAMETRIC (fanBoltProfile, fanEnvelope) takes every boolean. You cut an opening from
// fan_size and a bolt circle from fan_bolt_pitch. You do NOT subtract a fan: a mesh
// is a tessellation, and a bore cut from one is a polygon pretending to be a circle.
//
// THE MESH (fanVisualization) is for showing the real build, and nothing else.
// Noctua's own README says the impeller and internal frame structures have been
// deliberately altered; the mounting dimensions and outer envelope are the parts they
// stand behind, which is exactly what a case needs. See assets/noctua/readme.md.
//
// ORIENTATION. Airflow runs along +X: the fan sits on the inside of its module's
// front wall and pushes over the board and out through the rear. The cutting profiles are 2D, so the
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
// In the front wall's 2D frame, centred on the fan: profile x is across the wall,
// profile y is UP.

// Four holes on the standard 32mm pattern.
module fanBoltProfile(d) {
  for (sx = [-1, 1], sy = [-1, 1])
    translate([sx * fan_bolt_pitch / 2, sy * fan_bolt_pitch / 2])
      circle(d = d, $fn = 32);
}

// The fan's outer envelope, axis along +Y, front face on y = 0: what nothing printed
// may grow into.
module fanEnvelope() {
  translate([-fan_size / 2, 0, -fan_size / 2])
    cube([fan_size, fan_depth, fan_size]);
}

// ----------------------------------------------------------------------------
// MESH — showcase only
// ----------------------------------------------------------------------------

// % is the BACKGROUND modifier: drawn in preview, dropped from the final render.
// This is what keeps Noctua's geometry out of every STL this project publishes.
// Do NOT use # — that is the debug modifier and it IS included in the export.
//
// This model's native axis is +Y. rotate([0,0,-90]) is Rz(-90), which sends +Y to +X:
// the fan pushes toward the rear. Noctua's STEPs do not agree on an axis -- the NF-A8
// had its axis on Z -- which is why this is stated here rather than assumed. Centred.
module fanVisualization() {
  %rotate([0, 0, -90])
    color("SaddleBrown", 1)
      import(fan_asset, center = true);
}
