// ============================================================================
// THREADED INSERT SPECIFICATIONS & HOLE API
// ============================================================================
// Complete heat-set threaded insert management: specifications, helper
// functions, and hole masks.
// All geometry starts at origin [0,0,0] - position with translate()
//
// Usage:
//   include <lib/threaded_inserts.scad>
//
//   difference() {
//       your_part();
//       translate([x, y, z]) insert_hole_mask("M2.5");
//   }
//
// Convention (same as screws.scad):
//   Z=0 is the top surface where the insert enters the material.
//   The hole extends downward (negative Z).
//
//        ═══╤═════╤═══   Z=0  (surface, insert goes in here)
//           │     │      hole_diameter  (insert body sits here)
//           │     │
//           └─────┘      Z=-hole_depth
//
// Manufacturer nomenclature (Ruthex) mapping:
//   D1 -> insert_diameter          (outer / top diameter of the insert)
//   D2 -> insert_bottom_diameter   (tapered bottom end diameter)
//   D3 -> hole_diameter            (hole in the printed model)
//   L  -> insert_height            (hole_depth = L + 1 mm)
//   W  -> min_wall                 (minimum material around the hole)
// ============================================================================

// ============================================================================
// THREADED INSERT SPECIFICATIONS
// ============================================================================
// Format: [name, thread_diameter, insert_diameter, insert_bottom_diameter,
//          insert_height, hole_diameter, hole_depth, min_wall,
//          screw_clearance_diameter]
//
// Key measurements:
//   thread_diameter          - Nominal thread size of the insert (M2.5 -> 2.5)
//   insert_diameter          - Outer (largest/top) diameter of the insert body
//   insert_bottom_diameter   - Diameter at the tapered bottom end (reference)
//   insert_height            - Physical height of the insert
//   hole_diameter            - Diameter of the hole to melt/press the insert into
//   hole_depth               - MINIMUM hole depth (insert height + 1 mm for
//                              displaced plastic and screw tip overrun)
//   min_wall                 - MINIMUM wall thickness of material around the
//                              hole. Total minimum boss size (side view) is:
//                              min_wall + hole_diameter + min_wall
//   screw_clearance_diameter - Through-hole diameter if the mating screw must
//                              pass beyond the insert
insert_specs = [
  [
    // name                       Ruthex RX-M2x4.0
    "M2",
    // thread_diameter
    2.0,
    // insert_diameter            (D1)
    3.6,
    // insert_bottom_diameter     (D2)
    3.1,
    // insert_height              (L)
    4.0,
    // hole_diameter              (D3)
    3.2,
    // hole_depth                 (L + 1)
    5.0,
    // min_wall                   (W)
    1.3,
    // screw_clearance_diameter
    2.2,
  ],
  [
    // name                       Ruthex RX-M2.5x5.7
    "M2.5",
    // thread_diameter
    2.5,
    // insert_diameter            (D1)
    4.6,
    // insert_bottom_diameter     (D2)
    3.9,
    // insert_height              (L)
    5.7,
    // hole_diameter              (D3)
    4.0,
    // hole_depth                 (L + 1)
    6.7,
    // min_wall                   (W)
    1.6,
    // screw_clearance_diameter
    2.8,
  ],
  [
    // name                       Ruthex RX-M3x5.7
    "M3",
    // thread_diameter
    3.0,
    // insert_diameter            (D1)
    4.6,
    // insert_bottom_diameter     (D2)
    3.9,
    // insert_height              (L)
    5.7,
    // hole_diameter              (D3)
    4.0,
    // hole_depth                 (L + 1)
    6.7,
    // min_wall                   (W)
    1.6,
    // screw_clearance_diameter
    3.3,
  ],
  [
    // name                       Ruthex RX-M4x6.35
    "M4",
    // thread_diameter
    4.0,
    // insert_diameter            (D1)
    6.3,
    // insert_bottom_diameter     (D2)
    5.5,
    // insert_height              (L)
    6.35,
    // hole_diameter              (D3)
    5.6,
    // hole_depth                 (L + 1)
    7.35,
    // min_wall                   (W)
    2.1,
    // screw_clearance_diameter
    4.3,
  ],
];

// ============================================================================
// SPEC ACCESSORS
// ============================================================================
function get_insert_index(name) =
  search([name], insert_specs)[0];

