<#
  Skaner sieciowy urządzeń. Dane z poprzednich skanów trzyma w plikach xml. 
  Dla urządzeń niewidocznych od 3 godzin tworzy zgłoszenie w HelpDesku.
  Resetuje stan skanowań o 6 rano, albo jeśli nie był uruchamiany od 2 godzin.
  Przechowuje listę zgłoszonych adresow, aby nie dublować zgłoszeń. 
  
  Autor: piotrbanas@xper.pl
#>

import-module PBFunkcje
$czas = Get-Date
$sklep = 10
$sciezka = "C:\skrypty\wagi\$sklep"
$xmlsukces = "$sciezka\sukces.xml"
$xmlfail = "$sciezka\failed.xml"
set-location $sciezka

function new-lista {

    $IPs = Get-Content $sciezka\wagi$sklep.txt
    $sukces = ForEach ($IP in $IPs) { 
        $props = @{
              Adres = $IP
              Status = 'Nieustalony'
              Czas = $czas
              }
    $obj = New-Object -TypeName psobject -Property $props
    Write-Output $obj
    }
    $sukces | Export-Clixml -Path $xmlsukces
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

# Rano resetuj stan urządzeń albo jeli nie było aktualizacji od 2 godzin

if  ($czas.Hour -eq 6 -or (get-item $sciezka\failed.xml).LastWriteTime -lt  (Get-Date).AddHours(-2) ) {
  remove-item -Path $xmlsukces -Force
  remove-item -Path $xmlfail -Force

  # Generuję nową listę z pliku tekstowego
  new-lista
  # skanuję adresy z nowej listy
  new-skan -lista $xmlsukces

  # rozbijam adresy na sukces/failed
  $txp | Where-Object -property Status -eq 'OK' | Export-Clixml $xmlsukces -Encoding UTF8
  $txp | Where-Object -property Status -NE 'OK' | Export-Clixml $xmlfail -Encoding UTF8

}

 # następne skany:
else {
  # skanuję adresy, które trafiły w poprzednim skanowaniu do failed
  new-skan -lista $xmlfail
  # jeśli któreś zaczeły odpowiadać, zwaracm je do listy sukces
  $txs = $txp | Where-Object -property Status -eq 'OK'
  $tx0 = Import-Clixml $xmlsukces
  $tx0 += $txs
  $tx0 | export-clixml $xmlsukces -Encoding utf8
  # nadpisuję listę failed (pozostawiam oryginalny czas skanowania)
  $txp | Where-Object Status -EQ 'Błąd' | export-clixml $xmlfail -Encoding utf8
  
  # skanuję i nadpisuję nową listę sukces
  new-skan -lista $xmlsukces
  $txp | Where-Object -property Status -eq 'OK' | Export-Clixml $xmlsukces -Encoding UTF8
  # dopisuję nowe faile do listy failed
  $txf = Import-Clixml $xmlfail
  $txf += $txp | Where-Object status -EQ 'Błąd'
  $txf | Export-Clixml  $xmlfail -Encoding UTF8
  
}


# z failed wybieram adresy, które trafiły tam ponad 4 godziny temu
$failed = Import-Clixml $xmlfail 
$doZgloszenia = $failed | Where-Object {$_.Czas -lt (Get-Date).AddHours(-3)}

# tworzę treść emaila z pominięciem zgłoszonych w przeszłosci
$tresc = $doZgloszenia | Where-Object {$_.Adres -inotin (Import-Csv $sciezka\zgloszone.csv).adres}
   
$t = $tresc | ForEach-Object {
  $a = $_.Adres
  $c = $_.czas
  "`nUrządzenie $a nie odpowiada od conajmniej $c."
  # zgłoszone adresy zapisuję w pliku
  Export-Csv -InputObject $_ -Append -Path $sciezka\zgloszone.csv -NoTypeInformation -Encoding UTF8 -Force
}

$t += "`nProszę o sprawdzić urządzenia oraz media połączeniowe."

# wysyłam email tworzący zgłoszenie w HelpDesku
if ($tresc) {
Send-smtp -nadawca 'monitoring@xper.pl' -odbiorca 'helpdesk@xper.pl' -temat "[$sklep] Błąd łączności z urządzeniem sklepowym" -tresc $t
}

# sprawdzam zgłoszone wcześniej
Import-CSV $sciezka\zgloszone.csv | Export-Clixml $sciezka\zgl.xml
new-skan -lista $sciezka\zgl.xml 
$txp | Where-Object Status -NE 'OK' | Export-Csv -Path $sciezka\zgloszone.csv -NoTypeInformation -Encoding UTF8 -Force
