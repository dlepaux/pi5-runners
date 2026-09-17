// ============================================================================
// PI5-RUNNERS — CONFIGURATION
// ============================================================================
// Single source of truth for every dimension. Never hardcode in part files.
// Mirrors naja-miner/cad/config.scad, which mirrors lab-router's.
// ============================================================================

EPS       = 0.01;     // CSG safety
OVERLAP   = 0.1;
tolerance = 0.4;      // general print fit
$fn       = 64;
wall      = 3;

// ----------------------------------------------------------------------------
// RASPBERRY PI 5
// ----------------------------------------------------------------------------
// Mirrors SBC_Model_Framework's rpi5 entry in sbc_models.cfg. The submodule can be
// updated under us; scripts/test-board-assets.sh is what notices if these drift.
pi5_pcb          = [85, 56, 1.65];
pi5_hole_pattern = [58, 49];
pi5_hole_inset   = 3.5;
pi5_hole_d       = 2.7;

// The Active Cooler's top, above the PCB's TOP face. Derived from the framework's
// rpi5_oem model, NOT measured on real hardware. It sets slot 2's custom standoff and
// therefore the whole stack, so it is the first thing to re-measure if parts fight.
active_cooler_h  = 11.0;

// ----------------------------------------------------------------------------
// M.2 HAT+ — both variants
// ----------------------------------------------------------------------------
// From the official product brief RP-009234-MM, NOT from SBC_Model_Framework, which
// has no HAT geometry at all (grep it -- there is none).
hat_pcb_t            = 1.6;
hat_standard_size    = [65, 56.5];
hat_compact_size     = [71.5, 56.5];
hat_compact_header_w = 65;          // the Compact is 65 across its header edge

// The Compact is 6.5 WIDER than the standard and the difference is a tab on the -X
// side, hanging off the Pi's x=0 edge where the PCIe ribbon lands. It is not free:
// interior_x has to carry it, so the -X wall clears slot 2's overhang rather than the
// board's edge. Confirm against the real part -- the brief's drawing does not resolve
// the tab's position, and this claims the worst case.
hat_compact_overhang_x = hat_compact_size[0] - hat_compact_header_w;   // 6.5

// The HAT's hole pattern IS the Pi's -- 58 x 49 at 3.5 -- which is what lets it stack
// straight up. Read pi5_hole_* rather than retyping 58/49/3.5: two features doing
// their own arithmetic on one datum will eventually disagree.
//
// In Y that makes the HAT 0.5mm DEEPER than the board it sits on: holes 3.5 from its
// near edge and 4.0 from its far one, so a 56.5 HAT over a 56 Pi overhangs the +Y
// edge by 0.5. The fan plenum absorbs it, but the shell must not be sized to 56.
hat_overhang_y       = hat_standard_size[1] - pi5_pcb[1];   // 0.5

// The supplied stacking header. THIS is the number that clears the Active Cooler, and
// it is the whole reason the standard HAT+ works over the cooler and the Compact does
// not: Raspberry Pi ship the standard one with a 16mm header and say outright that the
// Compact cannot take the cooler beneath it.
hat_stack_h          = 16;

drive_t              = 2.3;   // M.2 single-sided module
screw_head           = 2;     // supplied knurled double-flanged retaining screw

// Slot occupied height, measured from the board's PCB UNDERSIDE.
hat_slot_h  = pi5_pcb[2] + hat_stack_h + hat_pcb_t + drive_t + screw_head;  // 23.55
bare_slot_h = pi5_pcb[2] + active_cooler_h;                                 // 12.65

// Slot 2's custom standoff is DERIVED, never typed: its only job is to clear the
// cooler the Compact was not designed to sit over. Landing on the same 16 as the
// standard HAT+ is not a coincidence -- both are set by the same cooler.
compact_standoff_h = hat_stack_h;
assert(compact_standoff_h >= active_cooler_h + 3,
       "slot 2 standoff must clear the Active Cooler by at least 3mm");

// ----------------------------------------------------------------------------
// THE STACK — derived, never typed. Changing a standoff moves everything.
// ----------------------------------------------------------------------------
// Slot 0 carries the standard M.2 HAT+, slot 1 the Compact, slot 2 a bare Pi.
slot_is_hat   = [true, true, false];

base_standoff = 10;         // microSD clearance, keeps the fan's sweep off the floor,
                            // and leaves the cable comb somewhere to live
slot_standoff = [30, 30];   // PCB top -> next PCB underside, slots 0->1 and 1->2
                            // 20+10 from stock M2.5 standoffs
roof_air      = 8;

// Occupied height of slot i, from its own PCB underside.
function slot_h(i) = slot_is_hat[i] ? hat_slot_h : bare_slot_h;

board_z = [
  base_standoff,
  base_standoff + pi5_pcb[2] + slot_standoff[0],
  base_standoff + pi5_pcb[2] + slot_standoff[0] + pi5_pcb[2] + slot_standoff[1],
];

stack_top  = board_z[2] + slot_h(2);    // 85.95
interior_h = stack_top + roof_air;      // 93.95

// Both HAT slots need real air above the drive or the fan has no channel to push
// through. 8.1mm at the declared standoffs; 4 is the floor below which the slot is a
// fin gap rather than a duct.
assert(slot_standoff[0] >= slot_h(0) - pi5_pcb[2] + 4,
       "slot 0 standoff leaves no air channel above the drive");
