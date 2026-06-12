# OneJobOwl

![OneJobOwl](https://noobtrap.eu/images/crystallights/Moonkin2.png)

OneJobOwl is a Classic WoW (TBC) addon with one purpose: **Faerie Fire uptime, enforced by owl.** If you're not the Moonkin, pick one and shame them when Faerie Fire expires on the target. If you *are* the Moonkin, enable **"I Am Owl"** mode and the owl grades you instead — praising clutch refreshes, shaming drops, and handing you a full report card at the end of the raid.

## Features

*   **Shame Mode** 💩 — (For Non-Moonkins) Tracks Faerie Fire on your target, two ways:
    *   **Shame Button** (default) — A moonkin owl pops up when FF drops. Left-click to send the shame, right-click to forgive (this time).
    *   **Auto-Shame** — Sends the message automatically, no button, no mercy.
*   **"I Am Owl" Mode** 🦉 — Self-tracking for Moonkins/druids.
    *   **Clutch refresh praise** — Refresh FF with seconds to spare and the owl praises you.
    *   **Drop shaming** — Let it fall off a living, attackable target and the owl will shame you.
    *   **After-battle report** — End of combat: uptime %, refresh count, downtime, and a colored letter grade.
*   **The Report Card** 🪶 — A parchment school-report of your whole session:
    *   Every graded encounter logged with its name, zone, grade, and stats.
    *   Scrollable encounter list, combined statistics, and a big colored **final grade**.
    *   Pops up automatically when you **leave the group/raid**; reopen anytime with `/ojo card`.
    *   Survives `/reload` (saved per character); a fresh session starts when you join a new group.
*   **Two-Faced Owl** — The speech-bubble owl swaps faces with its mood: happy for praise and good grades, mad for shames and C+/C/D/F report cards.
*   **Smart Detection** — The owl is harsh, but fair:
    *   **Phase forgiveness** — Bosses that vanish, fly off, or go unattackable (Solarian's void phase, Al'ar's rebirth, Kael's early phases, Lurker's submerge) don't earn you a shame when FF expires mid-phase. You get a clean re-arm when they return.
    *   **Death forgiveness** — A mob that dies with FF still on it is a job well done, not a drop.
    *   **Verified drops** — Every drop is double-checked after a short delay before anyone gets shamed, so death races and event-order quirks can't frame you.
    *   **Missed-drop safety net** — If a drop slips past live detection (tab-targeting at the wrong moment, etc.), the recast exposes it: the gap is billed as downtime and counted as a drop. No accidental S grades.
*   **Visual Feedback** — A draggable, scalable owl speech bubble with independent balloon scaling and configurable display duration.
*   **Customizable Messaging** — Add, edit, and delete your own Shame and Praise messages (200+ shames included), with one-click restore of defaults.
*   **Audio Alerts** — Separate configurable sounds for Shame events and for "I Am Owl" praise/reports, from a big list of in-game classics.
*   **Output Support** — Bubble on screen, or send to Whisper, Say, Yell, Party, or Raid (color codes are stripped automatically for chat channels).
*   **Advanced Tracking** — Watch a specific enemy by GUID with `/fftarget` (bypasses scope filters, clears when combat ends), configurable clutch threshold, and tracking scope (bosses only, elites, everything).
*   **Built-in Diagnostics** — `/ojo debug` walks the entire detection chain on your current target with PASS/FAIL per check, so "why is the owl quiet?" takes one command to answer.

## Grading Scale

| Grade | Score | Color |
| ----- | ----- | ----- |
| S | 97+ | Purple |
| A+ / A / A- | 80–96 | Green |
| B+ / B / B- | 65–79 | Light Green |
| C+ / C | 55–64 | Yellow |
| D | 50–54 | Orange |
| F | below 50 | Red |

The score is built from uptime % and refresh tightness, minus penalties for drops and total downtime. The final report-card grade is the average of your per-fight scores.

## Installation

1.  Download the latest version.
2.  Extract the `OneJobOwl` folder into your `Interface/AddOns/` directory.
3.  **Fully restart WoW** (a `/reload` is only enough when updating files that already existed — new files and textures need a restart).
4.  Type `/ojo` to open the options panel.

## Slash Commands

| Command | Description |
| ------------- | ------------------------------------------------ |
| `/ojo` | Open the options panel |
| `/ojo test` | Send a test shame message |
| `/ojo button` | Preview the shame button |
| `/ojo owl` | Preview the owl speech bubble |
| `/ojo card` | Open the session Report Card |
| `/ojo debug` | Print detection diagnostics for your current target |
| `/ojoclear` | Clear the session Report Card |
| `/shame <name>` | Set your Moonkin (whisper target) |
| `/shame target` | Set Moonkin from your current target |
| `/shame` | Show who's currently on the hook |
| `/shameclear` | Clear the Moonkin target |
| `/fftarget` | Watch FF on your current target by GUID (clears when combat ends) |
| `/ffclear` | Stop watching the specific enemy |

## Configuration

Open the options panel with `/ojo`:

### General
*   Enable/disable tracking.
*   **Mode**: Shame Button, Auto-Shame, or **I Am Owl**.
*   **Track Scope**: What triggers alerts (Bosses only, Elites, etc.). `/fftarget` always bypasses this — you picked it, so it matters.
*   Combat-only tracking toggle.

### Alerts & Reporting
*   **Shame Sound**: Plays when the shame button appears.
*   **I Am Owl Sound**: Plays whenever the owl speaks (praise, shame, or report).
*   **Clutch Threshold**: Seconds remaining that count as a "clutch" refresh.
*   **I Am Owl Report**: Toggles the end-of-combat scorecard **and** the automatic Report Card on group leave. (Encounters are still logged silently while off, and `/ojo card` always works.)

### UI & Output
*   **Output Channel**: Bubble, Whisper, Raid, Party, Say, or Yell.
*   **Bubble Settings**: Scale, balloon scale, duration, and an unlock mode to drag the owl into position.
*   **Button Settings**: Scale, glow color, and an unlock mode to drag the button.

### Messages
*   Add, edit, or delete custom Shame and Praise messages.
*   Restore the default lists with one click.

## Notes

*   Without a designated Moonkin (`/shame <name>`), the addon tracks only for druids — any form, Balance or Feral.
*   With a Moonkin designated, anyone can run the watch (raid-lead mode) and shames are whispered to the owl on the hook.
*   The Report Card belongs to the group session: joining a group wipes the slate, leaving presents the parchment. Fights done solo are logged too and viewable with `/ojo card`.
*   All settings, messages, and the current session log are saved per character.

## Author

**Gravebear**

***

Enjoy keeping those Moonkins honest (and grading yourself)! 🦉 Feedback and suggestions are welcome.
