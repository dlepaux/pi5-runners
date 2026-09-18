// ============================================================================
// PI5-RUNNERS — CONFIGURATION
// ============================================================================
// Single source of truth for every dimension. Never hardcode in part files.
// Mirrors naja-miner/cad/config.scad, which mirrors lab-router's.
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

// THE FRONT WALL IS THICKER. It carries the dust filter the hexrack way: a ring that
// sits FLUSH in a recess in the face, its fabric glued into a pocket on its back, held
// by 45-degree ribs. hexrack's ring is ~4 deep, and a 3mm wall cannot hold a 4mm
// recess, so the front is its own thickness -- and interiorOrigin() stops being
// [wall, wall, wall]. Everything that meets the shell goes through that one module.
filter_depth = 4;                    // ring thickness = recess depth
wall_front   = wall + filter_depth;  // 7: 3 behind the recess floor

// ----------------------------------------------------------------------------
// RASPBERRY PI 5
// ----------------------------------------------------------------------------
// Mirrors SBC_Model_Framework's rpi5 entry in sbc_models.cfg. The submodule can be
// updated under us; scripts/test-board-assets.sh is what notices if these drift.
pi5_pcb          = [85, 56, 1.65];
pi5_hole_pattern = [58, 49];
pi5_hole_inset   = 3.5;

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
// FANS — two Noctua NF-A4x10 5V, stacked into one 40 x 80 column
// ----------------------------------------------------------------------------
// Each: 4500 RPM, 8.2 m3/h, 17.9 dB(A), 1.78 mmH2O, 0.25W at 5V, 3-pin -- from Noctua's
// NF-A4x10 5V infosheet. Owned, so nothing to buy.
//
// 8.2 m3/h, NOT 4.85. An earlier revision of this project used 4.85, which is the
// fan's CFM figure read as m3/h, and it made every NF-A4x10 number ~40% too
// pessimistic -- including the one that ruled these fans out and sent the design to
// an NF-A8. Corrected: two of them put case air ~14.6K over the room, ~10K under the
// M.2 HAT's 50C ceiling in a 25C room. The NF-A4x20 pair would buy ~2K more.
//
// NO USB CABLE IN THE BOX (3:2-pin adaptor, OmniJoin set, extension). Both fans take
// 5V from a Pi's GPIO header -- pins 2 or 4 for 5V, 6 for ground -- at 0.25W each.
//
// WHY A COLUMN OF TWO 40s. The front wall carries the fans, so it must be as wide as
// the fan. An 80 made the case 92 wide around a 56 board; a 40 x 80 column is the same
// HEIGHT, so it still faces all three slots, but narrow enough that the board sets the
// width. The asserts below keep the column facing the whole stack.
fan_size       = 40;
fan_count      = 2;
fan_col_h      = fan_size * fan_count;   // 80: the column, and what faces the stack
fan_bolt_pitch = 32;                     // standard 40mm pattern

// MEASURED off Noctua's STEP, not the datasheet's 10. The frame is 11.0 deep -- its
// anti-vibration pads stand 0.5 proud of each face -- and a 16mm, 0.5mm hub label takes
// the whole mesh to 12.0. Clearance uses the envelope. The label gives the hub size.
fan_depth          = 12.0;
fan_hub_d          = 16;

// The committed mesh, NATIVE orientation -- axis along Y. Path relative to cad/:
// import() resolves against the MAIN document.
fan_asset        = "assets/noctua/NF-A4x10.stl";
fan_asset_extent = [40.0, 12.0, 40.0];   // native X, Y (axis), Z -- whole mesh
fan_asset_tol    = 0.6;

// A ROUND BORE BEHIND EACH FAN, NOT ONE SQUARE OPENING. A square as big as the fan
// removes the wall exactly where the fan's corner screws go: every bolt of the 40 x 80
// column -- and of the NF-A8 before it -- sat inside the opening, over empty air. The
// fans had nothing to screw into and no check looked for material round a bolt hole.
// A 38 bore leaves the four corners solid and a 2mm bar between the two fans, which
// is where their frames are solid anyway, so the bar costs no airflow.
//
// The ROUNDED RECTANGLE is kept where it is seen: the filter ring and its recess.
fan_bore_d  = 38;
fan_pilot_d = 2.5;   // the fans screw in from INSIDE, self-tapping into the front wall,
                     // so no head sits in the recess under the filter fabric

// The fans' combined throat: each bore less its hub.
fan_throat_area = fan_count * (PI * pow(fan_bore_d, 2) / 4 - PI * pow(fan_hub_d, 2) / 4);

fan_z0     = (interior_h - fan_col_h) / 2;
fan_col_zc = fan_z0 + fan_col_h / 2;
// Centre of fan k, 0 at the bottom. Interior frame.
function fan_zc(k) = fan_z0 + fan_size * (k + 0.5);

assert(fan_z0 <= board_z[0],
       "the fan column does not reach the bottom board");
assert(fan_z0 + fan_col_h >= stack_top,
       "the fan column does not reach the top of the stack -- slot 2 is out of the airstream");

