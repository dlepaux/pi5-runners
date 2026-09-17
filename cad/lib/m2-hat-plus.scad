// ============================================================================
// M.2 HAT+ — standard and Compact
// ============================================================================
// SBC_Model_Framework has no HAT geometry at all, so both are built here from the
// official product brief RP-009234-MM.
//
// ORIGIN CONVENTION. Both HATs are drawn in the PI'S frame, with the Pi's PCB
// underside at z=0 and its left-rear corner at [0,0]. The HAT's mounting pattern IS
// the Pi's -- 58 x 49 at 3.5 inset -- which is what lets it stack straight up, so a
// HAT whose holes sit over the Pi's holes has its own x=0 on the Pi's x=0.
//
// The caller therefore only ever positions the Pi.
// ============================================================================

include <../config.scad>

hat_corner_r = 3;

// ----------------------------------------------------------------------------
// OUTLINES (2D)
// ----------------------------------------------------------------------------

// The standard HAT+: a plain 65 x 56.5 rectangle. Its holes land on the Pi's, so it
// spans x 0..65 -- leaving the Pi's port end (x 65..85) uncovered, which is what lets
// the RJ45 and USB stacks stand proud of it.
module hatStandardOutline() {
  translate([hat_corner_r, hat_corner_r])
    offset(r = hat_corner_r)
      square([hat_standard_size[0] - 2 * hat_corner_r,
              hat_standard_size[1] - 2 * hat_corner_r]);
}

// The Compact, as a CONSERVATIVE BOUNDING ENVELOPE, not as its true L-shape.
//
// WHAT THIS ENVELOPE IS FOR: proving the Compact does not foul the shell or the board
// above it. It is deliberately larger than the part -- the real board is L-shaped and
// leaves the area over the SoC open, which is the whole point of the variant -- so it
// must NOT be reused to ask anything finer. An envelope carries the question it was
// built for; ask a different one and you need a different envelope.
//
// The brief gives 65 across the header edge and 71.5 overall, with a tab on the -X
// side. The tab's exact position is not resolvable from the drawing's rendering, so
// the envelope claims the whole 6.5mm difference on -X, which is the direction that
// costs case width. CONFIRM AGAINST THE REAL PART before trusting it to 0.5mm.
module hatCompactOutline() {
  translate([-hat_compact_overhang_x + hat_corner_r, hat_corner_r])
    offset(r = hat_corner_r)
      square([hat_compact_size[0] - 2 * hat_corner_r,
              hat_compact_size[1] - 2 * hat_corner_r]);
}

// ----------------------------------------------------------------------------
// SOLIDS (3D, in the Pi's frame)
// ----------------------------------------------------------------------------

// Everything the HAT assembly occupies above the Pi's PCB: the HAT's own PCB at the
// top of the stacking header, the M.2 module on top of it, and the retaining screw.
// Modelled as one slab of the outline's footprint -- again an over-estimate, and
// again only valid for "does this foul its neighbour".
module hatSolid(outline_module_is_compact = false) {
  z0 = pi5_pcb[2] + hat_stack_h;
  translate([0, 0, z0])
    linear_extrude(hat_pcb_t + drive_t + screw_head)
      if (outline_module_is_compact) hatCompactOutline(); else hatStandardOutline();
}

module hatStandardSolid() { hatSolid(false); }
module hatCompactSolid()  { hatSolid(true); }

// ----------------------------------------------------------------------------
// The Active Cooler, as the envelope the HATs have to clear.
// ----------------------------------------------------------------------------
// Footprint from the framework's rpi5_oem model: 58 x 40, seated on the two heatsink
// holes at the board's 3.5 inset. Swept to its full height, which is the conservative
// direction for a clearance test against anything above it.
module coolerEnvelope() {
  translate([pi5_hole_inset, pi5_hole_inset, pi5_pcb[2]])
    cube([58, 40, active_cooler_h]);
}

// ----------------------------------------------------------------------------
// SHOWCASE
// ----------------------------------------------------------------------------
// The HAT as it looks, not as it claims. hatSolid() is a slab swept to the top of the
// retaining screw -- correct for clearance, wrong for a picture. This is the PCB and
// the drive as separate bodies at their real heights.
module hatVisualization(compact = false) {
  z0 = pi5_pcb[2] + hat_stack_h;
  translate([0, 0, z0]) {
    color("ForestGreen")
      linear_extrude(hat_pcb_t)
        if (compact) hatCompactOutline(); else hatStandardOutline();
    // The M.2 module, lying along the board's long axis on top of the HAT.
    color("DimGray")
      translate([pi5_hole_inset + 8, pi5_pcb[1] / 2 - 11, hat_pcb_t])
        cube([compact ? 30 : 42, 22, drive_t]);
  }
}
