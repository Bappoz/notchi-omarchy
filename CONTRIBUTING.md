# Contributing

Issues and pull requests are welcome: design, animation, accessibility, translations, integrations, documentation and bug fixes. Describe expected/actual behavior, Omarchy/Hyprland/Qt versions, steps to reproduce and relevant redacted logs. Never include account records, prompts, private project paths, API keys or personal screenshots.

For PRs, explain the problem and final behavior, add screenshots for visual changes, and describe verification. Preserve existing user data, support disabled animations, use plain-text rendering for external data, and retain third-party licenses. Keep one focused change per PR. Do not modify /usr/share/omarchy or automatically rewrite users' bar/window configuration. Changes need maintainer review; suggestions are welcome without a promise of acceptance.

Run `python -m unittest discover -s tests`. In a disposable Wayland session with QtTest and Pillow available, run `NOTCHI_UI_TESTS=1 python -m unittest discover -s tests` for native visual/input checks. The UI suite opens temporary test windows and uses isolated state; close other previews first.
