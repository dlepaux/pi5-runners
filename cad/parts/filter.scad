// ============================================================================
// FILTER — the intake dust filter, on the front
// ============================================================================
// Press-fits into the fan opening from OUTSIDE the -X front wall. There is exactly
// one filter and that is not an economy: the case runs positive pressure, so the
// intake is the only unfiltered path air can take.
//
// A RETAINER FOR BOUGHT MEDIA, like hexrack's, not the filtration itself. The grille
// holds a pad of filter media against the intake; the media is what stops dust and
// what costs pressure. The grille only has to get out of its way.
//
// hexrack's triangle lattice, same constants as the rear, so the front and back of
// the case read as one design.
//
// Printed flat on its face, grille down. No supports: the lip points straight up.
// ============================================================================

include <../config.scad>
use <../lib/vents.scad>
use <../lib/noctua-fan.scad>

// Vectors now: the column is 40 x 80, not square.
function filterPlateSize()  = fan_opening + [2, 2] * filter_flange;
function filterGrilleSize() = fan_opening - [2, 2] * filter_frame;

module filterPlateProfile() {
  s = filterPlateSize();
  r = fan_opening_r + filter_flange;
  offset(r = r, $fn = 48)
    square([s[0] - 2 * r, s[1] - 2 * r], center = true);
}

// The grille's holes, in the plate's own frame, centred. Exposed so test-airflow.sh
// can measure exactly the area that is cut.
module filterGrilleProfile() {
  g = filterGrilleSize();
  translate([-g[0] / 2, -g[1] / 2])
    ventField(g[0], g[1]);
}

module filterPart() {
  difference() {
    union() {
      linear_extrude(filter_t) filterPlateProfile();

      // The lip: a rounded-square ring that presses into the opening. Undersized by
      // filter_clear on the OUTSIDE so it enters -- a press fit, not a clearance fit.
      translate([0, 0, filter_t])
        linear_extrude(filter_lip_h)
          difference() {
            fanOpeningProfile(-filter_clear);
            fanOpeningProfile(-filter_clear - filter_lip_t);
          }
    }

    translate([0, 0, -EPS])
      linear_extrude(filter_t + 2 * EPS)
        filterGrilleProfile();
  }
}

// The filter as fitted: outside the -X front wall, lip pointing +X into the opening.
//
// ONE PLACEMENT, USED BY BOTH THE FIT TEST AND THE SHOWCASE. It used to be written out
// twice, and both copies carried the same error: rotate([0,90,0]) alone sends the
// part's local x to world -Z and its local y to world Y, so the filter's 80mm side
// lay ACROSS a wall only 60.5 wide and its lip landed on solid wall either side of the
// opening. With a square fan every rotation fits, so the error was invisible until
// the column made the part oblong.
//
// Rz(90) first sends local x -> +Y and local y -> -X; Ry(90) then sends that -X to +Z
// and local z (the lip) to +X. Net: the 40 across the wall, the 80 up it, the lip in.
module filterMounted(pull = 0) {
  translate([-filter_t - pull, wall + interior_y / 2, wall + fan_col_zc])
    rotate([0, 90, 0])
      rotate([0, 0, 90])
        filterPart();
}

filterPart();
