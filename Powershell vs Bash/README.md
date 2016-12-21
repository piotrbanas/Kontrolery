Skrypt bash formatuje wyniki skanowania nmap do formatu "OK"/"BŁĄD". Ponieważ potok w świecie unixowym opiera sie na strumieniowaniu danych, jesteśmy zmuszeni wykorzystywać narzędzia manipulacji tekstu - grep, sed, czy awk.

W Powershellu potok przekazuje między komendami obiekty .NET-owe, dzięki czemu mamy większą swobodę łączenia komend i manipulowania wynikiem:

$skan = @('10.101.34.103', '10.101.34.105', '10.101.34.106') | %{(Test-Connection -ComputerName $_ -Count 3 -Quiet ) -replace 'True','OK' -replace 'False','BŁĄD'}

$skan += @('10.101.33.181', '10.101.33.186') |  %{(Test-NetConnection -computername $_ -port 80).TcpTestSucceeded -replace 'True','OK' -replace 'False','BŁĄD'}

