param([switch]$Check, [int]$ResumeProcess = 0)
# Only the process created here receives keys or is closed. Existing Studio work stays open.
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
. (Join-Path $PSScriptRoot 'studio_window.ps1')
Add-Type -AssemblyName System.Drawing
$name = if ($Check) { 'SlugshotTrainingReviewCheck' } else { 'SlugshotTrainingReview' }
$place = Join-Path $root "build/$name.rbxlx"
$out = Join-Path $root 'build/training/studio-review'
New-Item -ItemType Directory -Force $out | Out-Null
$exe = (Get-ChildItem "$env:LOCALAPPDATA/Roblox/Versions" -Recurse -Filter RobloxStudioBeta.exe | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
$started = Get-Date
$proc = if ($ResumeProcess) { Get-Process -Id $ResumeProcess } else { Start-Process $exe -ArgumentList "`"$place`"" -PassThru }
if ($ResumeProcess) { $started = $proc.StartTime }
for ($i=0; $i -lt 50; $i++) {
    Start-Sleep -Seconds 1
    $live = Get-Process -Id $proc.Id
    if ($live.MainWindowTitle -like "*$name*") { break }
}
$handle = $live.MainWindowHandle
if ($live.MainWindowTitle -notlike "*$name*") { throw 'Review place did not open' }
Start-Sleep -Seconds 8
try { StudioAction -handle $handle -keys '{F5}' } catch {
    # Studio's own window can receive its accelerator without moving focus away
    # from the user's current app when Windows denies SetForegroundWindow.
    Add-Type @'
using System;using System.Runtime.InteropServices;
public class TrainingPlay {[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);}
'@
    [TrainingPlay]::PostMessage($handle,0x0100,[IntPtr]0x74,[IntPtr]1) | Out-Null
    Start-Sleep -Milliseconds 70
    [TrainingPlay]::PostMessage($handle,0x0101,[IntPtr]0x74,[IntPtr]0xC0000001L) | Out-Null
}
Write-Output "Training Studio process $($proc.Id) opened"
if (-not $Check) { exit }
Add-Type @'
using System;
using System.Runtime.InteropServices;
public class TrainingCapture {
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h,IntPtr dc,uint flags);
}
'@
function Capture([string]$name) {
    $rect = New-Object ManageStudio+RECT
    [ManageStudio]::GetWindowRect($handle,[ref]$rect) | Out-Null
    $bitmap = New-Object System.Drawing.Bitmap ($rect.R-$rect.L),($rect.B-$rect.T)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $dc = $graphics.GetHdc()
    [TrainingCapture]::PrintWindow($handle,$dc,2) | Out-Null
    $graphics.ReleaseHdc($dc)
    $bitmap.Save((Join-Path $out "$name.png"),[System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose();$bitmap.Dispose()
}
$seen=@{};$passed=$false;$records=New-Object System.Collections.Generic.List[string]
$checkStarted = Get-Date
while (((Get-Date)-$checkStarted).TotalSeconds -lt 160) {
    Start-Sleep -Milliseconds 300
    foreach ($log in (Get-ChildItem "$env:LOCALAPPDATA/Roblox/logs" -Filter '*Studio*.log' | Where-Object {$_.CreationTime -ge $started.AddSeconds(-2)})) {
        try {
            $stream=[IO.File]::Open($log.FullName,'Open','Read','ReadWrite,Delete')
            $reader=New-Object IO.StreamReader $stream
            $content=$reader.ReadToEnd();$reader.Close();$stream.Close()
        } catch { continue }
        foreach ($line in ($content -split "`n")) {
            if ($line -match '\[TRAININGCHECK\].*' -and -not $seen.ContainsKey($line)) {
                $seen[$line]=$true;$record=$Matches[0].Trim();$records.Add($record);Write-Output $record
                if ($record -match 'view (\w+)') { Capture $Matches[1] }
                if ($record -match 'ALL PASS') {$passed=$true}
                if ($record -match 'FAIL') { $records | Set-Content (Join-Path $out 'results.txt'); throw $record }
            }
        }
    }
    if ($passed) {break}
}
$records | Set-Content (Join-Path $out 'results.txt')
Stop-Process -Id $proc.Id
if (-not $passed) {throw 'Training Studio checks timed out'}