// ----------------------------------------------------------------------------
// ENVELOPE
// ----------------------------------------------------------------------------
side_clear     = 3;     // board edge to the inner wall face. 3, not 2: the rear corner
                        // flanges pass the bottom PCB edge at 0.2mm otherwise
port_overhang  = 3;     // RJ45 and the USB-A stacks stand proud of the PCB's +X edge
fan_plenum     = 8;     // fan's inner face to the board's -X edge
fan_side_clear = 3;     // fan frame to the front wall's own edges

// X: fan, plenum, the Compact HAT's -X tab, the board, its ports. The tab hangs 6.5
// off the PCB where the PCIe ribbon lands, and it faces the fan, so the plenum clears
// the tab rather than the board edge.
board_x    = fan_depth + fan_plenum + hat_compact_overhang_x;
interior_x = board_x + pi5_pcb[0] + port_overhang + side_clear;

// Y: whichever is wider, the fan column or the board. With the 40s it is THE BOARD --
// 60.5 against the column's 46 -- which was the point of changing fans.
//
// The board sits against -Y so the USB-C and micro-HDMI connectors meet their wall
// instead of the bottom of a recess no plug reaches into.
board_y    = side_clear;
interior_y = max(fan_size + 2 * fan_side_clear,
                 board_y + pi5_pcb[1] + hat_overhang_y + side_clear);

assert(interior_y >= fan_size + 2 * fan_side_clear,
       "front wall is narrower than the fan column it carries");

outer = [interior_x + wall_front + wall, interior_y + 2 * wall, interior_h + 2 * wall];

// Bambu A1. Every printed part has to fit this, and the shell is the tall one.
bed = [256, 256, 256];

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
assembly_space = 50;

// Preview geometry. None of it is ever exported: generate-stl.sh renders the parts
// by name, and the showcase marks vendor geometry with %.
show_boards    = true;    // the three Pi 5s, from the framework (cooler included)
show_hats      = true;    // both M.2 HAT+ boards and their drives
show_standoffs = true;    // the M2.5 stacks the boards sit on
show_fan       = true;    // the two NF-A4x10 meshes
show_filter    = true;    // the intake filter, clipped on from outside
show_case      = true;    // the printed parts themselves

// ----------------------------------------------------------------------------
// CLIPS — hexrack's 45-degree rib into a groove, and nothing else
// ----------------------------------------------------------------------------
// The shell is SIX parts -- base, four walls, roof -- joined without screws or
// dovetails. Every joint is the one hexrack's dust filter uses: a square-section rib
// turned 45 degrees, half of it standing proud of one part, sitting in a matching
// groove in the other. It cams over as the parts are pushed together and drops in.
//
// (hexrack also carries a cylindrical snap in components/snap-fit.scad. It is dead
// code -- nothing includes it and its dimensions are defined nowhere -- so it is not
// the thing to copy.)
//
// EVERY JOINT ENGAGES BY PUSHING STRAIGHT DOWN, so the case assembles in one
// direction: base; front and rear walls onto the base rim; side walls down between
// the front and rear walls' corner flanges; roof down onto its rim.
clip_rib      = 1.7;        // hexrack's dust_clip_length: the rib's square section
clip_clear    = tolerance;  // groove stands this far off the rib all round
clip_rib_len  = 18;         // each rib's length

rim_t      = 2;    // base and roof rims: a band just inside the walls
rim_h      = 6;    // below the fan column's bottom (fan_z0 ~7) so the rim clears it
flange_t   = 1.6;  // front/rear walls' corner flanges, lying on the side walls' faces
flange_lap = 10;   // how far along the side wall each flange reaches

assert(clip_rib * sqrt(2) / 2 < min(rim_t, flange_t),
       "a rib is deeper than the rim or flange that carries half of it");
assert(rim_h < fan_z0, "the base rim reaches up into the fan column");

// ----------------------------------------------------------------------------
// VENTS — the exhaust budget
// ----------------------------------------------------------------------------
// Positive pressure: one filtered intake, and everything else leaves through these.
// The -Y field and the roof field feed ONE number, so either can be widened when
// test-airflow.sh says the intake is choked.
// TRIANGLES, and the same lattice hexrack uses -- cell 14, web 1.6, corner 1.2,
// stagger 0.5 -- so the two projects look like they came from the same hand. A
// triangle cannot rack, so the field keeps a 3mm wall stiff at an open-area fraction
// that would leave round holes floppy.
vent_tri_cell   = 14;
vent_wall       = 1.6;
vent_tri_radius = 1.2;
vent_tri_stagger = 0.5;

