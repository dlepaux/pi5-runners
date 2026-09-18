// ============================================================================
// PI5-RUNNERS — CONFIGURATION
// ============================================================================
// Single source of truth for every dimension. Never hardcode in part files.
// Mirrors naja-miner/cad/config.scad, which mirrors lab-router's.
//
// THE CASE IS A STACK OF MODULES, ONE PI 5 AND ONE FAN EACH. Every module is the same
// printed part: a vented floor the Pi screws to, four walls, the fan on the inside of
// the front one. Its bottom is a SPIGOT that drops into the module below and clips
// there; a LID closes the top one. The boards are never connected to each other.
// The FILTER PANEL is the whole front face: it slides down over dovetails on the
// modules' front faces, fabric glued behind a window per fan.
//
// FRAMES. The MODULE frame: x=0 the front face, y=0 the -Y outer face, z=0 the bottom
// of the spigot, which is the print bed. The STACK frame is module 0's; module k sits
// at z = k * module_pitch. The filter panel lives at x < 0.
// ============================================================================

// Both spec tables, INCLUDED not used: `use` imports modules and functions but not
// variables, and the fastener block below reads their constants. Neither includes
// config.scad, so there is no cycle. OpenSCAD does not hoist either, which is why
// these are at the top rather than beside the block that reads them.
include <lib/screws.scad>
include <lib/theaded-inserts.scad>

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

// The Active Cooler's top, above the PCB's TOP face. Derived from the framework's
// rpi5_oem model, NOT measured on real hardware. It sets the Compact's custom standoff and
// therefore every module's height, so it is the first thing to re-measure if parts fight.
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
// the module has to carry it, so its open front clears the tab rather than the
// board's edge. Confirm against the real part -- the brief's drawing does not resolve
// the tab's position, and this claims the worst case.
hat_compact_overhang_x = hat_compact_size[0] - hat_compact_header_w;   // 6.5

// The HAT's hole pattern IS the Pi's -- 58 x 49 at 3.5 -- which is what lets it stack
// straight up. Read pi5_hole_* rather than retyping 58/49/3.5: two features doing
// their own arithmetic on one datum will eventually disagree.
//
// In Y that makes the HAT 0.5mm DEEPER than the board it sits on: holes 3.5 from its
// near edge and 4.0 from its far one, so a 56.5 HAT over a 56 Pi overhangs the +Y
// edge by 0.5. The module must not be sized to 56.
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

// The Compact's custom standoff is DERIVED, never typed: its only job is to clear the
// cooler the Compact was not designed to sit over. Landing on the same 16 as the
// standard HAT+ is not a coincidence -- both are set by the same cooler.
compact_standoff_h = hat_stack_h;
assert(compact_standoff_h >= active_cooler_h + 3,
       "the Compact's standoff must clear the Active Cooler by at least 3mm");

// Slot k's board. Every module is the same part, so the slot only says what the
// preview puts in it -- and which envelope the fit tests check against the module.
slot_kind = ["standard", "compact", "bare"];   // bottom to top
function slot_h(k) = slot_kind[k] == "bare" ? bare_slot_h : hat_slot_h;

// ----------------------------------------------------------------------------
// FANS — one 40mm Noctua per module, 10 or 20mm deep
// ----------------------------------------------------------------------------
// ONE FAN PER PI. Each module carries its own fan on the inside of its front wall,
// powered from its own Pi's GPIO 5V -- pins 2 or 4, ground on 6 -- so a module is a
// complete unit: board, storage, cooler, airflow. Three fans against the two a shared
// column had is +50% airflow.
//
// fan_model is the one mode switch. The fan sits between the front wall and the
// board, so it sets the MODULE's length -- and the lid's, which is the module's
// footprint. Switching fans means reprinting modules and lid; the filter panel is the
// same part either way. generate-stl.sh writes both.
//
// Depth is MEASURED off Noctua's STEP, never the datasheet's 10 or 20: the frames'
// anti-vibration pads stand proud of each face and the hub label stands proud of
// that. The hub diameter comes off the same label. Airflow, pressure and noise are
// the 5V datasheets'.
//
// NF-A4x10 5V: 8.2 m3/h -- NOT 4.85, which is its CFM figure read as m3/h and once
// wrongly ruled these fans out. 3-pin, no USB adaptor.
// NF-A4x20 5V: +15% airflow, +27% static pressure -- the number that counts behind a
// filter. Worth a couple of kelvin, not a different class of cooling.
//
//   name,        depth, hub, asset,                          extent (native, axis Y),  m3/h, mmH2O, dB(A)
fan_models = [
  ["NF-A4x10", 12.0, 16, "assets/noctua/NF-A4x10.stl", [40.0, 12.0, 40.0], 8.2, 1.78, 17.9],
  ["NF-A4x20", 21.1, 20, "assets/noctua/NF-A4x20.stl", [40.0, 21.1, 40.0], 9.4, 2.26, 14.9],
];
fan_model = "NF-A4x10";

