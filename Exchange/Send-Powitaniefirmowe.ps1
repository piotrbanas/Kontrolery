<#
.SYNOPSIS             
Skrypt wysyła powitanie firmowe dla nowo zatrudnionych Pań
.DESCRIPTION            
Skrypt monitoruje nowo zakładane skrzynki pocztowe Exchange i dla Imion kończących się literą "a" wysyła miłe słowa od Administracji IT.
Używa Implicit Remoting do zaimportowania Exchange Management Shell
.PARAMETER exserver
Nazwa serwera Exchange
.PARAMETER plik
Ścieżka do pliku tekstowego z treścią powitania
.EXAMPLE
Send-PowitanieFirmowe.ps1 -exserver EX16 -tekst 'C:\temp\powitanie.txt'
.NOTES
Author: Piotr Witold Banaś
piotrbanas@xper.pl
#>

[CmdletBinding(SupportsShouldProcess)] 
#Requires -modules ActiveDirectory
Param
(
    [parameter(Mandatory)]
    [String[]]$exserver,

    [parameter(Mandatory)]
    [ValidateScript({Test-Path $_})]
    [String[]]$plik

)
Write-Verbose "Uzyskuje nazwe domeny"
$Domena = (Get-ADDomain).DNSRoot

try {
    Write-Verbose "Nawiazuje polaczenie z serwerem Exchange: $exserver.$domena"
    $VerbosePreference = 'SilentlyContinue'
    $exsesja = New-PSSession –ConfigurationName Microsoft.exchange –ConnectionUri "http://$exserver.$domena/powershell" -AllowRedirection -Authentication Kerberos -ErrorAction Stop
    $VerbosePreference = 'Continue'
}
catch {
    Throw $_
}
Write-Verbose "Importuje Exchange Management Shell do lokalnej sesji"
$VerbosePreference = 'SilentlyContinue'
Import-PSSession $exsesja
$VerbosePreference = 'Continue'

$noweskrzynki = Get-Mailbox -resultsize unlimited | Where-Object {$_.WhenMailboxCreated –ge ((Get-Date).Adddays(-1)) }
Write-Verbose "Wykryto $($noweskrzynki.Count) skrzynek zalozonych w ciagu ostatnich 24 godzin"
$panie = $noweskrzynki | select -ExpandProperty samaccountname | Get-Aduser -Properties Name, Givenname, EmailAddress | Where Givenname -like *a
Write-Verbose "Z tego $($panie.count) skrzynek Pań"

Write-Verbose "Importuje zawartosc pliku $plik"
$tekst = Get-Content -Path $plik | Out-String
$smtpserver = Get-ExchangeServer | select -expand fqdn

Foreach ($pani in $panie) {
    Write-Verbose "Wysylam powitanie do $($pani.GivenName) na adres $($pani.EmailAddress)"
    Send-MailMessage -Subject "Witaj $($pani.GivenName)" -Body $tekst -To $($pani.EmailAddress) -From "$env:USERNAME@$env:USERDOMAIN" -SmtpServer $smtpserver
}

Write-Verbose "Zamykam sesje $exsesja"
Remove-PSSession $exsesja