// ============================================================================
// CLIPS — every joint in the case, as one table
// ============================================================================
// hexrack's 45-degree rib into a groove (its dust-filter clip), used for every joint:
// walls to base, walls to each other, roof to walls, filter to front wall.
//
// ONE TABLE, THREE READERS. The parts that carry a rib, the shell that cuts the
// matching groove, and scripts/test-clips.sh all read clipJoints(). hexrack learned
// the hard way that a rib and its groove are one joint written in two files: its
// groove was once anchored to a different datum than its rib, moved 9mm away, and
// both parts still exported clean. Here there is one position per joint, full stop.
//
// A joint is [name, centre, axis, length, owner, mate]:
//   centre - the rib's axis, in the CASE frame, ON THE JOINT PLANE (the mate's face)
//   axis   - "x" or "y": the direction the rib runs
//   owner  - the part the rib belongs to; mate - the part the groove is cut into
//
// The rib is a square section turned 45 degrees and centred on the joint plane, so
// half of it is inside the owner and half stands proud into the mate's groove. The
// groove is the same diamond grown by clip_clear, so at rest the rib touches nothing.
// ============================================================================

include <../config.scad>

rib_half = clip_rib * sqrt(2) / 2;   // how far the rib stands proud of the plane

// Gap between a rim or flange and the wall face it lies against. The rib is centred
// on the WALL's face, so it spans the gap and still overlaps its owner by
// rib_half - rim_gap.
rim_gap = 0.2;

// Heights for the corner-flange ribs: a quarter, half and three quarters up the flange.
function flangeZ0() = wall + rim_h;
function flangeZ1() = outer[2] - wall - rim_h;
function flangeRibZ(k) = flangeZ0() + (flangeZ1() - flangeZ0()) * (k + 1) / 4;

// The filter's ribs sit on the recess's top and bottom faces, half-way through the
// ring's thickness.
function filterRecessHalfH() = filterOuter()[1] / 2 + filter_clear;
function filterCentreZ()     = wall + fan_col_zc;
function filterCentreY()     = wall + interior_y / 2;

function clipJoints() =
  let (
    xa   = wall_front + interior_x / 3,          // base/roof side ribs, at thirds
    xb   = wall_front + 2 * interior_x / 3,
    yl   = wall,                                  // -Y side wall's inner face
    yr   = outer[1] - wall,                       // +Y side wall's inner face
    zb   = wall + rim_h / 2,                      // base rim mid-height
    zt   = outer[2] - wall - rim_h / 2,           // roof rim mid-height
    xf   = wall_front + flange_lap / 2,           // front flanges' mid-length
    xr   = outer[0] - wall - flange_lap / 2,      // rear flanges' mid-length
    fl   = flange_lap - 2                         // flange rib length
  )
  concat(
    // Base rim to the side walls and the rear wall. NOT to the front wall: its recess
    // leaves too little behind the base-rim groove. The front wall is held by its own
    // corner flanges instead, and located by the rim.
    [ ["base-left-a",  [xa, yl, zb], "x", clip_rib_len, "base", "left"],
      ["base-left-b",  [xb, yl, zb], "x", clip_rib_len, "base", "left"],
      ["base-right-a", [xa, yr, zb], "x", clip_rib_len, "base", "right"],
      ["base-right-b", [xb, yr, zb], "x", clip_rib_len, "base", "right"],
      ["base-rear",    [outer[0] - wall, outer[1] / 2, zb], "y", clip_rib_len, "base", "rear"] ],

    // Roof rim to the side walls only: the front has the recess, the rear the ports.
    [ ["roof-left-a",  [xa, yl, zt], "x", clip_rib_len, "roof", "left"],
      ["roof-left-b",  [xb, yl, zt], "x", clip_rib_len, "roof", "left"],
      ["roof-right-a", [xa, yr, zt], "x", clip_rib_len, "roof", "right"],
      ["roof-right-b", [xb, yr, zt], "x", clip_rib_len, "roof", "right"] ],

    // Corner flanges: front and rear walls to both side walls, three ribs each.
    [ for (k = [0 : 2]) each [
        [str("front-left-",  k), [xf, yl, flangeRibZ(k)], "x", fl, "front", "left"],
        [str("front-right-", k), [xf, yr, flangeRibZ(k)], "x", fl, "front", "right"],
        [str("rear-left-",   k), [xr, yl, flangeRibZ(k)], "x", fl, "rear",  "left"],
        [str("rear-right-",  k), [xr, yr, flangeRibZ(k)], "x", fl, "rear",  "right"] ] ],

    // The filter ring into its recess, top and bottom.
    [ ["filter-top",    [filter_depth / 2, filterCentreY(), filterCentreZ() + filterRecessHalfH()],
                        "y", clip_rib_len, "filter", "front"],
      ["filter-bottom", [filter_depth / 2, filterCentreY(), filterCentreZ() - filterRecessHalfH()],
                        "y", clip_rib_len, "filter", "front"] ]
  );

// The diamond itself: a square section turned 45 degrees about the run direction.
module clipDiamond(axis, len, side) {
  if (axis == "x")
    rotate([45, 0, 0]) cube([len, side, side], center = true);
  else
    rotate([0, 45, 0]) cube([side, len, side], center = true);
}

module clipRib(j) {
  translate(j[1]) clipDiamond(j[2], j[3], clip_rib);
}

// The groove: the same diamond grown by clip_clear all round. clip_rib*sqrt(2)/2 is
// the half-diagonal, so adding clip_clear to it means adding clip_clear*sqrt(2) to
// the side.
module clipGroove(j) {
  translate(j[1]) clipDiamond(j[2], j[3] + 2 * clip_clear, clip_rib + sqrt(2) * clip_clear);
}

module ribsFor(owner) {
  for (j = clipJoints()) if (j[4] == owner) clipRib(j);
}

module groovesFor(mate) {
  for (j = clipJoints()) if (j[5] == mate) clipGroove(j);
}

module allGrooves() {
  for (j = clipJoints()) clipGroove(j);
}
