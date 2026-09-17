// ============================================================================
// BASE — floor, board bosses, feet
// ============================================================================
// The base carries the whole stack through four points: board 0 bolts to these
// bosses and boards 1 and 2 stand on standoffs from it.
// ============================================================================

include <../config.scad>
use <../lib/shell.scad>
use <../lib/sbc-helpers.scad>
use <../lib/placement.scad>

// One boss: a post from the floor to the bottom board's underside, with a heat-set
// insert pocket down from its top.
//
// HULLED ONTO A WAFER, not stood on the floor. A cylinder tangent to a plane is not
// attached to it -- it meets it along a line, zero contact area -- and the union
// renders, previews correctly, and exports as a plate plus four loose pucks.
module bossAt(x, y) {
  wafer_d = boss_d + 3;
  difference() {
    hull() {
      translate([x, y, 0]) cylinder(d = wafer_d, h = 0.6);
      translate([x, y, 0]) cylinder(d = boss_d, h = base_standoff);
    }
    translate([x, y, base_standoff - insert_m25_depth])
      cylinder(d = insert_m25_d, h = insert_m25_depth + EPS);
  }
}

module baseBosses() {
  interiorOrigin()
    translate([board_x, board_y, 0])
      for (p = pi5MountingHoles())
        bossAt(p[0], p[1]);
}

// Feet. Low and wide, under the four corners, clear of the walls' corner radius.
module feet() {
  inset = foot_d / 2 + 4;
  for (x = [inset, outer[0] - inset], y = [inset, outer[1] - inset])
    translate([x, y, -foot_h])
      cylinder(d1 = foot_d - 2, d2 = foot_d, h = foot_h + EPS);
}

module basePart() {
  union() {
    shellPanel("base");
    baseBosses();
    feet();
  }
}

basePart();