fan_row = [for (r = fan_models) if (r[0] == fan_model) r][0];
assert(!is_undef(fan_row), str("unknown fan_model: ", fan_model));

fan_depth        = fan_row[1];
fan_hub_d        = fan_row[2];
fan_asset        = fan_row[3];   // relative to cad/: import() resolves against the MAIN document
fan_asset_extent = fan_row[4];
fan_asset_tol    = 0.6;

fan_size       = 40;
fan_bolt_pitch = 32;
fan_clear      = 0.5;    // fan frame to the floor below it and the floor above it

// A ROUND BORE, NOT A SQUARE OPENING: a square as big as the fan removes the wall
// exactly where its corner screws go. 38 leaves every corner solid.
fan_bore_d  = 38;
fan_pilot_d = 2.5;   // the fan screws in from INSIDE, self-tapping into the front wall

fan_throat_area = PI * pow(fan_bore_d, 2) / 4 - PI * pow(fan_hub_d, 2) / 4;   // per fan

// ----------------------------------------------------------------------------
// STACKING — the spigot, the socket, the lap between them
// ----------------------------------------------------------------------------
// A module's bottom band is a SPIGOT: a ring inset from its outer faces that drops
// inside the walls of the module below. The walls then meet on a 45-degree LAP: the
// lower wall's top is bevelled on the inside down to a flat land, and the upper
// wall's underside follows that bevel at stack_gap. Outer faces stay flush, the land
// carries the weight, and the lap centres each module on the one below. All four
// sides: the front is a wall now, with the fan behind it.
//
// WHY A BEVEL AND NOT A STEP. The module prints floor-down, so the upper wall starts
// at the top of the spigot, 3mm outboard of it. As a step that is a 3mm ledge printed
// over air all the way round; as a 45-degree lap it prints like any other wall, and
// only the land -- stack_land + a little -- is left bridging.
stack_gap  = 0.2;     // spigot to socket, all round
spigot_t   = 2;       // the spigot ring's own thickness
spigot_h   = 8;       // how far a module drops into the one below
stack_land = 1;       // the flat top of each wall that bears the module above

// Inset of the upper module's outer face just below the land, and where its bevel
// meets the spigot. The bevel is offset from the lower one's by stack_gap along its
// NORMAL, which on a 45-degree face is stack_gap*sqrt(2) along the horizontal.
lap_inset0   = stack_land + stack_gap * sqrt(2);
spigot_inset = wall + stack_gap;
lap_h        = spigot_inset - lap_inset0;   // height of the upper module's bevel

assert(lap_h > 0, "the stacking bevel has no height -- stack_land is too wide");
assert(spigot_h > lap_h + 4, "the spigot has no straight band left for its clip ribs");

// ----------------------------------------------------------------------------
// MODULE — one Pi 5 and its fan, printed floor-down as one piece
// ----------------------------------------------------------------------------
// SIZED FOR THE TALLEST BOARD, so there is ONE module part and any board goes in any
// slot. A bare Pi wastes 11mm of height; three different modules would waste a
// reprint every time a board changes role.
floor_t       = 2.4;   // the vented floor: 12 layers at 0.2
rail_h        = 5.5;   // the insert rails ("canoes") the Pi sits on, above the floor
plenum_gap    = 3;     // fan's back face to the Compact HAT's tab
side_clear    = 3;     // board edge to a side wall's inner face
port_overhang = 3;     // RJ45 and USB-A stand proud of the PCB's +X edge
rear_clear    = 3;     // those connectors to the rear wall
module_air    = 5;     // top of the tallest board to the next module's floor, at least

// THE FRONT WALL IS AS THICK AS THE SPIGOT RING IS DEEP. Below the lap, the spigot's
// front band IS the front wall's lower part, so a front wall of spigot_inset +
// spigot_t gives the fan ONE flat face to sit on, from the floor to the next module:
// no step where the spigot ends. Above module_pitch it thins to `wall` -- that is the
// socket the module above drops into.
front_wall_t = spigot_inset + spigot_t;

// The Pi in the module frame: behind the front wall, the fan and the plenum. The
// Compact's tab hangs 6.5 off the PCB's -X edge, toward the fan, so the plenum is
// measured from the tab.
board_x = front_wall_t + fan_depth + plenum_gap + hat_compact_overhang_x;
board_y = wall + side_clear;
board_z = floor_t + rail_h;

module_l = board_x + pi5_pcb[0] + port_overhang + rear_clear + wall;
module_w = board_y + pi5_pcb[1] + hat_overhang_y + side_clear + wall;

