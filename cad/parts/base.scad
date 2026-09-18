// ============================================================================
// BASE — floor, rim, insert rails
// ============================================================================
// The base is where the case starts and where the board tower is fixed. The four
// walls push down onto its rim and click in; the tower screws into its inserts.
//
// NO PRINTED FEET. Feet below the floor leave the whole floor printing over air, and
// the base's other face carries the rim and rails, so either way up needs support.
// The underside is flat on the bed instead; stick-on rubber bumpons go on it.
// ============================================================================

include <../lib/shell.scad>
include <../lib/placement.scad>
use <../lib/sbc-helpers.scad>

// A band just inside the walls, rim_gap off each wall's inner face. The walls slide
// down over it; ribs on its outer face click into grooves in the walls.
module baseRim() {
  o = [wall_front + rim_gap, wall + rim_gap];
  s = [interior_x - 2 * rim_gap, interior_y - 2 * rim_gap];
  translate([0, 0, wall - OVERLAP])
    linear_extrude(rim_h + OVERLAP)
      difference() {
        translate(o) square(s);
        translate(o + [rim_t, rim_t]) square(s - [2 * rim_t, 2 * rim_t]);
      }
}

// The Pi's mounting holes, grouped into the two rows the rails run along.
function holeRows() =
  let (holes = pi5MountingHoles(),
       ys = [for (h = holes) h[1]])
  [ for (y = [min(ys), max(ys)]) [ for (h = holes) if (h[1] == y) h ] ];

// One rail per row, running along X -- along the airflow -- from its first hole to its
// last and canoe_overrun beyond. Rounded ends: a hull of two posts.
module canoes() {
  interiorOrigin()
    translate([board_x, board_y, -OVERLAP])
      for (row = holeRows()) {
        xs = [for (h = row) h[0]];
        y  = row[0][1];
        hull()
          for (x = [min(xs) - canoe_overrun + canoe_w / 2,
                    max(xs) + canoe_overrun - canoe_w / 2])
            translate([x, y, 0])
              cylinder(d = canoe_w, h = base_standoff + OVERLAP, $fn = 48);
      }
}

// An M2.5 heat-set insert pocket at the top of the rail under every mounting hole.
// Z = 0 of insert_hole_mask() is the entry surface, so it is placed at the rail top:
// the board's underside.
module insertPockets() {
  interiorOrigin()
    translate([board_x, board_y, base_standoff])
      for (h = pi5MountingHoles())
        translate([h[0], h[1], 0])
          insert_hole_mask("M2.5");
}

module basePart() {
  union() {
    difference() {
      union() {
        shellPanel("base");
        baseRim();
        canoes();
      }
      insertPockets();
    }
    ribsFor("base");
  }
}

basePart();
