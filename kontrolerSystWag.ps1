<#
    Narzędzie kontroli systemów RDM, Balance i wag.
    Korzysta z modułu PBFunkcje
    Wynik publikuje w postaci HTML. 
    Formatowanie HTML za pomocą stylu definiowanego w nagłówku oraz prostwj podmiany znaczników html.
#>
Start-Transcript -Path C:\frontoffice\log.txt

Set-Location -Path C:\frontoffice\
Import-Module -Name PBFunkcje
$today = Get-date

Remove-PSSession -ComputerName * -ErrorAction SilentlyContinue
$adresy = Get-Content -Path .\RDMIP.txt
# $adresy = Get-Content .\rdmTestEnv.txt

$sklepy = @(111,112,115,126,143,154,169)
$ping = New-Object System.Net.Networkinformation.ping
$serwery = Get-Content -Path .\sesje.txt

# status serwerów
$pingSerw = 
    ForEach ($ip in $serwery) {

    $p = $ping.Send($ip)

    $prop = @{
              Adres = $ip
              Status = $p.status
              Opóźnienie = $p.RoundtripTime
              }
     $obj = New-Object -TypeName PSObject -Property $prop
     Write-Output $obj
}

$b = $pingSerw | convertto-html -Fragment -As table


$adresy | . new-sesja  -user Administrator -passfile .\AdmPASS.txt
new-sesja -computername 192.168.22.58 -user InnyAdministrator -passfile 58admin.txt
$sesje = Get-PSSession | Where-Object -FilterScript {$_.ComputerName -in (Get-Content -Path .\sesje.txt)}

# Czy działają usługi
$time = Get-Date -format HH:mm
$b += Invoke-Command -Session $sesje -ScriptBlock {Get-Service | where {$_.displayname -like '*mysql*' -or $_.DisplayName -like '*apache*'}} |
 ConvertTo-Html -Property @{e='PSComputerName'; l='RDM usł.'}, @{e='Name'; l='Usługa'}, Status -Fragment -as Table

# Digi
$sesjeDigi = Get-PSSession | Where-Object -FilterScript {$_.ComputerName -in (Get-Content -Path .\RDMdigi.txt)}
$b += Invoke-Command -Session $sesjeDigi -ScriptBlock {Get-Service | where {$_.displayname -like '*BalanceHQ*' -or $_.DisplayName -like '*FireBird Server*'}} |
 ConvertTo-Html -Property @{e='PSComputerName'; l='Balance'}, @{e='DisplayName'; l='Usługa'}, Status -Fragment -as Table

# pliki rdm
$b += Invoke-COmmand -Session $sesje -ScriptBlock {Get-ChildItem -Path C:\Wagi\in\Archive | Where-Object -FilterScript {($_.LastWriteTime -gt (Get-Date).Date -and $_.LastWriteTime.Hour -lt 6) -and (! $_.PSIsContainer) }} |
 ConvertTo-Html -Property @{e='PSComputerName'; l='Cenniki'}, @{e='Name'; l='Plik'}, LastWriteTime, Length -Fragment -as Table
$b += Invoke-COmmand -Session $sesje -ScriptBlock {Get-ChildItem -Path C:\Wagi\in\ | Where-Object -FilterScript {! $_.PSIsContainer}} |
  ConvertTo-Html -Property @{e='PSComputerName'; l='RDMPliki'}, @{e='Name'; l='Pliki nie przetworzone'}, LastWriteTime, Length -Fragment -as Table

# pliki digi
#$b += Invoke-COmmand -Session $sesjeDigi -ScriptBlock {Get-ChildItem -Path C:\Digi\in_done | Where-Object -FilterScript {($_.LastWriteTime -gt (Get-Date).Date -and $_.LastWriteTime.Hour -lt 6) -and (! $_.PSIsContainer) }} |
# ConvertTo-Html -Property @{e='PSComputerName'; l='CennikiDigi'}, @{e='Name'; l='Plik'}, LastWriteTime, Length -Fragment -as Table
$b += Invoke-COmmand -Session $sesjeDigi -ScriptBlock {Get-ChildItem -Path C:\Digi\in\ | Where-Object -FilterScript {! $_.PSIsContainer}} |
  ConvertTo-Html -Property @{e='PSComputerName'; l='DigiPliki'}, @{e='Name'; l='Pliki nie przetworzone'}, LastWriteTime, Length -Fragment -as Table

