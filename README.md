# ReWind

Combo Strikes mastery tracker for Windwalker Monks. Shows your recent ability history so you never break mastery, and tells you off when you do.

Retail (12.0+) only. Uses `UNIT_SPELLCAST_SUCCEEDED` instead of `COMBAT_LOG_EVENT_UNFILTERED` so it works inside instances under the current addon restrictions.

## Features

| Feature | Description |
|---|---|
| **Ability History Strip** | Horizontal or vertical row of spell icons showing your last N abilities (2-12). Newest icon is full-size; older ones shrink and fade. Mastery breaks get a red border and glow. |
| **Growth Direction** | Strip can grow left, right, up, or down. |
| **Mastery Break Alerts** | Configurable sound when you repeat the same ability. |
| **Combat Reports** | End-of-fight summary with mastery uptime %, cast count, and itemised breaks. Colour-coded green/yellow/red. Keystone runs get aggregate reports. |
| **Zenith Ready Alert** | Sound and visual flash when Zenith comes off cooldown. Configurable glow style (pulse, proc flipbook, classic ants), colour, and intensity. |
| **Zenith Ready Icon** | Standalone movable spell icon shown while Zenith is available. Configurable size, opacity, and glow. |
| **Tiger Palm Warning** | Sound alert when you waste a GCD on Tiger Palm during the Zenith window. |
| **Cooldown Idle Warnings** | Alert when Touch of Death or Strike of the Windlord sit available too long during combat. Configurable delay threshold. |
| **Next Spell (Blizzard)** | Standalone movable icon showing Blizzard's `C_AssistedCombat` recommendation. Hidden if the API isn't available. |
| **Encounter Timeline** | Scrollable cast log with timestamps and break markers. Exportable as CSV. Auto-show after fights or open with `/rw timeline`. |
| **Aura Scanner** | Tracks player buffs (Zenith, BK!, Dance of Chi-Ji, Tigereye Brew) using the 12.0.5 aura instance API with taint-safe fallbacks. |
| **Unlock Overlays** | All movable frames show their name when unlocked for easy repositioning. Click-through when locked. |
| **Panel Appearance** | Configurable background opacity, LSM border texture selection, icon opacity and fade settings. |
| **Combat-Only Mode** | Separate "only in combat" toggles for the ability panel and zenith icon. Uses alpha instead of Show/Hide to avoid protected frame issues. |
| **Configurable Sounds** | Curated list of WoW sounds for all alerts, plus custom SoundKit ID input. Test buttons in config. |

## Tracked Abilities

The spell table matches the 13 active Combo Strikes entries:

Tiger Palm, Blackout Kick, Rising Sun Kick, Rushing Wind Kick, Fists of Fury, Spinning Crane Kick, Whirling Dragon Punch, Strike of the Windlord, Crackling Jade Lightning, Touch of Death, Slicing Winds, Celestial Conduit, Zenith Stomp.

Zenith itself doesn't trigger mastery but is tracked separately for cooldown alerts.

## Slash Commands

| Command | Action |
|---|---|
| `/rw` | Toggle display |
| `/rw config` | Open settings |
| `/rw timeline` | Show last encounter timeline |
| `/rw lock` | Lock/unlock all frames |
| `/rw reset` | Clear ability history |
| `/rw debug` | Toggle debug logging |
| `/rw test` | Inject test data |
| `/rl` | Reload UI (registered if not taken) |

## Installation

Clone into your WoW addons directory, then run `./download_deps.sh` (or `download_deps.ps1` on Windows) to pull libraries. Both scripts read from `.pkgmeta` so the dependency list is never duplicated. Or install via CurseForge.

## Dependencies

- Ace3 (AceAddon, AceDB, AceEvent, AceConsole, AceGUI, AceConfig)
- LibSharedMedia-3.0
- AceGUI-3.0-SharedMediaWidgets
