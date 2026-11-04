# Opens the transformation check place in its own Studio window, presses Play, captures that window at each logged moment,
# then closes the window it opened. Other Studio windows are never touched. Stops early if Play does not start.
param([Parameter(Mandatory = $true)][string]$OutDir, [int]$Timeout = 220)
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
$place = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "build\SlugshotTransformationCheck.rbxlx"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$exe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$started = Get-Date
$proc = Start-Process $exe -ArgumentList "`"$place`"" -PassThru
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 100; $i++) {
    Start-Sleep -Seconds 1
    $live = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($live -and $live.MainWindowTitle -like "*SlugshotTransformationCheck*") { $hwnd = $live.MainWindowHandle; break }
}
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "Studio did not open the place"; Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue; exit 1 }
Write-Output "Studio open after $([int]((Get-Date) - $started).TotalSeconds)s"

function Grab($path, $format) {
    $rect = New-Object Win+RECT
    [Win]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap ($rect.R - $rect.L), ($rect.B - $rect.T)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    [Win]::PrintWindow($hwnd, $dc, 2) | Out-Null
    $graphics.ReleaseHdc($dc)
    $bitmap.Save($path, $format)
    $graphics.Dispose(); $bitmap.Dispose()
}
function PressPlay {
    [Win]::SetForegroundWindow($hwnd) | Out-Null
    Start-Sleep -Milliseconds 300
    [Win]::PostMessage($hwnd, 0x0100, [IntPtr]0x74, [IntPtr]1) | Out-Null
    Start-Sleep -Milliseconds 60
    [Win]::PostMessage($hwnd, 0x0101, [IntPtr]0x74, [IntPtr]0xC0000001L) | Out-Null
}
function Record($view) {
    $frames = Join-Path $OutDir "motion-$view"
    New-Item -ItemType Directory -Force $frames | Out-Null
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $index = 0
    while ($watch.Elapsed.TotalSeconds -lt 3) {
        Grab (Join-Path $frames ("{0:D4}.jpg" -f $index)) ([System.Drawing.Imaging.ImageFormat]::Jpeg)
        $index++
    }
    Write-Output "recorded $view ($index frames in 3 s)"
}

Start-Sleep -Seconds 12
PressPlay
$lastPress = Get-Date
$seen = @{}
$running = $false
$logDir = "$env:LOCALAPPDATA\Roblox\logs"
while (((Get-Date) - $started).TotalSeconds -lt $Timeout) {
    Start-Sleep -Milliseconds 100
    foreach ($log in (Get-ChildItem $logDir -Filter *Studio*.log | Where-Object { $_.CreationTime -ge $started.AddSeconds(-2) })) {
        try {
            $stream = [System.IO.File]::Open($log.FullName, 'Open', 'Read', 'ReadWrite,Delete')
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            $reader.Close(); $stream.Close()
        } catch { continue }
        foreach ($line in ($content -split "`n")) {
            if ($line -match "TRANSCHECK|CombatSelfTest\] (FAIL|.*ALL PASS)|\[Combat\]|InfernoMotion|SlugTransformation|Stack Begin|FLog::Error.*(Script|luau)") {
                $key = $log.Name + $line
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    $running = $running -or ($line -match "TRANSCHECK")
                    if ($line -match "TRANSCHECK shot (\S+)") { Grab (Join-Path $OutDir "$($Matches[1]).png") ([System.Drawing.Imaging.ImageFormat]::Png) }
                    elseif ($line -match "TRANSCHECK record (\S+)") { Record $Matches[1] }
                    Write-Output ($line.Trim() -replace "^.*?\[FLog::[A-Za-z]+\] ", "")
                }
            }
        }
    }
    if ($seen.Keys | Where-Object { $_ -match "TRANSCHECK (PASS|FAIL)" }) { break }
    if (-not $running -and ((Get-Date) - $lastPress).TotalSeconds -gt 45) { Write-Output "Play has not started; pressing again"; PressPlay; $lastPress = Get-Date }
}
Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
Write-Output "done after $([int]((Get-Date) - $started).TotalSeconds)s"