// EXHAUST: THE REAR WALL, WRAPPING ONTO THE REAR OF BOTH SIDES. No roof field: a
// lid with holes in it drops dust straight onto the boards.
//
// WHY THE SIDES. Rear-only was tried and MEASURED: the three port clusters' exclusion
// zones take ~43% of the rear wall, and what is left of it -- hexrack's lattice is
// ~53% open -- reaches 2451mm2 against the fan's 4320mm2 throat. 57%. Even venting
// the ENTIRE rear with no zones only reaches 4306, i.e. the rear wall alone cannot
// carry this fan whatever you do to it. Wrapping onto the rear portion of the side
// walls restores a matched exit and keeps the top and the front clean.
vent_margin     = 3;    // solid border left around every field
vent_rear_w     = interior_y - 2 * vent_margin;
vent_side_depth = 32;   // how far forward from the rear the side fields reach -- the most
                        // that stays behind the -Y ports once the rear flange takes its lap

// THE -Y SIDE FIELD MUST STAY BEHIND THE USB-C AND MICRO-HDMI CUTOUTS. Measured off the
// framework's -Y mask: that cluster ends at board x = 42.60. The field's front edge is
// derived and asserted against it, so a longer vent_side_depth fails here rather than
// cutting triangles through the side of a USB-C port.
side_port_cluster_x1 = 42.60;
// Ends before the rear wall's corner flange, which overlaps the side wall's inner face
// and would otherwise sit over triangles -- see CLIPS below.
side_field_x0 = interior_x - flange_lap - vent_margin - vent_side_depth;   // interior
assert(side_field_x0 > board_x + side_port_cluster_x1 + 3,
       "side exhaust field reaches forward into the -Y port cutouts");

// EXCLUSION ZONE, hexrack's idea: a rounded rectangle carved out of the vent CUTTER,
// per board, so no triangle ever clips a port. The ports then sit in clean solid
// material with the pattern running around them, which is the whole reason hexrack's
// back face reads as deliberate rather than as holes that happened to miss.
// Per board, in the rear wall's plane, around the RJ45/USB cluster.
//
// SIZED FROM THE MEASURED CLUSTER, not guessed: the framework's +X mask spans
// Y 2.33..54.50 and Z 1.65..17.90 in the board frame -- 52.2 x 16.3. The zone is that
// plus exclusion_pad all round. Every millimetre here comes straight out of the only
// exhaust this case has, so it is as tight as a clean margin allows.
exclusion_pad = 1.5;
exclusion_cluster_y = [2.33, 54.50];
exclusion_cluster_z = [1.65, 17.90];
exclusion_w = exclusion_cluster_y[1] - exclusion_cluster_y[0] + 2 * exclusion_pad;
exclusion_h = exclusion_cluster_z[1] - exclusion_cluster_z[0] + 2 * exclusion_pad;
exclusion_r = 3;

// ----------------------------------------------------------------------------
// DUST FILTER — hexrack's principle
// ----------------------------------------------------------------------------
// A RING that sits FLUSH in a recess in the front wall. The filter fabric is glued
// into a shallow pocket on the ring's back and spans the opening; the ring only
// frames it. Two 45-degree ribs, top and bottom, click into grooves in the recess --
// the same joint as every other in this case.
//
// The ring's inner opening is the ROUNDED RECTANGLE over the whole column: it is what
// is seen from the front, and it is wider than both round bores behind it, so the
// plastic restricts nothing -- the fabric is the only thing in the airstream.
fan_opening      = [fan_size, fan_col_h];   // the ring's inner opening
fan_opening_r    = 6;

// Bands round the opening. The top and bottom are thin because the front wall part
// only has ~7mm above and below the column, and the groove needs wall behind it.
filter_band_side = 6;
filter_band_v    = 3.5;
filter_clear     = 0.3;    // ring to recess, all round
filter_glue_d    = 0.32;   // hexrack's glue pocket depth, on the ring's back
filter_glue_lip  = 1;      // solid lip left at the ring's outer edge, round the pocket

function filterOuter() = fan_opening + 2 * [filter_band_side, filter_band_v];
function filterOuterR() = fan_opening_r + filter_band_v;

// ----------------------------------------------------------------------------
// FASTENERS AND BASE FEATURES
// ----------------------------------------------------------------------------
// M2.5 throughout, because that is what a Pi mounts on and one insert size means one
// soldering-iron tip and one bag of screws. READ FROM lib/theaded-inserts.scad rather
// than typed: a Ruthex RX-M2.5x5.7 wants 6.7mm of hole, not 5.7, because the extra
// millimetre takes displaced plastic and screw-tip overrun. A pocket cut to the
// insert's own length leaves the board seating on the screw instead of the standoff.
insert_m25        = "M2.5";
insert_m25_boss   = get_insert_min_boss(insert_m25);

// The bottom board sits on two RAILS, hexrack's "canoes", with an M2.5 heat-set insert
// under each mounting hole. The standoff tower's lowest male threads go down through
// board 0 into those inserts, clamping it: the whole stack is one screwed unit.
//
// hexrack runs its canoes ALONG ITS AIRFLOW, and so do these -- front to back, along X.
// Run across, a 10mm rail under the bottom board is a dam in the airstream.
boss_d        = insert_m25_boss;   // 7.2, from the insert table
canoe_w       = boss_d + 2;        // a millimetre of wall either side of the boss
canoe_overrun = 4;                 // rail runs this far past its outer holes

