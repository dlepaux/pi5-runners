// ============================================================================
// LID — closes the top module
// ============================================================================
// A module's underside with a plate on it instead of a module: its chamfer lies on
// the top module's bevel and clips there on the same four ribs. Solid: a lid with
// holes in it drops dust straight onto the top board.
//
// PRINTED UPSIDE DOWN, plate on the bed: the lap then narrows as it rises and the
// ribs are square bars on it, every face at 45. lidPrint() is that orientation;
// lidPart() is the lid as it sits, for the assembly and the fit tests.
// ============================================================================

include <../lib/stacking.scad>

lid_top = lap_top + lid_t;

// The lid without its ribs: what bears on the top module, and what the seating
// checks measure -- with the ribs on, a rib biting the bevel would pass for the lap.
module lidBody() {
  difference() {
    union() {
      hull() {
        waferAt(lap_z0) inset(wall);
        waferAt(lap_top - EPS) inset(0);
      }
      translate([0, 0, lap_top - EPS]) linear_extrude(lid_t + EPS) outline();
    }
    // Open inside the chamfer: the plate is all the lid needs to close the top.
    translate([0, 0, -1]) linear_extrude(lap_top + 1) inset(wall);
  }
}

module lidPart() {
  union() { lidBody(); lapRibs(); }
}

// Rx(180) sends z to -z and y to -y; the translate puts it back on the bed.
module lidPrint() {
  translate([0, module_w, lid_top]) rotate([180, 0, 0]) lidPart();
}

lidPrint();
