// ============================================================================
// SCREW SPECIFICATIONS & HOLE API
// ============================================================================
// Complete screw management: specifications, helper functions, and hole masks.
// All geometry starts at origin [0,0,0] - position with translate()
//
// Usage:
//   include <lib/screws.scad>
//
//   difference() {
//       your_part();
//       translate([x, y, z]) screw_hole_mask("M3-16", "front", front_depth=3);
//   }
// ============================================================================

// ============================================================================
// SCREW SPECIFICATIONS
// ============================================================================
// Normalized screw specifications for different sizes
// Format: [name, thread_diameter, pilot_hole_diameter, through_hole_diameter, 
//          head_diameter, head_height, countersink_diameter, countersink_depth, 
//          min_engagement_depth]
//
// Key measurements:
//   thread_diameter       - Nominal screw size (3mm for M3, 4mm for M4, etc.)
//   pilot_hole_diameter   - Hole where screw threads into and grips material (self-tapping)
//   through_hole_diameter - Clearance hole (screw slides through freely, no threading)
//   head_diameter         - Size of screw head (for clearance calculations)
//   head_height           - Thickness of screw head
//   countersink_diameter  - Diameter at top of countersink cone (typically 2× thread diameter)
//   countersink_depth     - Depth of countersink recess for flush mounting
//   min_engagement_depth  - Minimum depth needed for secure threading (typically 2× thread diameter)
pilot_hole_small_thread_factor = 0.98;
pilot_hole_regular_thread_factor = 0.97;
pilot_hole_large_thread_factor = 0.95;
screw_specs = [
  [
    // name
    "M2.5-4",
    // thread_diameter
    2.47,
    // pilot_hole_diameter
    2.47 * pilot_hole_small_thread_factor,
    // through_hole_diameter
    2.5,
    // head_diameter
    5.05,
    // head_height
    0.5,
    // countersink_diameter
    5.5,
    // countersink_depth
    0.4,
    // min_engagement_depth
    4.5,
  ],
  [
    // name
    "M3-16",
    // thread_diameter
    2.9,
    // pilot_hole_diameter
    2.9 * pilot_hole_small_thread_factor,
    // through_hole_diameter
    3.0,
    // head_diameter
    5.5,
    // head_height
    1.8,
    // countersink_diameter
    6.0,
    // countersink_depth
    1.5,
    // min_engagement_depth
    16.0,
  ],
  [
    // name
    "M3-30",
    // thread_diameter
    2.9,
    // pilot_hole_diameter
    2.9 * pilot_hole_small_thread_factor,
    // through_hole_diameter
    3.0,
    // head_diameter
    5.5,
    // head_height
    1.8,
    // countersink_diameter
    6.0,
    // countersink_depth
    1.5,
    // min_engagement_depth
    30.0,
  ],
  [
    // name
    "M3-10",
    // thread_diameter
    2.9,
    // pilot_hole_diameter
    2.9 * pilot_hole_small_thread_factor,
    // through_hole_diameter
    3.0,
    // head_diameter
    5.4,
    // head_height
    1.7,
    // countersink_diameter
    6.0,
    // countersink_depth
    1.4,
    // min_engagement_depth
    10.0,
  ],
  [
    // name
    "M3.5-20",
    // thread_diameter
    3.35,
    // pilot_hole_diameter
    2.6,
    // through_hole_diameter
    3.5,
    // head_diameter
    6.8,
    // head_height
    2.58,
    // countersink_diameter
    7.0,
    // countersink_depth
    2.7,
    // min_engagement_depth
    20,
  ],
  [
    // name
    "M4-50",
    // thread_diameter
    3.9,
    // pilot_hole_diameter
    3.9 * pilot_hole_small_thread_factor,
    // through_hole_diameter
    4.0,
    // head_diameter
    7.25,
    // head_height
    2.55,
    // countersink_diameter
    8.0,
    // countersink_depth
    2.0,
    // min_engagement_depth
    52.0,
  ],
  [
    // name
    "M5-Noctua",
    // thread_diameter
    4.8,
    // pilot_hole_diameter
    4.8 * pilot_hole_regular_thread_factor,
    // through_hole_diameter
    5.0,
    // head_diameter
    7.05,
    // head_height
    1.4,
    // countersink_diameter
    7.5,
    // countersink_depth
    1.5,
    // min_engagement_depth
    10.0,
  ],
];

