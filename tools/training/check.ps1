# Opens the training check place in its own Studio window, presses Play, captures on each logged stop, then closes the
# window it opened. Other Studio windows are never touched. Stops early if Play does not start.
param([string]$OutDir = "build/training/check", [int]$Timeout = 300)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win {
    [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    public delegate bool EnumProc(IntPtr h, IntPtr p);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc f, IntPtr p);
    public static IntPtr Viewport(IntPtr root, int width, int height) {
        IntPtr found = IntPtr.Zero;
        EnumChildWindows(root, (h, p) => {
            RECT r; GetWindowRect(h, out r);
            if (Math.Abs(r.R-r.L-width) <= 4 && Math.Abs(r.B-r.T-height) <= 4) found = h;
            return true;
        }, IntPtr.Zero);
        return found;
    }
    public struct RECT { public int L, T, R, B; }
}
"@
$place = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "build\SlugshotLobbyTrainingCheck.rbxlx"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$OutDir = (Resolve-Path $OutDir).Path
$exe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort-Object LastWriteTime | Select-Object -Last 1).FullName
$started = Get-Date
$proc = Start-Process $exe -ArgumentList "`"$place`"" -PassThru -WindowStyle Normal
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 120; $i++) {
    Start-Sleep -Seconds 1
    $live = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($live -and $live.MainWindowTitle -like "*SlugshotLobbyTrainingCheck*") { $hwnd = $live.MainWindowHandle; break }
}
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "Studio did not open the place"; Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue; exit 1 }
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
}
function PressPlay {
    [Win]::ShowWindow($hwnd, 9) | Out-Null # a minimised window never gets the key
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
$done = $false
$failures = 0
$logDir = "$env:LOCALAPPDATA\Roblox\logs"
while (-not $done -and ((Get-Date) - $started).TotalSeconds -lt $Timeout) {
    Start-Sleep -Milliseconds 300
    foreach ($log in (Get-ChildItem $logDir -Filter *Studio*.log | Where-Object { $_.CreationTime -ge $started.AddSeconds(-2) })) {
        try {
            $stream = [System.IO.File]::Open($log.FullName, 'Open', 'Read', 'ReadWrite,Delete')
            $reader = New-Object System.IO.StreamReader($stream)
            $content = $reader.ReadToEnd()
            $reader.Close(); $stream.Close()
        } catch { continue }
        foreach ($line in ($content -split "`n")) {
            if ($line -match "TRAINCHECK|\[Training\]|HubArt: solid|\[FLog::Error\]|\[FLog::Warning\]") {
                $key = $line # the timestamp stays in: each key press logs the same words
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    $clean = $line.Trim() -replace "^.*?\[FLog::[A-Za-z]+\] ", ""
                    if ($line -match "TRAINCHECK|\[Training\]") { $running = $true }
                    if ($line -match "TRAINCHECK FAIL") { $failures++ }
                    if ($line -match "TRAINCHECK capture (\S+)") { Capture $Matches[1] }
                    elseif ($line -match "TRAINCHECK key down") { [Win]::SetForegroundWindow($hwnd) | Out-Null; [Win]::PostMessage($hwnd, 0x0100, [IntPtr]0x57, [IntPtr]1) | Out-Null }
                    elseif ($line -match "TRAINCHECK key up") { [Win]::PostMessage($hwnd, 0x0101, [IntPtr]0x57, [IntPtr]0xC0000001L) | Out-Null }
                    elseif ($line -match "TRAINCHECK click (\d+) (\d+) (\d+) (\d+)") {
                        $clickX, $clickY, $viewW, $viewH = [int]$Matches[1], [int]$Matches[2], [int]$Matches[3], [int]$Matches[4]
                        $viewHandle = [Win]::Viewport($hwnd, $viewW, $viewH)
                        if ($viewHandle -eq [IntPtr]::Zero) { throw "Could not find the test viewport for native mouse input" }
                        [Win]::SetForegroundWindow($hwnd) | Out-Null
                        $point = [IntPtr](($clickY -shl 16) -bor $clickX)
                        [Win]::PostMessage($viewHandle, 0x0200, [IntPtr]0, $point) | Out-Null
                        [Win]::PostMessage($viewHandle, 0x0201, [IntPtr]1, $point) | Out-Null
                        Start-Sleep -Milliseconds 80
                        [Win]::PostMessage($viewHandle, 0x0202, [IntPtr]0, $point) | Out-Null
                    }
                    elseif ($line -match "TRAINCHECK press (F|Two|Return|R|E)") {
                        $keyCode = @{ F = 0x46; Two = 0x32; Return = 0x0D; R = 0x52; E = 0x45 }[$Matches[1]]
                        [Win]::SetForegroundWindow($hwnd) | Out-Null
                        [Win]::PostMessage($hwnd, 0x0100, [IntPtr]$keyCode, [IntPtr]1) | Out-Null
                        Start-Sleep -Milliseconds 80
                        [Win]::PostMessage($hwnd, 0x0101, [IntPtr]$keyCode, [IntPtr]0xC0000001L) | Out-Null
                    }
                    elseif ($line -match "TRAINCHECK done") { $done = $true }
                    Write-Output $clean
                }
            }
        }
    }
    if (-not $running -and ((Get-Date) - $lastPress).TotalSeconds -gt 45) { Write-Output "Play has not started; pressing again"; PressPlay; $lastPress = Get-Date }
}
Capture "end"
Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
Write-Output "finished after $([int]((Get-Date) - $started).TotalSeconds)s, completed=$done"
if (-not $done -or $failures -gt 0) { throw "Training check failed: completed=$done, failures=$failures" }
