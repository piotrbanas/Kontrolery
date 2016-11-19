<#
    .SYNOPSIS
    Narzędzie codziennej podmiany nazw artykułów w systemie IBM TGCS
    .DESCRIPTION
    Lokalna zmiana nazw artykułów 
    .PARAMETER sklep
    .EXAMPLE
    .\insert.ps1 -sklep 54 -matryca .\matryca.csv
    .NOTES
    Autor: piotrbanas@xper.pl
    .LINK
    https://github.com/piotrbanas
#>
[cmdletbinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory,
     ValueFromPipeline,
     Position = 0,
     HelpMessage = 'Podaj numer sklepu')]
     [ValidateSet(24, 35, 36, 54, 91, 102, 134)]
     [int]$sklep,

     [Parameter(Mandatory,
     Position = 1,
     HelpMessage = 'Podaj ścieżkę matrycy produktów')]
     [ValidateScript({Test-Path $_})]
     [string]$matryca
)
switch ($sklep)
    {
        24 {$nr=47}
        35 {$nr=48}
        36 {$nr=45}
        54 {$nr=50}
        91 {$nr=44}
        102 {$nr=46}
        134 {$nr=49}
         
        default {"Nieprawidłowy numer sklepu"
                  Break
                 }
    } # End switch

Import-Module PBunkcje -Verbose:$false | Out-Null
$today = (Get-Date).ToString('yyyyMMdd')
$temppath = 'C:\insert'
$cennik = 'FHAUCP00.'+$today+'.1'
$outfile = $temppath+'\FHAUCP00'
Remove-Item $outfile -force -ErrorAction SilentlyContinue

Write-Verbose "Mapuję folder cennika sklepu $sklep"
$mountname = 'SRV'+$sklep
new-mount -mountpoint "\\192.168.32.$nr\D$\temp\home\as400\BOFO\Good" -mountname $mountname -user "192.168.32.$nr\Administrator" -passfile $temppath\AdminPass.txt

Write-Verbose "Importuję kody kreskowe obserwowanych towarów i docelowe nazwy z pliku $matryca"
$mapping = Import-Csv $matryca -encoding OEM -Delimiter ","

#Wyciągnij interesujące nas linie z cennika 
$match =  select-string $mapping.EAN -path "$mountname`:\$cennik" -Encoding OEM | select-object -ExpandProperty line
If ($match) {
Write-Verbose "Znalazłem następujące artykuły:"
$match | ForEach-Object {Write-Verbose $_.substring(41,30)}
}

#Podmień nazwy

foreach ($line in $match) {
  foreach($map in $mapping) {
    if ($line -like "*$($map.EAN)*") { 
      Write-Verbose "Koryguję nazwę artykułu $($map.EAN)"
      ($line).Replace($line.substring(41,30), $map.nazwa) | Out-File -Append -Filepath $outfile -encoding OEM
    }
  }
}

Write-Verbose "Odmontowuję folder cennika"
Remove-PSDrive $mountname | Out-Null

#Wyślij plik wynikowy (jeśli istnieje) na ftp kontrolera kas
$ftp = "ftp://user:pas@192.168.$sklep.78/FHAUCP00"
$webclient = New-Object System.Net.WebClient
$uri = New-Object System.Uri($ftp)
if (Test-Path $outfile) {
    Write-Verbose "Wysyłam $outfile do ftp kontrolera $sklep"
    "Uploading $outfile on $today..." | tee -append $temppath\ftpLog.txt
    $webclient.UploadFile($uri, $outfile) | tee -append $temppath\ftpLog.txt
} else {Write-Verbose "Brak danych do wysyłki na ftp"}

Write-EventLog -LogName Automatyzacja -Source 'PBFunkcje' -EventId 30 -Message 'Monitorowanie artykułów w cenniku'