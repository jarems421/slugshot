# Opens the settings check place in its own Studio window, presses Play, captures that window at each logged moment, then
# closes the window it opened. Other Studio windows are never touched. Stops early if Play does not start.
param([Parameter(Mandatory = $true)][string]$OutDir, [int]$Timeout = 150)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    public struct RECT { public int L, T, R, B; }
}
"@
$place = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "build\SlugshotSettingsCheck.rbxlx"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$exe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$started = Get-Date
$proc = Start-Process $exe -ArgumentList "`"$place`"" -PassThru -WindowStyle Normal
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    $live = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($live -and $live.MainWindowTitle -like "*SlugshotSettingsCheck*") { $hwnd = $live.MainWindowHandle; break }
}
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "Studio did not open the place"; Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue; exit 1 }
Write-Output "Studio $($proc.Id) open after $([int]((Get-Date) - $started).TotalSeconds)s"

function Capture($name) {
    $rect = New-Object Win+RECT
    [Win]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $w = $rect.R - $rect.L; $h = $rect.B - $rect.T
    $bitmap = New-Object System.Drawing.Bitmap $w, $h
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    [Win]::PrintWindow($hwnd, $dc, 2) | Out-Null
    $graphics.ReleaseHdc($dc)
    $bitmap.Save((Join-Path $OutDir "$name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
    Write-Output "captured $name ($w x $h)"
}
function PressPlay {
    [Win]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 300
    [Win]::PostMessage($hwnd, 0x0100, [IntPtr]0x74, [IntPtr]1) | Out-Null
    Start-Sleep -Milliseconds 60
    [Win]::PostMessage($hwnd, 0x0101, [IntPtr]0x74, [IntPtr]0xC0000001L) | Out-Null
}

Start-Sleep -Seconds 12
PressPlay
$lastPress = Get-Date
$seen = @{}
$running = $false
$logDir = "$env:LOCALAPPDATA\Roblox\logs"
while (((Get-Date) - $started).TotalSeconds -lt $Timeout) {
    Start-Sleep -Milliseconds 300
    foreach ($log in (Get-ChildItem $logDir -Filter *Studio*.log | Where-Object { $_.CreationTime -ge $started.AddSeconds(-2) })) {
        try {
            $stream = [System.IO.File]::Open($log.FullName, 'Open', 'Read', 'ReadWrite,Delete')
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            $reader.Close(); $stream.Close()
        } catch { continue }
        foreach ($line in ($content -split "`n")) {
            if ($line -match "SETTINGSCHECK (PASS|FAIL|done|store done)|\[FLog::Error\]") {
                $key = $log.Name + $line
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    Add-Content -LiteralPath (Join-Path $OutDir "runtime.log") -Value $line
                    if ($line -match "SETTINGSCHECK") { $running = $true }
                    Write-Output ($line.Trim() -replace "^.*?\[FLog::[A-Za-z]+\] ", "")
                }
            }
        }
    }
    if ($seen.Keys | Where-Object { $_ -match "SETTINGSCHECK done" }) { break }
    if (-not $running -and ((Get-Date) - $lastPress).TotalSeconds -gt 45) { Write-Output "Play has not started; pressing again"; PressPlay; $lastPress = Get-Date }
}
Capture "end"
# The test client leaves normally; allow PlayerRemoving to flush the final snapshot.
Start-Sleep -Seconds 4
$released = $false
foreach ($log in (Get-ChildItem $logDir -Filter *Studio*.log | Where-Object { $_.CreationTime -ge $started.AddSeconds(-2) })) {
    $text = Get-Content -LiteralPath $log.FullName -Raw
    if ($text -match "SETTINGSCHECK PASS production leave flush/release") { $released = $true }
    foreach ($line in ($text -split "`n" | Where-Object { $_ -match "SETTINGSCHECK PASS production leave flush/release|SETTINGSCHECK FAIL" })) {
        Add-Content -LiteralPath (Join-Path $OutDir "runtime.log") -Value $line
        Write-Output $line.Trim()
    }
}
Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
if (-not ($seen.Keys | Where-Object { $_ -match "SETTINGSCHECK done" }) -or ($seen.Keys | Where-Object { $_ -match "SETTINGSCHECK FAIL" })) {
    throw "Settings runtime checks failed or did not complete; inspect the captured log."
}
if (-not $released) { throw "Production leave flush was not observed" }
Write-Output "done after $([int]((Get-Date) - $started).TotalSeconds)s"
