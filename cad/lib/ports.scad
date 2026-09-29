// ============================================================================
// PORTS — connector openings, from the framework's own IO mask
// ============================================================================
// NOT a table of coordinates typed into this project. The framework knows where every
// connector is and can emit the mask itself, so retyping them would be a second source
// of truth for the one part of this case that is unforgiving about a millimetre.
//
// TWO PROBLEMS HAD TO BE SOLVED TO USE IT.
//
// 1. THE MASK DOES NOT REACH THE WALL. Each component's mask is swept only ~7-10mm
//    outward from its connector, and this case's -Y wall has its OUTER face 11mm from
//    the board edge. Subtracting the mask as published cuts 1mm into a 3mm wall and
//    leaves 2mm of solid PETG in front of every USB-C and micro-HDMI port. It renders,
//    it exports, it looks right in preview, and the ports are blind. So the mask is
//    swept further along the wall's own normal before it is used.
//
// 2. SWEEPING DRAGS THE OTHER WALLS' CONNECTORS WITH IT. The mask is one object
//    containing every side connector, so sweeping it toward -Y also drags the RJ45 and
//    the USB stacks toward -Y.
//
//    THIS FILE USED TO CLAIM THAT INTERSECTING WITH THE WALL FIXED THAT. IT DID NOT.
//    Intersecting with the -Y wall only confines the sweep to the wall's THICKNESS; the
//    wall spans the case's whole length, so a dragged RJ45 still lands in it -- at its
//    own x, which is the rear end of the -Y wall. Three spurious notches, one per board,
//    cut into the corner of the side wall. Every check passed, because every check
//    asked whether ports were BLOCKED and none asked whether there were holes that
//    should not exist. A render found it.
//
//    So each wall now sweeps ONLY ITS OWN connectors -- maskBeyond() isolates them by
//    which way they stick out -- and the dragged ones never exist.
//
// The heatsink and GPIO masks are disabled: they are top-facing, 40mm tall, and belong
// to a case with an opening over the cooler. Leaving them in takes the mask from 7
// bodies to 49 and reaches 41mm up.
// ============================================================================

include <../config.scad>
include <sbc-helpers.scad>
use <placement.scad>

port_sweep_step = 5;    // < the mask's own ~7mm reach, so copies overlap
port_sweep_dist = 25;   // comfortably past the wall's outer face

// The side connectors only.
module ioMaskSides() {
  sbc(model = "rpi5", enableheatsink = "disable", enablegpio = "disable",
      enablemask = true);
}

// One wall's connectors, smeared along that wall's normal so they certainly pass
// through it. maskBeyond() is defined below with the probes; OpenSCAD resolves module
// names across the file, so the order does not matter here.
//
// It starts a wall's thickness INWARD too. The rear jacks sit in the wall, and the
// mask only begins 0.1-0.3mm past the PCB edge, 0.9mm behind the wall's inner face --
// swept outward only, it left a lip there that the RJ45 ran into.
module ioMaskSwept(which) {
  dir = which == "-Y" ? [0, -1, 0] : [1, 0, 0];
  for (d = [-wall : port_sweep_step : port_sweep_dist])
    translate(dir * d) maskBeyond(which);
}

// The volume of one wall of a module, in the module frame. Grown on the in-plane
// edges so an opening that reaches a corner still cuts cleanly.
module wallSlab(which) {
  g = 2 * EPS;
  if (which == "-Y")
    translate([-g, -EPS, -g]) cube([module_l + 2 * g, wall + 2 * EPS, module_h + 2 * g]);
  else if (which == "+Y")
    translate([-g, module_w - wall - EPS, -g]) cube([module_l + 2 * g, wall + 2 * EPS, module_h + 2 * g]);
  else if (which == "+X")
    translate([module_l - wall - EPS, -g, -g]) cube([wall + 2 * EPS, module_w + 2 * g, module_h + 2 * g]);
}

// Where one wall's openings are cut: the wall, and on -Y the port island's bulge
// inside it -- the connectors' openings must go through the whole stepped-in panel.
module portSlab(which) {
  if (which == "-Y")
    translate([-2 * EPS, -EPS, -2 * EPS]) cube([module_l + 4 * EPS, island_inner + 2 * EPS, module_h + 4 * EPS]);
  else wallSlab(which);
}

// Everything to subtract from one wall for the module's one board.
module portCuts(which) {
  intersection() {
    onBoard() ioMaskSwept(which);
    portSlab(which);
  }
}

