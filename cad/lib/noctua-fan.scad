// ============================================================================
// NOCTUA NF-A8 5V PWM
// ============================================================================
// Two things live here and they do different jobs.
//
// PARAMETRIC (fanBore, fanBoltPattern) takes every boolean. You cut an opening from
// fan_size and a bolt circle from fan_bolt_pitch. You do NOT subtract a fan: a mesh
// is a tessellation, and a bore cut from one is a polygon pretending to be a circle.
//
// THE MESH (fanVisualization80) is for showing the real build, and nothing else.
// Noctua's own README says the impeller and internal frame structures have been
// deliberately altered; the mounting dimensions and outer envelope are the parts they
// stand behind, which is exactly what a case needs. See assets/noctua/readme.md.
//
// ORIENTATION. Airflow runs along -Y: the fan sits on the +Y wall and pushes toward
// the boards. The mounting face is at the wall.
// ============================================================================

include <../config.scad>

// The declared extent must describe the file on disk. scripts/test-assets.sh measures
// the file; these asserts catch the cheaper case where someone edits a number in
// config.scad without regenerating anything.
//
// Compared WITH A TOLERANCE, not for equality. The mesh is a tessellation of a vendor
// model whose frame measures 80.1 x 80.0 x 25.4 against a nominal 80 x 80 x 25 -- the
// 0.4 in Z is the anti-vibration pads and is real, the 0.1 in X is tessellation.
// Asserting equality against the nominal would fail on a correct asset.
assert(abs(fan_asset_extent[0] - fan_size) <= fan_asset_tol
    && abs(fan_asset_extent[1] - fan_size) <= fan_asset_tol,
       "fan_asset_extent disagrees with fan_size — regenerate the asset");
assert(abs(fan_asset_extent[2] - fan_depth) <= fan_asset_tol,
       "fan_asset_extent disagrees with fan_depth — regenerate the asset");

// ----------------------------------------------------------------------------
// PARAMETRIC — everything that cuts
// ----------------------------------------------------------------------------

// The opening, in the wall's frame: centred on [0,0], axis along Y.
//
// A ROUNDED SQUARE rather than the fan's circular bore. The fan does not care -- its
// throat is the impeller's swept annulus whatever shape the hole is -- and a square
// opening is both more open area and a better match for a square-cornered case.
module fanOpeningProfile(clear = 0) {
  s = fan_opening + 2 * clear;
  offset(r = fan_opening_r, $fn = 48)
    square([s - 2 * fan_opening_r, s - 2 * fan_opening_r], center = true);
}

module fanBore(depth, clear = 0) {
  rotate([-90, 0, 0])
    linear_extrude(depth)
      fanOpeningProfile(clear);
}

// The four mounting holes on the standard 71.5 x 71.5 pattern.
module fanBoltPattern(depth, d) {
  for (sx = [-1, 1], sz = [-1, 1])
    translate([sx * fan_bolt_pitch / 2, 0, sz * fan_bolt_pitch / 2])
      rotate([-90, 0, 0])
        cylinder(h = depth, d = d, center = false);
}

// The frame's outer envelope — what the shell must not grow into.
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
// rotate([-90,0,0]) maps the mesh's native +Z axis to world -Y: the fan sits on the
// +Y wall and pushes toward the boards. Doing it here rather than baking it into the
// generator keeps the asset byte-identical to what Noctua published.
module fanVisualization80() {
  %rotate([-90, 0, 0])
    color("SaddleBrown", 1)
      import(fan_asset, center = true);
}
