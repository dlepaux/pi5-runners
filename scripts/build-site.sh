#!/bin/bash
# ============================================================================
# Build the project page: every STL, one zip per fan, one static index.html
# ============================================================================
#   ./scripts/build-site.sh            # into _site/, then serve it: python3 -m http.server -d _site
#
# No framework, no Node: the page is written here, from the STLs just rendered, so
# the sizes it shows are MEASURED off the files it links -- never typed. The figures
# quoted from the readme (case air rise, exhaust area) are the suite's, not the page's.
# Static assets (style, viewer, font, vendored three.js, hero loop) live in site/.
# Photos dropped into site/photos/ as .webp get a gallery; with none, no section.
# CI runs this after the test suite and publishes _site/ to GitHub Pages.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="${1:-_site}"

./scripts/generate-stl.sh

rm -rf "$OUT"
mkdir -p "$OUT/stl"
cp -R site/. "$OUT/"
cp stl/*.stl "$OUT/stl/"

# Everything for one build, per fan: one module, one tray, one lid and one
# filter -- three modules, trays and filters are printed, but one file is all a slicer needs.
for fan in NF-A4x10 NF-A4x20; do
    zip -jq "$OUT/pi5-runners-$fan.zip" "stl/module-$fan.stl" stl/tray.stl \
        "stl/lid-$fan.stl" stl/filter.stl
done

size() {
    python3 scripts/lib/stl-stats.py "stl/$1.stl" --bboxes | head -1 \
        | awk '{ printf "%.1f × %.1f × %.1f mm", $1, $2, $3 }'
}
kb() { echo "$(( ($(wc -c <"stl/$1.stl") + 1023) / 1024 )) KB"; }
zipkb() { echo "$(( ($(wc -c <"$OUT/pi5-runners-$1.zip") + 1023) / 1024 )) KB"; }
STL_COUNT=$(ls stl/*.stl | wc -l | tr -d ' ')

COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
BUILT=$(date -u +%Y-%m-%d)
# Only CI runs the suite before building, so only CI says so.
TESTED=""
[ -n "${CI:-}" ] && TESTED=", after the full test suite passed"

# A download button and its 3D view. <fan> is empty for parts both fans share.
dl() {  # dl <file> <label> [fan]
    local fan_attr=""
    [ -n "${3:-}" ] && fan_attr=" data-fan=\"$3\""
    printf '<a class="btn primary" href="stl/%s.stl" download%s>%s <small>%s</small></a>' \
        "$1" "$fan_attr" "$2" "$(kb "$1")"
    printf '<button class="view" type="button" data-stl="stl/%s.stl" data-title="%s"%s>View in 3D</button>' \
        "$1" "$2" "$fan_attr"
}
# The size line of a part that comes in both fan lengths.
sizes() {  # sizes <part>
    printf '<p class="size" data-fan="NF-A4x10">%s</p><p class="size" data-fan="NF-A4x20">%s</p>' \
        "$(size "$1-NF-A4x10")" "$(size "$1-NF-A4x20")"
}

PHOTOS=""
shopt -s nullglob
photos=(site/photos/*.webp)
if [ ${#photos[@]} -gt 0 ]; then
    PHOTOS='<section id="photos"><h2>Printed</h2><p class="intro">PETG, as it comes off the printer and on the shelf.</p><div class="photos">'
    for p in "${photos[@]}"; do
        name=$(basename "$p" .webp)
        PHOTOS+="<img src=\"photos/$name.webp\" alt=\"${name//-/ }\" loading=\"lazy\">"
    done
    PHOTOS+='</div></section>'
fi
PHOTOS_NAV=""
[ -n "$PHOTOS" ] && PHOTOS_NAV='<a href="#photos">Photos</a>'

cat >"$OUT/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>pi5-runners</title>
<meta name="description" content="A 3D-printable tower for three Raspberry Pi 5 GitHub Actions runners. One 40 mm Noctua per module, nothing screwed together but the fans, no supports.">
<meta name="theme-color" content="#09090b">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⬢</text></svg>">
<link rel="preload" href="fonts/archivo-variable-latin.woff2" as="font" type="font/woff2" crossorigin>
<link rel="stylesheet" href="style.css">
<script type="importmap">
{ "imports": { "three": "./vendor/three/three.module.min.js", "three/addons/": "./vendor/three/addons/" } }
</script>
</head>
<body>
<div class="wrap">
  <header class="top">
    <a class="brand" href="#">pi5-runners</a>
    <nav><a href="#why">Why this shape</a>$PHOTOS_NAV<a href="#parts">Parts</a><a href="#build">Build</a></nav>
  </header>

  <section class="hero">
    <div>
      <span class="eyebrow">OpenSCAD · PETG · no supports</span>
      <h1>Three Raspberry Pi&nbsp;5 runners in one printed tower</h1>
      <p class="lede">Three modules that clip together, one Pi&nbsp;5 and one 40&nbsp;mm Noctua
      each, built for CI jobs that hold every core at 100% for half an hour.
      Nothing is screwed together but the fans.</p>
      <div class="cta">
        <a class="btn primary" href="#parts">Download the parts</a>
        <a class="btn" href="#why">How it stays cool</a>
      </div>
      <p class="fine">Free for personal use under CC BY-NC-SA 4.0. Every part prints without
      supports, in the orientation it downloads in.</p>
    </div>
    <div class="hero-media">
      <video autoplay muted loop playsinline preload="metadata" poster="media/holo-poster.jpg"
        aria-label="The three modules and the lid pulling apart and clicking back together">
        <source src="media/holo.mp4" type="video/mp4">
      </video>
    </div>
  </section>

  <div class="figures" role="list">
    <div class="figure" role="listitem"><b>≈ 9.7 K</b><span>case air rise over the room, three NF-A4x10s, about 40 W</span></div>
    <div class="figure" role="listitem"><b>203%</b><span>exhaust area against each fan's throat</span></div>
    <div class="figure" role="listitem"><b>3 × 1</b><span>one fan per Pi, each powered from its own GPIO</span></div>
    <div class="figure" role="listitem"><b>$STL_COUNT</b><span>STL files, none needing support</span></div>
  </div>

  <section id="why">
    <h2>Why this shape</h2>
    <p class="intro">CI runners hold 100% CPU for 30 to 50 minutes at a stretch, three boards
    at once. Every decision follows from sustained load, not from idle.</p>
    <div class="grid three">
      <div class="card"><h3><span class="dot"></span>One fan per Pi</h3>
        <p>Each module is a complete unit: its own 40&nbsp;mm Noctua, screwed in from the front
        and powered from its own Pi. That is 50% more air than the two-fan column an earlier
        version shared.</p></div>
      <div class="card"><h3><span class="dot"></span>Front to back</h3>
        <p>Each fan draws through its dust filter, pushes over its own SoC and drive, and leaves
        through rearward louvres in the rear and sides. Never through the lid, which would drop
        dust on a board.</p></div>
      <div class="card"><h3><span class="dot"></span>One way in for dust</h3>
        <p>The modules run at positive pressure with a single filtered intake, so dust can only
        enter where the filter is. The ports sit in clean solid wall, flush with the outside.</p></div>
    </div>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Fans</th><th>Case air rise</th><th>Margin to the HAT's 50 °C, 25 °C room</th></tr></thead>
        <tbody>
          <tr><td>3 × NF-A4x10 5V</td><td class="hi">≈ 9.7 K</td><td class="hi">≈ 15 K</td></tr>
          <tr><td>3 × NF-A4x20 5V</td><td>≈ 8.5 K</td><td>≈ 16.5 K</td></tr>
        </tbody>
      </table>
    </div>
    <p class="caption">ΔT = Q / (ρ · c<sub>p</sub> · V̇), for about 40 W of heat. The 20&nbsp;mm fans
    buy about a kelvin, not a different class of cooling.</p>
  </section>

  <section id="holds">
    <h2>What it holds</h2>
    <p class="intro">Every module is the same part, sized for the tallest board, so any board fits
    any module. The boards are never connected to each other.</p>
    <div class="table-wrap">
      <table>
        <thead><tr><th>Module</th><th>Board</th><th>Storage</th><th>Cooling</th></tr></thead>
        <tbody>
          <tr><td>Bottom</td><td>Pi 5</td><td>M.2 HAT+ (2242 NVMe)</td><td>Active Cooler</td></tr>
          <tr><td>Middle</td><td>Pi 5</td><td>M.2 HAT+ Compact (2230 NVMe)</td><td>Active Cooler, 16 mm standoffs</td></tr>
          <tr><td>Top</td><td>Pi 5</td><td>None</td><td>Active Cooler</td></tr>
        </tbody>
      </table>
    </div>
  </section>

  $PHOTOS

  <section id="parts">
    <h2>Parts</h2>
    <p class="intro">Pick the 40&nbsp;mm Noctua you fit. It sets the length of the module and the
    lid. The tray and the filter are the same for both.</p>
    <div class="fan-pick" role="radiogroup" aria-label="Fan">
      <label><input type="radio" name="fan" id="fan-a4x10" checked> NF-A4x10 · 10 mm</label>
      <label><input type="radio" name="fan" id="fan-a4x20"> NF-A4x20 · 20 mm</label>
    </div>
    <div class="grid two">
      <div class="card part">
        <div class="head"><h3>Module</h3><span class="count">print ×3</span></div>
        <p>Floor down. One Pi&nbsp;5 and its fan each. The modules stack and clip together.</p>
        $(sizes module)
        <div class="actions">$(dl module-NF-A4x10 "Module" NF-A4x10) $(dl module-NF-A4x20 "Module" NF-A4x20)</div>
      </div>
      <div class="card part">
        <div class="head"><h3>Tray</h3><span class="count">print ×3</span></div>
        <p>Floor down. The Pi screws onto its four feet on the bench, then the tray clicks into
        the window in its module's floor.</p>
        <p class="size">$(size tray)</p>
        <div class="actions">$(dl tray "Tray")</div>
      </div>
      <div class="card part">
        <div class="head"><h3>Dust filter</h3><span class="count">print ×3</span></div>
        <p>Face down. Glue filter fabric into the pocket on its back and clip it into a module's
        front.</p>
        <p class="size">$(size filter)</p>
        <div class="actions">$(dl filter "Dust filter")</div>
      </div>
      <div class="card part">
        <div class="head"><h3>Lid</h3><span class="count">print ×1</span></div>
        <p>Plate down. Clips onto the top module. Solid, so no dust falls on a board.</p>
        $(sizes lid)
        <div class="actions">$(dl lid-NF-A4x10 "Lid" NF-A4x10) $(dl lid-NF-A4x20 "Lid" NF-A4x20)</div>
      </div>
    </div>
    <div class="card all">
      <p>A module, a tray, a filter and the lid for your fan, zipped. Print the first three ×3.</p>
      <a class="btn" data-fan="NF-A4x10" href="pi5-runners-NF-A4x10.zip" download>All parts · NF-A4x10 <small>$(zipkb NF-A4x10)</small></a>
      <a class="btn" data-fan="NF-A4x20" href="pi5-runners-NF-A4x20.zip" download>All parts · NF-A4x20 <small>$(zipkb NF-A4x20)</small></a>
    </div>
  </section>

  <section id="build">
    <h2>Build it</h2>
    <p class="intro">What happens after the download, in the order it happens.</p>
    <ol class="steps">
      <li class="card"><h3>Pi onto its tray</h3><p>On the bench. The HAT's M2.5 standoffs thread
        through the Pi into the tray's printed feet and cut their own thread. Snug, not tight.
        A bare Pi takes M2.5&nbsp;×&nbsp;6 screws.</p></li>
      <li class="card"><h3>Fan into its module</h3><p>From the front, with the four self-tapping
        screws in the fan's own bag, not M3s. The heads sink below the filter recess.</p></li>
      <li class="card"><h3>Tray into its module</h3><p>Hold it just over the floor and short of
        the rear wall, slide it back until the ports sit in their holes, then press it down until
        the four clips click. Plug the fan into that Pi's GPIO: 5&nbsp;V on pin 2 or 4, ground on 6.</p></li>
      <li class="card"><h3>Stack</h3><p>Tilt each module, hook its front clip in first, then press
        the rear down until the other three click. Click the lid onto the top one.</p></li>
      <li class="card"><h3>Filters</h3><p>Glue fabric into the pocket on the back of each filter
        and click it into its recess, over the screw heads.</p></li>
      <li class="card"><h3>You also need</h3><ul class="need">
        <li>3 × Noctua 40&nbsp;mm 5V fan, NF-A4x10 or NF-A4x20</li>
        <li>M2.5 × 6 screws, 4 per Pi without a HAT</li>
        <li>Filter fabric</li></ul></li>
    </ol>
  </section>

  <footer>
    <p>Built from <code>$COMMIT</code> on $BUILT$TESTED. Part sizes are measured off the files
    this page links.</p>
    <p>CC BY-NC-SA 4.0. Archivo is under the <a href="licences/archivo-LICENSE-OFL-1.1.txt">SIL OFL 1.1</a>,
    three.js under the <a href="licences/three-LICENSE-MIT.txt">MIT licence</a>.</p>
  </footer>
</div>

<dialog id="viewer" aria-label="Part viewer">
  <div class="bar"><div><h3></h3><span></span></div>
    <form method="dialog"><button class="close">Close</button></form></div>
  <canvas></canvas>
</dialog>
<script type="module">
  // three.js loads on the first "View in 3D", never before.
  let viewer;
  document.addEventListener('click', async (event) => {
    const button = event.target.closest('[data-stl]');
    if (!button) return;
    viewer ??= await import('./viewer.js');
    viewer.open(button.dataset.stl, button.dataset.title);
  });
</script>
</body>
</html>
HTML

./scripts/test-site.sh "$OUT"
echo "✅ $OUT/ written — serve it with: python3 -m http.server -d $OUT"
