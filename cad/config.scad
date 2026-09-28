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
// Each module's front wall carries a round DUST FILTER with two flats, clipped into a
// recess over its fan.
//
// FRAMES. The MODULE frame: x=0 the front face, y=0 the -Y outer face, z=0 the bottom
// of the spigot, which is the print bed. The STACK frame is module 0's; module k sits
// at z = k * module_pitch.
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
// screwed in from outside through the wall, the hexrack way,
// powered from its own Pi's GPIO 5V -- pins 2 or 4, ground on 6 -- so a module is a
// complete unit: board, storage, cooler, airflow. Three fans against the two a shared
// column had is +50% airflow.
//
// fan_model is the one mode switch. The fan sits between the front wall and the
// board, so it sets the MODULE's length -- and the lid's, which is the module's
// footprint. Switching fans means reprinting modules and lid; the dust filters are
// the same part either way. generate-stl.sh writes both.
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
fan_model = "NF-A4x20";

fan_row = [for (r = fan_models) if (r[0] == fan_model) r][0];
assert(!is_undef(fan_row), str("unknown fan_model: ", fan_model));

fan_depth        = fan_row[1];
fan_hub_d        = fan_row[2];
fan_asset        = fan_row[3];   // relative to cad/: import() it only from a file IN cad/ -- see noctua-fan.scad
fan_asset_extent = fan_row[4];
fan_asset_tol    = 0.6;

fan_size       = 40;
fan_bolt_pitch = 32;
fan_clear      = 0.5;    // fan frame to the floor below it and the floor above it

// A ROUND BORE, NOT A SQUARE OPENING: a square as big as the fan removes the wall
// exactly where its corner screws go. 38 leaves every corner solid.
fan_bore_d  = 38;

fan_throat_area = PI * pow(fan_bore_d, 2) / 4 - PI * pow(fan_hub_d, 2) / 4;   // per fan

// ----------------------------------------------------------------------------
// CLIPS — hexrack's 45-degree rib into a groove
// ----------------------------------------------------------------------------
// The same joint as hexrack's dust filter: a square-section rib turned 45 degrees,
// half of it standing proud of one part, dropping into a matching groove in the
// other. Three ribs on every SPIGOT -- one per side wall, one on the rear -- into
// grooves in the SOCKET of the module below; and two on every dust filter.
// HEXRACK'S FULL SIZE (1.7 x 18). A 40% smaller rib (1.0 x 11) was tried to look
// lighter and printed too small; back to the size hexrack proved.
clip_rib     = 1.7;          // hexrack's dust_clip_length: the rib's square section
clip_clear   = tolerance;    // groove stands this far off the rib all round
clip_rib_len = 18;

rib_half    = clip_rib * sqrt(2) / 2;                        // proud of the joint plane
groove_half = (clip_rib + sqrt(2) * clip_clear) * sqrt(2) / 2;

// THE RIB IS THE SPIGOT'S LAST ELEMENT: its lowest vertex is the spigot's bottom edge,
// so nothing of the spigot hangs below the clip.
clip_z = rib_half;

// ----------------------------------------------------------------------------
// STACKING — the spigot, the socket, the lap between them
// ----------------------------------------------------------------------------
// A module's bottom band is a SPIGOT: a U inset from its side and rear faces that
// drops inside the walls of the module below. The walls then meet on a 45-degree LAP:
// the lower wall's top is bevelled on the inside, and the upper wall's underside is a
// chamfer lying ON that bevel and running on out to its own outer face. The bevel
// carries the weight and centres each module on the one below. The lower wall rises
// into the V under the chamfer as a LIP, so the outer faces meet flush.
//
// THE FRONT IS A BUTT JOINT. Each module's front wall runs its full height and sits
// flat on the front wall below, so the stack's front is one continuous face and each
// module's dust filter lies wholly in its own module. The lower module's side walls
// stop behind the front wall above their socket, to leave it room.
//
// WHY A CHAMFER TO THE OUTER FACE. The module prints floor-down, so the upper wall
// starts at the top of the spigot, 3mm outboard of it. As a step that is a 3mm ledge
// printed over air; a chamfer that stops short of the outer face still leaves a roof
// there -- the first print's was 1.3mm, bearing on the land, and it sagged. Taken all
// the way out, nothing on the lap is printed over air. Bearing on the bevel instead of
// the land is the cost: the bevel's print tolerance, not a layer, sets the stack height.
stack_gap  = 0.2;     // spigot to socket wall, radially, below the lap
spigot_t   = 2;       // the spigot ring's own thickness
stack_land = 1;       // how far in from the outer face the bevel meets socket_z
// THE LIP STOPS ONE EXTRUSION LINE WIDE, not at a knife edge. A tip thinner than the
// nozzle's line is dropped or printed ragged by the slicer and chips in handling; at
// 0.4 it prints as one clean line and leaves a 0.4mm hairline at the joint.
lip_t      = 0.4;
// The chamfer's clearance off the bevel, along its normal. Nominal only -- the print's
// own tolerance swallows it, so the bevel bears -- but two coincident slanted faces
// are what a mesh boolean cannot resolve: at zero the fit tests read noise as overlap.
lap_gap    = 0.05;

