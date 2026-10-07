// ============================================================================
// CASE — assembly and per-part entry point
// ============================================================================
//   openscad -D 'case_part="module"' cad/case.scad
//   openscad -D 'assembly_space=30' cad/case.scad          // pull the stack apart
//   openscad -D 'fan_model="NF-A4x20"' cad/case.scad       // the 20mm fans
//   openscad -D 'case_part="module"' -D 'runner=2' cad/case.scad   // srv-runner-2's
//
// fan_model changes the module and the lid; the dust filter is the same either way.
// runner changes only the module's engraved name; the assembly labels them 1..3 up.
//
// Every printed part comes out of here IN ITS PRINT ORIENTATION: module floor-down,
// lid plate-down, dust filter face-down.
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
use <parts/filter.scad>

case_parts = ["module", "tray", "lid", "filter"];

module casePart(name) {
  if (name == "module") modulePart(runner);
  if (name == "tray")   trayPart();
  if (name == "lid")    lidPrint();
  if (name == "filter") filterPart();
}

// ----------------------------------------------------------------------------
// EXPLODE — modules apart, trays up, lid up, filters forward
// ----------------------------------------------------------------------------
// Each module takes its fan with it, each tray its board: that is what is screwed to
// each. A tray rises clear of its module's top, assembly_space over it, slide_travel
// forward -- where it goes in, short of the rear wall -- and every module above makes
// room for it. Less than clear hides it inside its own walls. Closed (0), everything
// sits where it stands.
function trayLift()       = assembly_space > 0 ? module_h + assembly_space : 0;
function explodeModule(k) = [0, 0, k * (assembly_space + trayLift())];
function explodeTray()    = assembly_space > 0 ? [-slide_travel, 0, trayLift()] : [0, 0, 0];
function explodeLid()     = [0, 0, module_count * (assembly_space + trayLift()) + assembly_space];

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

// The fan on the inside of the front wall, pushing toward the rear.
module fanContents() {
  if (show_fan)
    translate([front_wall_t + fan_depth / 2, fan_yc, fan_zc])
      fanVisualization() import(fan_asset, center = true);
}

// ----------------------------------------------------------------------------
// ENTRY
// ----------------------------------------------------------------------------
if (case_part == "assembly") {
  for (k = [0 : module_count - 1])
    translate(explodeModule(k)) moduleAt(k) {
      if (show_case) modulePart(k + 1);
      translate(explodeTray()) {
        if (show_case) color("Orange") trayPart();
        slotContents(slot_kind[k]);
      }
      fanContents();
      if (show_filter) color("DimGray") filterMounted(assembly_space);
    }
  if (show_case) translate(explodeLid()) lidAt() lidPart();
} else {
  // One printed part, with no preview geometry anywhere near it.
  assert(len([for (p = case_parts) if (p == case_part) p]) == 1,
         str("unknown case_part: ", case_part));
  casePart(case_part);
}
