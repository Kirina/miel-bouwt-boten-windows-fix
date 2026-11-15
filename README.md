# Miel Monteur – Recht Door Zee! on Windows 11

I wanted to relive my childhood and play the games I used to play. But sadly I do not have a computer with Windows XP laying around anymore so Miel Monteur did not work!

The following issues kept occurring that really disturbed the gameplay:

- dialogue being cut off (with the taskbar flashing briefly)
- Windows Firewall popups that keep popping up
- the game not starting after the CD files were moved off drive `D:`

After some logging and Clauding it made a nice setup that fixed the problems and now the game runs smoothly.

Click **`MielStart.bat`** to start the game after adding the setup files to the game folder or an adjacent folder.

Probably also works for other Miel Monteur games but haven't tested.

## Files

| File                  | What it does                                                                                                         |
| --------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `MielStart.bat`       | **Double-click this to play.** Starts `MielStart.ps1` in 32-bit PowerShell.                                          |
| `MielStart.ps1`       | Maps the CD folder to `D:`, starts the game, and disables Windows "window ghosting" for the game (the dialogue fix). |
| `tools/focuslog2.ps1` | Diagnostic only. Logs focus changes, game window state, and when Windows considers the game "hung".                  |

## Expected layout

You can load the files in this folder in the Zip2Iso file you get from the Miel Monteur download or have it in a separate folder

```
miel-bouwt-boten\
├─ Zip2Iso\                        <- the CD contents (DATA\, MOVIES\, SOUND\, Xtras\, ...)
└─ miel-bouwt-boten-windows-fix\   <- this folder
```

The game can be installed from the CD or bought from the [transposia](https://www.agoramarketing.be/transposia/?download=miel-monteur-bouwt-boten) website.

`MielStart.ps1` looks for the CD files (the folder containing `DATA\Data.cst`) in its own folder and in `..\Zip2Iso`.
If yours are somewhere else, set `$cdDir` near the top of `MielStart.ps1`.

## One-time setup

### 1. Remove the unused internet plugins (fixes the firewall popups)

The game loads every plugin in its `xtras` folder at startup. Three of them are internet plugins.
They make Windows Firewall ask for network access, and every popup takes focus away from the game.
The game never uses them: its only online feature was downloading extra parts from transposia.com, which no longer exists.

Run this in an **administrator** PowerShell:

```powershell
$x = "C:\Program Files (x86)\Transposia\Miel Monteur - Recht Door Zee!\xtras"
New-Item -ItemType Directory "$x\..\xtras-backup" -Force
Move-Item "$x\NETLINGO.*","$x\INETURL.*","$x\NETFILE.*" "$x\..\xtras-backup\"
```

To undo, move the files from `xtras-backup` back into `xtras`.

### 2. Use DirectSound (the default)

There are two `Mullebat.ini` files: one in the install folder and one in the CD's `MOVIES` folder.
Set both to `DirectSound: 1`, which is the original setting.

```powershell
# administrator PowerShell
Set-Content -Path "C:\Program Files (x86)\Transposia\Miel Monteur - Recht Door Zee!\Mullebat.ini" -Value "DirectSound: 1" -NoNewline
```

Don't set it to `0` unless you also copy `Xtras\MIX32.X32` from the CD into the install's `xtras` folder.
The installer doesn't copy that plugin, and the game may not start without it.

## Playing

Double-click **`MielStart.bat`**. A console window opens, and starts the game.

Start the game this way rather than through `MielBoten.exe` → _Speel_.

## What was wrong, and why the fixes work

### Dialogue cut off, taskbar flashing: Windows "window ghosting"

While a character speaks, the game waits for the line to finish in a loop that ignores Windows messages.
On Windows 98/XP that was fine. On Windows 10/11, after about 5 seconds without a response Windows decides the program has hung.
It then replaces the window with a pale "Not responding" stand-in window.
That stand-in isn't a fullscreen game window, so **the taskbar shows for a moment**.
The swap disrupts the game mid-line, so the speech gets cut off and the text balloon disappears.

`MielStart.ps1` starts the game. As soon as the game window exists, it calls the Windows function
[`DisableProcessWindowsGhosting`](https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-disableprocesswindowsghosting)
inside the game's process, through a remote thread. After that, Windows leaves the game alone while it waits.
The game itself isn't modified.

### The game didn't start after moving the files: it looks for its CD

At startup (`MOVIES\StartCD.dxr`) the game tries every drive letter, looking for `<drive>:\DATA\Data.cst` at the **root** of a drive.
The install in Program Files only contains save data. All scenes, sounds and dialogue are read from the "CD".
Once the files were in a normal folder instead of the root of `D:`, the game couldn't find them.

`MielStart.ps1` fixes this by running `subst D: "<CD folder>"`, which makes the folder look like the root of drive `D:`.
You can do the same by hand:

```powershell
subst D: "C:\Users\<you>\Documents\My Games\miel-bouwt-boten\Zip2Iso"   # map
subst D: /d                                                             # unmap
```

`subst` is forgotten when you restart, which is why the launcher does it every time.
If `D:` is taken, change `$cdDrive` in `MielStart.ps1`.

### Firewall popups: unused internet plugins

The game runs on the Macromedia Director 6 engine. At startup, Director loads every plugin ("Xtra") in the game's `xtras` folder,
whether the game uses it or not. Three of them are internet plugins: `NETLINGO`, `INETURL` and `NETFILE` (each as `.X32` and `.X16`).
They set up networking, so Windows Firewall asks whether `Mullebat.exe` may use the network.

The popups kept coming back because no firewall rule for the game was ever saved.
Windows asked again on every start, and again when the game was started from a different file
(`MielBoten.exe` → `TOOL.EXE` → `Mullebat.exe`, or the CD copy versus the installed copy).
Every popup also takes focus away from the fullscreen game.

The game doesn't need these plugins. None of its scenes (`MOVIES\*.dxr` / `*.cxt`) use any internet commands.
Its only online feature was downloading extra parts from transposia.com, which no longer exists.
The "plugins" mentioned in `Leesmij.txt` are just `.cst` files the game picks up from its local `Plugins` folder, without any internet access.
Moving the three internet plugins out of `xtras` (setup step 1) stops Director from loading them, so the firewall has nothing to ask about.