// Helper functions to retrieve screw specifications
function get_screw_index(name) =
  search([name], screw_specs)[0];

function get_screw_spec(name, property) =
  let (
    idx = get_screw_index(name),
    spec = screw_specs[idx]
  ) property == "name" ? spec[0]
  : property == "thread_diameter" ? spec[1]
  : property == "pilot_hole_diameter" ? spec[2]
  : property == "through_hole_diameter" ? spec[3]
  : property == "head_diameter" ? spec[4]
  : property == "head_height" ? spec[5]
  : property == "countersink_diameter" ? spec[6]
  : property == "countersink_depth" ? spec[7]
  : property == "min_engagement_depth" ? spec[8]
  : undef;

// ============================================================================
// SCREW HOLE MASK

// ============================================================================
// SCREW HOLE MASK
// ============================================================================
// Creates a complete screw hole mask for boolean difference operations.
//
// Parameters:
//   screw       - Screw size name from screw_specs ("M3-16", "M4", "M5")
//   type        - "front" (countersink + pass-through)
//                 "back"  (pilot hole only)
//                 "through" (pass-through hole only, no countersink)
//                 "both"  (complete assembly for preview)
//   front_depth - Depth of pass-through section (material thickness)
//   back_depth  - Depth of pilot hole (thread engagement)
//
// Geometry:
//   Z=0 is at the countersink top surface (screw head flush point)
//   Front section extends from Z=0 to Z=-front_depth
//   Back section extends from Z=-front_depth to Z=-(front_depth+back_depth)
//
//        ┌─────────┐  Z=0 (countersink top)
//         ╲       ╱   countersink cone
//          │     │    pass-through hole
//   ───────┴─────┴─── Z=-front_depth (interface)
//           │   │     pilot hole (narrower)
//           └───┘     Z=-(front_depth+back_depth)

module screw_hole_mask(screw = "M3-16", type = "both") {
  // Get screw specifications
  through_d = get_screw_spec(screw, "through_hole_diameter");
  pilot_d = get_screw_spec(screw, "pilot_hole_diameter");
  csink_d = get_screw_spec(screw, "countersink_diameter");
  csink_depth = get_screw_spec(screw, "countersink_depth");
  min_engagement_depth = get_screw_spec(screw, "min_engagement_depth");

  eps = 0.01; // Small value for clean boolean operations

  // Front section: countersink + pass-through hole
  if (type == "front" || type == "both") {
    // Countersink cone (top of screw head)
    translate([0, 0, -csink_depth])
      cylinder(d1=through_d, d2=csink_d, h=csink_depth + eps, $fn=30);

    // Pass-through hole (screw shaft clearance)
    translate([0, 0, -min_engagement_depth - eps])
      cylinder(d=through_d, h=min_engagement_depth - csink_depth + 2 * eps, $fn=30);
  }

  // Through hole only (no countersink)
  if (type == "through") {
    translate([0, 0, -min_engagement_depth - eps])
      cylinder(d=through_d, h=min_engagement_depth + 2 * eps, $fn=30);
  }

  // Back section: pilot hole (threads grip here)
  if (type == "back" || type == "both") {
    translate([0, 0, -min_engagement_depth - eps])
      cylinder(d=pilot_d, h=min_engagement_depth + 4 * eps, $fn=30);
  }
}

// ============================================================================
// HELPER: Get all hole diameters for a screw size
// ============================================================================
// Returns [through_hole_d, pilot_hole_d, countersink_d]
function get_screw_holes(screw) =
  [
    get_screw_spec(screw, "through_hole_diameter"),
    get_screw_spec(screw, "pilot_hole_diameter"),
    get_screw_spec(screw, "countersink_diameter"),
  ];
