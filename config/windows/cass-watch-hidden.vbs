' Launch cass.exe in watch mode with no visible window.
' Exits silently if cass.exe is already running (prevents duplicates when
' the Cass Watch Daemon task fires after a re-logon).
Set shell = CreateObject("Wscript.Shell")
Set wmi = GetObject("winmgmts:\\.\root\cimv2")
Set procs = wmi.ExecQuery("SELECT * FROM Win32_Process WHERE Name='cass.exe'")
If procs.Count > 0 Then
  WScript.Quit 0
End If
cassPath = shell.ExpandEnvironmentStrings("%USERPROFILE%") & "\.local\bin\cass.exe"
' 0 = hidden window, False = don't wait for exit (detach)
shell.Run """" & cassPath & """ index --watch", 0, False
