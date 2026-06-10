![](https://noobtrap.eu/images/crystallights/Moonkin2.png)

A Classic WoW (TBC) addon that shames Moonkins for letting **Improved Faerie Fire** fall off, and lets you track your own performance.

## Features

- **Shame Mode**: Tracks **Faerie Fire** on your target with two modes:
  - **Shame Button** (default) — A moonkin owl appears when IFF drops. Click to shame.
  - **Auto-Shame** — Automatically sends a message (no button).
- **"I Am Owl" Mode**: Self-tracking mode to grade your own IFF uptime with performance reports.
- **Customizable Messaging**: Edit and manage both your Shame and Praise messages.
- **Support for Whispers/Chat Channels**: Send reports/shames via Whisper, Say, Party, or Raid.
- **Advanced Tracking**: Watch specific bosses by GUID, configurable sound/thresholds, and tracking scope.
- **Draggable UI**: Fully draggable shame button with adjustable scale.

## Installation

1. Download the latest version
2. Extract the `OneJobOwl` folder into your `Interface/AddOns/` directory
3. Restart WoW or type `/reload`
4. Type `/ojo` to open the options panel

## Slash Commands

| Command | Description |
|---|---|
| `/ojo` | Open options panel |
| `/ojo test` | Send a test shame message |
| `/ojo button` | Preview the shame button |
| `/shame <name>` | Set your Moonkin (whisper target) |
| `/shame target` | Set Moonkin from current target |
| `/shameclear` | Clear Moonkin target |
| `/fftarget` | Watch FF on current target (clears after combat) |
| `/ffclear` | Stop watching specific enemy |

## Configuration

Open the options panel with `/ojo`:

### General
- Enable/disable tracking
- Mode: Shame Button, Auto-Shame, or **I Am Owl Mode**
- Track on: Bosses only, Bosses & Elites, or Everything

### Output
- Channel (Whisper, Raid, Party, Say, Yell)
- Moonkin name (for whispering)

### Alerts & Reporting
- Sound on button pop
- Warning threshold (seconds remaining)
- **I Am Owl Report**: Toggle performance scorecard at end of combat

### Shame Button
- Unlock to drag
- Button scale

### Messages
- Edit, add, or delete Shame or Praise messages
- Restore defaults

## Notes

- **"I Am Owl" Mode**: When enabled, the addon tallies your uptime, refresh efficiency, and downtime, providing a letter-grade report at the end of combat.
- Works best when the Moonkin has the addon too (for receiving whispers), but not required.
- The FF Enemy feature (`/fftarget`) is perfect for bosses with adds.
- All settings are saved per character.

## Author

**Gravebear**

---

Enjoy keeping those Moonkins honest (and grading yourself)! 🦉
Feedback and suggestions are welcome.
