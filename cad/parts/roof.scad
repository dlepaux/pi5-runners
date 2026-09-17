// ============================================================================
// roof — printed part
// ============================================================================
// Cut from the one shellSolid() in lib/shell.scad. Everything this part is, it is
// because of its claim; nothing here re-derives a wall position.
// ============================================================================

include <../config.scad>
use <../lib/shell.scad>

module roofPart() {
  shellPanel("roof");
}

roofPart();
