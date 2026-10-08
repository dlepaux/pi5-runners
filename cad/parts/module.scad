// ============================================================================
// MODULE — one Raspberry Pi 5 and its fan, printed as one piece
// ============================================================================
// Floor and four walls. The Pi screws straight into four printed feet on the floor;
// its fan sits on the inside of the front wall, screwed from outside, and hexrack's
// round dust filter clips into the front wall over it. The module's chamfered
// underside lies on the bevel of the module below and clips there, one rib a wall;
// the module above lies on this one's. Print it three times.
//
// The floor under the Pi is a separate TRAY (config.scad, TRAY), dropped into a
// window in it: the Pi screws onto the tray on the bench.
//
// PRINTED FLOOR-DOWN, AS IT STANDS, WITH NO SUPPORT:
//   - the floor is the first layers, on the bed
//   - the walls step out from it on a 45-degree chamfer that reaches the outer face,
//     their ribs square bars on it with every face at 45: no ledge, no roof
//   - the walls rise straight; port and vent openings are short bridges; the fan
//     bore is an arch in the front wall, its crown a bridge that shortens to nothing
//   - the filter's recess is an arch too, 4mm deep off the web behind it
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
// The front wall is solid front_wall_t deep for the filter's recess and the fan, up to
// front_top, short of the next module's floor; above that only its outer `wall` rises,
// into the lap, like the other three.
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
        frontTopCut();
      }
      bothYWalls() islandBulge();
    }
    bothYWalls() islandPocket();
  }
}

// The front wall's inner part: level at front_top over the filter's recess, then
// falling to the fan's top on the inside face (config.scad). Profile x into the wall,
// y up; inside the walls only, so the corners keep their round.
module frontTopCut() {
  intersection() {
    translate([0, 0, floor_t]) linear_extrude(module_pitch) inset(wall);
    onYWall(module_w) linear_extrude(module_w)
      polygon([[0, front_top], [front_fall_x, front_top], [front_wall_t, front_foot],
               [front_wall_t + EPS, front_foot], [front_wall_t + EPS, module_pitch + 1],
               [0, module_pitch + 1]]);
  }
}

// ----------------------------------------------------------------------------
// THE PORT ISLAND — the -Y wall stepped in round the USB-C and micro-HDMIs, and the
// +Y wall the same, mirrored, uncut
// ----------------------------------------------------------------------------
// The island's face, seen from outside: x along the wall, z up, grown by g on every
// side, its corners with it -- so hull() between two is a 45-degree step all round.
module islandFace(g) {
  translate([island_x[0] + island_r, island_z[0] + island_r])
    offset(r = island_r + g)
      square([island_x[1] - island_x[0] - 2 * island_r, island_z[1] - island_z[0] - 2 * island_r]);
}

