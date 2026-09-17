// ============================================================================
// FILTER — the intake dust filter
// ============================================================================
// Press-fits into the fan opening from OUTSIDE the +Y wall. There is exactly one
// filter in this case and that is not an economy: the case runs positive pressure, so
// the intake is the only unfiltered path air can take. Every other opening is an
// exhaust, and air leaving does not carry dust in.
//
// Printed flat on its face, grille down. No supports: the lip is the only feature off
// the plate and it points straight up.
// ============================================================================

include <../config.scad>
use <../lib/vents.scad>
use <../lib/noctua-fan.scad>

// The plate oversails the opening so it cannot fall inward, and the lip inside it
// grips the opening's walls.
function filterPlateSize() = fan_opening + 2 * filter_flange;

module filterPlateProfile() {
  s = filterPlateSize();
  r = fan_opening_r + filter_flange;
  offset(r = r, $fn = 48)
    square([s - 2 * r, s - 2 * r], center = true);
}

// The grille area: the opening, less a solid border. filter_frame is what stops the
// triangles running out to the lip and leaving it hanging off nothing.
function filterGrilleSize() = fan_opening - 2 * filter_frame;

module filterPart() {
  g = filterGrilleSize();

  difference() {
    union() {
      // The plate.
      linear_extrude(filter_t) filterPlateProfile();

      // The lip: a rounded-square ring sized to press into the opening. Undersized by
      // filter_clear on the OUTSIDE so it enters; the case's own tolerance is not
      // reused here because this is a press fit, not a clearance fit.
      translate([0, 0, filter_t])
        linear_extrude(filter_lip_h)
          difference() {
            fanOpeningProfile(-filter_clear);
            fanOpeningProfile(-filter_clear - filter_lip_t);
          }
    }

    // The grille, centred on the plate.
    translate([-g / 2, -g / 2, -EPS])
      linear_extrude(filter_t + 2 * EPS)
        ventField(g, g, filter_cell, filter_web);
  }
}

// Open area of the grille, so the airflow test can hold it against the fan's throat.
// A filter that chokes the intake is worse than no filter: it moves the restriction
// from somewhere measurable to somewhere nobody looks.
function filterOpenArea() =
  ventOpenArea(filterGrilleSize(), filterGrilleSize(), filter_cell, filter_web);

filterPart();
