// ============================================================================
// WALLS — front, rear, left, right
// ============================================================================
// Four plates, each printed flat on its outer face, so every vent triangle is a
// straight-through hole with no overhang and every clip rib and flange stands up.
//
// The front and rear walls take the full width, corners included, and carry a CORNER
// FLANGE at each end: a strip that reaches flange_lap along the side wall's inner face
// with three clip ribs on it. The side walls drop in between them from above and
// click onto the flanges and the base rim. The flanges start above the base rim and
// stop below the roof rim, so the three never meet.
// ============================================================================

include <../lib/shell.scad>

// One corner flange. x0..x0+len along X; side -1 is the -Y wall, +1 the +Y wall.
module cornerFlange(x0, len, side) {
  y0 = side < 0 ? wall + rim_gap : outer[1] - wall - rim_gap - flange_t;
  translate([x0, y0, flangeZ0()])
    cube([len, flange_t, flangeZ1() - flangeZ0()]);
}

module frontPart() {
  union() {
    shellPanel("front");
    // Starts OVERLAP inside the wall so the flange is fused to it, not tangent to it.
    for (s = [-1, 1]) cornerFlange(wall_front - OVERLAP, flange_lap + OVERLAP, s);
    ribsFor("front");
  }
}

module rearPart() {
  union() {
    shellPanel("rear");
    for (s = [-1, 1]) cornerFlange(outer[0] - wall - flange_lap, flange_lap + OVERLAP, s);
    ribsFor("rear");
  }
}

module leftPart()  { shellPanel("left"); }
module rightPart() { shellPanel("right"); }

// Which one to render standalone; case.scad and generate-stl.sh pick by name instead.
wall_part = "front";
if (wall_part == "front") frontPart();
if (wall_part == "rear")  rearPart();
if (wall_part == "left")  leftPart();
if (wall_part == "right") rightPart();
