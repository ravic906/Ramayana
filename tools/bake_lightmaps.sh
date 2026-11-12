#!/usr/bin/env bash
# Bakes a level's LightmapGI with Godot's own baker, on a CPU-only server:
# the editor runs under Xvfb on Mesa's software Vulkan (lavapipe), and
# addons/baker presses "Bake Lightmaps" for the scene named in BAKE_SCENE.
#   GODOT=/path/to/godot tools/bake_lightmaps.sh res://kandas/01_bala/training_grounds.tscn
set -euo pipefail
: "${GODOT:?set GODOT to the Godot 4.7 editor binary}"
cd "$(dirname "$0")/.."
export VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}
for scene in "$@"; do
  echo "Baking $scene"
  BAKE_SCENE="$scene" BAKE_TIMEOUT_S=${BAKE_TIMEOUT_S:-5400} \
    xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" --path . --editor --rendering-driver vulkan 2>&1 \
    | grep --line-buffered -E "BAKER|ERROR: .*[Ll]ightmap|SCRIPT ERROR"
done
