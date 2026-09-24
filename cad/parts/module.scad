// ============================================================================
// MODULE — one Raspberry Pi 5 and its fan, printed as one piece
// ============================================================================
// Floor and four walls. The Pi screws into heat-set inserts in two rails on the floor;
// its fan sits on the inside of the front wall, screwed from outside, and hexrack's
// round dust filter clips into the front wall over it. The module's spigot drops
// into the module below and clips there; the module above drops into this one's
// socket. Print it three times.
//
// PRINTED FLOOR-DOWN, AS IT STANDS, WITH NO SUPPORT:
//   - the vented floor is the first layers, on the bed
//   - the spigot's outer band steps out to the wall on a 45-degree chamfer that
//     reaches the outer face: no ledge, no roof
//   - the walls rise straight; port and vent openings are short bridges; the fan
//     bore is an arch in the front wall, its crown a bridge that shortens to nothing
//   - the filter's round recess has its flats top and bottom: the top flat is a short
//     bridge, the arc beside it a short overhang off the web behind it
//   - the socket's bevel and clip grooves face inward and upward
// ============================================================================

include <../lib/stacking.scad>
include <../lib/placement.scad>
use <../lib/ports.scad>
use <../lib/vents.scad>
use <../lib/sbc-helpers.scad>
include <../lib/dust-filter.scad>

// ----------------------------------------------------------------------------
// BODY — spigot, floor, walls, socket
// ----------------------------------------------------------------------------
module moduleBody() {
  difference() {
    union() {
      spigotSolid();
      translate([0, 0, lap_top])
        linear_extrude(module_h - lap_top) outline();
      // The front wall: full width, from the bed to the module above, which sits on it.
      linear_extrude(module_pitch) frontWallOutline();
    }
    spigotCavity(floor_t);
    translate([0, 0, spigot_h - EPS])
      linear_extrude(module_pitch - spigot_h + 2 * EPS) insetRect(wall, front_wall_t);
    socketCut();
  }
}

// ----------------------------------------------------------------------------
// RAILS AND INSERTS
// ----------------------------------------------------------------------------

// The Pi's mounting holes, grouped into the two rows the rails run along.
function holeRows() =
  let (holes = pi5MountingHoles(),
       ys = [for (h = holes) h[1]])
  [ for (y = [min(ys), max(ys)]) [ for (h = holes) if (h[1] == y) h ] ];

// One rail per row, along X -- with the airflow -- from its first hole to its last and
// canoe_overrun beyond, round-ended.
module canoeFootprint() {
  translate([board_x, board_y])
    for (row = holeRows()) {
      xs = [for (h = row) h[0]];
      hull()
        for (x = [min(xs) - canoe_overrun + canoe_w / 2,
                  max(xs) + canoe_overrun - canoe_w / 2])
          translate([x, row[0][1]]) circle(d = canoe_w, $fn = 48);
    }
}

// Clipped to the spigot: with the walls this close to the board, a round-ended rail
// would otherwise stand out past the spigot band into the module below. As tall as
// board_lift makes them: from the floor to the board's underside.
module canoes() {
  translate([0, 0, floor_t - OVERLAP])
    linear_extrude(board_z - floor_t + OVERLAP)
      intersection() { canoeFootprint(); insetRect(spigot_inset); }
}

// Z = 0 of insert_hole_mask() is the entry surface: the rail top, the board's underside.
module insertPockets() {
  onBoard()
    for (h = pi5MountingHoles())
      translate([h[0], h[1], 0]) insert_hole_mask(insert_m25);
}

// ----------------------------------------------------------------------------
// VENTS
// ----------------------------------------------------------------------------
// rotate([90,0,90]) is Rz(90).Rx(90): profile x -> Y, profile y -> Z, extrusion -> +X.
module onXWall(x0) {
  translate([x0, 0, 0]) rotate([90, 0, 90]) children();
}
// rotate([90,0,0]) is Rx(90): profile x -> X, profile y -> Z, extrusion -> -Y. So a
// sweep through a Y wall STARTS at its high-Y face.
module onYWall(y_high) {
  translate([0, y_high, 0]) rotate([90, 0, 0]) children();
}

