<#
.Synopsis
   Skrypt konfiguracyjny awaryjnego serwera aplikacyjnego.
.DESCRIPTION
   Procedura w przypadku przełączenia lokalnego [serwera aplikacyjnego] na awaryjny. 
   Uruchamiana na serwerze docelowym z "podniesionej" konsoli Powershell lub ISE.
   Po zakończonej konfiguracji wysyła do ADM maila z wynikiem testów akceptacyjnych.
.EXAMPLE
   .\ProceduraAwaryjnaAPP.ps1 -sklep 35 -Verbose
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory,
     ValueFromPipeline,
     HelpMessage = 'Podaj numer sklepu')]
     [ValidateSet(24, 35, 36, 54, 91, 102, 134)]
     [int]$sklep
)

$teraz = Get-Date -Format yyyy-MM-dd
$InstalerFolder = 'C:\APP1\instaler'
$BackupFolder = 'C:\APP1_BACKUPY'
$app1file = (Get-ChildItem "$InstalerFolder\app1*.exe").name
if(!$app1file) {
Write-Output "Umieść plik instalacyjny APP1 w folderze $InstalerFolder"
Start-Sleep 5
break}
$instalerAPP1 = "$InstalerFolder"+'\'+"$app1file" | Out-String

# Zatrzymywanie usług
Write-Verbose 'Zatrzymuję usługi'
Stop-Service 'FileZilla Server' -ErrorAction SilentlyContinue
Start-Process 'C:\APP2\Server\Service_Unin.bat' -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5
Get-Service Apache* | Stop-Service -ErrorAction SilentlyContinue
Stop-Service MySQL_APP1 -ErrorAction SilentlyContinue
Disable-ScheduledTask APPUPDATE -ErrorAction SilentlyContinue

# Kopiowanie danych z backupu
Write-Verbose "Usuwam stare C:\APP1 i C:\Input"
Remove-Item -Path C:\APP1 -Force -Recurse
Remove-Item -Path C:\Input -Force -Recurse
Write-Verbose "Kopiuję APP1 i Input z backupu"
Copy-Item -Path "$BackupFolder\$sklep\APP1" -Container -Recurse -Destination C:\
Copy-Item -Path "$BackupFolder\$sklep\Input" -Container -Recurse -Destination C:\


# Instalacja APP1
Write-Verbose "Instaluję $installerAPP1"
Start-Process $instalerAPP1 -Argumentlist "/S" -NoNewWindow
Write-Verbose "Uruchamiam usługę filezilla"
Start-Service 'FileZilla Server' 
Set-Service 'FileZilla Server' -StartupType Automatic


# Dla sklepów, które wymagają także [APP2]:
if ($sklep -in 24, 54, 134) {
    Write-Verbose "Usuwam folder APP2"
    Remove-Item -Path "C:\APP2" -Force -Recurse
    Write-Verbose "Kopiuję folder APP2 z folderu backupu"
    Copy-Item -Path "$BackupFolder\$sklep\APP2" -Container -Recurse -Force -Destination C:\
    Write-Verbose "Instaluję usługi APP2"
    Start-Process "C:\APP2\Server\Service_Inst.bat"
}

Write-Verbose "Przegrywam transmission.bat (został nadpisany podczas instalacji $installerAPP1)"
Copy-item $BackupFolder\$sklep\APP1\htdocs\app1\transmission.bat -Destination C:\APP1\htdocs\app1\ -Force

# Start zadania w harmonogramie
try {
    Write-Verbose "Próbuję włączyć zadanie w harmonogramie"
    Enable-ScheduledTask -TaskName APPUPDATE -ErrorAction Stop
}
catch {
    Write-Output "Uruchamianie zadania: Niepowodzenie."
    Write-Output "Uruchom skrypt jako Admnistrator, lub ręcznie uruchom w harmonogramie zadanie APPUPDATE."
    Start-Sleep 5
    break
}

# Wywołuję testy akceptacyjne
$testy = Invoke-Pester -Script @{Path = "$PSScriptRoot\TestyOperacyjne.tests.ps1"; Parameters = @{Sklep = $sklep}} -PassThru
$body = $testy.TestResult | Select Name, Result | ConvertTo-Html | Out-String
Send-MailMessage -Body $body -From pester@xper.pl -to piotrbanas@schiever.com.pl -SmtpServer smtp.xper.pl -Subject "Przełączenie APP1 $sklep na serwer awaryjny" -Encoding UTF8 -BodyAsHtml
