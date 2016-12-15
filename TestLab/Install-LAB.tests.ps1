
#Testy środowiska lab

Param
(
    [parameter()]
    [String]$LabName = 'LAB1',

    [Parameter()]
    [pscredential]$credential = (Get-Credential)

)

$nameToIP = foreach ($n in @('Node1', 'Node2')) {
    $v = Get-vm -name $n
    $props = @{
        Nazwa = $n
        Adres = $v.NetworkAdapters.IPAddresses[0]
    }
    $obj = New-Object -TypeName PSObject -Property $props
    Write-Output $obj
}

$sesjadc = New-PSSession -ComputerName DC$Labname -Credential $credential
$sesjeSrv = $nameToIP.Adres | ForEach-Object { New-PSSession -ComputerName $_ -Credential $credential }

Describe "Maszyny Wirtualne" {
    It "VM DC$LabName" {
        (Get-VM DC$LabName).State | Should Be 'Running'
    }
    $NameToIP.Nazwa | ForEach-Object {
        It "VM $_" {
            (Get-VM $_).State | Should Be 'Running'
        }
    }
}

Describe "Połączenia do serwerów" {
    It "Połączenie do DC$Labname" {
        $sesjadc.State | Should Be 'Opened'
    }
    $NameToIP | ForEach-Object {
        It "Połaczenie do $($_.keys)" {
            ($sesjeSrv | where computername -eq $_.adres).State | Should Be 'Opened'
        }
    }
}

Describe "Serwer www" {
    Context "Usługa IIS" {
        It "Usługa W3SVC" {
        (Invoke-Command -Session ($sesjeSrv | where computername -eq ($nameToIP | where nazwa -eq 'Node1').Adres ) -ScriptBlock {Get-Service W3SVC }).Status | Should be 'Running'
        }
    }
  
    Context "Odpowiedź z serwera ISS" {
        $web = Invoke-WebRequest -Uri ($nameToIP | where nazwa -eq 'Node1').Adres
        It "Poprawna nazwa w tytule strony" {
            $web.ParsedHtml.title | Should be "IIS Windows Server"
        }
    }
}