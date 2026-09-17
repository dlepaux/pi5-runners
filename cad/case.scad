// ============================================================================
// CASE — assembly and per-part entry point
// ============================================================================
// Open this file and set case_part in config.scad, or override it:
//
//   openscad -D 'case_part="shell"' cad/case.scad
//   openscad -D 'assembly_space=30' cad/case.scad     // pull it apart to look at it
//
// THIS IS THE ONLY FILE ALLOWED TO TOUCH cad/assets/. The vendor fan mesh enters
// through fanVisualization80(), which marks it with % so it is drawn in preview and
// dropped from every render. scripts/test-assets.sh is what holds that true.
//
// THE EXPLODE LIVES HERE AND NOWHERE ELSE. placement.scad has no idea assembly_space
// exists, so a fit test cannot measure an exploded position even by accident.
// ============================================================================

include <config.scad>
include <lib/placement.scad>
use <lib/shell.scad>
use <lib/m2-hat-plus.scad>
use <lib/noctua-fan.scad>
use <lib/sbc-helpers.scad>
use <parts/filter.scad>
use <parts/base.scad>
use <parts/roof.scad>

// ----------------------------------------------------------------------------
// EXPLODE
// ----------------------------------------------------------------------------
// Along Z, because that is the axis this case stacks on. The shell stays put and
// everything else moves away from it: base down, roof up, and each board fans out by
// its own index so you can see into the slots.
function explode_z(which) =
    which == "base"   ? -assembly_space
  : which == "roof"   ?  assembly_space
  : which == "filter" ?  0
  :                      0;

module exploded(which) {
  translate([0, 0, explode_z(which)]) children();
}

// ----------------------------------------------------------------------------
// PREVIEW CONTENT
// ----------------------------------------------------------------------------

// The M2.5 stack under board i, drawn at each of the framework's four hole positions.
module standoffsUnder(i) {
  h = i == 0 ? base_standoff : slot_standoff[i - 1];
  color("Silver")
    for (p = pi5MountingHoles())
      translate([p[0], p[1], -h])
        cylinder(d = 5, h = h);
}

module assemblyContents() {
  for (i = [0 : 2]) {
    // Each board rises by i * assembly_space so the stack opens up.
    translate([0, 0, i * assembly_space]) {
      if (show_boards)
        onBoard(i) pi5Board();

      if (show_hats && slot_is_hat[i])
        onBoard(i) hatVisualization(i == 1);

      if (show_standoffs)
        onBoard(i) standoffsUnder(i);
    }
  }

  // The filter, clipped onto the intake from outside.
  if (show_filter)
    translate([wall + interior_x / 2, outer[1] + filter_t + assembly_space,
               wall + fan_z0 + fan_size / 2])
      rotate([90, 0, 0])
        color("DimGray") filterPart();

  // The fan, on the +Y wall, facing the stack. Its own frame is centred on the bore,
  // so it is placed by the bore's centre rather than by a corner.
  if (show_fan)
    interiorOrigin()
      translate([interior_x / 2, interior_y - fan_depth, fan_z0 + fan_size / 2])
        fanVisualization80();
}

// ----------------------------------------------------------------------------
// ENTRY
// ----------------------------------------------------------------------------

if (case_part == "assembly") {
  if (show_case) {
    exploded("base")  basePart();
                      shellPanel("shell");
    exploded("roof")  roofPart();
  }
  assemblyContents();
} else if (case_part == "filter") {
  filterPart();
} else if (case_part == "base") {
  basePart();
} else if (case_part == "roof") {
  roofPart();
} else {
  // One printed part, at the origin, with no preview geometry anywhere near it.
  shellPanel(case_part);
}