// The -Y wall's geometry, and its mirror on +Y.
module bothYWalls() {
  children();
  translate([0, module_w, 0]) mirror([0, 1, 0]) children();
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
// POSTS — the board's four feet
// ----------------------------------------------------------------------------

// Where the feet stand, d across: the feet themselves at post_d, their chamfered
// roots at post_d + 2 * post_chamfer.
module postFootprint(d = post_d) {
  translate([board_x, board_y])
    for (h = pi5MountingHoles()) translate([h[0], h[1]]) circle(d = d, $fn = 48);
}

// From the floor to the board's underside, flaring on the chamfer at the root. Clipped
// to the inside: with the walls this close to the board, a foot would otherwise stand
// into a wall.
module posts() {
  intersection() {
    union() {
      translate([0, 0, floor_t - OVERLAP])
        linear_extrude(board_z - floor_t + OVERLAP) postFootprint();
      translate([board_x, board_y, floor_t - OVERLAP])
        for (h = pi5MountingHoles())
          translate([h[0], h[1]])
            cylinder(d1 = post_d + 2 * (post_chamfer + OVERLAP), d2 = post_d,
                     h = post_chamfer + OVERLAP, $fn = 48);
    }
    linear_extrude(board_z + 1) inset(wall);
  }
}

// The pilot holes, down from the board's underside: the screw cuts its own thread.
module pilotHoles() {
  onBoard()
    for (h = pi5MountingHoles())
      translate([h[0], h[1], -pilot_depth]) cylinder(d = pilot_d, h = pilot_depth + EPS, $fn = 30);
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

// The port cluster, and the PCB-edge slot under it -- both rear_hole_rise taller, as
// their holes are (allPortCuts()).
module exclusionZone() {
  hull() for (dz = [0, rear_hole_rise])
    translate(exclusionCentre() + [0, dz])
      offset(r = exclusion_r, $fn = 30)
        square([exclusion_w - 2 * exclusion_r, exclusion_h - 2 * exclusion_r], center = true);
  if (pcb_slot_depth > 0)
    translate([board_y - pcb_slot_clear - exclusion_pad,
               board_z - pcb_slot_clear - exclusion_pad])
      square([pi5_pcb[1] + 2 * (pcb_slot_clear + exclusion_pad),
              pcb_slot_h + 2 * exclusion_pad + rear_hole_rise]);
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
   exclusionCentre()[1] + exclusion_h / 2 + rear_hole_rise];

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
// Clear of the tray's seam and its clips' springs, a band from the window's edge in
// past the slots: a lattice across them would leave edges in slivers. The tray's
// middle and the floor round it are cut alike.
module floorVentProfile() {
  m = wall + lap_z0 + vent_margin;
  x0 = front_wall_t + vent_margin;
  if (floor_vents)
    difference() {
      translate([x0, m]) ventField(module_l - m - x0, module_w - 2 * m);
      difference() {
        trayOutline(tray_r + tray_gap * sqrt(2) + vent_margin);
        trayOutline(tray_r - tray_strip - tray_slit - vent_margin);
      }
      offset(delta = vent_margin) postFootprint(post_d + 2 * post_chamfer);
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
// The bore, through the whole front wall, less a boss round each screw; and the fan's
// four screw holes: hexrack's screw_hole_mask "front" -- countersink and pass-through --
// cut fan_screw_sink under the recess floor, a counterbore over it, so the screws go
// in from outside and their heads sit below the ring. Rotated so the mask's -Z runs
// +X, into the wall.
module fanCut() {
  onFrontWall(-EPS) linear_extrude(front_wall_t + 2 * EPS)
    difference() {
      circle(d = fan_bore_d, $fn = 96);
      for (sy = [-1, 1], sz = [-1, 1])
        translate([sy * fan_bolt_pitch / 2, sz * fan_bolt_pitch / 2]) circle(r = fan_boss_r, $fn = 48);
    }
  for (sy = [-1, 1], sz = [-1, 1])
    translate([filter_depth, fan_yc + sy * fan_bolt_pitch / 2, fan_zc + sz * fan_bolt_pitch / 2])
      rotate([0, -90, 0]) {
        translate([0, 0, -fan_screw_sink]) screw_hole_mask(fan_screw, "front");
        translate([0, 0, -fan_screw_sink - EPS])
          cylinder(d = fan_csink_d, h = fan_screw_sink + 2 * EPS, $fn = 48);
      }
}

// ----------------------------------------------------------------------------
// THE MODULE, WHOLE -- what the module and its tray are both cut from
// ----------------------------------------------------------------------------
// render() is NOT optional: preview does not evaluate booleans, and a body cut by
// ports, four vent fields, a bore, a recess and eight clip features blows past OpenSCAD's normalisation
// limit -- blank window, perfect export.
module moduleWhole() {
  render()
    difference() {
      union() {
        moduleBody();
        posts();
        lapRibs();
      }
      pilotHoles();
      bevelGrooves();
      allPortCuts();
      ventCuts();
      fanCut();
      filterRecess();
      filterGrooves();
    }
}

// ----------------------------------------------------------------------------
// THE TRAY AND ITS WINDOW
// ----------------------------------------------------------------------------
// The feet's axes, module frame: the corners the tray's outline is drawn round.
function feetBox() =
  let (h = pi5MountingHoles(), xs = [for (p = h) p[0]], ys = [for (p = h) p[1]])
  [[board_x + min(xs), board_y + min(ys)], [board_x + max(xs), board_y + max(ys)]];

// The tray's outline r from the feet's axes, corners round each foot.
module trayOutline(r) {
  b = feetBox();
  translate(b[0]) offset(r = r, $fn = 96) square(b[1] - b[0]);
}

// The tray's thickness, its edges at 45 all round, narrowest on the bed, grown g along
// their normal; and the feet on it. ONLY the feet over the floor: anything wider would
// hand the tray whatever of the module stood over it.
module trayRegion(g) {
  h = g * sqrt(2);
  hull() {
    waferAt(-1) trayOutline(tray_r - floor_t - 1 + h);
    waferAt(floor_t) trayOutline(tray_r + h);
  }
  translate([0, 0, floor_t - EPS])
    linear_extrude(board_z - floor_t + 1) postFootprint(post_d + 2 * (post_chamfer + OVERLAP));
}

// THE TRAY CLIPS: the lap's half '>', one a side, on the tray's chamfer, its centre on
// the chamfer's foot -- the same row as lapJoints().
function trayJoints() =
  let (b = feetBox(), e = tray_r - floor_t, xm = (b[0][0] + b[1][0]) / 2, ym = (b[0][1] + b[1][1]) / 2)
  [ ["tray-left",  [xm, b[0][1] - e, 0], "x", clip_rib_len, [0, -1, 0]],
    ["tray-right", [xm, b[1][1] + e, 0], "x", clip_rib_len, [0,  1, 0]],
    ["tray-front", [b[0][0] - e, ym, 0], "y", clip_rib_len, [-1, 0, 0]],
    ["tray-rear",  [b[1][0] + e, ym, 0], "y", clip_rib_len, [ 1, 0, 0]] ];

// THE CLIPS' SPRINGS: a slot behind each, tray_strip in from the tray's edge, running
// between the two feet on that side.
module traySlits() {
  b = feetBox();
  run = post_d / 2 + post_chamfer + tray_slit_end;   // from a foot's axis to a slot's end
  off = tray_r - tray_strip - tray_slit;             // from the axes' line to the slot
  translate([0, 0, -1]) linear_extrude(floor_t + 2) {
    for (y = [b[0][1] - off - tray_slit, b[1][1] + off])
      translate([b[0][0] + run, y]) square([b[1][0] - b[0][0] - 2 * run, tray_slit]);
    for (x = [b[0][0] - off - tray_slit, b[1][0] + off])
      translate([x, b[0][1] + run]) square([tray_slit, b[1][1] - b[0][1] - 2 * run]);
  }
}

// ----------------------------------------------------------------------------
// THE PARTS
// ----------------------------------------------------------------------------
// The module: the whole, less the window, the tray's feet and the clips' grooves.
module modulePart() {
  render()
    difference() {
      moduleWhole();
      trayRegion(tray_gap);
      for (j = trayJoints()) clipGroove(j);
    }
}

// The tray, uncut: its chamfers stand EPS proud of the whole's -- a rib whose side
// lies exactly on one is tangent to it, and exports as a loose prism.
module trayBlank() { intersection() { moduleWhole(); trayRegion(EPS); } }

// ribs = false is its BODY, what bears on the window and what has to go down past
// the module.
module trayPart(ribs = true) {
  render()
    difference() {
      union() {
        trayBlank();
        if (ribs) for (j = trayJoints()) clipRib(j);
      }
      traySlits();
    }
}

modulePart();
