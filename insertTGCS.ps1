<# 
   Narzędzie codziennej podmiany nazw artykułów w systemie IBM TGCS
   Kontakt piotrbanas@xper.pl
   Wymaga modułu PBFunkcje.
   Matryca podmiany z pliku csv.
#>
#Start-Transcript -Path C:\insert\transcript.txt

cd c:\insert
Import-Module PBFunkcje
new-mount -user 'Administrator' -mountpoint "\\192.168.32.54\D$\temp\home\as400\BOFO\Good" -mountname 'srv54' -passfile AdmPass.txt

$today = (Get-Date).ToString('yyyyMMdd')
$temppath = 'C:\insert'
$cennik = 'FHAUCP00.'+$today+'.1'
$tempfile = $temppath+'\FHAUCP00_'+$today+'.tmp'
$outfile = $temppath+'\FHAUCP00'
Remove-Item $outfile -force

#Importuj kody kreskowe obserwowanych towarów i docelowe nazwy
$matryca = "$temppath\matryca.csv"
$mapping = Import-Csv $matryca -encoding OEM -Delimiter ","

#Wyciągnij interesujące nas linie z cennika do pliku tymczasowego. Plik tymczasowy jest przy okazji logiem historii zmian.
select-string $mapping.EAN -path srv54:\$cennik -Encoding OEM | select-object -ExpandProperty line | out-file $tempfile -Force

#Podmień nazwy w pliku tymczasowym
$content = Get-Content $tempfile

foreach ($line in $content) {
  foreach($map in $mapping) {
    if ($line -like "*$($map.EAN)*") { 
      ($line).Replace($line.substring(41,30), $map.nazwa) | Out-File -Append -Filepath $outfile -encoding OEM
    }
  }
}

#Odmontuj cenniki
Remove-PSDrive srv54

#Wyślij plik wynikowy (jeśli istnieje) na ftp kontrolera kas
$ftp = "ftp://user:pass@192.168.54.78/FHAUCP00"
$webclient = New-Object System.Net.WebClient
$uri = New-Object System.Uri($ftp)
if ((Get-item $outfile).length -gt 0kb) {
"Uploading $outfile on $today..." | tee -append $temppath\ftpLog.txt
$webclient.UploadFile($uri, $outfile) | tee -append $temppath\ftpLog.txt}
# Stop-Transcript

Write-EventLog -LogName Automatyzacja -Source 'PBFunkcje' -EventId 30 -Message 'Monitorowanie artykułów w cenniku'