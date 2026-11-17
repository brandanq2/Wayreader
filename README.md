# FieldNotes

A World of Warcraft: Forever addon that puts your **focused quest's** text in a small reading panel right beside it in the objective tracker. You can follow the story and the objective while you travel, without opening the quest log.

```
┌──────────────────────────────┐   ◆ The Defias Brotherhood
│ [18] The Defias Brotherhood −│      - Defias Messenger slain: 0/1
│ ──────────────────────────── │
│ - Defias Messenger slain: 0/1│
│                              │
│ OBJECTIVE                    │
│ Kill the Defias Messenger... │
│                              │
│ STORY                        │
│ Gryan Stoutmantle has asked..│
└──────────────────────────────┘
```

- **Focus a quest** (click it in the tracker or on the map) and the panel opens beside it, lined up with the quest's entry.
- **Live progress** at the top. Finished objectives get a tick and turn grey, and the panel says *Ready to turn in* when you're done.
- **Objective and Story** come straight from the game's quest log text. Scroll with the mouse wheel when the text is long.
- **Collapse** with the `−` button and it shrinks to a book tab. It stays collapsed until you focus a different quest, then opens again on its own. Click the tab to reopen it.
- Beside the tracker, the panel stops short of your target, focus and player frames (wherever you've put them) and scrolls instead. If it does overlap something, it draws on top so the text stays readable. Clicks pass through it.
- The panel follows the tracker as it moves. If you've moved the tracker to the left side of the screen, the panel flips to its right.

## Fitting it to your screen

The default size is relative to your screen: about a fifth of its width and a third of its height. It scales with resolution and UI scale, so a 1080p setup starts with a smaller panel than an ultrawide one.

It works like Blizzard's own frames in **Edit Mode**. The panel shows with a blue outline:

- **Click it** to select it (yellow outline) and open the FieldNotes settings window: **Width**, **Max Height**, **Text Size**, **Background Opacity**, **Attach to Objective Tracker**, **Show Story**, **Hide in Combat**, plus **Reset Size** and **Reset Position**.
- **Drag it** anywhere, for example a narrow column along the edge of the screen. It then stays there instead of following the tracker. Tick *Attach to Objective Tracker* to put it back.

`/fn unlock` does the same without opening Edit Mode; close the settings window when you're done.

## Key bindings

In their own **FieldNotes** section of **Options → Keybindings**. These work without hovering over the panel:

| Binding | |
|---|---|
| Scroll Down / Scroll Up | About three lines per press |
| Page Down / Page Up | Nearly a full panel per press, keeping two lines for context |
| Collapse / Open Panel | Toggle between the panel and the book tab |

Tip: the Keybindings screen accepts mouse wheel combinations. Binding **Shift + Mouse Wheel** to Scroll Down/Up gives you global wheel scrolling while the plain wheel still zooms the camera.

## Commands

| Command | |
|---|---|
| `/fn unlock` / `/fn lock` | Move and resize the panel without opening Edit Mode |
| `/fn attach` | Put the panel back beside the focused quest in the tracker |
| `/fn toggle` | Turn the panel on or off |
| `/fn open` | Reopen a collapsed panel |
| `/fn story` | Show or hide the Story section |
| `/fn combat` | Hide the panel during combat |
| `/fn border <gold/ornate/simple>` | Border style: rounded Forever gold (default), the heavier gold dialog border, or a thin line |
| `/fn font <9-24>` | Text size (default 13) |
| `/fn width <200-700>` | Panel width |
| `/fn height <120-900>` | Max panel height before it scrolls |
| `/fn reset` | Restore default settings, size and position |
| `/fn debug` | Print what FieldNotes sees: focused quest, tracker block, anchor |

## How it works

- The focused quest is the super-tracked quest (`C_SuperTrack.GetSuperTrackedQuestID`).
- Text comes from `GetQuestLogQuestText(logIndex)` and progress from `C_QuestLog.GetQuestObjectives`. Every string is checked with `issecretvalue`, since Forever runs on the Midnight client.
- The panel finds the quest's block through the tracker modules (`QuestObjectiveTracker:GetExistingBlock`, with 10.x fallbacks). It only *reads* block positions and never hooks or modifies Blizzard frames, so it can't taint the tracker's secure item buttons.

## Releasing

Same pipeline as WasteNot: pushing a `v*` tag runs `.github/workflows/release.yml`, which stamps the version into the TOC, zips `FieldNotes/`, publishes a GitHub release and uploads to CurseForge for Forever (`## Interface: 16001` → `1.60.1`). It needs the repo secrets `CF_API_KEY` and `CF_PROJECT_ID`.

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Development

`World of Warcraft/_forever_/Interface/AddOns/FieldNotes` is a junction to `FieldNotes/` in this repo, so edits show up after a `/reload` in-game.