# status wag
$pingiW = ForEach ($s in $sklepy) {
$iplist = Get-Content "C:\Skrypty\wagi\$s\wagi$s.txt"

    ForEach ($ip in $iplist) {

    $p = $ping.Send($ip, 2000)

    $prop = @{
              Sklep = $s
              WagiDown = $ip
              Status = $p.status
              }
     $obj = New-Object -TypeName PSObject -Property $prop
     Write-Output $obj
}
}

$b += $pingiW | where Status -eq 'TimedOut' | ConvertTo-Html -Fragment -as Table -Property Sklep, WagiDown, Status

Remove-PSSession -ComputerName *

    $head = @' 
<style> 
body { background-color:#FFD58C; 
       font-family:Tahoma; 
       font-size:8pt; } 
td, th { border:0.2px solid black;  
         border-collapse:collapse; } 
th { color:white; 
     background-color:black; } 
table, tr, td, th { padding: 1px; margin: 0px } 
table { float: left; width: 33% }
</style> 
'@ 


$b = $b -replace 'Running', '<font color=Green>Running</font>'
$b = $b -replace 'Stopped', "<span style=`"background-color: #ff0000`">Stopped</span>"
$b = $b -replace '192.111.43.36', "<span style=`"background-color: #bf80ff`">111</span>"
$b = $b -replace '192.112.43.36', "<span style=`"background-color: #ffff4d`">112</span>"
$b = $b -replace '192.124.43.36', "<span style=`"background-color: #00ffff`">124</span>"
$b = $b -replace '192.137.43.36', "<span style=`"background-color: #ff9900`">137</span>"
$b = $b -replace '192.151.43.36', "<span style=`"background-color: #ccebff`">151</span>"
$b = $b -replace '192.120.43.36', "<span style=`"background-color: #cceb0f`">120</span>"
$b = $b -replace '192.135.43.36', "<span style=`"background-color: #008000`">135</span>"
$b = $b -replace '192.13.43.36', "<span style=`"background-color: #c2c2a3`">13</span>"
$b = $b -replace '192.21.43.36', "<span style=`"background-color: #ffccff`">21</span>"

$b = $b -replace '<tr><td>113</td><td>', "<tr><td><span style=`"background-color: #bf80ff`">113</span></td><td>"
$b = $b -replace '<tr><td>114</td><td>', "<tr><td><span style=`"background-color: #ffff4d`">114</span></td><td>"
$b = $b -replace '<tr><td>121</td><td>', "<tr><td><span style=`"background-color: #00ffff`">121</span></td><td>"
$b = $b -replace '<tr><td>136</td><td>', "<tr><td><span style=`"background-color: #ff9900`">136</span></td><td>"
$b = $b -replace '<tr><td>141</td><td>', "<tr><td><span style=`"background-color: #ccebff`">141</span></td><td>"
$b = $b -replace '<tr><td>150</td><td>', "<tr><td><span style=`"background-color: #cceb0f`">150</span></td><td>"
$b = $b -replace '<tr><td>165</td><td>', "<tr><td><span style=`"background-color: #008000`">165</span></td><td>"
$b = $b -replace '<tr><td>10</td><td>', "<tr><td><span style=`"background-color: #c2c2a3`">10</span></td><td>"
$b = $b -replace '<tr><td>22</td><td>', "<tr><td><span style=`"background-color: #ffccff`">22</span></td><td>"


$b = $b -replace '<tr><th>RDM usł.', '<tr><th>Usł. RDM</th></tr><tr><th>RDM-y'
$b = $b -replace '<tr><th>Balance', '<th>Usł. Balance</th><tr><th>Balance'
$b = $b -replace '<tr><th>Cenniki', '<tr><th>Cenniki Nocne</tr></th><tr><th>RDM-y.'
$b = $b -replace '<tr><th>Address</th>', '<tr><th>Ping serwerów:</th></tr><tr><th>Address</th>'
$b = $b -replace '<tr><th>RDMPliki', '<tr><th></th><th>Pliki wiszące</th></tr><tr><th>RDM-y'


New-mount -mountpoint '\\x.x.x.x\raporty' -mountname ITRapo

ConvertTo-Html -Head $head -PostContent $b -Body "<h1>Kontrola systemów wagowych. $today</h1>" > "C:\frontoffice\rdm.html"
Copy-Item -Path C:\frontoffice\rdm.html -Destination "ITRapo\rdm.html" -Force

Write-EventLog -LogName Automatyzacja -Source 'PBFunkcje' -EventId 10 -Message 'Kontrola systemów RDM'
Stop-Transcript