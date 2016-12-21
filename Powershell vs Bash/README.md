Skrypt bash formatuje wyniki skanowania nmap do formatu "OK"/"BŁĄD".

To samo w Powershellu:

New-PSDrive -PSProvider FileSystem -Name Skany -Root '10.101.33.31\Backup'

$or = @('10.101.34.103', '10.101.34.105', '10.101.34.106') | %{(Test-Connection -ComputerName $_ -Count 3 -Quiet ) -replace 'True','OK' -replace 'False','BŁĄD'}

$or += @('10.101.33.181', '10.101.33.186') |  %{(Test-NetConnection -computername $_ -port 80).TcpTestSucceeded -replace 'True','OK' -replace 'False','BŁĄD'}

$or | Out-File Skany:\101nmap.txt