assert(slot_standoff[1] >= slot_h(1) - pi5_pcb[2] + 4,
       "slot 1 standoff leaves no air channel above the drive");

// ----------------------------------------------------------------------------
// FAN — Noctua NF-A8 5V PWM
// ----------------------------------------------------------------------------
// 55.5 m3/h, 17.7 dB(A), 2.37 mmH2O, 0.75W at 5V, with a USB power adaptor cable in
// the box -- so it feeds from a USB port inside the case, no GPIO wiring and no PSU.
//
// THE 80mm IS WHY THIS CASE HAS NO PLENUM. At 80 it spans the whole board stack and
// presents a fresh-air front to all three slots at once. A 40mm fan needed a side
// plenum and ~40mm of extra width to approximate that. The assert below is what keeps
// that true: a slot that grows fails here instead of quietly leaving the top board
// out of the airstream.
fan_size       = 80;
fan_bolt_pitch = 71.5;   // standard 80mm pattern. NOT the Compact HAT's 71.5 width --
                         // they are the same number for unrelated reasons.
fan_hub_d      = 30;

// 25.4, NOT the datasheet's 25. Measured off Noctua's own STEP: the AAO frame's
// integrated anti-vibration pads stand 0.2 proud of each mounting face. A 25mm pocket
// makes the fan sit on its pads instead of on the wall, or bows the wall. Model the
// part, not a box around it.
fan_depth          = 25.4;
fan_depth_nominal  = 25;

// The committed mesh. It is in its NATIVE orientation -- axis along Z -- and
// lib/noctua-fan.scad rotates it into this project's -Y convention at import, which
// is one line rather than a mesh-rewriting step in the generator.
//
// THE PATH IS RELATIVE TO cad/, NOT TO THE LIB THAT IMPORTS IT. import() resolves
// against the MAIN document while include/use resolve against the calling file, so
// "../assets/..." written from lib/'s point of view looks for <repo>/assets when
// tests.scad is the document -- which is how this landed the first time. Only
// cad/case.scad and cad/tests.scad ever import it and both live in cad/.
fan_asset        = "assets/noctua/NF-A8.stl";
fan_asset_extent = [80.1, 80.0, 25.4];   // native X, Y, Z as generated
fan_asset_tol    = 0.6;                  // tessellation slack; the mesh is not nominal

fan_throat_area = PI * pow(fan_size, 2) / 4 - PI * pow(fan_hub_d, 2) / 4;   // ~4320

fan_z0 = (interior_h - fan_size) / 2;
assert(fan_z0 <= board_z[0],
       "fan does not reach the bottom board -- the stack has outgrown an 80mm fan");
assert(fan_z0 + fan_size >= stack_top,
       "fan does not reach the top of the stack -- slot 2 is out of the airstream");

// ----------------------------------------------------------------------------
// ENVELOPE
// ----------------------------------------------------------------------------
side_clear    = 2;     // board edge (or its overhang) to the inner wall face
port_overhang = 3;     // RJ45 and the USB-A stacks stand proud of the PCB's +X edge
fan_plenum    = 8;     // fan's inner face to the HAT's +Y edge
exhaust_gap   = 8;     // board's -Y edge to the -Y wall

// X: the -X wall clears slot 1's Compact tab, NOT the board edge. The tab hangs
// 6.5 off the PCB and the wall has to be behind it, which is 6.5mm of case that the
// standard HAT+ alone would not have cost.
board_x    = hat_compact_overhang_x + side_clear;
interior_x = board_x + pi5_pcb[0] + port_overhang + side_clear;

// Y: exhaust gap, board, the HAT's 0.5 overhang past the Pi's +Y edge, plenum, fan.
board_y    = exhaust_gap;
interior_y = board_y + pi5_pcb[1] + hat_overhang_y + fan_plenum + fan_depth;

outer = [interior_x + 2 * wall, interior_y + 2 * wall, interior_h + 2 * wall];

// ----------------------------------------------------------------------------
// ASSEMBLY / PREVIEW
// ----------------------------------------------------------------------------
// Open cad/case.scad and set case_part. Mirrors hexrack's body_part /
// bodyAssembly_space pair, turned through 90 degrees: hexrack stacks its sections
// along Y, this case stacks along Z.
//
//   "assembly" - everything, for looking at
//   "base" | "shell" | "roof" | "filter" - one printed part
case_part = "assembly";

// Explode distance. 0 means every part sits where it really sits, which is what you
// want for checking a joint and useless for seeing one: at 0 each tenon is swallowed
// by its neighbour's rebate. Push it to 20-40 to pull the case apart along Z.
//
// THE EXPLODE LIVES ONLY IN case.scad. placement.scad never reads assembly_space, so
// no fit test can accidentally measure an exploded position -- the checks are
// structurally incapable of seeing it rather than merely defaulting to 0.
assembly_space = 0;

// Preview geometry. None of it is ever exported: generate-stl.sh renders the parts
// by name, and the showcase marks vendor geometry with %.
show_boards    = true;    // the three Pi 5s, from the framework (cooler included)
show_hats      = true;    // both M.2 HAT+ boards and their drives
show_standoffs = true;    // the M2.5 stacks the boards sit on
show_fan       = true;    // the NF-A8 mesh
show_case      = true;    // the printed parts themselves
