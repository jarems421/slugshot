# Opens the loadout check place in its own Studio window, presses Play, captures that window at each logged moment, then
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
$place = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "build\SlugshotLoadoutCheck.rbxlx"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$exe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$started = Get-Date
$proc = Start-Process $exe -ArgumentList "`"$place`"" -PassThru
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 40; $i++) {
    Start-Sleep -Seconds 1
    $live = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($live -and $live.MainWindowTitle -like "*SlugshotLoadoutCheck*") { $hwnd = $live.MainWindowHandle; break }
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
    if ($name -like 'fp-*' -or $name -like 'third-*') {
        [Win]::SetForegroundWindow($hwnd) | Out-Null
        Start-Sleep -Milliseconds 100
        [Win]::PostMessage($hwnd, 0x0100, [IntPtr]0x4B, [IntPtr]1) | Out-Null
        Start-Sleep -Milliseconds 40
        [Win]::PostMessage($hwnd, 0x0101, [IntPtr]0x4B, [IntPtr]0xC0000001L) | Out-Null
    }
}
function PressPlay {
    [Win]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 300
    [Win]::PostMessage($hwnd, 0x0100, [IntPtr]0x74, [IntPtr]1) | Out-Null
    Start-Sleep -Milliseconds 60
    [Win]::PostMessage($hwnd, 0x0101, [IntPtr]0x74, [IntPtr]0xC0000001L) | Out-Null
}

function Record($view) {
    $rect = New-Object Win+RECT
    [Win]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $w = $rect.R - $rect.L; $h = $rect.B - $rect.T
    $frames = Join-Path $OutDir "motion-$view"
    New-Item -ItemType Directory -Force $frames | Out-Null
    [Win]::SetForegroundWindow($hwnd) | Out-Null
    [Win]::PostMessage($hwnd, 0x0100, [IntPtr]0x4B, [IntPtr]1) | Out-Null
    Start-Sleep -Milliseconds 40
    [Win]::PostMessage($hwnd, 0x0101, [IntPtr]0x4B, [IntPtr]0xC0000001L) | Out-Null
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $timings = @()
    $index = 0
    while ($watch.Elapsed.TotalSeconds -lt 7.1) {
        $bitmap = New-Object System.Drawing.Bitmap $w, $h
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $dc = $graphics.GetHdc()
        [Win]::PrintWindow($hwnd, $dc, 2) | Out-Null
        $graphics.ReleaseHdc($dc)
        $timings += $watch.Elapsed.TotalMilliseconds
        $bitmap.Save((Join-Path $frames ("{0:D4}.jpg" -f $index)), [System.Drawing.Imaging.ImageFormat]::Jpeg)
        $graphics.Dispose(); $bitmap.Dispose()
        $index++
        Start-Sleep -Milliseconds 35
    }
    $timings | ConvertTo-Json | Set-Content (Join-Path $frames "timing.json")
    Write-Output "recorded $view ($index real-time frames)"
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
            if ($line -match "LOADOUTCHECK|CombatSelfTest|LoadoutCheck|CreatorError|Combat\.|SlugInspect|FloppyIdle|FloppyFace|Settings:|PvpHud|GooBar|Goo:|SlugIcon:|Inventory:|Keybinds:|FLog::Error.*(Script|luau)|Stack Begin") {
                $key = $log.Name + $line
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    if ($line -match "LOADOUTCHECK (shot|record|key|wheel|PASS|FAIL)") { $running = $true }
                    if ($line -match "LOADOUTCHECK shot (\S+)") { Capture $Matches[1] }
                    elseif ($line -match "LOADOUTCHECK record (fp|third)") { Record $Matches[1] }
                    elseif ($line -match "LOADOUTCHECK key result (.+)") { Write-Output "key result: $($Matches[1].Trim())" }
                    elseif ($line -match "LOADOUTCHECK key ([VR2Q])") {
                        $code = switch ($Matches[1]) { 'V' { 0x56 } 'R' { 0x52 } '2' { 0x32 } 'Q' { 0x51 } }
                        [Win]::SetForegroundWindow($hwnd) | Out-Null
                        Start-Sleep -Milliseconds 100
                        [Win]::PostMessage($hwnd, 0x0100, [IntPtr]$code, [IntPtr]1) | Out-Null
                        Start-Sleep -Milliseconds 60
                        [Win]::PostMessage($hwnd, 0x0101, [IntPtr]$code, [IntPtr]0xC0000001L) | Out-Null
                    }
                    elseif ($line -match "LOADOUTCHECK wheel (up|down)") {
                        $delta = if ($Matches[1] -eq 'up') { 120 } else { -120 }
                        $rect = New-Object Win+RECT
                        [Win]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
                        $point = (($rect.T + 300) -shl 16) -bor ($rect.L + 500)
                        [Win]::PostMessage($hwnd, 0x020A, [IntPtr]($delta -shl 16), [IntPtr]$point) | Out-Null
                    }
                    elseif ($line -match "FLog::") { Write-Output ($line.Trim() -replace "^.*?\[FLog::[A-Za-z]+\] ", "") }
                }
            }
        }
    }
    if ($seen.Keys | Where-Object { $_ -match "LOADOUTCHECK (PASS|FAIL)" }) { break }
    if (-not $running -and ((Get-Date) - $lastPress).TotalSeconds -gt 45) { Write-Output "Play has not started; pressing again"; PressPlay; $lastPress = Get-Date }
}
Capture "end"
Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
Write-Output "done after $([int]((Get-Date) - $started).TotalSeconds)s"

if (-not ($seen.Keys | Where-Object { $_ -match "LOADOUTCHECK PASS" })) { throw "loadout review did not complete successfully" }

if (-not ($seen.Keys | Where-Object { $_ -match "CombatSelfTest.*ALL PASS" })) { throw "Shared flight regressions did not pass" }
