![Wayreader: Turn the page, take the path.](https://raw.githubusercontent.com/brandanq2/Wayreader/main/docs/images/wayreader-wordmark.png)

**Wayreader** puts your focused quest's story and objectives in a small reading panel right beside it in the objective tracker, so you can follow the story while you play.

Focus a quest and its text opens next to the tracker. Read the quest giver's story, check the objective and watch your progress, all while you keep moving.

## Features

- **Reads alongside you**: Focus a quest (click it in the tracker or on the map) and the panel opens beside it, lined up with its entry
- **The whole story**: Shows the quest's full story text and objective, word for word from the game
- **Live progress**: Objectives tick off and grey out as you finish them, and the panel tells you when the quest is ready to turn in
- **Scroll without the mouse**: Key bindings for scrolling and paging through long stories, in their own Wayreader section of the Keybindings menu. Bind Shift + Mouse Wheel to scroll from anywhere while the plain wheel still zooms the camera
- **Edit Mode support**: Works like Blizzard's own frames. Click it in Edit Mode to change its width, height, text size and background opacity, or drag it anywhere on screen
- **Stays out of the way**: Sizes itself to your screen, stops short of your target, focus and player frames, and collapses to a small book tab until you focus a different quest
- **Looks like it belongs**: A rounded gold border and fading header rule to match the WoW: Forever interface

## Getting Started

1. Install Wayreader
2. Track a quest and click it in the objective tracker to focus it
3. Read on the move. Click the **-** button to tuck the panel away; it reopens when you focus another quest

To move or resize it, open **Edit Mode** and click the panel. To scroll with the keyboard, set up the bindings under **Options → Keybindings → Wayreader**.

## Key Bindings

| Binding | Description |
|---------|-------------|
| Scroll Down / Scroll Up | About three lines per press |
| Page Down / Page Up | Nearly a full panel per press, keeping two lines for context |
| Collapse / Open Panel | Switch between the panel and the book tab |

## Slash Commands

| Command | Description |
|---------|-------------|
| `/wr unlock` / `/wr lock` | Move and resize the panel without opening Edit Mode |
| `/wr attach` | Put the panel back beside the focused quest |
| `/wr toggle` | Turn the panel on or off |
| `/wr open` | Reopen a collapsed panel |
| `/wr story` | Show or hide the Story section |
| `/wr combat` | Hide the panel during combat |
| `/wr border <gold/ornate/simple>` | Border style |
| `/wr font <9-24>` | Text size |
| `/wr reset` | Restore default settings, size and position |

## Notes

- Built for **World of Warcraft: Forever**
- Quest text comes straight from your quest log, in your client's language
- Wayreader only reads the objective tracker and never changes Blizzard's frames, so it won't interfere with quest item buttons or Edit Mode layouts
