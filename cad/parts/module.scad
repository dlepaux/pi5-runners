// ============================================================================
// MODULE — one Raspberry Pi 5 and its fan, printed as one piece
// ============================================================================
// Floor and four walls. The Pi screws into heat-set inserts in four posts on the floor;
// its fan sits on the inside of the front wall, screwed from outside, and hexrack's
// round dust filter clips into the front wall over it. The module's chamfered
// underside lies on the bevel of the module below and clips there, one rib a wall;
// the module above lies on this one's. Print it three times.
//
// PRINTED FLOOR-DOWN, AS IT STANDS, WITH NO SUPPORT:
//   - the floor is the first layers, on the bed
//   - the walls step out from it on a 45-degree chamfer that reaches the outer face,
//     their ribs square bars on it with every face at 45: no ledge, no roof
//   - the walls rise straight; port and vent openings are short bridges; the fan
//     bore is an arch in the front wall, its crown a bridge that shortens to nothing
//   - the filter's recess has a 4mm-deep flat top off the web behind it
//   - the bevel and its clip grooves face inward and upward
// ============================================================================

include <../lib/stacking.scad>
include <../lib/placement.scad>
use <../lib/ports.scad>
use <../lib/vents.scad>
use <../lib/sbc-helpers.scad>
include <../lib/dust-filter.scad>

// ----------------------------------------------------------------------------
// BODY — lap, floor, walls, bevel
// ----------------------------------------------------------------------------
// The front wall is solid front_wall_t deep up to the next module's floor, which lies
// on it; above that only its outer `wall` rises, into the lap, like the other three.
module moduleBody() {
  difference() {
    union() {
      difference() {
        union() {
          lapSolid();
          translate([0, 0, lap_top - EPS])
            linear_extrude(module_h - lap_top + EPS) outline();
        }
        translate([0, 0, floor_t])
          linear_extrude(module_pitch - floor_t + EPS) cavityOutline();
        bevelCut();
      }
      islandBulge();
    }
    islandPocket();
  }
}

// ----------------------------------------------------------------------------
// THE PORT ISLAND — the -Y wall stepped in round the USB-C and micro-HDMIs
// ----------------------------------------------------------------------------
// The island's face, seen from outside: x along the wall, z up, grown by g above and
// below only -- its ends stay square to the wall.
module islandFace(g) {
  translate([island_x[0], island_z[0] - g])
    offset(r = island_r) offset(delta = -island_r)
      square([island_x[1] - island_x[0], island_z[1] - island_z[0] + 2 * g]);
}

// A wafer of the face at y, [y - EPS, y]: hull() between two is the 45-degree step.
module islandAt(y) {
  translate([0, y, 0]) rotate([90, 0, 0]) linear_extrude(EPS) children();
}

// Outside: from the island's face at island_outer out past the wall, grown as much
// as it is deep, so the ceiling and the floor of the recess run out at 45.
module islandPocket() {
  hull() {
    islandAt(island_outer) islandFace(0);
    islandAt(-1) islandFace(island_outer + 1);
  }
}

// Inside: from the wall's inner face in to island_inner, the same way.
module islandBulge() {
  hull() {
    islandAt(island_inner) islandFace(0);
    islandAt(wall) islandFace(island_inner - wall);
  }
}

// ----------------------------------------------------------------------------
// POSTS AND INSERTS
// ----------------------------------------------------------------------------

// One round post per mounting hole, not a rail per row: less plastic, and the air
// under the board runs between four posts instead of along two walls.
module postFootprint() {
  translate([board_x, board_y])
    for (h = pi5MountingHoles()) translate([h[0], h[1]]) circle(d = post_d, $fn = 48);
}

// Clipped to the inside: with the walls this close to the board, a post would
// otherwise stand into a wall. As tall as board_lift makes them, less the standoffs:
// from the floor to rail_top.
module posts() {
  translate([0, 0, floor_t - OVERLAP])
    linear_extrude(rail_top - floor_t + OVERLAP)
      intersection() { postFootprint(); inset(wall); }
}

