# ReWind

Combo Strikes mastery tracker for Windwalker Monks. Shows your recent ability history so you never break mastery, and tells you off when you do.

Retail only. Uses `UNIT_SPELLCAST_SUCCEEDED` instead of `COMBAT_LOG_EVENT_UNFILTERED` so it works inside instances under the current addon restrictions.

## Features

### Ability History Strip
A horizontal row of spell icons showing your last N abilities (configurable, 2–12). The most recent ability is full-size and full opacity; older ones progressively shrink and fade. Mastery breaks get a red border and glow so they're impossible to miss.

### Mastery Break Alerts
Plays a sound when you cast the same ability twice in a row. Toggleable.

### Combat Reports
Prints a summary to chat at the end of each fight and M+ run:
```
Combat end — 98.5% mastery uptime (65/66 casts, 1 break)
  Breaks: Tiger Palm x1
```
Colour-coded: green for 100%, yellow for 95%+, red below that. Breaks are itemised by spell name. Keystone runs get an aggregate report on completion or reset.

### Zenith Ready Alerts
Sound and visual flash when Zenith or Zenith Stomp comes off cooldown. Toggleable.

### Encounter Timeline
Scrollable cast log showing every ability used during a fight with timestamps and mastery break markers. Exportable as CSV — hit the Export button, Ctrl+A, Ctrl+C, and paste it wherever you like. No WarcraftLogs upload needed. Can auto-show after each fight or be opened manually with `/rw timeline`.

### Next Spell (Blizzard)
Optional display of Blizzard's `C_AssistedCombat` recommended next ability. Off by default — the config toggle is hidden if the API isn't available. Take the suggestions with a healthy dose of scepticism.

## Tracked Abilities

The spell table matches the 13 active `Combo Strikes:` entries on Wowhead:

- Tiger Palm
- Blackout Kick
- Rising Sun Kick
- Rushing Wind Kick
- Fists of Fury
- Spinning Crane Kick
- Whirling Dragon Punch
- Strike of the Windlord
- Crackling Jade Lightning
- Touch of Death
- Slicing Winds
- Celestial Conduit
- Zenith Stomp

Zenith itself doesn't trigger mastery but is tracked separately for the cooldown-ready alert.

## Slash Commands

| Command | Action |
|---|---|
| `/rw` | Toggle display |
| `/rw config` | Open settings |
| `/rw timeline` | Show last encounter timeline |
| `/rw lock` | Lock/unlock frame position |
| `/rw reset` | Clear ability history |
| `/rw test` | Inject test data (including a deliberate mastery break) |

## Configuration

All settings available via `/rw config` or the WoW addon settings panel:

**Display:** Show/hide panel, lock position, history length (2–12), icon size (20–64px), opacity fade rate, minimum opacity.

**Behaviour:** Mastery break sound, combat report, Zenith ready alert, Blizzard next-spell display, auto-show timeline, clear history on combat end.

## Installation

Clone into your WoW addons directory, then run `./download_deps.sh` to pull Ace3 libraries, or install via CurseForge.

## Dependencies

- Ace3 (AceAddon, AceDB, AceEvent, AceConsole, AceGUI, AceConfig)