// The fan, centred across the module, as low as it can sit WITH EVERY SCREW HOLE IN
// FULL WALL. Below spigot_h the front wall is only the spigot band, 2mm thick, with the
// socket of the module below standing in front of it: a screw long enough to hold
// there pokes out of the band and stops the module dropping into its socket. So the
// lower screw holes clear spigot_h, which is ~3mm higher than the floor alone asks.
fan_yc = module_w / 2;
fan_zc = max(floor_t + fan_clear + fan_size / 2,
             spigot_h + fan_bolt_pitch / 2 + fan_pilot_d / 2 + 0.5);

// Floor to floor: whichever needs more, the tallest board or the fan. It is the fan.
module_pitch = max(board_z + hat_slot_h + module_air, fan_zc + fan_size / 2 + fan_clear);
module_h     = module_pitch + spigot_h;

module_count = 3;
lid_t        = 3;     // the lid's plate, above its spigot
stack_h = module_count * module_pitch + spigot_h + lid_t;   // floor of 0 to lid top

// The module above must drop in without touching this one's board.
assert(module_pitch - (board_z + hat_slot_h) >= 3,
       "less than 3mm between a HAT and the next module's floor");
assert(fan_size + 6 <= module_w - 2 * wall, "the fan is wider than the module's inside");

// THE FAN'S BORE STILL DIPS INTO THE MODULE BELOW. It runs down past spigot_h, where
// this module's front band sits inside the socket of the one below -- so every module
// also cuts the bore of the module ABOVE through its own socket front, one pitch up.
// Lifting the bore clear as well would cost another 2mm a module.
assert(fan_zc - fan_bolt_pitch / 2 - fan_pilot_d / 2 >= spigot_h,
       "a fan screw hole lands in the spigot band, where its screw would block stacking");

// The Pi's connectors must cut through FULL wall, not through the spigot band where
// the wall is inset: the lowest connector starts 1.53 above the PCB underside.
assert(board_z + 1.5 > spigot_h,
       "a connector would land in the inset spigot band instead of the wall");

// ----------------------------------------------------------------------------
// CLIPS — hexrack's 45-degree rib into a groove
// ----------------------------------------------------------------------------
// The same joint as hexrack's dust filter: a square-section rib turned 45 degrees,
// half of it standing proud of one part, dropping into a matching groove in the
// other. Ribs on the SPIGOT's outer faces (every module, and the lid); grooves in the
// SOCKET, the top of every module's walls. None on the front: the fan bores are there.
clip_rib     = 1.7;          // hexrack's dust_clip_length: the rib's square section
clip_clear   = tolerance;    // groove stands this far off the rib all round
clip_rib_len = 18;
clip_z       = 3;            // rib centre, above the spigot bottom

rib_half    = clip_rib * sqrt(2) / 2;                        // proud of the joint plane
groove_half = (clip_rib + sqrt(2) * clip_clear) * sqrt(2) / 2;

assert(rib_half - stack_gap > 0.5, "a spigot rib barely overlaps its own spigot");
assert(clip_z - groove_half >= 0, "the socket groove would run off the spigot's bottom");
assert(clip_z + groove_half < spigot_h - lap_h,
       "the socket groove runs into the bevel above it");
assert(wall - groove_half >= 1.2, "the socket groove leaves under 1.2mm of wall behind it");

// ----------------------------------------------------------------------------
// DOVETAILS — the filter panel slides down over them
// ----------------------------------------------------------------------------
// A male rail near each edge of every module's FRONT face, vertical. The filter panel
// carries the channels and slides down over all three modules at once. The rail's
// bottom is chamfered at 45 degrees: the wall below it is the inset spigot band, so a
// square-ended rail would start over air.
dovetail_d     = 2.5;    // how far the rail stands off the face
dovetail_w     = 6;      // width at the root
dovetail_angle = 20;     // flank angle from the face's normal
dovetail_y     = 6.5;    // rail centre, in from each side face
dovetail_clear = 0.25;   // channel to rail, all round

dovetail_tip_w = dovetail_w + 2 * dovetail_d * tan(dovetail_angle);

// Clear of the fan's bore and of its screw holes.
assert(dovetail_y + dovetail_tip_w / 2 + 2 < fan_yc - fan_bolt_pitch / 2 - fan_pilot_d,
       "the dovetail rail runs into the fan's screw holes");
assert(dovetail_y - dovetail_tip_w / 2 - dovetail_clear >= 2,
       "the panel has under 2mm outside its dovetail channel");

