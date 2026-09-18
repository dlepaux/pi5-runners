// ============================================================================
// PI5-RUNNERS — CONFIGURATION
// ============================================================================
// Single source of truth for every dimension. Never hardcode in part files.
// Mirrors naja-miner/cad/config.scad, which mirrors lab-router's.
//
// THE CASE IS A STACK OF MODULES, ONE PI 5 EACH. Every module is the same printed
// part: a vented floor the Pi screws to, three walls, an open front. Its bottom is a
// SPIGOT that drops into the module below and clips there; a LID closes the top one.
// The boards are never connected to each other -- each lives in its own module.
// The FRONT FACE is one separate part: it slides down over dovetails on the modules'
// sides, carries the two fans, and holds the dust filter.
//
// FRAMES. The MODULE frame: x=0 the open front edge, y=0 the -Y outer face, z=0 the
// bottom of the spigot, which is the print bed. The STACK frame is module 0's; module
// k sits at z = k * module_pitch. The front face lives at x < 0.
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
// MODULE — one Pi 5, printed floor-down as one piece
// ----------------------------------------------------------------------------
// SIZED FOR THE TALLEST BOARD, so there is ONE module part and any board goes in any
// slot. A bare Pi wastes 11mm of height; three different modules would waste a
// reprint every time a board changes role.
floor_t      = 2.4;   // the vented floor: 12 layers at 0.2
rail_h       = 5.5;   // the insert rails ("canoes") the Pi sits on, above the floor
front_clear  = 2;     // open front edge to the Compact HAT's tab
side_clear   = 3;     // board edge to a side wall's inner face
port_overhang = 3;    // RJ45 and USB-A stand proud of the PCB's +X edge
rear_clear   = 3;     // those connectors to the rear wall
module_air   = 5;     // top of the tallest board to the next module's floor

// The Pi in the module frame. The Compact's tab hangs 6.5 off the PCB's -X edge,
// toward the open front, so the front clearance is measured from the tab.
board_x = front_clear + hat_compact_overhang_x;
board_y = wall + side_clear;
board_z = floor_t + rail_h;

module_l = board_x + pi5_pcb[0] + port_overhang + rear_clear + wall;
module_w = board_y + pi5_pcb[1] + hat_overhang_y + side_clear + wall;

// Floor to floor. The module above sits this much higher.
module_pitch = board_z + hat_slot_h + module_air;

// ----------------------------------------------------------------------------
// STACKING — the spigot, the socket, the lap between them
// ----------------------------------------------------------------------------
// A module's bottom band is a SPIGOT: a ring inset from its outer faces that drops
// inside the walls of the module below. The walls then meet on a 45-degree LAP: the
// lower wall's top is bevelled on the inside down to a flat land, and the upper
// wall's underside follows that bevel at stack_gap. Outer faces stay flush, the land
// carries the weight, and the lap centres each module on the one below.
//
// WHY A BEVEL AND NOT A STEP. The module prints floor-down, so the upper wall starts
// at the top of the spigot, 3mm outboard of it. As a step that is a 3mm ledge printed
// over air all the way round; as a 45-degree lap it prints like any other wall, and
// only the land -- stack_land + a little -- is left bridging.
//
// Three walls only: the front is open, so the spigot is a U and the side walls run
// out to x = 0.
stack_gap  = 0.2;     // spigot to socket, all round
spigot_t   = 2;       // the spigot ring's own thickness
spigot_h   = 8;       // how far a module drops into the one below
stack_land = 1;       // the flat top of each wall that bears the module above

module_h = module_pitch + spigot_h;

module_count = 3;
lid_t        = 3;     // the lid's plate, above its spigot

stack_h = module_count * module_pitch + spigot_h + lid_t;   // floor of 0 to lid top

// Inset of the upper module's outer face just below the land, and where its bevel
// meets the spigot. The bevel is offset from the lower one's by stack_gap along its
// NORMAL, which on a 45-degree face is stack_gap*sqrt(2) along the horizontal.
lap_inset0  = stack_land + stack_gap * sqrt(2);
spigot_inset = wall + stack_gap;
lap_h       = spigot_inset - lap_inset0;   // height of the upper module's bevel

assert(lap_h > 0, "the stacking bevel has no height -- stack_land is too wide");
assert(spigot_h > lap_h + 4, "the spigot has no straight band left for its clip ribs");

// The module above must drop in without touching this one's board: its floor bottom
// sits at module_pitch, and the tallest board's top is below it by module_air.
assert(module_air >= 3, "less than 3mm between a HAT and the next module's floor");

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
// SOCKET, the top of every module's walls. And on the filter's two flat sides.
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
// DOVETAILS — the front face slides down over them
// ----------------------------------------------------------------------------
// A male rail on each side wall's OUTER face, near the front, vertical. Vertical
// because both parts print standing: a dovetail running up the print is a plain prism
// in each, with nothing to bridge. Its bottom is chamfered at 45 degrees -- the wall
// below it is the inset spigot band, so a square-ended rail would start over air.
dovetail_d     = 2.5;    // how far the rail stands off the wall
dovetail_w     = 6;      // width at the root
dovetail_angle = 20;     // flank angle from the wall's normal
dovetail_x     = 6;      // rail centre, back from the open front edge
dovetail_clear = 0.25;   // channel to rail, all round
cheek_gap      = 0.3;    // the front face's cheek to the module's side face
cheek_skin     = 1.8;    // cheek behind the channel's floor

dovetail_tip_w = dovetail_w + 2 * dovetail_d * tan(dovetail_angle);
cheek_t        = dovetail_d + dovetail_clear + cheek_skin;
cheek_end_x    = dovetail_x + dovetail_tip_w / 2 + dovetail_clear + cheek_skin;

