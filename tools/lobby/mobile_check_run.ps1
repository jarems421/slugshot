# Opens the mobile check place in its own Studio window, presses Play, follows the check through the Studio log, resizes the window
# and captures it when asked, then closes that window. Everything is sent to this one window, never to whatever else has focus.
param([string]$Place, [string]$OutDir, [int]$Timeout = 300)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class CheckWindow {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int ht, uint f);
    public struct RECT { public int L, T, R, B; }
}
"@
$name = [System.IO.Path]::GetFileName($Place)
$logDir = "$env:LOCALAPPDATA\Roblox\logs"
$started = Get-Date
Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*$name*" } | Stop-Process -Force -Confirm:$false
$before = @(Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | ForEach-Object Id)
Start-Process $Place
$proc = $null
for ($i = 0; $i -lt 90 -and -not $proc; $i++) {
    Start-Sleep -Seconds 2
    $proc = Get-Process RobloxStudioBeta -ErrorAction SilentlyContinue | Where-Object { ($before -notcontains $_.Id) -and $_.MainWindowTitle -like "*$name*" } | Select-Object -First 1
}
if (-not $proc) { throw "Studio did not open $name" }
Start-Sleep -Seconds 25
$hwnd = (Get-Process -Id $proc.Id).MainWindowHandle

function Capture($shot) {
    $rect = New-Object CheckWindow+RECT
    [CheckWindow]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap ($rect.R - $rect.L), ($rect.B - $rect.T)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    [CheckWindow]::PrintWindow($hwnd, $dc, 2) | Out-Null
    $graphics.ReleaseHdc($dc)
    $bitmap.Save((Join-Path $OutDir "$shot.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
}

function PressPlay {
    [CheckWindow]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 300
    [CheckWindow]::PostMessage($hwnd, 0x0100, [IntPtr]0x74, [IntPtr]1) | Out-Null
    Start-Sleep -Milliseconds 60
    [CheckWindow]::PostMessage($hwnd, 0x0101, [IntPtr]0x74, [IntPtr]0xC0000001L) | Out-Null
}

try {
    PressPlay
    $seen = @{}
    $running = $false
    $lastPress = Get-Date
    $finished = $false
    while (((Get-Date) - $started).TotalSeconds -lt $Timeout -and -not $finished) {
        Start-Sleep -Milliseconds 500
        foreach ($log in (Get-ChildItem $logDir -Filter *Studio*.log | Where-Object { $_.LastWriteTime -ge $started })) {
            $content = $null
            try {
                $stream = [System.IO.File]::Open($log.FullName, 'Open', 'Read', 'ReadWrite,Delete')
                $reader = New-Object System.IO.StreamReader($stream)
                $content = $reader.ReadToEnd()
                $reader.Close(); $stream.Close()
            } catch { continue }
            foreach ($line in ($content -split "`n")) {
                if ($line -notmatch "HUBCHECK|HubArt") { continue }
                $key = $log.Name + $line.Trim()
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true
                $running = $true
                if ($line -match "HUBCHECK") { Write-Output ($line.Trim() -replace "^.*?\[FLog::[A-Za-z]+\] ", "") }
                if ($line -match "HUBCHECK size (\d+) (\d+)") { [CheckWindow]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, [int]$Matches[1], [int]$Matches[2], 0x0016) | Out-Null }
                if ($line -match "HUBCHECK shot (\S+)") { Capture $Matches[1] }
                if ($line -match "HUBCHECK tour ends") { $finished = $true }
            }
        }
        if (-not $running -and ((Get-Date) - $lastPress).TotalSeconds -gt 75) { PressPlay; $lastPress = Get-Date }
    }
    if (-not $finished) { throw "The check didn't finish within $Timeout seconds" }
} finally {
    Stop-Process -Id $proc.Id -Force -Confirm:$false -ErrorAction SilentlyContinue
}
