Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System; using System.Runtime.InteropServices;
public class ManageStudio {
[DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,IntPtr p);
[DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
[DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a,uint b,bool attach);
[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr h);
[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
[DllImport("user32.dll")] public static extern void mouse_event(uint f,uint x,uint y,uint d,UIntPtr e);
public struct RECT {public int L,T,R,B;}
}
"@
function StudioAction([IntPtr]$handle,[string]$keys,[int]$x=-1,[int]$y=-1) {
 $foreThread=[ManageStudio]::GetWindowThreadProcessId([ManageStudio]::GetForegroundWindow(),[IntPtr]::Zero)
 $thisThread=[ManageStudio]::GetCurrentThreadId()
 $joined=[ManageStudio]::AttachThreadInput($thisThread,$foreThread,$true)
 try {
  [ManageStudio]::BringWindowToTop($handle) | Out-Null
  [ManageStudio]::SetForegroundWindow($handle) | Out-Null
  Start-Sleep -Milliseconds 300
  if ([ManageStudio]::GetForegroundWindow() -ne $handle) {throw "Could not focus intended Studio window $handle"}
  if ($x -ge 0) {
   $r=New-Object ManageStudio+RECT
   [ManageStudio]::GetWindowRect($handle,[ref]$r) | Out-Null
   [ManageStudio]::SetCursorPos($r.L+$x,$r.T+$y) | Out-Null
   [ManageStudio]::mouse_event(2,0,0,0,[UIntPtr]::Zero)
   Start-Sleep -Milliseconds 80
   [ManageStudio]::mouse_event(4,0,0,0,[UIntPtr]::Zero)
  } elseif ($keys) { [System.Windows.Forms.SendKeys]::SendWait($keys) }
 } finally {if ($joined) {[ManageStudio]::AttachThreadInput($thisThread,$foreThread,$false) | Out-Null}}
}