spigot_inset = wall + stack_gap;

// AS SHORT AS THE CLIP ALLOWS. The groove in the module below must sit wholly under
// that module's bevel, which starts (wall - stack_land) below socket_z.
spigot_h = ceil((clip_z + groove_half + wall - stack_land + 0.3) * 10) / 10;

// The upper module's chamfer, in its own frame: lap_gap off the lower bevel's plane,
// so it reaches its outer face stack_land (and lap_gap*sqrt(2)) above socket_z, and at
// 45 degrees it rises as far as it runs in, down to the spigot.
lap_top = spigot_h + stack_land + lap_gap * sqrt(2);
lap_h   = spigot_inset;

assert(clip_z + rib_half <= lap_top - lap_h,
       "the spigot rib runs into the spigot's own bevel");
assert(lip_t > 0 && lip_t < stack_land, "the lip must end between a knife edge and the old land");

// ----------------------------------------------------------------------------
// DUST FILTER — a round ring with two flats, one per module
// ----------------------------------------------------------------------------
// hexrack's filter, reshaped: a CIRCULAR ring cut by two flats, left and right, that
// sits FLUSH in a recess in the module's front wall. Fabric is glued into a 0.32mm
// pocket on its back reaching 4mm out from the window; two 45-degree ribs on the
// flats, running vertically at the ring's back, click into grooves in the recess.
//
// WHY A CIRCLE, NOT hexrack's HEXAGON. The ring must cover the fan's corner screws,
// which sit on the DIAGONALS. A hexagon with flats top and bottom has its points on
// the horizontal, so it came 59.4mm wide and left 2mm of front face each side -- no
// room for rounded corners (corner_r). A circle through the same heads is 52.5 wide.
//
// THE FLATS ARE THE CLIP SEATS, AT THE SIDES. They sit just past the glue pocket, and
// on the sides the clips read as part of the ring's outline rather than as caps on
// it. The cost is height: the module is set by the full circle, 2.4mm more than by
// the flats. The recess's crown, standing in the module, is a 4mm-deep arc off the web
// behind it -- steeper than 45 near the top, the price of the round look
// (test-print.sh budgets it).
//
// THE RING COVERS THE FAN SCREWS. They go in from outside, countersunk into the
// recess floor, so the ring is sized to lie over every head: a corner hole at (16, 16)
// sits 16*sqrt(2) = 22.6 out, and its countersink reaches half its diameter further.
filter_depth     = 4;                    // ring thickness = recess depth
fan_web          = 3;                    // front wall behind the recess: what the screws pass
filter_clear     = tolerance / 2;        // ring to recess, all round: hexrack's
filter_glue_d    = 0.32;                 // hexrack's glue pocket depth
filter_glue_band = 4;                    // pocket reaches this far out from the window

fan_screw    = "M3-Noctua";
fan_csink_d  = get_screw_spec(fan_screw, "countersink_diameter");
fan_screw_r  = fan_bolt_pitch / 2 * sqrt(2);                // a corner hole, from the centre

filter_r_in  = fan_bore_d / 2;                              // the window frames the bore
filter_r_out = fan_screw_r + fan_csink_d / 2 + 0.5;         // the ring covers every head
filter_a_out = filter_r_in + filter_glue_band + 1;          // centre to a flat
filter_r_recess = filter_r_out + filter_clear;
filter_a_recess = filter_a_out + filter_clear;
filter_flat  = 2 * sqrt(filter_r_out ^ 2 - filter_a_out ^ 2);   // a flat's length
filter_rib_len = 0.6 * filter_flat;      // clear of the arc at both ends, groove included

assert(filter_a_out < filter_r_out, "the flats miss the circle -- the ring has no flats");
assert(fan_bolt_pitch / 2 + fan_csink_d / 2 + 0.5 <= filter_a_out,
       "a flat cuts across a screw head");
