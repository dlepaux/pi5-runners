// ============================================================================
// CLIPS — hexrack's 45-degree rib into a groove
// ============================================================================
// hexrack's dust-filter clip, used for every clipped joint here: modules to each
// other, the lid to the top module, the filter to the front face.
//
// A joint is [name, centre, axis, length] -- or, on a 45-degree lap, [..., outward]:
//   centre - the rib's axis ON THE JOINT PLANE (the mating part's face), in the frame
//            of the part that carries the rib
//   axis   - "x", "y" or "z": the direction the rib runs
//
// ONE POSITION PER JOINT. The part with the rib and the part with the groove both read
// the same row; hexrack once had a groove anchored to a different datum than its rib,
// 9mm away, and both parts still exported clean. scripts/test-clips.sh checks every row.
//
// The rib is a square section turned 45 degrees and centred on the joint plane, so
// half of it stands proud into the mate's groove. The groove is the same diamond grown
// by clip_clear, so at rest the rib touches nothing.
// ============================================================================

include <../config.scad>

module clipDiamond(axis, len, side) {
  if (axis == "x")      rotate([45, 0, 0]) cube([len, side, side], center = true);
  else if (axis == "y") rotate([0, 45, 0]) cube([side, len, side], center = true);
  else                  rotate([0, 0, 45]) cube([side, side, len], center = true);
}

module clipRib(j) {
  if (len(j) > 4) lapClip(j, 0, j[3], 0);
  else translate(j[1]) clipDiamond(j[2], j[3], clip_rib);
}

// clip_rib*sqrt(2)/2 is the half-diagonal, so growing it by clip_clear means growing
// the side by clip_clear*sqrt(2).
module clipGroove(j) {
  if (len(j) > 4) lapClip(j, clip_clear, j[3] + 2 * clip_clear, lap_hold_clear);
  else translate(j[1]) clipDiamond(j[2], j[3] + 2 * clip_clear, clip_rib + sqrt(2) * clip_clear);
}

// ON A 45-DEGREE LAP (a joint with a fifth field, the wall's outward direction): the
// UPPER HALF of the diamond's '>', in the wall's cross-section -- h outward from the
// inner face, z up from the part's underside. Flat underside on z = 0 from the rib's
// inner corner at h = -lap_z0, where the chamfer meets the bed; the holding face
// falling outward from the apex at lap_clip_angle; the chamfer's plane (45) its third
// side. grow > 0 is the groove: grow off every face but the holding one, which
// stands only hold off it (lap_hold_clear), so the clip takes a lifted module at once.
module lapClipProfile(grow, hold) {
  a = lap_rib;
  apex = [-lap_z0 + a, a];
  big = 20;
  intersection() {
    offset(r = grow, $fn = 16)
      polygon([[-lap_z0, 0], apex, [-lap_z0 + lap_rib_w, 0]]);
    // The holding face's side, moved `hold` out along its normal (up and outward).
    translate(apex) rotate(90 - lap_clip_angle)
      translate([hold - big, -big / 2]) square(big);
  }
}

// The profile (h, z) swept `len` along the joint's axis: h along the outward
// direction o, z up, the sweep along the axis.
module lapClip(j, grow, len, hold) {
  o = j[4];
  a = j[2] == "x" ? [1, 0, 0] : [0, 1, 0];
  translate(j[1])
    multmatrix([[o[0], 0, a[0], 0], [o[1], 0, a[1], 0], [o[2], 1, a[2], 0]])
      linear_extrude(len, center = true) lapClipProfile(grow, hold);
}
