![](https://noobtrap.eu/images/crystallights/Moonkin2.png)


A Classic WoW (TBC) addon that shames Moonkins for letting **Improved Faerie Fire** fall off.

## Features

- Tracks **Faerie Fire** on your target
- Two modes:
  - **Shame Button** (default) — A moonkin owl appears when IFF drops. Click to shame.
  - **Auto-Shame** — Automatically sends a message (no button)
- Fully customizable shame messages
- Supports whispering a designated Moonkin or chat channel selection.
- Can watch a specific boss by GUID (great for multi-target fights)
- Configurable sound, threshold, tracking scope (bosses only / elites / everything)
- Draggable shame button with scale options

## Installation

1. Download the latest version
2. Extract the `OneJobOwl` folder into your `Interface/AddOns/` directory
3. Restart WoW or type `/reload`
4. Type `/ojo` to open the options panel

## Slash Commands

| Command         | Description |
|-----------------|-----------|
| `/ojo`          | Open options panel |
| `/ojo test`     | Send a test shame message |
| `/ojo button`   | Preview the shame button |
| `/shame <name>` | Set your Moonkin (whisper target) |
| `/shame target` | Set Moonkin from current target |
| `/shameclear`   | Clear Moonkin target |
| `/fftarget`     | Watch FF on current target (clears after combat) |
| `/ffclear`      | Stop watching specific enemy |

## Configuration

Open the options panel with `/ojo`:

### General
- Enable/disable tracking
- Mode: Shame Button or Auto-Shame
- Track on: Bosses only, Bosses & Elites, or Everything

### Output
- Channel (Whisper, Raid, Party, Say, Yell)
- Moonkin name (for whispering)

### Alerts
- Sound on button pop
- Warning threshold (seconds remaining)

### Shame Button
- Unlock to drag
- Button scale

### Shame Messages
- Edit, add, or delete messages
- Restore defaults

## Default Shame Messages

Includes dozens of funny roasts like:
- "You had one job, owl..."
- "Laser chicken, your Improved Faerie Fire is missing again."
- "Your Faerie Fire uptime is a war crime."

## Notes

- Works best when the Moonkin has the addon too (for receiving whispers), but not required.
- The FF Enemy feature (`/fftarget`) is perfect for bosses with adds.
- All settings are saved per character.

## Author

**Gravebear**

---

Enjoy keeping those Moonkins honest! 🦉
Feedback and suggestions are welcome.
