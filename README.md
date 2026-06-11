
![OneJobOwl](https://noobtrap.eu/images/crystallights/Moonkin2.png)

A Classic WoW (TBC) addon that shames Moonkins for letting **Improved Faerie Fire** fall off, and lets you track your own performance.

## Features

- **Shame Mode**: Tracks **Faerie Fire** on your target with two modes:
  - **Shame Button** (default) — A moonkin owl appears when IFF drops. Click to shame.
  - **Auto-Shame** — Automatically sends a message (no button).
- **"I Am Owl" Mode**: Self-tracking mode to grade your own IFF uptime, efficiency, and refresh timing with performance reports.
- **Visual Feedback**: A customizable, draggable Owl speech bubble that displays your performance messages in real-time.
- **Customizable Messaging**: Edit and manage your own Shame or Praise messages.
- **Audio Alerts**: Configurable sound alerts for both Shame events and "I Am Owl" praise/performance events.
- **Output Support**: Send reports/shames via Whisper, Say, Party, or Raid.
- **Advanced Tracking**: Watch specific targets by GUID, configurable sound/thresholds, and tracking scope.

## Installation

1. Download the latest version.
2. Extract the `OneJobOwl` folder into your `Interface/AddOns/` directory.
3. Restart WoW or type `/reload`.
4. Type `/ojo` to open the options panel.

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
- Enable/disable tracking.
- **Mode**: Choose between Shame Button, Auto-Shame, or **I Am Owl Mode**.
- **Track Scope**: Configure what units trigger alerts (Bosses only, Elites, etc.).

### Alerts & Reporting
- **Shame Sound**: Choose a sound to play when the shame button appears.
- **I Am Owl Sound**: Choose a custom sound to play whenever the owl speaks (Praise/Shame).
- **Warning Threshold**: Set the seconds remaining before a "clutch" refresh is detected.
- **I Am Owl Report**: Toggle your end-of-combat performance scorecard.

### UI & Output
- **Output Channel**: Choose where to send messages (Whisper, Raid, Party, Say, Yell).
- **Bubble Settings**: Toggle and configure the visual "I Am Owl" speech bubble (scale, duration, position).
- **Button Settings**: Drag, scale, and unlock the Shame button.

### Messages
- Add, edit, or delete custom Shame or Praise messages.
- Easily restore default message lists.

## Notes

- **"I Am Owl" Mode**: When active, the addon grades your performance. 
  - **Clutch Refreshes**: Refreshes performed with low time remaining trigger audio/visual praise.
  - **Performance Report**: At the end of combat, you receive a detailed summary including uptime percentage, refresh counts, and a final letter grade.
- All settings are saved per character.

## Author

**Gravebear**

---

Enjoy keeping those Moonkins honest (and grading yourself)! 🦉
Feedback and suggestions are welcome.
