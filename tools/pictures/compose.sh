#!/bin/zsh
# Lays the captures from tools/pictures.sh out into docs/images: the showcase pictures from
# compose.html (shot with headless Chromium at 2x), and the plain captures, trimmed and converted.
#   ./tools/pictures/compose.sh
set -euo pipefail
cd "${0:A:h}/../.."
RAW=build/pictures/raw
IMG=docs/images
mkdir -p $IMG build/pictures/shots
CHROME=${CHROME:-/Applications/Chromium.app/Contents/MacOS/Chromium}
PAGE="file://$PWD/tools/pictures/compose.html"

shoot() {   # name, width, height, query
    "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
        --window-size=$2,$3 --screenshot=build/pictures/shots/$1.png "$PAGE?$4" >/dev/null 2>&1
    cwebp -quiet -q 88 build/pictures/shots/$1.png -o $IMG/$1.webp
    echo "  $1.webp"
}
shoot hero-light 1280 760 "scene=hero&theme=light"
shoot hero-dark 1280 760 "scene=hero&theme=dark"
shoot share-light 1280 620 "scene=share&theme=light"
shoot share-dark 1280 620 "scene=share&theme=dark"
shoot cover 1280 800 "scene=cover&theme=light" && mv $IMG/cover.webp build/pictures/   # for the stuffs shelf, not the docs

# the prompter as it really draws: kept as PNG, for its see-through corners
for n in follow controls warm mirror floating; do
    magick $RAW/$n.png -strip $IMG/prompter-$n.png 2>/dev/null
done
# the windows: the scripts window in both looks (the README picks by the reader's), Settings in light
for look in light dark; do cwebp -quiet -q 90 $RAW/scripts-$look.png -o $IMG/scripts-$look.webp; done
for n in settings-prompter settings-voice; do cwebp -quiet -q 90 $RAW/$n-light.png -o $IMG/$n-light.webp; done
ls $IMG | wc -l
