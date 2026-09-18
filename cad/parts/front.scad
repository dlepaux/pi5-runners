// ============================================================================
// FRONT FACE — fans, dust filter, and the dovetails that hold it to the stack
// ============================================================================
// A U-channel as tall as the whole stack: a plate across the front, and a cheek down
// each side that wraps back over the modules and carries a female dovetail. It slides
// DOWN over the rails of every module at once, so it also ties the stack together.
//
// The two fans screw to the plate's inner face and blow into the PLENUM between the
// plate and the open module fronts; every module draws from it. The plate's outer
// face carries the pill-shaped filter recess.
//
// PRINTED STANDING, as it stands in the case, with no support:
//   - the dovetail channels and the filter's clip grooves run up the print
//   - the plenum's floor is on the bed; its ceiling rises at 45 degrees from the
//     plate above the fans to the module fronts, instead of bridging 68mm
//   - the fan bores and the pill recess are arches in a vertical face
//
// fan_model sets this part's depth, and nothing else's.
// ============================================================================

include <../lib/stacking.scad>
use <../lib/noctua-fan.scad>

plate_x0 = -front_d;             // the plate's outer face
plate_x1 = -front_d + plate_t;   // its inner face, where the fans sit
front_y0 = -cheek_gap - cheek_t;
front_y1 = module_w + cheek_gap + cheek_t;
fan_top  = fan_z0 + fan_col_h;

// The plate's 2D frame, centred on the fan column: profile x -> Y, profile y -> Z,
// extrusion -> +X.
module onPlate(x0) {
  translate([x0, fan_col_yc, fan_col_zc]) rotate([90, 0, 90]) children();
}

// The filter's two clip joints, on the pill's straight sides, half-way through the
// ring's thickness. Axis "z": the ribs run up the print.
function filterJoints() =
  let (x = plate_x0 + filter_depth / 2, r = pill_r_out + filter_clear)
  [ ["filter-left",  [x, fan_col_yc - r, fan_col_zc], "z", clip_rib_len],
    ["filter-right", [x, fan_col_yc + r, fan_col_zc], "z", clip_rib_len] ];

// ----------------------------------------------------------------------------
// BODY
// ----------------------------------------------------------------------------
module frontBody() {
  // Plate.
  translate([plate_x0, front_y0, 0]) cube([plate_t, front_y1 - front_y0, front_h]);

  // Cheeks, from the plate back past the modules' dovetails.
  for (y0 = [front_y0, module_w + cheek_gap])
    translate([plate_x0, y0, 0]) cube([cheek_end_x - plate_x0, cheek_t, front_h]);

  // The plenum's floor, on the bed, stopping cheek_gap short of the modules.
  translate([plate_x1 - OVERLAP, -cheek_gap - OVERLAP, 0])
    cube([-cheek_gap - plate_x1 + OVERLAP, module_w + 2 * (cheek_gap + OVERLAP), floor_t]);

  // The plenum's ceiling: 45 degrees up from the plate at the top of the fan column,
  // solid above. config.scad asserts it closes below front_h.
  translate([0, module_w + cheek_gap + OVERLAP, 0])
    rotate([90, 0, 0])
      linear_extrude(module_w + 2 * (cheek_gap + OVERLAP))
        polygon([[plate_x1 - OVERLAP, fan_top],
                  [-cheek_gap, fan_top + (-cheek_gap - plate_x1)],
                  [-cheek_gap, front_h],
                  [plate_x1 - OVERLAP, front_h]]);
}

// ----------------------------------------------------------------------------
// CUTS
// ----------------------------------------------------------------------------

// Round bores and the fans' pilot holes, through the plate. The fans screw in from
// the plenum side, self-tapping into the 3mm behind the recess floor.
module fanCut() {
  onPlate(plate_x0 - EPS)
    linear_extrude(plate_t + 2 * EPS) {
      fanBoreProfile();
      fanBoltProfile(fan_pilot_d);
    }
}

// The pill recess the filter ring sits flush in.
module filterRecess() {
  onPlate(plate_x0 - EPS)
    linear_extrude(filter_depth + EPS) pillProfile(pill_r_out + filter_clear);
}

// The female dovetails: the rail's section grown by dovetail_clear, the full height.
module dovetailChannels() {
  bothSides()
    translate([0, 0, -1]) linear_extrude(front_h + 2) dovetailProfile(dovetail_clear);
}

module frontPart() {
  render()
    difference() {
      frontBody();
      fanCut();
      filterRecess();
      dovetailChannels();
      for (j = filterJoints()) clipGroove(j);
    }
}

frontPart();
