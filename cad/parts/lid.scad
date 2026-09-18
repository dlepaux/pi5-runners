// ============================================================================
// LID — closes the top module
// ============================================================================
// A module's spigot with a plate on it instead of a module: it drops into the top
// module's socket, clips there on the same three ribs, and sits on the same land. Solid: a
// lid with holes in it drops dust straight onto the top board.
//
// PRINTED UPSIDE DOWN, plate on the bed: the spigot's lap then narrows as it rises and
// the ribs are diamonds on a vertical face. lidPrint() is that orientation; lidPart()
// is the lid as it sits, for the assembly and the fit tests.
// ============================================================================

include <../lib/stacking.scad>

module lidPart() {
  difference() {
    union() {
      spigotSolid();
      // The front: a module's front wall stops at module_pitch, so the lid carries
      // the last spigot_h of it, sitting on the top module's front wall.
      cube([front_wall_t, module_w, spigot_h]);
      translate([0, 0, spigot_h]) linear_extrude(lid_t) square([module_l, module_w]);
      spigotRibs();
    }
    spigotCavity(-EPS);
  }
}

// Rx(180) sends z to -z and y to -y; the translate puts it back on the bed.
module lidPrint() {
  translate([0, module_w, spigot_h + lid_t]) rotate([180, 0, 0]) lidPart();
}

lidPrint();
