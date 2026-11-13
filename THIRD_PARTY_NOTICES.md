Notchi for Omarchy is an independent Linux/Omarchy adaptation inspired by
OpenNotchi, by nannndev and the OpenNotchi contributors:
https://github.com/nannndev/OpenNotchi

NotchShape.qml, the UI layout and motion profiles adapt the macOS SwiftUI
and Windows implementation at revision 817e2e0b3464e8df01cace0acdc354de24c9f403.
The provider PNGs in assets/providers are copied from its macOS Resources.
Its MIT license and copyright notice are preserved in LICENSE. No affiliation
is implied. docs/UI_REFERENCE.md maps original files to the adaptation.

The SVG icons in assets/icons use Lucide, the same icon library used by the
OpenNotchi Windows app: https://github.com/lucide-icons/lucide
Revision: 53fab88ff9d1b48f4704b5b5b560d6b4d560bf4c. White stroke and local aliases
are adaptations. ISC and Feather MIT notices are in assets/icons/LICENSE.
Filled playback controls/captions use simple locally reconstructed geometry.
Apple SF Symbols are not bundled.

Inter Variable is bundled from https://github.com/rsms/inter under the
SIL Open Font License. Its notice is in assets/fonts/LICENSE.txt.

Offline prayer calculations use PrayTime v3.2 by Hamid Zarrabi-Zadeh:
https://github.com/zarrabi/praytime
The unmodified calculator is in vendor/praytime.cjs and its MIT license is
in vendor/LICENSE.

Omarchy's own panels and commands are used from the installed operating
system. Their source files are not copied or modified by this plugin.

Optional data sources: Open-Meteo (weather), LRCLIB (lyrics), Frankfurter
(reference currency rates), CoinGecko (crypto), Alpha Vantage (stocks),
Home Assistant and Spotify Web API. Requests occur only after a user action.

File sharing launches the existing LocalSend app with the selected local files.
LocalSend is not bundled: https://github.com/localsend/localsend

Transparent provider SVGs (claude, codex, agy, cursor) are from
Omarchy's MIT-licensed agents plugin assets, installed on this computer:
https://github.com/omacom/omarchy/tree/quattro/shell/plugins/agents/assets
The MIT copyright notice is in assets/providers/LICENSE.omarchy.

The Copilot SVG is the official copilot-24 from GitHub Primer Octicons:
https://github.com/primer/octicons/blob/main/icons/copilot-24.svg
White fill is a local adaptation. Its MIT notice is in assets/providers/LICENSE.octicons.

The GPT mint-knot and Claude animated/static sprites in assets/mascots are
unaltered assets from SaiTejaVoonna/mascot-for-agents (gpt-v5 and claude-v5),
commit 5a3c68b7b5e21ab02944f28153c4d40abb04e244.
https://github.com/SaiTejaVoonna/mascot-for-agents
Copyright (c) 2026 Emote Garden contributors. MIT notice included in
assets/mascots/LICENSE; selected expressions listed in assets/mascots/SOURCE.md.
This is community artwork, not official OpenAI or Anthropic artwork.
The earlier locally drawn pet geometry was replaced by these sprites.

Version 0.5 renders new eye-only native 2D rigs in ui/AgentPet.qml.
ui/Knot.js adapts the scanline silhouette geometry from the same MIT source's
assets/mascots/gpt/silhouette.json (commit recorded above).
Facial panel, eye-only expressions, keyboard, thought cloud, glasses/book and
magnifying glass rigs are implemented locally; existing GIFs are kept as reference.
No raster source image was edited to create the active models.

ILoveNotch by niyamvora (https://github.com/niyamvora/ILoveNotch) informed
the task and usage-dashboard organization. No Swift code or artwork from that
project is bundled; the Omarchy implementation uses native Qt components.
