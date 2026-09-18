// ============================================================================
// FILTER PANEL — the whole front face is the dust filter
// ============================================================================
// hexrack's filter principle at full size: a printed frame, fabric glued into a
// shallow pocket on its back, one round window in front of each module's fan. It
// covers the stack from the desk to the top of the lid and slides DOWN over the two
// dovetail rails on every module's front face, so it also ties the stack together.
//
// Positive pressure: the fans draw through this panel and nothing else, so it is the
// only place dust can enter -- the only reason there is exactly one filter.
//
// PRINTED FLAT, face down (panelPrint): the windows are vertical holes, the glue
// pocket faces up, and the dovetail channels are grooves in the top face whose flanks
// lean dovetail_angle off vertical. panelPart() is the panel as it stands on the case.
// ============================================================================

include <../lib/stacking.scad>

// One window per module, on its fan's axis.
module windows() {
  for (k = [0 : module_count - 1])
    translate([panel_x0 - 1, fan_yc, k * module_pitch + fan_zc])
      rotate([0, 90, 0]) cylinder(d = window_d, h = panel_t + 2, $fn = 96);
}

// The channels: each rail's section grown by dovetail_clear, the panel's full height.
module dovetailChannels() {
  bothSides()
    translate([0, 0, -1]) linear_extrude(stack_h + 2) dovetailProfile(dovetail_clear);
}

// The fabric's pocket on the back, between the channels, less a border top and bottom.
module gluePocket() {
  translate([-panel_gap - filter_glue_d, glue_y0, 2])
    cube([filter_glue_d + EPS, module_w - 2 * glue_y0, stack_h - 4]);
}

module panelPart() {
  render()
    difference() {
      translate([panel_x0, 0, 0]) cube([panel_t, module_w, stack_h]);
      windows();
      dovetailChannels();
      gluePocket();
    }
}

// Ry(-90) sends x to z: the outer face lands on the bed, the back faces up.
module panelPrint() {
  translate([stack_h, 0, -panel_x0]) rotate([0, -90, 0]) panelPart();
}

panelPrint();
