// ============================================================================
// PLACEMENT — where the three boards sit
// ============================================================================
// The stack is self-supporting from the base: board 0 bolts to the base bosses and
// boards 1 and 2 stand on standoffs from the one below. So there is exactly one
// datum chain, computed in config.scad as board_z, and everything here reads it.
//
// Nothing in this file types a z. A feature that does its own arithmetic on the same
// datum will eventually disagree with the one that does not.
// ============================================================================

include <../config.scad>
use <m2-hat-plus.scad>

// ----------------------------------------------------------------------------
// FRAMES
// ----------------------------------------------------------------------------

// TWO FRAMES, AND THE WALL IS THE DIFFERENCE BETWEEN THEM.
//
// board_x/board_y/board_z and interior_* are all measured in the INTERIOR frame, whose
// origin is the inside corner of the floor. shellSolid() is built in the CASE frame,
// whose origin is the outside corner. They differ by `wall` on every axis.
//
// Everything that has to meet the shell goes through interiorOrigin(). Getting this
// wrong is invisible for a long time: a suite that only ever compares interior things
// to each other -- slot against slot, slot against roof -- passes perfectly while the
// whole stack sits 3mm inside the floor.
module interiorOrigin() {
  translate([wall, wall, wall]) children();
}

// Board i's frame: the Pi's PCB underside at z=0, its left-rear corner at [0,0].
// Every board sits at the same x/y -- they are a stack, not a staircase -- so the
// only thing that varies is z.
module onBoard(i) {
  interiorOrigin()
    translate([board_x, board_y, board_z[i]]) children();
}

// ----------------------------------------------------------------------------
// ENVELOPES
// ----------------------------------------------------------------------------

// Everything slot i occupies, as ONE SLAB from the PCB underside to the top of the
// tallest thing on it, in the case's frame.
//
// WHAT THIS IS FOR: "does slot i foul its neighbour, the shell, or the roof". It is a
// deliberate over-estimate -- the space above a bare Pi's cooler is mostly air, and
// the Compact's L-shape leaves the SoC open -- so it is USELESS for anything finer.
// Do not reuse it to test the fan's reach: the fan is entitled to the air this slab
// claims, and asking this envelope that question reports a collision that is not real.
module slotSlab(i) {
  onBoard(i)
    linear_extrude(slot_h(i))
      if (slot_is_hat[i] && i == 1) hatCompactOutline();
      else if (slot_is_hat[i])      hatStandardOutline();
      else                          square([pi5_pcb[0], pi5_pcb[1]]);
}

// Just the bare PCB of board i -- what a neighbouring slot must not touch.
module boardPcb(i) {
  onBoard(i) cube(pi5_pcb);
}

// The roof's inner face, as a plane to test the top slot against.
module roofPlane() {
  interiorOrigin()
    translate([-EPS, -EPS, interior_h])
      cube([interior_x + 2 * EPS, interior_y + 2 * EPS, wall]);
}