// THE CHEEK MUST STOP SHORT OF THE -Y CONNECTORS. Measured off the framework's -Y
// mask: USB-C and the micro-HDMIs start 6.25 along the board.
side_port_cluster_x = [6.25, 42.60];
assert(cheek_end_x + 2 < board_x + side_port_cluster_x[0],
       "the front face's cheek would cover the USB-C port");
assert(dovetail_x - dovetail_tip_w / 2 > 1, "the rail runs off the module's front edge");

// ----------------------------------------------------------------------------
// FANS — two 40mm Noctuas stacked into a 40 x 80 column; 10 or 20mm deep
// ----------------------------------------------------------------------------
// THE ONE MODE SWITCH. The fans live only in the front face, so fan_model changes the
// front face's depth and nothing else: modules, lid and filter are the same part
// either way. Switching fans means reprinting the front face alone.
//
// Depth is MEASURED off Noctua's STEP, never the datasheet's 10 or 20: the frames'
// anti-vibration pads stand proud of each face and the hub label stands proud of
// that. The hub diameter comes off the same label. Airflow, pressure and noise are
// the 5V datasheets'.
//
// NF-A4x10 5V: 8.2 m3/h -- NOT 4.85, which is its CFM figure read as m3/h and once
// wrongly ruled these fans out. 3-pin, no USB adaptor: 5V from a Pi's GPIO header.
// NF-A4x20 5V: +15% airflow, +27% static pressure -- the number that counts behind a
// filter. Worth roughly 2K of case air, not a different class of cooling.
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
fan_count      = 2;
fan_col_h      = fan_size * fan_count;
fan_bolt_pitch = 32;

// A ROUND BORE BEHIND EACH FAN. A single opening as big as the column removes the wall
// exactly where the fans' corner screws go. 38 leaves every corner solid.
fan_bore_d  = 38;
fan_pilot_d = 2.5;   // the fans screw in from INSIDE, self-tapping into the plate

fan_throat_area = fan_count * (PI * pow(fan_bore_d, 2) / 4 - PI * pow(fan_hub_d, 2) / 4);

// ----------------------------------------------------------------------------
// FRONT FACE — a U-channel printed standing: plate, two cheeks, the fans behind
// ----------------------------------------------------------------------------
// The plate carries the filter recess and the fan bores; the cheeks wrap back over
// the modules' sides and carry the female dovetails. Between the plate and the open
// module fronts is the PLENUM the fans blow into, and every module draws from it.
//
// Closed at the bottom by a floor on the print bed. Closed at the top by a 45-degree
// CEILING rising from the plate above the fan column to the module fronts -- a flat
// ceiling there would be a 68mm bridge.
filter_depth = 4;                       // the ring's thickness = its recess's depth
plate_t      = wall + filter_depth;     // 3 of plate behind the recess floor
plenum_gap   = 3;                       // fan's back face to the module fronts
front_d      = plate_t + fan_depth + plenum_gap;   // plate's outer face at x = -front_d
front_w      = module_w + 2 * (cheek_gap + cheek_t);
front_h      = stack_h;                 // flush with the lid

// The column is centred on what it feeds: the module fronts, from the bottom floor's
// top to the top module's ceiling (the lid's spigot).
fan_col_zc = (floor_t + module_count * module_pitch) / 2;
fan_z0     = fan_col_zc - fan_col_h / 2;
function fan_zc(k) = fan_z0 + fan_size * (k + 0.5);
fan_col_yc = module_w / 2;

ceiling_top = fan_z0 + fan_col_h + fan_depth + plenum_gap;   // where the 45 meets x = 0

assert(fan_z0 > floor_t + 1, "the fan column runs into the front face's floor");
assert(ceiling_top <= front_h,
       "the plenum's 45-degree ceiling does not close below the top of the front face");
assert(fan_size + 2 * 3 <= module_w, "the fan column is wider than the modules");

// ----------------------------------------------------------------------------
// DUST FILTER — hexrack's principle, in a vertical pill
// ----------------------------------------------------------------------------
// A ring that sits FLUSH in a recess in the plate, fabric glued into a pocket on its
// back. A PILL: two half-circles on the fans' own axes joined by straight sides, so it
// follows both fan circles. The clip ribs go on the STRAIGHT sides, where the recess
// wall is flat and runs up the print.
pill_r_in       = fan_bore_d / 2 + 0.5;       // the opening: both bores, whole
filter_band     = 3.5;
pill_r_out      = pill_r_in + filter_band;
pill_span       = fan_size * (fan_count - 1); // centre to centre of the half-circles
filter_clear    = 0.3;
filter_glue_d   = 0.32;   // hexrack's glue pocket depth
filter_glue_lip = 1;

assert(rib_half > filter_clear + 0.5, "the filter rib barely overlaps the ring");
assert(clip_rib_len < pill_span, "the filter rib is longer than the pill's straight side");
assert(2 * (pill_r_out + filter_clear + groove_half) + 4 < front_w,
       "the filter recess eats the front face's edges");

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
//   "module" | "lid" | "front" | "filter" - one printed part
case_part = "assembly";

// Explode distance: modules apart, lid up, front face forward, filter further. The
// boards travel with their modules -- each is screwed to its own floor.
//
// THE EXPLODE LIVES ONLY IN case.scad. placement.scad never reads it, so no fit test
// can measure an exploded position even by accident.
assembly_space = 30;

show_boards    = true;    // the Pi 5s, from the framework (cooler included)
show_hats      = true;    // both M.2 HAT+ boards and their drives
show_standoffs = true;    // the HATs' M2.5 standoffs
show_fan       = true;    // the two fan meshes, of fan_model
show_filter    = true;
show_front     = true;
show_case      = true;    // modules and lid

// Bambu A1. Every printed part has to fit.
bed = [256, 256, 256];
