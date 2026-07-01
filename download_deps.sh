#!/bin/bash
set -euo pipefail

mkdir -p Libs

deps=(
  "LibStub|https://repos.wowace.com/wow/libstub/trunk"
  "CallbackHandler-1.0|https://repos.wowace.com/wow/callbackhandler/trunk/CallbackHandler-1.0"
  "AceAddon-3.0|https://repos.wowace.com/wow/ace3/trunk/AceAddon-3.0"
  "AceEvent-3.0|https://repos.wowace.com/wow/ace3/trunk/AceEvent-3.0"
  "AceDB-3.0|https://repos.wowace.com/wow/ace3/trunk/AceDB-3.0"
  "AceConsole-3.0|https://repos.wowace.com/wow/ace3/trunk/AceConsole-3.0"
  "AceGUI-3.0|https://repos.wowace.com/wow/ace3/trunk/AceGUI-3.0"
  "AceConfig-3.0|https://repos.wowace.com/wow/ace3/trunk/AceConfig-3.0"
)

for entry in "${deps[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  echo "Checking out Libs/${name}..."
  svn checkout "$url" "Libs/${name}"
  echo "Done."
done