// ----------------------------------------------------------------------------
// FILTER PANEL — the whole front face is the dust filter
// ----------------------------------------------------------------------------
// hexrack's principle at full size: a printed frame with the fabric glued into a
// shallow pocket on its back, one round window in front of each fan. It covers the
// stack from the desk to the lid and slides down over the modules' dovetails.
//
// PRINTED FLAT, face down: the windows are vertical holes, the glue pocket faces up,
// and the dovetail channels are grooves in the top face whose flanks lean 20 degrees
// off vertical -- well inside what prints without support.
panel_gap   = 0.3;    // panel's back to the module fronts
panel_skin  = 2;      // panel in front of the channels' floor
panel_x0    = -(dovetail_d + dovetail_clear + panel_skin);   // its outer face
panel_t     = -panel_x0 - panel_gap;
window_d    = fan_bore_d;   // the bore is the restriction; a bigger window only thins the glue land
filter_glue_d = 0.32;   // hexrack's glue pocket depth

// The fabric's pocket: between the two channels, the panel's full height less a border.
glue_y0 = dovetail_y + dovetail_tip_w / 2 + dovetail_clear + 1.5;
assert(glue_y0 < fan_yc - window_d / 2 - 2, "the glue pocket does not clear the windows");

// ----------------------------------------------------------------------------
// VENTS — hexrack's triangle lattice
// ----------------------------------------------------------------------------
// Cell 14, web 1.6, corner 1.2, stagger 0.5 -- hexrack's, so the projects read as one
// family. A triangle cannot rack, so a 3mm wall stays stiff at a high open fraction.
vent_tri_cell    = 14;
vent_wall        = 1.6;
vent_tri_radius  = 1.2;
vent_tri_stagger = 0.5;
vent_margin      = 3;    // solid border round every field

// EXHAUST: the rear wall and the rear of both side walls. Never the lid: a lid with
// holes drops dust straight onto the top board. Fields stay above the spigot band and
// below the socket's clip grooves.
vent_z0 = spigot_h + vent_margin;
vent_z1 = module_pitch + clip_z - groove_half - vent_margin;

// The -Y connectors, measured off the framework's -Y mask: USB-C and the micro-HDMIs
// span 6.25..42.60 along the board.
side_port_cluster_x = [6.25, 42.60];

// The side fields start behind the -Y connectors -- both sides, so the two walls
// match -- and stop before the rear wall.
side_field_x = [board_x + side_port_cluster_x[1] + vent_margin,
                module_l - wall - vent_margin];
assert(side_field_x[1] - side_field_x[0] > 2 * vent_tri_cell,
       "the side exhaust field is too short to hold the lattice");

// EXCLUSION ZONE, hexrack's idea: the rear port cluster sits in clean solid wall with
// the lattice running round it. Sized from the MEASURED cluster -- the framework's +X
// mask spans Y 2.33..54.50 and Z 1.65..17.90 in the board frame.
exclusion_pad       = 1.5;
exclusion_cluster_y = [2.33, 54.50];
exclusion_cluster_z = [1.65, 17.90];
exclusion_w = exclusion_cluster_y[1] - exclusion_cluster_y[0] + 2 * exclusion_pad;
exclusion_h = exclusion_cluster_z[1] - exclusion_cluster_z[0] + 2 * exclusion_pad;
exclusion_r = 3;

// ----------------------------------------------------------------------------
// FASTENERS — the Pi screws into its own module
// ----------------------------------------------------------------------------
// M2.5 heat-set inserts in two rails on the floor, one under each mounting hole.
// READ FROM lib/theaded-inserts.scad: a Ruthex RX-M2.5x5.7 wants 6.7 of hole, not 5.7.
// The HAT's M2.5 male-female standoffs thread through the Pi into those inserts.
//
// The rails run ALONG X, with the airflow, as hexrack's canoes do.
insert_m25    = "M2.5";
boss_d        = get_insert_min_boss(insert_m25);   // 7.2
canoe_w       = boss_d + 2;
canoe_overrun = 4;

assert(board_z - get_insert_spec(insert_m25, "hole_depth") >= 1,
       "the insert pocket would break through the floor");

// ----------------------------------------------------------------------------
// ASSEMBLY / PREVIEW
// ----------------------------------------------------------------------------
// Open cad/case.scad and set case_part:
//   "assembly" - everything, for looking at
//   "module" | "lid" | "filter" - one printed part
case_part = "assembly";

// Explode distance: modules apart, lid up, filter panel forward. The
// boards travel with their modules -- each is screwed to its own floor.
//
// THE EXPLODE LIVES ONLY IN case.scad. placement.scad never reads it, so no fit test
// can measure an exploded position even by accident.
assembly_space = 30;

show_boards    = true;    // the Pi 5s, from the framework (cooler included)
show_hats      = true;    // both M.2 HAT+ boards and their drives
show_standoffs = true;    // the HATs' M2.5 standoffs
show_fan       = true;    // one fan mesh per module, of fan_model
show_filter    = true;    // the filter panel
show_case      = true;    // modules and lid

// Bambu A1. Every printed part has to fit.
bed = [256, 256, 256];