assert(fan_csink_d / 2 < fan_web + filter_depth, "the countersink is deeper than the wall");

// ----------------------------------------------------------------------------
// FASTENERS — the Pi screws into its own module
// ----------------------------------------------------------------------------
// M2.5 heat-set inserts in two rails on the floor, one under each mounting hole.
// READ FROM lib/theaded-inserts.scad: a Ruthex RX-M2.5x5.7 wants 6.7 of hole, not 5.7.
// THE BOARD STANDS ON STANDOFFS, not on the rails: an M2.5 x board_standoff_h male-
// female standoff screws into each insert, female end up, and the HAT's own male-
// female standoffs thread through the Pi into those (a bare Pi takes an M2.5 screw).
// The board keeps its height on the fan's axis; the rails stop short of it by the
// standoff, which leaves air under the whole board instead of a printed bed.
//
// The rails run ALONG X, with the airflow, as hexrack's canoes do.
insert_m25    = "M2.5";
boss_d        = get_insert_min_boss(insert_m25);   // 7.2
canoe_w       = boss_d + 2;
canoe_overrun = 4;
board_standoff_h  = 5;     // M2.5 male-female, rail top to board underside
board_standoff_af = 5;     // M2.5 standoff hex, across flats

assert(rail_top - get_insert_spec(insert_m25, "hole_depth") >= 1,
       "the insert pocket would break through the floor");
assert(board_standoff_af / cos(30) <= boss_d, "the standoff's hex overhangs its insert boss");

// ----------------------------------------------------------------------------
// MODULE — one Pi 5 and its fan, printed floor-down as one piece
// ----------------------------------------------------------------------------
// SIZED FOR THE TALLEST BOARD, so there is ONE module part and any board goes in any
// slot. A bare Pi wastes height; three different modules would waste a reprint every
// time a board changes role.
floor_t       = 2.4;   // the vented floor: 12 layers at 0.2
rail_h        = 5.5;   // the insert rails ("canoes") at their lowest: board_lift adds to it
plenum_gap    = 3;     // fan's back face to the Compact HAT's tab
module_air    = 5;     // top of the tallest board to the next module's floor, at least

// REAR: THE PORTS COME THROUGH THE WALL, FLUSH WITH ITS OUTER FACE, like the official
// case's. They used to stop 3mm short of the wall on a guessed 3mm overhang, which put
// the RJ45 6.6mm and the USB-A stacks 7.9mm inside the case -- more than half a USB-A
// plug's 12mm shell, so a plug could not seat. The reach is MEASURED off the
// framework's rpi5, and test-fit.sh holds it there: the RJ45 stands 2.40 past the
// PCB's +X edge, the USB-A stacks 1.11, so flushing the RJ45 leaves the USB-A 1.3 in.
//
// THE PI SLIDES IN. With its jacks in the wall it cannot drop in from above: it goes
// down short of the wall and slides back into its holes, BEFORE its HAT, while the
// Compact's tab and the plenum leave room ahead of it. config.scad asserts that room.
rear_port_reach = 2.40;  // RJ45 face past the PCB's +X edge
rear_port_proud = 0;     // RJ45 face past the rear wall's outer face; negative recesses it
slide_clear     = 0.5;   // jacks to the wall's inner face while the Pi goes down
// THE PCB GOES INTO THE WALL TOO. 2.40 of RJ45 against a 3mm wall puts the PCB's last
// 0.6 in it, so the wall's inner face carries a slot for the edge, its roof at 45
// degrees so it prints. The slot is what the Pi slides back into.
pcb_slot_clear  = 0.3;   // round the PCB's +X edge, in the slot

// SIDES: THE PI IS CENTRED ACROSS THE MODULE, so its two rails sit symmetrically on
// the floor -- the first print had them 2.5mm toward -Y and it read as a mistake. The
// Pi is located by its four screws, not by the walls. The cost is on -Y: its USB-C and
// micro-HDMI sockets now sit 3mm behind the wall instead of 0.5, and a USB-C plug's
// shell is ~6.5mm long -- check a plug seats on the next print. The HAT's 0.5 overhang
// on +Y is why that side is 0.5 tighter.
side_clear     = 3;     // -Y: board to wall
side_clear_pos = 2.5;   // +Y: HAT overhang to wall

// The front wall: the recess the filter sits in, and the web behind it the fan's
// screws pass through.
front_wall_t = filter_depth + fan_web;

