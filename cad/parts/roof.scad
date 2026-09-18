// ============================================================================
// ROOF — lid and clip rim
// ============================================================================
// Clicks straight down onto the side walls, the same joint as the base. No retainer:
// the board tower is screwed into the base's inserts and holds itself.
//
// The rim is a U, not a ring: along both side walls and the front, NOT the rear. At
// the rear the top board's USB stack stands up to z 94.2, and a rim there would sit
// in front of it.
// ============================================================================

include <../lib/shell.scad>

module roofRim() {
  z0 = outer[2] - wall - rim_h;
  h  = rim_h + OVERLAP;
  x0 = wall_front + rim_gap;
  x1 = outer[0] - wall - rim_gap;
  // -Y and +Y sides
  for (y = [wall + rim_gap, outer[1] - wall - rim_gap - rim_t])
    translate([x0, y, z0]) cube([x1 - x0, rim_t, h]);
  // front
  translate([x0, wall + rim_gap, z0])
    cube([rim_t, interior_y - 2 * rim_gap, h]);
}

module roofPart() {
  union() {
    shellPanel("roof");
    roofRim();
    ribsFor("roof");
  }
}

roofPart();
