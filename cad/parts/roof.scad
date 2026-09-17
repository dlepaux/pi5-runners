// ============================================================================
// ROOF — lid, exhaust field, top-board retainer
// ============================================================================
// The retainer is a SPACER, not a fixing: it presses on the top board so the stack
// cannot flex, and nothing is screwed into it.
//
// ONLY TWO POSTS, AND THE COOLER IS WHY. The Active Cooler's footprint is 58 x 40
// seated at the board's 3.5 inset, so it covers the mounting holes at y = 3.5
// entirely. The pair at y = 52.5 is the only one standing in clear air. Four posts
// would render, export and print, and two of them would land on a fan.
// ============================================================================

include <../config.scad>
use <../lib/shell.scad>
use <../lib/sbc-helpers.scad>
use <../lib/placement.scad>

// The holes the cooler does not cover. Derived from the cooler's own footprint rather
// than listed, so a different cooler moves the posts instead of silently fouling them.
function retainerHoles() =
  [ for (p = pi5MountingHoles())
      if (p[1] > pi5_hole_inset + cooler_footprint[1]) p ];

// Reach from the roof's inner face down to the top board's PCB top.
function retainerDrop() =
  (outer[2] - wall) - (wall + board_z[2] + pi5_pcb[2]);

module roofRetainer() {
  drop = retainerDrop();
  assert(drop > 0, "the roof is below the top board — retainer would be inside it");
  assert(len(retainerHoles()) >= 2,
         "fewer than two retainer posts clear the cooler");

  interiorOrigin()
    translate([board_x, board_y, 0])
      for (p = retainerHoles())
        translate([p[0], p[1], board_z[2] + pi5_pcb[2]])
          cylinder(d = retainer_d, h = drop);
}

module roofPart() {
  union() {
    shellPanel("roof");
    roofRetainer();
  }
}

roofPart();
