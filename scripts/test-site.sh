#!/bin/bash
# ============================================================================
# Every file the built page points at exists in the build
# ============================================================================
#   ./scripts/test-site.sh _site
#
# build-site.sh runs this last, so a renamed STL or a missing asset fails the
# build instead of shipping a dead button. External links are not followed: the
# page is meant to load nothing from another site. Links a visitor follows (<a href> to
# the repo) are not loads, so they are dropped before the scan.
# ============================================================================
set -euo pipefail
SITE="${1:?usage: test-site.sh <built site dir>}"
PAGE="$SITE/index.html"
[ -s "$PAGE" ] || { echo "❌ no $PAGE"; exit 1; }

# Everything the page or its viewer will request: links, sources, posters, part views,
# the import map's targets and the viewer module itself.
refs=$(sed -E 's/(<a [^>]*)href="https?:\/\/[^"]*"/\1/g' "$PAGE" \
    | grep -oE '(href|src|poster|data-stl)="[^"#][^"]*"' | sed -E 's/^[a-z-]+="//; s/"$//' \
    | grep -v '^data:')
refs+=$'\n'$(grep -oE '"\./[^"]+"' "$PAGE" | tr -d '"' | sed 's|^\./||')

FAILED=0
COUNT=0
while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    case "$ref" in
        http://*|https://*|//*) echo "❌ third-party request: $ref"; FAILED=1; continue ;;
    esac
    COUNT=$((COUNT + 1))
    # An import-map prefix ("vendor/three/addons/") is a directory.
    if [ ! -e "$SITE/$ref" ]; then echo "❌ missing: $ref"; FAILED=1; fi
done <<<"$refs"

# The viewer imports its addons through the map, so they must be where the prefix says.
for addon in STLLoader OrbitControls; do
    grep -q "three/addons/$addon.js" "$SITE/viewer.js" \
        && [ -s "$SITE/vendor/three/addons/$addon.js" ] \
        || { echo "❌ viewer addon not served: $addon"; FAILED=1; }
done

[ "$FAILED" -eq 0 ] || exit 1
echo "✅ page references: $COUNT, all present"