// The slot the PCB's +X edge runs into, board frame. Its roof rises at 45 degrees
// toward the room, so printed floor-down it is a slope, not a ceiling over air.
// Only when the edge actually reaches the wall -- a recessed rear_port_proud may not.
module pcbEdgeSlot() {
  c = pcb_slot_clear;
  if (pcb_slot_depth > 0)
    translate([0, pi5_pcb[1] + c, 0])
      rotate([90, 0, 0])
        linear_extrude(pi5_pcb[1] + 2 * c)
          polygon([[pcb_slot_x0 - EPS, -c],
                   [pi5_pcb[0] + c,   -c],
                   [pi5_pcb[0] + c,   pi5_pcb[2] + c],
                   [pcb_slot_x0 - EPS, pi5_pcb[2] + c + pcb_slot_depth + EPS]]);
}

module allPortCuts() {
  portCuts("-Y");
  portCuts("+X");
  onBoard() pcbEdgeSlot();
}

// ----------------------------------------------------------------------------
// PROBES — an INDEPENDENT check that each port is open
// ----------------------------------------------------------------------------
// The obvious test -- intersect the finished panel with the mask and require nothing
// left -- is CIRCULAR. The panel was cut with that mask, so the intersection is empty
// whatever the sweep distance, including zero. It passed on a wall with 2mm of solid
// PETG in front of every USB-C port.
//
// A probe has to be derived differently from the cut. These take the mask's SILHOUETTE
// along the wall's normal and extrude it from the board edge right out past the case.
// If the cut did not reach all the way through, the probe finds the material that is
// left, because the probe's length owes nothing to port_sweep_dist.
//
// Isolated per wall by which way the connector sticks out: the -Y connectors are the
// part of the mask below the board's y=0 edge, the +X ones the part beyond x=85.
// Projecting the whole mask would put a USB-A silhouette on the -Y wall, where there
// is correctly no hole, and report it as a blocked port.

probe_reach = 60;

module maskBeyond(which) {
  big = 400;
  intersection() {
    ioMaskSides();
    if (which == "-Y") translate([-big/2, -big, -big/2]) cube([big, big, big]);
    else               translate([pi5_pcb[0], -big/2, -big/2]) cube([big, big, big]);
  }
}

// The Pi's REAR EDGE ITSELF, not its mask, board frame: everything from 1mm short of
// the rear wall's inner face outward -- the PCB's end in its slot, the RJ45 and both
// USB-A stacks in their holes. slotSlab() stops at that face; this is the finer
// question it cannot answer. Framework CSG, no import, so a clearance test against it
// cannot collapse to a false empty.
module rearEdge() {
  big = 400;
  intersection() {
    sbc(model = "rpi5", enableheatsink = "disable", enablegpio = "disable",
        enablemask = false);
    translate([pcb_slot_x0 - 1, -big/2, -big/2]) cube([big, big, big]);
  }
}

// The Pi's -Y CONNECTORS THEMSELVES, not their mask, board frame: everything past the
// PCB's -Y edge -- USB-C and both micro-HDMIs. The port island stands island_gap off
// their faces; this is what a clearance test holds it to. Framework CSG, no import.
module sideEdge() {
  big = 400;
  intersection() {
    sbc(model = "rpi5", enableheatsink = "disable", enablegpio = "disable",
        enablemask = false);
    translate([-big/2, -big, -big/2]) cube([big, big, big]);
  }
}

// rotate([-90,0,0]) maps -Y onto +Z, so projection() -- which only ever flattens along
// Z -- sees the silhouette along the wall's normal. The result is extruded and turned
// back. Get the sign wrong and the probe lands behind the board, renders nothing, and
// passes.
module portProbe(which) {
  if (which == "-Y")
    rotate([90, 0, 0])
      linear_extrude(probe_reach)
        projection(cut = false)
          rotate([-90, 0, 0])
            maskBeyond("-Y");
  else
    // TRANSLATED TO THE BOARD'S +X FACE. projection() flattens everything to z=0, which
    // back-rotates to x=0 -- the board's NEAR edge. Without this the probe starts in the
    // middle of the case and drives outward through the interior, so it reports every
    // post and boss in its path as a blocked port and tells you nothing about the wall.
    // The -Y probe needs no such shift only because the board's -Y face IS y=0.
    translate([pi5_pcb[0], 0, 0])
      rotate([0, 90, 0])
        linear_extrude(probe_reach)
          projection(cut = false)
            rotate([0, -90, 0])
              maskBeyond("+X");
}

module allPortProbes() {
  onBoard() { portProbe("-Y"); portProbe("+X"); }
}
