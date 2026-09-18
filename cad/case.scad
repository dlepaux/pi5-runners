// ============================================================================
// CASE — assembly and per-part entry point
// ============================================================================
//   openscad -D 'case_part="left"' cad/case.scad
//   openscad -D 'assembly_space=30' cad/case.scad     // pull the case apart
//
// THIS IS THE ONLY FILE ALLOWED TO TOUCH cad/assets/. The vendor fan mesh enters
// through fanVisualization(), which marks it with % so it is drawn in preview and
// dropped from every render. scripts/test-assets.sh holds that true.
//
// THE EXPLODE MOVES THE CASE, NEVER THE BOARDS. The boards are one screwed tower
// fixed to the base's inserts, so they stay exactly where they sit and the case comes
// apart around them: each wall straight out from its face, the base down, the roof
// up. placement.scad has no idea assembly_space exists, so no fit test can measure an
// exploded position even by accident.
// ============================================================================

include <config.scad>
include <lib/placement.scad>
include <lib/shell.scad>
use <lib/m2-hat-plus.scad>
use <lib/noctua-fan.scad>
use <lib/sbc-helpers.scad>
use <parts/base.scad>
use <parts/roof.scad>
use <parts/walls.scad>
use <parts/filter.scad>

// ----------------------------------------------------------------------------
// PARTS BY NAME
// ----------------------------------------------------------------------------
case_parts = concat(shell_parts, ["filter"]);

module casePart(name) {
  if (name == "base")   basePart();
  if (name == "front")  frontPart();
  if (name == "rear")   rearPart();
  if (name == "left")   leftPart();
  if (name == "right")  rightPart();
  if (name == "roof")   roofPart();
  if (name == "filter") filterPart();
}

// ----------------------------------------------------------------------------
// EXPLODE — each part straight out from the face it forms
// ----------------------------------------------------------------------------
function explode(which) =
  let (s = assembly_space)
    which == "base"  ? [0, 0, -s]
  : which == "roof"  ? [0, 0,  s]
  : which == "front" ? [-s, 0, 0]
  : which == "rear"  ? [ s, 0, 0]
  : which == "left"  ? [0, -s, 0]
  : which == "right" ? [0,  s, 0]
  :                    [0, 0, 0];

// ----------------------------------------------------------------------------
// PREVIEW CONTENT
// ----------------------------------------------------------------------------

// The M2.5 standoffs under board i, at the framework's four hole positions.
module standoffsUnder(i) {
  h = i == 0 ? base_standoff : slot_standoff[i - 1];
  color("Silver")
    for (p = pi5MountingHoles())
      translate([p[0], p[1], -h])
        cylinder(d = 5, h = h);
}

module assemblyContents() {
  // The tower: never exploded.
  for (i = [0 : 2]) {
    if (show_boards)
      onBoard(i) pi5Board();
    if (show_hats && slot_is_hat[i])
      onBoard(i) hatVisualization(i == 1);
    if (show_standoffs)
      onBoard(i) standoffsUnder(i);
  }

  // The fans are screwed to the front wall, so they travel with it.
  if (show_fan)
    translate(explode("front"))
      interiorOrigin()
        translate([fan_depth / 2, interior_y / 2, fan_col_zc])
          fanVisualization();

  // The filter clicks into the front wall's recess: it goes out twice as far, so it
  // clears the wall it came out of.
  if (show_filter)
    color("DimGray") filterMounted(2 * assembly_space);
}

// ----------------------------------------------------------------------------
// ENTRY
// ----------------------------------------------------------------------------
if (case_part == "assembly") {
  if (show_case)
    for (p = shell_parts)
      translate(explode(p)) casePart(p);
  assemblyContents();
} else {
  // One printed part, with no preview geometry anywhere near it.
  assert(len([for (p = case_parts) if (p == case_part) p]) == 1,
         str("unknown case_part: ", case_part));
  casePart(case_part);
}
