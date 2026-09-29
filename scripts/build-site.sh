#!/bin/bash
# ============================================================================
# Build the download page: every STL, one zip per fan, one static index.html
# ============================================================================
#   ./scripts/build-site.sh            # into _site/, then open _site/index.html
#
# No framework, no Node: the page is written here, from the STLs just rendered, so
# the sizes it shows are MEASURED off the files it links -- never typed.
# CI runs this after the test suite and publishes _site/ to GitHub Pages.
# ============================================================================
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

OUT="${1:-_site}"

./scripts/generate-stl.sh

rm -rf "$OUT"
mkdir -p "$OUT/stl"
cp stl/*.stl "$OUT/stl/"

# Everything for one build, per fan: three of each part are printed, but one file is
# all a slicer needs.
for fan in NF-A4x10 NF-A4x20; do
    zip -jq "$OUT/pi5-runners-$fan.zip" "stl/module-$fan.stl" "stl/lid-$fan.stl" stl/filter.stl
done

size() {
    python3 scripts/lib/stl-stats.py "stl/$1.stl" --bboxes | head -1 \
        | awk '{ printf "%.1f × %.1f × %.1f mm", $1, $2, $3 }'
}
kb() { echo "$(( ($(wc -c <"stl/$1.stl") + 1023) / 1024 )) KB"; }

COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "local")
BUILT=$(date -u +%Y-%m-%d)
# Only CI runs the suite before building, so only CI says so.
TESTED=""
[ -n "${CI:-}" ] && TESTED=", after the full test suite passed"

# One download link per file.
dl() {  # dl <file> <label>
    printf '<a class="dl" href="stl/%s.stl" download>%s<span>%s</span></a>' "$1" "$2" "$(kb "$1")"
}

cat >"$OUT/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>pi5-runners</title>
<meta name="description" content="3D-printable stack for three Raspberry Pi 5 CI runners: print-ready STL files.">
<link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><text y='.9em' font-size='90'>⬢</text></svg>">
<style>
  :root {
    --bg: #f6f6f4; --card: #ffffff; --ink: #1c1f23; --muted: #62676e;
    --line: #e2e2dd; --accent: #0f766e; --accent-ink: #ffffff;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --bg: #141618; --card: #1d2023; --ink: #e8e9ea; --muted: #9aa0a6;
      --line: #2e3236; --accent: #2dd4bf; --accent-ink: #0b1514;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--bg); color: var(--ink);
    font: 16px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
  }
  main { max-width: 760px; margin: 0 auto; padding: 48px 16px 64px; }
  h1 { font-size: 2rem; margin: 0 0 4px; letter-spacing: -0.02em; }
  .lede { color: var(--muted); margin: 0 0 32px; }
  h2 { font-size: 1.05rem; margin: 0; }
  .card {
    background: var(--card); border: 1px solid var(--line); border-radius: 12px;
    padding: 20px; margin-bottom: 16px;
  }
  .head { display: flex; justify-content: space-between; align-items: baseline; gap: 12px; }
  .count { color: var(--accent); font-weight: 600; white-space: nowrap; }
  .meta { color: var(--muted); font-size: 0.9rem; margin: 4px 0 14px; }
  .row { display: flex; flex-wrap: wrap; gap: 8px; }
  .dl {
    display: inline-flex; align-items: baseline; gap: 8px; text-decoration: none;
    background: var(--accent); color: var(--accent-ink); font-weight: 600;
    padding: 9px 14px; border-radius: 8px;
  }
  .dl span { font-weight: 400; opacity: 0.8; font-size: 0.85rem; }
  .dl:hover { filter: brightness(1.08); }
  .dl.ghost { background: transparent; color: var(--accent); border: 1px solid var(--accent); }
  .note { color: var(--muted); font-size: 0.9rem; margin-top: 28px; }
  code { font-size: 0.9em; }
</style>
</head>
<body>
<main>
  <h1>pi5-runners</h1>
  <p class="lede">A stack of three modules for three Raspberry Pi 5 CI runners, one fan
  each, round dust filters. PETG, no supports. Pick the files for the 40&nbsp;mm
  Noctua you fit: <b>NF-A4x10</b> (10&nbsp;mm) or <b>NF-A4x20</b> (20&nbsp;mm).</p>

  <section class="card">
    <div class="head"><h2>Module — the shell</h2><span class="count">print ×3</span></div>
    <p class="meta">Floor down. One Pi 5 and its fan each; they stack and clip together.<br>
    NF-A4x10: $(size module-NF-A4x10) · NF-A4x20: $(size module-NF-A4x20)</p>
    <div class="row">$(dl module-NF-A4x10 "NF-A4x10") $(dl module-NF-A4x20 "NF-A4x20")</div>
  </section>

  <section class="card">
    <div class="head"><h2>Dust filter</h2><span class="count">print ×3</span></div>
    <p class="meta">Face down. Glue filter fabric into the pocket on its back, clip it into
    a module's front. Same for both fans · $(size filter)</p>
    <div class="row">$(dl filter "Dust filter")</div>
  </section>

  <section class="card">
    <div class="head"><h2>Lid — the top</h2><span class="count">print ×1</span></div>
    <p class="meta">Plate down. Clips onto the top module.<br>
    NF-A4x10: $(size lid-NF-A4x10) · NF-A4x20: $(size lid-NF-A4x20)</p>
    <div class="row">$(dl lid-NF-A4x10 "NF-A4x10") $(dl lid-NF-A4x20 "NF-A4x20")</div>
  </section>

  <section class="card">
    <div class="head"><h2>Everything</h2></div>
    <p class="meta">Module, dust filter and lid for one fan, zipped.</p>
    <div class="row">
      <a class="dl ghost" href="pi5-runners-NF-A4x10.zip" download>All parts · NF-A4x10</a>
      <a class="dl ghost" href="pi5-runners-NF-A4x20.zip" download>All parts · NF-A4x20</a>
    </div>
  </section>

  <p class="note">Also needed: 3 × Noctua 40&nbsp;mm 5V fans, 12 × M3 countersunk
  self-tappers (M3×12 for the NF-A4x10, M3×20 for the NF-A4x20), 12 × M2.5 heat-set
  inserts, filter fabric. Built from <code>$COMMIT</code> on $BUILT$TESTED.
  CC BY-NC-SA 4.0.</p>
</main>
</body>
</html>
HTML

echo "✅ $OUT/ written — open $OUT/index.html"
