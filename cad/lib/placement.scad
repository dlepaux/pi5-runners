// ============================================================================
// PLACEMENT — where a board sits in its module, and where a module sits in the stack
// ============================================================================
// Every module is the same part with the same board position, so there is one board
// datum -- board_x/y/z in config.scad -- and one stacking datum, module_pitch.
//
// Nothing in this file types a coordinate. A feature that does its own arithmetic on
// the same datum will eventually disagree with the one that does not.
// ============================================================================

include <../config.scad>
use <m2-hat-plus.scad>

// Module k's frame, in the stack frame.
module moduleAt(k) {
  translate([0, 0, k * module_pitch]) children();
}

// The lid sits where a module_count-th module would.
module lidAt() {
  moduleAt(module_count) children();
}

// The board's frame, in its module's frame: PCB underside at z=0, the Pi's left-rear
// corner at [0,0].
module onBoard() {
  translate([board_x, board_y, board_z]) children();
}

// ----------------------------------------------------------------------------
// ENVELOPES — module frame
// ----------------------------------------------------------------------------

// Everything a board of the given kind occupies, as ONE SLAB from the PCB underside
// to the top of the tallest thing on it.
//
// A deliberate over-estimate -- the air over a bare Pi's cooler is mostly empty, and
// the Compact's L-shape leaves the SoC open -- so it answers "does this board touch its
// module" and nothing finer.
module slotSlab(kind) {
  onBoard() {
    // The Pi itself, to the top of its tallest connector or its cooler.
    linear_extrude(max(bare_slot_h, exclusion_cluster_z[1]))
      square([pi5_pcb[0], pi5_pcb[1]]);
    // The HAT, over its own outline, to the top of its drive's retaining screw.
    if (kind != "bare")
      linear_extrude(hat_slot_h)
        if (kind == "compact") hatCompactOutline(); else hatStandardOutline();
  }
}

// Just the bare PCB -- what the rails must reach and not pierce.
module boardPcb() {
  onBoard() cube(pi5_pcb);
}
