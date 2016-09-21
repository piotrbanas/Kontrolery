<#
  Skaner urządzeń sklepowych, w szczególności wag. Dane z poprzednich skanów trzyma w plikach xml. 
  Dla urządzeń niewidocznych od 4 godzin tworzy zgłoszenie w HelpDesku.
  Resetuje stan skanowań o 6 rano, albo jeśli nie był uruchamiany od 2 godzin.
  Przechowuje listę zgłoszonych adresow, aby nie dublować zgłoszeń. 
  
  Do zrobienia: logika usuwająca adresy z listy zgłoszonych po przywróceniu działania.
#>

import-module PBFunkcje
set-location C:\Skrypty\wagi\121
$czas = Get-Date

function new-lista {

    $IPs = Get-Content C:\Skrypty\wagi\121\wagi121.txt
    $sukces = ForEach ($IP in $IPs) { 
        $props = @{
              Adres = $IP
              Status = 'Nieustalony'
              Czas = $czas
              }
    $obj = New-Object -TypeName psobject -Property $props
    Write-Output $obj
    }
    $sukces | Export-Clixml -Path 'C:\skrypty\wagi\121\sukces.xml'

} # end new-lista

function new-skan {
  param(
    [Parameter(Mandatory=$true)]
    [string]$lista
    )
  $txList = Import-Clixml -Path "$lista"
  $script:txp = 
    foreach ($txL in $txList){
        if (Test-Connection -ComputerName $txL.Adres -count 1 -ErrorAction SilentlyContinue)
        {
        $props = @{
            Adres = $txL.Adres
            Status = 'OK'
            Czas = $czas
            } # props
        
        } # if
        else {
        $props = @{
            Adres = $txL.Adres
            Status = 'Błąd'
            # pozostawiam czas oryginalnego faila
            Czas = $txL.Czas 
            } # props
        } # else

        $obj = New-Object -TypeName psobject -Property $props
        Write-Output $obj
        } # end foreach
  return $txp
} # end new-skan

# Rano resetuj stan urządzeń albo jeśli nie było aktualizacji od 2 godzin
if  ($czas.Hour -eq 6 -or (get-item .\failed.xml).LastWriteTime -lt  (Get-Date).AddHours(-2) ) {
  remove-item -Path 'C:\Skrypty\wagi\121\sukces.xml' -Force
  remove-item -Path 'C:\Skrypty\wagi\121\failed.xml' -Force

  # Generuję nową listę z pliku tekstowego
  new-lista
  
  # skanuję adresy z nowj listy
  new-skan -lista 'C:\Skrypty\wagi\121\sukces.xml'

  # rozbijam adresy na sukces/failed
  $txp | Where-Object -property Status -eq 'OK' | Export-Clixml 'C:\Skrypty\wagi\121\sukces.xml' -Encoding UTF8
  $txp | Where-Object -property Status -NE 'OK' | Export-Clixml 'C:\Skrypty\wagi\121\failed.xml' -Encoding UTF8

} # end if

 # następne skany:
else {
  # skanuję adresy, które poprzednio trafiły do failed
  new-skan -lista 'C:\Skrypty\wagi\121\failed.xml'
  # jeśli któreś zaczeły odpowiadać, zwracam je do listy sukces
  $txs = $txp | Where-Object -property Status -eq 'OK'
  $tx0 = Import-Clixml .\sukces.xml
  $tx0 += $txs
  $tx0 | export-clixml 'C:\Skrypty\wagi\121\sukces.xml' -Encoding utf8
  # nadpisuję listę failed (pozostawiam oryginalny czas skanowania)
  $txp | Where-Object Status -EQ 'Błąd' | export-clixml .\failed.xml -Encoding utf8
  
  # skanuję i nadpisuję nową listę sukces
  new-skan -lista 'C:\Skrypty\wagi\121\sukces.xml'
  $txp | Where-Object -property Status -eq 'OK' | Export-Clixml  .\sukces.xml -Encoding UTF8
  # dopisuję nowe faile do listy failed
  $txf = Import-Clixml .\failed.xml
  $txf += $txp | Where-Object status -EQ 'Błąd'
  $txf | Export-Clixml  .\failed.xml -Encoding UTF8
} # end else

# z failed wybieram adresy, które trafiły tam ponad 4 godziny temu
$failed = Import-Clixml 'C:\Skrypty\wagi\121\failed.xml' 
$doZgloszenia = $failed | Where-Object {$_.Czas -lt (Get-Date).AddHours(-4)}

# tworzę treść emaila z pominięciem zgłoszonych w przeszłosci
$tresc = $doZgloszenia | where {$_.Adres -inotin (Import-Csv .\zgloszone.csv).adres}
   
$t = $tresc | ForEach-Object {
  $a = $_.Adres
  $c = $_.czas
  "`nUrządzenie $a nie odpowiada od conajmniej $c."
  # zgłoszone adresy zapisuję w pliku
  Export-Csv -InputObject $_ -Append -Path .\zgloszone.csv -NoTypeInformation -Encoding UTF8 -Force
} # end foreach-object

$t += "`nProszę o sprawdzić urządzenia oraz media połączeniowe."

# wysyłam email tworzący zgłoszenie w HelpDesku
if ($tresc) {
Send-smtp -nadawca 'kontroler@domena.com.pl' -odbiorca 'helpdesk@domena.com.pl' -SerwerSMTP 'mail.domena.com.pl' -temat '[121] Błąd łączności z urządzeniem sklepowym' -tresc $t
}
