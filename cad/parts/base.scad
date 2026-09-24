// ============================================================================
// BASE — the feet the bottom module clips into
// ============================================================================
// The top of a module with no module under it: the same socket -- bevel, lip and
// three clip grooves -- so the bottom module drops in and clicks exactly as it does
// onto another module, and its front wall butt-joins a solid block, as in the stack.
// Round it, a SKIRT: the module's outline grown by base_skirt on the sides and rear,
// rising past the joint to just under the lowest vents. The front stays flush -- a
// skirt there would cover the filter's lower edge and trap it.
//
// AN OPEN FRAME. The rim runs only under the socket walls and the front block; a
// plate would add filament and nothing else, the bottom floor faces the desk anyway.
//
// THE BASE IS MODULE -1's TOP SLICE, in module -1's frame: its socket IS
// moduleBody()'s, cut from the same code, so it cannot drift from the modules'.
// basePrint() brings it onto the bed; baseAt() places it in the stack.
//
// PRINTED RIM DOWN, AS IT STANDS, WITH NO SUPPORT: the skirt is vertical, the socket's
// bevel and grooves face inward and up as on a module's top.
// ============================================================================

include <../lib/stacking.scad>
use <module.scad>

base_z0 = module_pitch - base_floor_t;   // the bed, in module -1's frame

// Front flat and flush at x = 0 with corner_r corners; sides and rear grown by
// base_skirt, their corners concentric with the module's.
module baseOutline() {
  s = base_skirt;
  hull()
    for (c = [[corner_r,              corner_r - s,            corner_r],
              [corner_r,              module_w - corner_r + s, corner_r],
              [module_l - corner_r,   corner_r,                corner_r + s],
              [module_l - corner_r,   module_w - corner_r,     corner_r + s]])
      translate([c[0], c[1]]) circle(r = c[2]);
}

module basePart() {
  difference() {
    union() {
      // The rim under the socket walls, and the solid block the front wall stands on.
      // Exactly module_pitch high: the bottom module stands on it. What sits on the
      // rim reaches OVERLAP down into it instead.
      translate([0, 0, base_z0])
        linear_extrude(module_pitch - base_z0)
          difference() { baseOutline(); insetRect(wall, front_wall_t); }
      // The socket: moduleBody()'s, above module_pitch.
      intersection() {
        moduleBody();
        translate([-1, -1, module_pitch - OVERLAP]) cube([module_l + 2, module_w + 2, module_h]);
      }
      // The skirt, solid against the socket walls up to their lip...
      translate([0, 0, module_pitch - OVERLAP])
        linear_extrude(module_h - module_pitch + 2 * OVERLAP)
          difference() { baseOutline(); outline(); }
      // ...then standing off the bottom module's outer face.
      translate([0, 0, module_h])
        linear_extrude(module_pitch + base_skirt_h - module_h)
          difference() { baseOutline(); offset(delta = base_skirt_clear) outline(); }
    }
    socketGrooves();
  }
}

// Onto the bed: the rim's underside at z = 0.
module basePrint() {
  translate([0, 0, -base_z0]) basePart();
}

basePrint();
