rem @ECHO OFF
echo Commit: Rev#%2 > c:\temp\msg.txt
echo wykonany przez: >> c:\temp\msg.txt
"C:\Program Files\Subversion\bin\svnlook.exe" author -r %2 %1 >> c:\temp\msg.txt
echo Zmiany: >> C:\temp\msg.txt
"C:\Program Files\Subversion\bin\svnlook.exe" changed -r %2 %1 >> c:\temp\msg.txt
echo Komentarz: >> C:\temp\msg.txt
"C:\Program Files\Subversion\bin\svnlook.exe" log -r %2 %1 >> c:\temp\msg.txt

SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%emailer.ps1
PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& '%PowerShellScriptPath%'";