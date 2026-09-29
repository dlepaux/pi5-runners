// ============================================================================
// STACKING — the lap between two modules and the clips on it
// ============================================================================
// Everything two stacked parts have to agree on lives here, once:
//
//   lapSolid()     the underside of every module and of the lid: the 45-degree
//                  chamfer under all four walls, filled across
//   bevelCut()     the bevel cut into the top of every module's walls
//   lapJoints()    the clip ribs on a chamfer, half a '>' each; the SAME rows, raised
//                  by module_pitch, are the grooves in the bevel of the module below
//
// All in the MODULE frame: x=0 the front face, y=0 the -Y outer face, z=0 the floor's
// underside. See config.scad.
// ============================================================================

include <../config.scad>
include <clips.scad>

// ----------------------------------------------------------------------------
// OUTLINES
// ----------------------------------------------------------------------------

// The module's footprint: every vertical corner rounded to corner_r.
module outline() {
  offset(r = corner_r) offset(delta = -corner_r) square([module_l, module_w]);
}

// The footprint inset by d on all four sides, its corners concentric with it -- so a
// wall or a lap keeps its width round them. d < 0 grows it.
module inset(d) {
  offset(r = -d, $fn = 48) outline();
}

// The module's inside below the next module's floor: inside the walls, behind the
// front wall.
module cavityOutline() {
  intersection() {
    inset(wall);
    translate([front_wall_t, -1]) square([module_l, module_w + 2]);
  }
}

// A wafer of a 2D outline at height z: hull() between two of these is a frustum --
// exact for these concentric rounded rectangles, 45 degrees all round when the inset
// changes as much as the height.
module waferAt(z) {
  translate([0, 0, z]) linear_extrude(EPS) children();
}

// ----------------------------------------------------------------------------
// LAP — the underside: a chamfer under all four walls
// ----------------------------------------------------------------------------
// Solid up to lap_top: one frustum, the chamfer's 45-degree plane carried on down
// past the walls' inner faces (at lap_z0) to the bed, so the floor under the rib
// narrows to it instead of stepping -- a step there is a ledge -- and stands lap_z0
// clear of the walls below. The owner adds its walls above and cuts its inside.
module lapSolid() {
  hull() {
    waferAt(0) inset(wall + lap_z0);
    waferAt(lap_top - EPS) inset(0);
  }
}

// ----------------------------------------------------------------------------
// BEVEL — the top of every module's walls
// ----------------------------------------------------------------------------
// The next module's chamfer, lap_sink lower, carried 1mm past the outer faces so the
// cut runs out through the top instead of meeting it face to face; and the inside
// above its floor. The lip is what the part's height, module_h, leaves of the wedge.
module bevelCut() {
  z0 = module_pitch + lap_z0 - lap_sink;
  hull() {
    waferAt(z0) inset(wall);
    waferAt(z0 + wall + 1) inset(-1);
  }
  translate([0, 0, module_pitch]) linear_extrude(lap_z0 + 1) inset(wall);
}

// ----------------------------------------------------------------------------
// CLIP JOINTS
// ----------------------------------------------------------------------------
// One rib per wall. A lap joint carries a fifth field, the wall's outward direction:
// clipRib() and clipGroove() build it as half a '>' on the lap (lib/clips.scad) rather
// than a diamond on a vertical face. Its centre is on the wall's inner face at z = 0,
// half way along the wall.
function lapJoints() =
  let (xm = (front_wall_t + module_l - wall) / 2)
  [ ["left",  [xm, wall, 0],               "x", clip_rib_len, [0, -1, 0]],
    ["right", [xm, module_w - wall, 0],    "x", clip_rib_len, [0,  1, 0]],
    ["rear",  [module_l - wall, module_w / 2, 0], "y", clip_rib_len, [ 1, 0, 0]],
    ["front", [wall, module_w / 2, 0],     "y", clip_rib_len, [-1, 0, 0]] ];

// The same joint, seen from the module below: its groove, in its own frame.
function bevelJoint(j) = [j[0], j[1] + [0, 0, module_pitch], j[2], j[3], j[4]];

module lapRibs()      { for (j = lapJoints()) clipRib(j); }
module bevelGrooves() { for (j = lapJoints()) clipGroove(bevelJoint(j)); }
