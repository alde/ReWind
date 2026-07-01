# ReWind

Combo Strikes mastery tracker for Windwalker Monks. Shows your recent ability history so you never break mastery, and tells you off when you do.

Built for **Midnight 12.0.7**. Uses `UNIT_SPELLCAST_SUCCEEDED` instead of `COMBAT_LOG_EVENT_UNFILTERED` so it works inside instances under the 12.0 addon restrictions.

## Features

### Ability History Strip
A horizontal row of spell icons showing your last N abilities (configurable, 2–12). The most recent ability is full-size and full opacity; older ones shrink and fade. Mastery breaks get a red border and glow so they're impossible to miss.

### Mastery Break Alerts
Plays a sound when you cast the same ability twice in a row. Toggleable.

### Combat Reports
Prints a summary to chat at the end of each fight and M+ run:
```
Combat end — 98.5% mastery uptime (65/66 casts, 1 break)
  Breaks: Tiger Palm x1
```
Colour-coded: green for 100%, yellow for 95%+, red below. Breaks itemised by spell. Keystone runs get an aggregate report on completion.

### Zenith Ready Alerts
Sound + visual flash when Zenith or Zenith Stomp comes off cooldown. Toggleable.

### Next Spell (Blizzard)
Optional display of Blizzard's `C_AssistedCombat` recommended next ability (12.0+ only). Off by default — the config toggle is hidden on pre-12.0 clients. Take the suggestions with a healthy dose of scepticism.

## Slash Commands

| Command | Action |
|---|---|
| `/rw` | Toggle display |
| `/rw config` | Open settings |
| `/rw lock` | Lock/unlock frame position |
| `/rw reset` | Clear ability history |
| `/rw test` | Inject test data (including a deliberate mastery break) |

## Configuration

All settings available via `/rw config` or the WoW addon settings panel:

**Display:** Show/hide panel, lock position, history length, icon size, opacity fade rate, minimum opacity.

**Behaviour:** Mastery break sound, combat report, Zenith ready alert, Blizzard next-spell display, clear history on combat end.

## Installation

Clone into your WoW addons directory, then run `./download_deps.sh` to pull Ace3 libraries, or install via CurseForge.

## Dependencies

- Ace3 (AceAddon, AceDB, AceEvent, AceConsole, AceGUI, AceConfig)
