# Logs focus changes AND changes to the game window (position/size/visible) and the screen resolution.
# Stop with Ctrl+C. Log: focuslog2.txt next to this script.
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class FG2 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern int GetWindowThreadProcessId(IntPtr h, out int pid);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern bool IsHungAppWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[void][FG2]::SetProcessDPIAware()
$log = Join-Path $PSScriptRoot "focuslog2.txt"
"=== started $(Get-Date -Format o)" | Out-File $log -Encoding utf8
function W($s) { $l = "{0}  {1}" -f (Get-Date -Format "HH:mm:ss.fff"), $s; $l | Out-File $log -Append -Encoding utf8; Write-Host $l }
Write-Host "Logging to $log  (Ctrl+C to stop)"
$lastFg = [IntPtr]::Zero; $lastGame = ""; $lastScreen = ""
while ($true) {
  $h = [FG2]::GetForegroundWindow()
  if ($h -ne $lastFg) {
    $lastFg = $h
    $procId = 0; [void][FG2]::GetWindowThreadProcessId($h, [ref]$procId)
    $t = New-Object System.Text.StringBuilder 256; [void][FG2]::GetWindowText($h, $t, 256)
    $c = New-Object System.Text.StringBuilder 256; [void][FG2]::GetClassName($h, $c, 256)
    $name = try { (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { "pid $procId" }
    W ("FOCUS   {0}  class=[{1}]  title=[{2}]" -f $name, $c, $t)
  }
  $screen = "{0}x{1}" -f [FG2]::GetSystemMetrics(0), [FG2]::GetSystemMetrics(1)
  if ($screen -ne $lastScreen) { $lastScreen = $screen; W "SCREEN  $screen" }
  $gp = Get-Process Mullebat -ErrorAction SilentlyContinue | Select-Object -First 1
  $g = if ($gp) { $gp.MainWindowHandle } else { [IntPtr]::Zero }
  if ($g -ne [IntPtr]::Zero) {
    $r = New-Object FG2+RECT; [void][FG2]::GetWindowRect($g, [ref]$r)
    $s = "handle={0} rect=({1},{2})-({3},{4}) visible={5} minimized={6} HUNG={7}" -f $g, $r.L, $r.T, $r.R, $r.B, [FG2]::IsWindowVisible($g), [FG2]::IsIconic($g), [FG2]::IsHungAppWindow($g)
  } else { $s = "no game window" }
  if ($s -ne $lastGame) { $lastGame = $s; W "GAME    $s" }
  Start-Sleep -Milliseconds 15
}
