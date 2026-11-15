# Miel Monteur - Recht Door Zee! launcher
# Fixes the glitching dialogue on Windows 10/11:
#   The game ignores Windows while it waits for a spoken line to finish. After 5 seconds Windows
#   thinks it hung and swaps in a "ghost" window (taskbar flashes), which breaks the dialogue.
#   This launcher starts the game and calls DisableProcessWindowsGhosting() inside the game process,
#   so Windows leaves it alone.
# Must run in 32-bit PowerShell (the game is 32-bit). Use MielStart.bat to start it.
param([switch]$DryRun)

$ErrorActionPreference = 'Stop'
$gameDir = 'C:\Program Files (x86)\Transposia\Miel Monteur - Recht Door Zee!'
$gameExe = Join-Path $gameDir 'Mullebat.exe'
$cdDrive = 'D:'   # drive letter the game looks for its CD on (change if D: is taken)

# The folder with the CD files (the one containing DATA\Data.cst). Set $cdDir by hand if it is elsewhere.
$here  = Split-Path -Parent $MyInvocation.MyCommand.Path
$cdDir = @($here, (Join-Path (Split-Path -Parent $here) 'Zip2Iso')) |
         Where-Object { Test-Path (Join-Path $_ 'DATA\Data.cst') } | Select-Object -First 1
if (-not $cdDir) { throw "CD files not found. Edit `$cdDir in MielStart.ps1 to point at the folder containing DATA\Data.cst." }

if ([IntPtr]::Size -ne 4) { throw 'Start this via MielStart.bat (needs 32-bit PowerShell).' }

Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Inj {
  [DllImport("kernel32.dll", CharSet=CharSet.Ansi)] public static extern IntPtr GetModuleHandle(string n);
  [DllImport("kernel32.dll", CharSet=CharSet.Ansi)] public static extern IntPtr GetProcAddress(IntPtr m, string p);
  [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(int access, bool inherit, int pid);
  [DllImport("kernel32.dll")] public static extern IntPtr CreateRemoteThread(IntPtr p, IntPtr a, uint s, IntPtr start, IntPtr param, uint f, out uint tid);
  [DllImport("kernel32.dll")] public static extern uint WaitForSingleObject(IntPtr h, uint ms);
  [DllImport("kernel32.dll")] public static extern bool CloseHandle(IntPtr h);
  [DllImport("kernel32.dll", CharSet=CharSet.Ansi)] public static extern IntPtr LoadLibraryA(string n);
}
"@

# Address of DisableProcessWindowsGhosting in OUR user32.dll
$localUser32 = [Inj]::GetModuleHandle('user32.dll')
if ($localUser32 -eq [IntPtr]::Zero) { $localUser32 = [Inj]::LoadLibraryA('user32.dll') }
$localFn = [Inj]::GetProcAddress($localUser32, 'DisableProcessWindowsGhosting')
if ($localFn -eq [IntPtr]::Zero) { throw 'DisableProcessWindowsGhosting not found in user32.dll' }
$offset = $localFn.ToInt64() - $localUser32.ToInt64()
Write-Host ("user32 base 0x{0:X8}, DisableProcessWindowsGhosting at +0x{1:X}" -f $localUser32.ToInt64(), $offset)
if ($DryRun) { Write-Host 'Dry run OK.'; return }

# 1. Make the CD folder available as D:\ (the game looks for D:\DATA\Data.cst)
if (-not (Test-Path "$cdDrive\DATA\Data.cst")) {
  if (Test-Path "$cdDrive\") { throw "$cdDrive is in use by something else. Change `$cdDrive in MielStart.ps1." }
  subst $cdDrive "$cdDir"
  Write-Host "Mapped $cdDrive -> $cdDir"
}

# 2. Start the game
$p = Start-Process -FilePath $gameExe -WorkingDirectory $gameDir -PassThru
Write-Host "Game started (pid $($p.Id)), waiting for its window..."

# 3. Wait until the game has loaded user32 and created its window (well before the 5s ghost timeout)
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt 20) {
  $p.Refresh()
  if ($p.HasExited) { throw 'The game closed before the fix could be applied.' }
  if ($p.MainWindowHandle -ne [IntPtr]::Zero) { break }
  Start-Sleep -Milliseconds 50
}

# 4. Find user32.dll in the game process and call DisableProcessWindowsGhosting there
$remoteUser32 = $p.Modules | Where-Object { $_.ModuleName -ieq 'user32.dll' } | Select-Object -First 1
if (-not $remoteUser32) { throw 'user32.dll not found in the game process.' }
$remoteFn = [IntPtr]($remoteUser32.BaseAddress.ToInt64() + $offset)

$PROCESS_ALL = 0x1F0FFF
$h = [Inj]::OpenProcess($PROCESS_ALL, $false, $p.Id)
if ($h -eq [IntPtr]::Zero) { throw "Could not open the game process (error $([Runtime.InteropServices.Marshal]::GetLastWin32Error()))." }
$tid = 0
$t = [Inj]::CreateRemoteThread($h, [IntPtr]::Zero, 0, $remoteFn, [IntPtr]::Zero, 0, [ref]$tid)
if ($t -eq [IntPtr]::Zero) { [Inj]::CloseHandle($h) | Out-Null; throw 'Could not apply the fix (CreateRemoteThread failed).' }
[void][Inj]::WaitForSingleObject($t, 5000)
[Inj]::CloseHandle($t) | Out-Null
[Inj]::CloseHandle($h) | Out-Null
Write-Host ("Fix applied after {0:N1}s: window ghosting disabled for the game. Veel plezier!" -f $sw.Elapsed.TotalSeconds)
Start-Sleep -Seconds 2
