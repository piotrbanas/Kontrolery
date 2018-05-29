<#
.SYNOPSIS
Sprawdzenie stanu wniosku o wydanie dowodu osobistego.
.Description
Funkcja odpytuje urzedowe API i jesli wniosek jest do odbioru wysyla maila z powiadomieniem.
Podajemy nr. wniosku i dane konta pocztowego. Za pierwszym razem zapyta o haslo do poczty.
.EXAMPLE
StatusWniosku.ps1 -nrwniosku '1234567/2018/1234567/01' -email 'pwshlover@xxx.pl' -smtpServer 'smtp.xxx.pl'
.EXAMPLE
Uruchom najpierw z PowerShell-a by wygenerowac bezpieczny plik z haslem.
Umiesc w Harmonogramie Zadan:
Powershell.exe -NoProfile -WindowStyle Hidden -Command "& 'D:\StatusWniosku.ps1' -nrwniosku '1234567/2018/1234567/01' -email 'pwshlover@xxx.pl' -smtpServer 'smtp.xxx.pl'"
#>
Param (
[Parameter(Mandatory, ValueFromPipeline)]
# Example: '1234567/2018/1234567/01'
[string]$nrwniosku,
[Parameter(Mandatory)]
[string]$email,
[Parameter(Mandatory)]
[string]$smtpServer, 
[int]$port = 587
)

$req = Invoke-webrequest "https://obywatel.gov.pl/esrvProxy/proxy/sprawdzStatusWniosku?numerWniosku=$nrwniosku"
$message = Convertfrom-json $req.Content | select -expand  status | Select-Object -ExpandProperty message
$passfile = (Join-Path (Split-Path $profile) Pass$email.txt)

if (!(Test-Path $passfile)) {
    Read-Host "Podaj hasło dla $email" -AsSecureString | ConvertFrom-SecureString | Out-File "$passfile"
}
$pass = Get-Content -path $passfile | ConvertTo-SecureString
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $email, $pass

If ($message -notmatch 'Nie możesz') {
    Send-MailMessage -Subject 'Status wniosku' -Body $message -To $email -SmtpServer $smtpServer -from $email -Port $port -UseSsl -Credential $cred -Encoding UTF8
}