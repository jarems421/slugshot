# Opens the gun-side check place (build_hub.py --gun), presses Play, captures each logged view, then
# closes the window it opened. Takes focus only if Play has not started from a plain F5. Other Studio windows are never touched.
# -Unfocused hands focus back to VS Code once the tour starts, so Studio runs as it does in the background (15 frames a
# second) and Roblox's automatic graphics level falls: the lighting check compares this with a focused run.
param([Parameter(Mandatory = $true)][string]$OutDir, [int]$Timeout = 320, [switch]$Unfocused)
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
    [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
    public struct RECT { public int L, T, R, B; }
}
"@
$place = Join-Path (Split-Path $PSScriptRoot -Parent | Split-Path -Parent) "build\SlugshotLobbyGunCheck.rbxlx"
New-Item -ItemType Directory -Force $OutDir | Out-Null
$exe = (Get-ChildItem "$env:LOCALAPPDATA\Roblox\Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
# Recovery copies of this throwaway place (left when a run's window is closed) make Studio ask to restore, which
# swallowed the Play key. The place is rebuilt each run, so they hold nothing worth keeping.
Remove-Item "$env:LOCALAPPDATA\Roblox\RobloxStudio\AutoSaves\SlugshotLobbyGunCheck_AutoRecovery_*" -ErrorAction SilentlyContinue
$started = Get-Date
$proc = Start-Process $exe -ArgumentList "`"$place`"" -PassThru
$hwnd = [IntPtr]::Zero
for ($i = 0; $i -lt 120; $i++) {
    Start-Sleep -Seconds 1
    $live = Get-Process -Id $proc.Id -ErrorAction SilentlyContinue
    if ($live -and $live.MainWindowTitle -like "*SlugshotLobbyGunCheck*") { $hwnd = $live.MainWindowHandle; break }
}
if ($hwnd -eq [IntPtr]::Zero) { Write-Output "Studio did not open the place"; Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue; exit 1 }
Write-Output "Studio $($proc.Id) open after $([int]((Get-Date) - $started).TotalSeconds)s"
# A minimized window renders nothing and takes no keys: restore it (this check's own window only).
[Win]::ShowWindow($hwnd, 9) | Out-Null

function Capture($name) {
    # A minimized window captures as a 160 x 28 strip (seen once at a forced low graphics level): restore it first.
    if ([Win]::IsIconic($hwnd)) {
        [Win]::ShowWindow($hwnd, 9) | Out-Null
        [Win]::SetForegroundWindow($hwnd) | Out-Null
        Start-Sleep -Milliseconds 1500
        Write-Output "restored the minimized window before $name"
    }
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
function PressPlay([bool]$focus = $false) {
    # A plain F5 posted to the window, which Studio takes when its window is active. If that hasn't started Play, the
    # retry brings this check's own window forward first (Studio ignored unfocused key messages in some runs).
    if ($focus) { [Win]::ShowWindow($hwnd, 9) | Out-Null; [Win]::SetForegroundWindow($hwnd) | Out-Null; Start-Sleep -Milliseconds 300 }
    [Win]::PostMessage($hwnd, 0x0100, [IntPtr]0x74, [IntPtr]0) | Out-Null
    Start-Sleep -Milliseconds 60
    [Win]::PostMessage($hwnd, 0x0101, [IntPtr]0x74, [IntPtr]0) | Out-Null
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
        # Only this check's own log: other sessions' Studio windows open logs too, with some of the same lines.
        if ($content -notmatch "SlugshotLobbyGunCheck") { continue }
        foreach ($line in ($content -split "`n")) {
            if ($line -match "server foundation ready") { $running = $true }
            # Case-sensitive: the place's own name, SlugshotLobbyGunCheck, appears in Studio's "open place" line and once
            # counted as the tour having started, so Play was never pressed again.
            if ($line -cmatch "GUNCHECK|CreatorError" -and $line -notmatch "Failed to upload TexturePack") {
                $key = $log.Name + $line
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = $true
                    if ($line -cmatch "GUNCHECK") { $running = $true }
                    if ($Unfocused -and $line -cmatch "GUNCHECK tour starts") {
                        $code = Get-Process Code -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | Select-Object -First 1
                        if ($code) { Write-Output "focus to VS Code: $([Win]::SetForegroundWindow($code.MainWindowHandle))" }
                    }
                    if ($line -cmatch "GUNCHECK shot (\S+)") { Capture $Matches[1] }
                    elseif ($line -cmatch "GUNCHECK menu open") {
                        # Roblox's menu opened over the view (seen at low graphics levels): Escape, to this window only.
                        [Win]::PostMessage($hwnd, 0x0100, [IntPtr]0x1B, [IntPtr]0) | Out-Null
                        Start-Sleep -Milliseconds 60
                        [Win]::PostMessage($hwnd, 0x0101, [IntPtr]0x1B, [IntPtr]0) | Out-Null
                        Write-Output "closed Roblox's menu"
                    }
                    elseif ($line -cmatch "GUNCHECK (ground|light)") { Write-Output ($line.Trim() -replace "^.*?GUNCHECK", "GUNCHECK") }
                    elseif ($line -match "FLog::") { Write-Output ($line.Trim() -replace "^.*?\[FLog::[A-Za-z]+\] ", "") }
                }
            }
        }
    }
    if ($seen.Keys | Where-Object { $_ -match "GUNCHECK (PASS|FAIL)" }) { break }
    if (-not $running -and ((Get-Date) - $lastPress).TotalSeconds -gt 45) { Write-Output "Play has not started; pressing again"; PressPlay $true; $lastPress = Get-Date }
}
Capture "end"
Stop-Process -Id $proc.Id -ErrorAction SilentlyContinue
Write-Output "done after $([int]((Get-Date) - $started).TotalSeconds)s"

if (-not ($seen.Keys | Where-Object { $_ -match "GUNCHECK PASS" })) { throw "gun-side tour did not complete" }

