// ============================================================================
// STACKING — the spigot, the socket, the lap between them, and the dovetail rails
// ============================================================================
// Everything two stacked parts have to agree on lives here, once:
//
//   spigotSolid()  the bottom band of every module and of the lid
//   socketLap()    the bevel cut into the top of every module's walls
//   spigotJoints() the clip ribs on a spigot; the SAME rows, raised by module_pitch,
//                  are the grooves in the socket of the module below
//
// All in the MODULE frame: x=0 the front face, y=0 the -Y outer face, z=0 the
// spigot's bottom. See config.scad.
// ============================================================================

include <../config.scad>
include <clips.scad>

// ----------------------------------------------------------------------------
// OUTLINES
// ----------------------------------------------------------------------------

// The module's footprint inset by d on its sides and rear -- the three walls that
// stack on a lap. The front butt-joins, so the front edge stays at x0.
module insetRect(d, x0 = 0) {
  translate([x0, d]) square([module_l - d - x0, module_w - 2 * d]);
}

// A wafer of a 2D outline at height z: hull() between two of these is a frustum,
// exact for the convex rectangles above.
module waferAt(z) {
  translate([0, 0, z]) linear_extrude(EPS) children();
}

// ----------------------------------------------------------------------------
// SPIGOT — the bottom band, solid; the owner cuts its own cavity
// ----------------------------------------------------------------------------
// A straight band inset spigot_inset from the outer faces, then the 45-degree lap out
// to lap_inset0 at spigot_h. Above spigot_h the owner's full outline takes over, so
// the land's underside -- lap_inset0 wide -- is the only thing printed over air.
module spigotSolid() {
  z_lap = spigot_h - lap_h;
  linear_extrude(z_lap + EPS) insetRect(spigot_inset);
  hull() {
    waferAt(z_lap) insetRect(spigot_inset);
    waferAt(spigot_h - EPS) insetRect(lap_inset0);
  }
}

// The spigot's inside, from z0 up to spigot_h, behind the front wall. A module starts
// it at its floor's top; the lid is hollow all the way down.
module spigotCavity(z0) {
  translate([0, 0, z0])
    linear_extrude(spigot_h - z0 + EPS) insetRect(spigot_inset + spigot_t, front_wall_t);
}

// ----------------------------------------------------------------------------
// SOCKET — the top of every module's walls
// ----------------------------------------------------------------------------
// Above module_pitch the walls are the socket: `wall` thick on the sides and rear,
// and NOTHING in front of the front wall's line -- the module above stands its own
// front wall there, full width, on this one's. The inside opens at 45 degrees up to a
// stack_land-wide flat at module_h, carried past module_h at the same slope so the
// cut runs out through the top rather than meeting it face to face.
module socketCut() {
  translate([0, 0, module_pitch])
    linear_extrude(module_h - module_pitch + 1) insetRect(wall, -1);
  translate([-1, -1, module_pitch])
    cube([front_wall_t + 1, module_w + 2, module_h - module_pitch + 1]);
  hull() {
    waferAt(module_h - (wall - stack_land)) insetRect(wall, -1);
    waferAt(module_h + 1) insetRect(stack_land - 1, -1);
  }
}

// ----------------------------------------------------------------------------
// CLIP JOINTS
// ----------------------------------------------------------------------------
// Ribs on the spigot's outer faces, centred on the plane of the lower module's inner
// wall face: one per side wall, one on the rear. Three hold a module; five only made
// it harder to pull apart.
function spigotJoints() =
  let (yl = wall, yr = module_w - wall, xr = module_l - wall, z = clip_z,
       xm = (front_wall_t + module_l - wall) / 2)
  [ ["left",  [xm, yl, z], "x", clip_rib_len],
    ["right", [xm, yr, z], "x", clip_rib_len],
    ["rear",  [xr, module_w / 2, z], "y", clip_rib_len] ];

// The same joint, seen from the module below: its groove, in its own frame.
function socketJoint(j) = [j[0], j[1] + [0, 0, module_pitch], j[2], j[3]];

module spigotRibs()    { for (j = spigotJoints()) clipRib(j); }
module socketGrooves() { for (j = spigotJoints()) clipGroove(socketJoint(j)); }