function get_insert_spec(name, property) =
  let (
    idx = get_insert_index(name),
    spec = insert_specs[idx]
  ) property == "name" ? spec[0]
  : property == "thread_diameter" ? spec[1]
  : property == "insert_diameter" ? spec[2]
  : property == "insert_bottom_diameter" ? spec[3]
  : property == "insert_height" ? spec[4]
  : property == "hole_diameter" ? spec[5]
  : property == "hole_depth" ? spec[6]
  : property == "min_wall" ? spec[7]
  : property == "screw_clearance_diameter" ? spec[8]
  : undef;

// Minimum outer size (diameter / square side) of the boss that can host the
// insert: min_wall + hole_diameter + min_wall
function get_insert_min_boss(insert) =
  get_insert_spec(insert, "hole_diameter") + 2 * get_insert_spec(insert, "min_wall");

// Convenience: [hole_diameter, hole_depth, min_boss]
function get_insert_hole(insert) =
  [
    get_insert_spec(insert, "hole_diameter"),
    get_insert_spec(insert, "hole_depth"),
    get_insert_min_boss(insert),
  ];

// ============================================================================
// THREADED INSERT HOLE MASK
// ============================================================================
// Creates the hole mask for boolean difference operations.
//
// Parameters:
//   insert        - Insert name from insert_specs ("M2", "M2.5", "M3", "M4")
//   type          - "blind"   : insert pocket only (default, closed bottom)
//                   "through" : insert pocket + screw clearance continuing down
//                   "insert"  : solid model of the insert itself (preview / fit)
//   depth         - Override hole depth (defaults to spec minimum hole_depth)
//   lead_in       - Small chamfer at the mouth to help align/start the insert
//   through_depth - Length of the screw clearance hole below the pocket
//                   (only used with type == "through")
//
// Geometry: Z=0 at the entry surface, hole goes to -depth.
module insert_hole_mask(insert = "M2.5", type = "blind", depth = undef,
                        lead_in = 0.4, through_depth = 10) {
  hole_d = get_insert_spec(insert, "hole_diameter");
  hole_h = is_undef(depth) ? get_insert_spec(insert, "hole_depth") : depth;
  clear_d = get_insert_spec(insert, "screw_clearance_diameter");

  eps = 0.01;

  if (type == "blind" || type == "through") {
    // Main pocket for the insert body
    translate([0, 0, -hole_h])
      cylinder(d=hole_d, h=hole_h + eps, $fn=40);

    // Lead-in chamfer at the mouth
    if (lead_in > 0) {
      translate([0, 0, -lead_in])
        cylinder(d1=hole_d, d2=hole_d + 2 * lead_in, h=lead_in + eps, $fn=40);
    }
  }

  // Screw clearance below the insert (screw longer than insert)
  if (type == "through") {
    translate([0, 0, -hole_h - through_depth])
      cylinder(d=clear_d, h=through_depth + 2 * eps, $fn=30);
  }

  // Solid representation of the insert (for preview / clash checking)
  if (type == "insert") {
    ins_d = get_insert_spec(insert, "insert_diameter");
    ins_bd = get_insert_spec(insert, "insert_bottom_diameter");
    ins_h = get_insert_spec(insert, "insert_height");
    translate([0, 0, -ins_h])
      cylinder(d1=ins_bd, d2=ins_d, h=ins_h, $fn=40);
  }
}

// ============================================================================
// BOSS HELPER
// ============================================================================
// Generates a cylindrical boss sized to safely host an insert.
// Use it *before* the difference() that carves insert_hole_mask().
//
//   difference() {
//       union() {
//           your_part();
//           translate([x, y, 0]) insert_boss("M2.5");
//       }
//       translate([x, y, 0]) insert_hole_mask("M2.5");
//   }
//
// Parameters:
//   insert - Insert name
//   height - Boss height (defaults to spec hole_depth)
//   wall   - Wall thickness around the hole (defaults to spec min_wall)
// Grows downward from Z=0, matching the hole mask convention.
module insert_boss(insert = "M2.5", height = undef, wall = undef) {
  hole_d = get_insert_spec(insert, "hole_diameter");
  w = is_undef(wall) ? get_insert_spec(insert, "min_wall") : wall;
  h = is_undef(height) ? get_insert_spec(insert, "hole_depth") : height;

  translate([0, 0, -h])
    cylinder(d=hole_d + 2 * w, h=h, $fn=40);
}