// The Pi in the module frame: behind the front wall, the fan and the plenum. The
// Compact's tab hangs 6.5 off the PCB's -X edge, toward the fan, so the plenum is
// measured from the tab.
board_x = front_wall_t + fan_depth + plenum_gap + hat_compact_overhang_x;
board_y = wall + side_clear;
board_z0 = floor_t + rail_h + board_standoff_h;   // the board at its lowest; board_lift raises it below

module_l = board_x + pi5_pcb[0] + rear_port_reach - rear_port_proud;
// The jacks sit wall + rear_port_proud deep in the rear wall. Slid that far forward
// (and slide_clear more) to go down past it, the bare Pi's -X edge must clear the fan.
slide_travel = max(0, wall + rear_port_proud) + slide_clear;
assert(plenum_gap + hat_compact_overhang_x >= slide_travel,
       "no room ahead of the Pi to slide its jacks into the rear wall");
module_w = board_y + pi5_pcb[1] + hat_overhang_y + side_clear_pos + wall;
assert(abs(board_y + pi5_pcb[1] / 2 - module_w / 2) < EPS, "the Pi (and its rails) is not centred across the module");

// THE FOUR VERTICAL CORNERS ARE ROUNDED, for the look. Vertical, so it costs nothing to
// print. Every outline -- walls, spigot, lap, socket, lid -- is inset from the same
// rounded footprint, so the lap stays concentric round the rear corners. The front
// corners are what limit it: they pass beside the filter's recess, which at its widest
// leaves 5.3mm of front face each side.
corner_r = 4;

// FLOOR TO FLOOR: whichever needs most -- the tallest board, the fan, or the filter's
// recess with a clip groove and a millimetre of wall above and below it. It is the
// filter.
filter_band_h = 2 * (filter_r_recess + 1);
module_pitch = max(board_z0 + hat_slot_h + module_air,
                   floor_t + fan_size + 2 * fan_clear,
                   filter_band_h);
// socket_z is the bevel's reference: where it is stack_land in from the outer face.
// The part itself ends higher, on its lip.
socket_z     = module_pitch + spigot_h;
module_h     = socket_z + stack_land - lip_t;

// The fan and its filter, centred on the module's front face.
fan_yc = module_w / 2;
fan_zc = module_pitch / 2;

// BOARD LIFT. The filter sets the module's height, not the board, so there is room to
// spare -- and a board left on the floor sends the top of the fan's flow over the HAT
// instead of across the board. By default the tallest board (the Pi, its HAT and the
// drive's screw) is CENTRED ON THE FAN'S AXIS; the rails grow by the lift, so the Pi
// still screws straight into its inserts. Override with -D board_lift=0 for the floor.
board_lift = max(0, fan_zc - hat_slot_h / 2 - board_z0);
board_z    = board_z0 + board_lift;
rail_top   = board_z - board_standoff_h;   // where the inserts go in

module_count = 3;
lid_t        = 3;     // the lid's plate, above its spigot
stack_h = module_count * module_pitch + spigot_h + lid_t;   // floor of 0 to lid top

// THE BASE: a module's socket on an open rim, with a skirt round it (parts/base.scad).
base_floor_t     = 3;           // the rim under the bottom module
base_skirt       = 2;           // skirt beyond the module's sides and rear
// Skirt top, above the bottom module's underside: DERIVED, because the clip sets
// spigot_h. Midway between the joint it hides (module_h, spigot_h + 0.6 up) and the
// lowest vents (vent_z0 - 1, spigot_h + 2 up).
base_skirt_h     = spigot_h + 1.3;
base_skirt_clear = stack_gap;   // skirt to the module's outer face, above the lip

assert(base_skirt_h < vent_z0 - 1, "the base's skirt covers the lowest vents");
assert(module_pitch + base_skirt_h > module_h, "the skirt stops below the joint it hides");

assert(board_lift >= 0, "board_lift cannot sink the board into its floor");
assert(module_pitch - (board_z + hat_slot_h) >= 3,
       "board_lift leaves less than 3mm between a HAT and the next module's floor");
assert(fan_zc - fan_size / 2 >= floor_t + fan_clear, "the fan sits on the floor");
assert(module_w / 2 - filter_a_recess - corner_r >= 1,
       "corner_r cuts into the filter's recess: under 1mm of wall at the front corners");
assert(fan_size + 2 <= module_w - 2 * wall, "the fan is wider than the module's inside");
assert(board_y + pi5_hole_inset - boss_d / 2 >= spigot_inset,
       "the rail's insert boss would stand outside the spigot");

// The Pi's connectors must cut through FULL wall, not the inset spigot band: the
// lowest connector starts 1.53 above the PCB underside.
assert(board_z + 1.5 > lap_top,
       "a connector would land in the inset spigot band instead of the wall");