// hexrack's back face: the vents with an exclusion zone round the port cluster, so
// every connector sits in clean solid wall. Centred on the MEASURED cluster, which is
// not symmetric about the board.
function exclusionCentre() =
  [board_y + (exclusion_cluster_y[0] + exclusion_cluster_y[1]) / 2,
   board_z + (exclusion_cluster_z[0] + exclusion_cluster_z[1]) / 2];

module exclusionZone() {
  translate(exclusionCentre())
    offset(r = exclusion_r, $fn = 30)
      square([exclusion_w - 2 * exclusion_r, exclusion_h - 2 * exclusion_r], center = true);
}

// Each profile is its own module so test-airflow.sh measures EXACTLY what is cut.
module rearVentProfile() {
  difference() {
    translate([wall + vent_margin, vent_z0])
      diamondField(module_w - 2 * (wall + vent_margin), vent_z1 - vent_z0);
    exclusionZone();
  }
}

module sideVentProfile() {
  translate([side_field_x[0], vent_z0])
    slotField(side_field_x[1] - side_field_x[0], vent_z1 - vent_z0);
}

// The floor: inside the spigot ring on all four sides, clear of the rails. It is what
// lets each module breathe into the one above, and it is the first layers of the
// print. INSIDE THE RING: a field that reaches under the ring leaves the ring's band
// standing over the holes -- a ledge, found when the front stopped being open.
module floorVentProfile() {
  m = spigot_inset + spigot_t + vent_margin;
  x0 = front_wall_t + vent_margin;
  difference() {
    translate([x0, m]) ventField(module_l - m - x0, module_w - 2 * m);
    offset(delta = vent_margin) canoeFootprint();
  }
}

module ventCuts() {
  onXWall(module_l - wall - EPS)
    linear_extrude(wall + 4 * EPS) rearVentProfile();
  onYWall(wall + EPS)
    linear_extrude(wall + 4 * EPS) sideVentProfile();
  onYWall(module_w + EPS)
    linear_extrude(wall + 4 * EPS) sideVentProfile();
  translate([0, 0, -EPS])
    linear_extrude(floor_t + 2 * EPS) floorVentProfile();
}

// ----------------------------------------------------------------------------
// FAN AND FILTER
// ----------------------------------------------------------------------------
// The bore, through the whole front wall, and the fan's four screw holes: hexrack's
// screw_hole_mask "front" -- countersink and pass-through -- cut from the recess floor
// inward, so the screws go in from outside and their heads sit flush under the ring.
// Rotated so the mask's -Z runs +X, into the wall.
module fanCut() {
  onFrontWall(-EPS) linear_extrude(front_wall_t + 2 * EPS) circle(d = fan_bore_d, $fn = 96);
  for (sy = [-1, 1], sz = [-1, 1])
    translate([filter_depth, fan_yc + sy * fan_bolt_pitch / 2, fan_zc + sz * fan_bolt_pitch / 2])
      rotate([0, -90, 0]) screw_hole_mask(fan_screw, "front");
}

// ----------------------------------------------------------------------------
// THE PART
// ----------------------------------------------------------------------------
// render() is NOT optional: preview does not evaluate booleans, and a body cut by
// ports, four vent fields, a bore, a recess and eight clip features blows past OpenSCAD's normalisation
// limit -- blank window, perfect export.
module modulePart() {
  render()
    difference() {
      union() {
        moduleBody();
        canoes();
        spigotRibs();
      }
      insertPockets();
      socketGrooves();
      allPortCuts();
      ventCuts();
      fanCut();
      filterRecess();
      filterGrooves();
    }
}

modulePart();