// Z = 0 of insert_hole_mask() is the entry surface: the rail top, a standoff below
// the board's underside.
module insertPockets() {
  onBoard()
    for (h = pi5MountingHoles())
      translate([h[0], h[1], -board_standoff_h]) insert_hole_mask(insert_m25);
}

// The board's standoffs as bought parts: a hex envelope (across corners) from each
// insert up to the board. Not printed -- for the preview and the fit tests.
module boardStandoffs() {
  onBoard()
    for (h = pi5MountingHoles())
      translate([h[0], h[1], -board_standoff_h])
        cylinder(d = board_standoff_af / cos(30), h = board_standoff_h, $fn = 6);
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

// The port cluster, and the PCB-edge slot under it.
module exclusionZone() {
  translate(exclusionCentre())
    offset(r = exclusion_r, $fn = 30)
      square([exclusion_w - 2 * exclusion_r, exclusion_h - 2 * exclusion_r], center = true);
  if (pcb_slot_depth > 0)
    translate([board_y - pcb_slot_clear - exclusion_pad,
               board_z - pcb_slot_clear - exclusion_pad])
      square([pi5_pcb[1] + 2 * (pcb_slot_clear + exclusion_pad),
              pcb_slot_h + 2 * exclusion_pad]);
}

// Each profile is its own module so test-airflow.sh measures EXACTLY what is cut.
// REAR: the side louvres' shape, straight through -- the air here already heads
// straight out. The port cluster takes the wall's middle, so they run in a band above
// and a band below it, in the same columns, so they read as running top to bottom
// with the ports between. A band shorter than a slot is wide is left solid.
module rearVentProfile() {
  x0 = wall + vent_margin;
  w  = module_w - 2 * x0;
  bands = [[vent_z0, rearExclusionZ()[0]], [rearExclusionZ()[1], vent_z1]];
  difference() {
    for (b = bands) if (b[1] - b[0] >= vent_slot_w)
      translate([x0, b[0]]) louvreField(w, b[1] - b[0]);
    exclusionZone();
  }
}

// The exclusion zone's bottom and top, the PCB-edge slot included.
function rearExclusionZ() =
  [min(exclusionCentre()[1] - exclusion_h / 2, board_z - pcb_slot_clear - exclusion_pad),
   exclusionCentre()[1] + exclusion_h / 2];

// The louvres' face on the wall's INNER side; sideVentCut() leans them rearward.
module sideVentProfile() {
  translate([side_field_x[0], vent_z0])
    louvreField(side_field_x[1] - side_field_x[0], vent_z1 - vent_z0);
}

// A straight cut through a Y wall, sheared about its inner face so x grows by
// vent_side_lean toward the outer face: \\\ on +Y, /// on -Y from above.
module sideVentCut(y_inner, outward) {
  translate([0, y_inner, 0])
    multmatrix([[1, outward * tan(vent_side_angle), 0, 0], [0, 1, 0, 0], [0, 0, 1, 0]])
      translate([0, -y_inner, 0])
        onYWall(y_inner + (outward > 0 ? wall + 2 * EPS : EPS))
          linear_extrude(wall + 4 * EPS) sideVentProfile();
}

// The floor lattice, OFF BY DEFAULT (floor_vents): hexrack's triangles, inside the
// walls and clear of the posts, letting a module breathe into the one above. Off, the
// floor is solid -- the first layers print whole and nothing falls from one board
// onto the next. Every consumer reads this module, so off means off everywhere.
module floorVentProfile() {
  m = wall + lap_z0 + vent_margin;
  x0 = front_wall_t + vent_margin;
  if (floor_vents)
    difference() {
      translate([x0, m]) ventField(module_l - m - x0, module_w - 2 * m);
      offset(delta = vent_margin) postFootprint();
    }
}

module ventCuts() {
  onXWall(module_l - wall - EPS)
    linear_extrude(wall + 4 * EPS) rearVentProfile();
  sideVentCut(wall, -1);
  sideVentCut(module_w - wall, 1);
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
        posts();
        lapRibs();
      }
      insertPockets();
      bevelGrooves();
      allPortCuts();
      ventCuts();
      fanCut();
      filterRecess();
      filterGrooves();
    }
}

modulePart();
