#!/bin/sh
# Refait toutes les vignettes des circuits (resources/vignettes/), un
# lancement de Godot par circuit. Il faut un écran : xvfb-run en fournit un.
#
#   tools/vignettes.sh [godot] [id…]
cd "$(dirname "$0")/.." || exit 1
GODOT=${1:-godot}
[ $# -gt 0 ] && shift
IDS=$*
if [ -z "$IDS" ]; then
	for fiche in $(grep -o 'res://resources/tracks/[a-z0-9_]*_info.tres' scripts/race/track_catalog.gd); do
		IDS="$IDS $(grep -m1 '^id = ' "${fiche#res://}" | sed 's/id = "//; s/"//')"
	done
fi
for id in $IDS; do
	xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --path . --resolution 1280x720 \
		--rendering-driver opengl3 -s tools/lance_outil.gd -- vignettes "$id" 6 2>&1 | grep -E "^vignette|ERROR" | head -3
done
