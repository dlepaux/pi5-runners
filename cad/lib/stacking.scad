// ============================================================================
// STACKING — the spigot, the socket, the lap between them, and the dovetail rails
// ============================================================================
// Everything two stacked parts have to agree on lives here, once:
//
//   spigotSolid()  the bottom band of every module and of the lid
//   socketLap()    the bevel cut into the top of every module's walls
//   spigotJoints() the clip ribs on a spigot; the SAME rows, raised by module_pitch,
//                  are the grooves in the socket of the module below
//   dovetailProfile() the rails on the modules and the channels in the front face
//
// All in the MODULE frame: x=0 the open front edge, y=0 the -Y outer face, z=0 the
// spigot's bottom. See config.scad.
// ============================================================================

include <../config.scad>
include <clips.scad>

// ----------------------------------------------------------------------------
// OUTLINES
// ----------------------------------------------------------------------------

// The module's footprint inset by d on its three walls -- -Y, +Y and the +X rear.
// The front is open, so the front edge stays put; front_ext pushes it forward for
// cutters that must run out through it.
module insetRect(d, front_ext = 0) {
  translate([-front_ext, d]) square([module_l - d + front_ext, module_w - 2 * d]);
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

// The spigot ring's inside, from z0 up to spigot_h. A module starts it at its floor's
// top; the lid is hollow all the way down.
module spigotCavity(z0) {
  translate([0, 0, z0])
    linear_extrude(spigot_h - z0 + EPS) insetRect(spigot_inset + spigot_t, 1);
}

// ----------------------------------------------------------------------------
// SOCKET — the top of every module's walls
// ----------------------------------------------------------------------------
// The inside of the walls opens at 45 degrees from the wall's inner face up to a
// stack_land-wide flat at module_h. Carried past module_h at the same slope, so the
// cut runs out through the top rather than meeting it face to face.
module socketLap() {
  hull() {
    waferAt(module_h - (wall - stack_land)) insetRect(wall, 1);
    waferAt(module_h + 1) insetRect(stack_land - 1, 1);
  }
}

// ----------------------------------------------------------------------------
// CLIP JOINTS
// ----------------------------------------------------------------------------
// Ribs on the spigot's outer faces, centred on the plane of the lower module's inner
// wall face. Two per side wall, one on the rear. None on the front: it is open.
function spigotJoints() =
  let (yl = wall, yr = module_w - wall, xr = module_l - wall, z = clip_z)
  [ ["left-a",  [module_l / 3,     yl, z], "x", clip_rib_len],
    ["left-b",  [2 * module_l / 3, yl, z], "x", clip_rib_len],
    ["right-a", [module_l / 3,     yr, z], "x", clip_rib_len],
    ["right-b", [2 * module_l / 3, yr, z], "x", clip_rib_len],
    ["rear",    [xr, module_w / 2,     z], "y", clip_rib_len] ];

// The same joint, seen from the module below: its groove, in its own frame.
function socketJoint(j) = [j[0], j[1] + [0, 0, module_pitch], j[2], j[3]];

module spigotRibs()    { for (j = spigotJoints()) clipRib(j); }
module socketGrooves() { for (j = spigotJoints()) clipGroove(socketJoint(j)); }

// ----------------------------------------------------------------------------
// DOVETAILS
// ----------------------------------------------------------------------------
// One rail's section in the XY plane, for the -Y side: root on the wall's outer face
// at y = 0, flaring to dovetail_tip_w at y = -dovetail_d. The root runs OVERLAP into
// the wall so the rail is fused to it, not tangent to it.
module dovetailProfile(grow = 0) {
  hr = dovetail_w / 2;
  ht = dovetail_tip_w / 2;
  offset(delta = grow)
    translate([dovetail_x, 0])
      polygon([[-hr, OVERLAP], [hr, OVERLAP], [ht, -dovetail_d], [-ht, -dovetail_d]]);
}

// Both sides: the +Y one is the -Y one mirrored about the module's centre line.
module bothSides() {
  children();
  translate([0, module_w, 0]) mirror([0, 1, 0]) children();
}

// A module's male rails: from spigot_h, where the full wall starts, to module_h. The
// bottom rises at 45 degrees off the wall face -- below it is the inset spigot band,
// so a square end would be a 2.5mm ledge over air.
module dovetailRails() {
  bothSides() {
    hull() {
      waferAt(spigot_h)
        intersection() {
          dovetailProfile();
          translate([-1, -EPS]) square([module_l, OVERLAP + EPS]);
        }
      waferAt(spigot_h + dovetail_d) dovetailProfile();
    }
    translate([0, 0, spigot_h + dovetail_d])
      linear_extrude(module_h - spigot_h - dovetail_d) dovetailProfile();
  }
}
