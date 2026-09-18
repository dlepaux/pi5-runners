// ============================================================================
// CASE — assembly and per-part entry point
// ============================================================================
//   openscad -D 'case_part="module"' cad/case.scad
//   openscad -D 'assembly_space=30' cad/case.scad          // pull the stack apart
//   openscad -D 'fan_model="NF-A4x20"' cad/case.scad       // the 20mm fans
//
// Every printed part comes out of here IN ITS PRINT ORIENTATION: module floor-down,
// lid plate-down, front face standing, filter face-down.
//
// THIS IS THE ONLY FILE ALLOWED TO TOUCH cad/assets/. The vendor fan mesh enters
// through fanVisualization(), which marks it with % so it is drawn in preview and
// dropped from every render. scripts/test-assets.sh holds that true.
// ============================================================================

include <config.scad>
include <lib/placement.scad>
use <lib/m2-hat-plus.scad>
use <lib/noctua-fan.scad>
use <lib/sbc-helpers.scad>
use <parts/module.scad>
use <parts/lid.scad>
use <parts/front.scad>
use <parts/filter.scad>

case_parts = ["module", "lid", "front", "filter"];

module casePart(name) {
  if (name == "module") modulePart();
  if (name == "lid")    lidPrint();
  if (name == "front")  frontPart();
  if (name == "filter") filterPart();
}

// ----------------------------------------------------------------------------
// EXPLODE — modules apart, lid up, front face forward
// ----------------------------------------------------------------------------
// Each module takes its board with it: the Pi is screwed to its own floor.
function explodeModule(k) = [0, 0, k * assembly_space];
function explodeLid()     = [0, 0, module_count * assembly_space + assembly_space];
function explodeFront()   = [-assembly_space, 0, 0];

// ----------------------------------------------------------------------------
// PREVIEW CONTENT
// ----------------------------------------------------------------------------

// The HAT's M2.5 standoffs, from the Pi's top face to the HAT's underside.
module hatStandoffs() {
  color("Silver")
    for (p = pi5MountingHoles())
      translate([p[0], p[1], pi5_pcb[2]]) cylinder(d = 5, h = hat_stack_h);
}

module slotContents(kind) {
  onBoard() {
    if (show_boards)                       pi5Board();
    if (show_hats && kind != "bare")       hatVisualization(kind == "compact");
    if (show_standoffs && kind != "bare")  hatStandoffs();
  }
}

module frontContents() {
  if (show_front) color("SteelBlue") frontPart();
  if (show_fan)
    translate([-front_d + plate_t + fan_depth / 2, fan_col_yc, fan_col_zc])
      fanVisualization();
  if (show_filter)
    color("DimGray") filterMounted(assembly_space);
}

// ----------------------------------------------------------------------------
// ENTRY
// ----------------------------------------------------------------------------
if (case_part == "assembly") {
  for (k = [0 : module_count - 1])
    translate(explodeModule(k)) moduleAt(k) {
      if (show_case) modulePart();
      slotContents(slot_kind[k]);
    }
  if (show_case) translate(explodeLid()) lidAt() lidPart();
  translate(explodeFront()) frontContents();
} else {
  // One printed part, with no preview geometry anywhere near it.
  assert(len([for (p = case_parts) if (p == case_part) p]) == 1,
         str("unknown case_part: ", case_part));
  casePart(case_part);
}