// ----------------------------------------------------------------------------
// VENTS — triangles on the floor, 45-degree slots on the sides, diamonds on the rear
// ----------------------------------------------------------------------------
// FLOOR: hexrack's triangle lattice -- cell 14, web 1.6, corner 1.2, stagger 0.5. A
// triangle cannot rack, so the floor stays stiff at a high open fraction.
//
// WALLS: simpler shapes, every edge at 45 degrees (lib/vents.scad): a grille of
// slanted bars on the sides, a diamond lattice on the rear round its port cluster.
vent_tri_cell    = 14;
vent_wall        = 1.6;
vent_tri_radius  = 1.2;
vent_tri_stagger = 0.5;
vent_margin      = 3;    // solid border round every field

vent_slot_w       = 3;     // side slot, across
vent_slot_bar     = 2.5;   // the bar between two slots, square to them
vent_diamond      = 5;     // rear diamond's side
vent_diamond_web  = 1.6;   // rear bar between two diamonds, square to them
vent_side_share   = 0.5;   // how much of the room behind the -Y ports the side grille takes

// EXHAUST: the rear wall and the rear of both side walls. Never the lid: a lid with
// holes drops dust straight onto the top board. Fields stay above the spigot band and
// below the socket's clip grooves.
vent_z0 = spigot_h + vent_margin;
vent_z1 = module_pitch + clip_z - groove_half - vent_margin;

// The -Y connectors, measured off the framework's -Y mask: USB-C and the micro-HDMIs
// span 6.25..42.60 along the board.
side_port_cluster_x = [6.25, 42.60];

// The side fields sit behind the -Y connectors -- both sides, so the two walls match
// -- and against the rear wall, where the air leaves the board. They take only
// vent_side_share of that room: the full length read as too much opening.
side_room_x  = [board_x + side_port_cluster_x[1] + vent_margin,
                module_l - wall - vent_margin];
side_field_x = [side_room_x[1] - vent_side_share * (side_room_x[1] - side_room_x[0]),
                side_room_x[1]];
assert(side_field_x[1] - side_field_x[0] > 3 * (vent_slot_w + vent_slot_bar),
       "the side exhaust field is too short to hold a grille");

// EXCLUSION ZONE, hexrack's idea: the rear port cluster sits in clean solid wall with
// the lattice running round it. Sized from the MEASURED cluster -- the framework's +X
// mask spans Y 2.33..54.50 and Z 1.65..17.90 in the board frame.
exclusion_pad       = 1.5;
exclusion_cluster_y = [2.33, 54.50];
exclusion_cluster_z = [1.65, 17.90];
exclusion_w = exclusion_cluster_y[1] - exclusion_cluster_y[0] + 2 * exclusion_pad;
exclusion_h = exclusion_cluster_z[1] - exclusion_cluster_z[0] + 2 * exclusion_pad;
exclusion_r = 3;

// The PCB-edge slot, board frame: from the rear wall's inner face to past the PCB's
// edge, and its full height with the 45-degree roof. The exclusion zone takes it in
// too, or the slot's floor clips the tops of the diamonds under it.
pcb_slot_x0    = module_l - wall - board_x;
pcb_slot_depth = pi5_pcb[0] + pcb_slot_clear - pcb_slot_x0;
pcb_slot_h     = pi5_pcb[2] + 2 * pcb_slot_clear + pcb_slot_depth;
assert(pcb_slot_depth < wall - 1, "the PCB slot leaves under 1mm of rear wall");

// ----------------------------------------------------------------------------
// ASSEMBLY / PREVIEW
// ----------------------------------------------------------------------------
// Open cad/case.scad and set case_part:
//   "assembly" - everything, for looking at
//   "module" | "lid" | "filter" - one printed part
case_part = "assembly";

// Explode distance: modules apart, lid up, filters forward. The
// boards travel with their modules -- each is screwed to its own floor.
//
// THE EXPLODE LIVES ONLY IN case.scad. placement.scad never reads it, so no fit test
// can measure an exploded position even by accident.
assembly_space = 50;

show_boards    = true;    // the Pi 5s, from the framework (cooler included)
show_hats      = true;    // both M.2 HAT+ boards and their drives
show_standoffs = false;    // the M2.5 standoffs: under each board, and each HAT's
show_fan       = true;    // one fan mesh per module, of fan_model
show_filter    = true;    // the dust filters
show_case      = true;    // modules and lid

// Bambu A1. Every printed part has to fit.
bed = [256, 256, 256];
