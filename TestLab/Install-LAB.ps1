<#
.SYNOPSIS             
    Skrypt generuje środowisko testowe
.DESCRIPTION
    Skrypt generuje wirtualne laoratorium: Kontroler domeny, serwer ISS oraz serwer plików. Wszystkie w edycji Core.
    Wypełnia bazę AD przykładowymi danymi z pliku names.csv
    Wymaga Hyper-V. 
    Wymaga modułu Convert-WindowsImage (doinstalowuje z Galerii).
    Wymaga WMF 5 (do zestawienia sesji po szynie wirtualizatora).
.PARAMETER Isopath
    Ścieżka do pliku iso z obrazem Windows Server
.PARAMETER LabPath
    Ścieżka folderu LAB
.PARAMETER UnattendedXml
    Ścieżka pliku nienadzorowanej instalacji. 
    W nim umieszczamy tymczasowe hasło lokalnego Administratora.
.PARAMETER LabName
    Nazwa Lab-a
.EXAMPLE
Install-Lab.ps1 -ISOPath 'C:\technet\iso\WINBLUE_X64FRE_SERVER_EVAL_EN-US_DV9.iso' -LabPath 'C:\LAB' -LabName 'LAB2' -UnattendXml 'C:\LAB\unattend.xml'
.LINK
https://github.com/piotrbanas
#>

Param
(
    [parameter(Mandatory)]
    [ValidateScript({Test-Path $_})]
    [String]$ISOPath,

    [parameter()]
    [ValidateScript({Test-Path -PathType Container $_ })]
    [String]$LabPath = 'C:\LAB',

    [parameter()]
    [ValidateScript({Test-Path $_})]
    [String]$UnattendXml = "$LabPath\unattend.xml",

    [parameter()]
    [String]$LabName = 'LAB1'
    
)

#region poswiadczenia
$adminpassfile = "$LabPath\adminpass.txt"
if (!(Test-Path $adminpassfile)) {
    Read-Host "Podaj hasło dla lokalnego administratora" -AsSecureString | ConvertFrom-SecureString | Out-File "$adminpassfile"
}

$adpassfile = "$LabPath\adpass.txt"
if (!(Test-Path $adpassfile)) {
    Read-Host "Podaj hasło dla administratora domenowego" -AsSecureString | ConvertFrom-SecureString | Out-File "$adpassfile"
}


$adminpass = Get-Content -path $adminpassfile | ConvertTo-SecureString
$admincred = new-object -typename System.Management.Automation.PSCredential -argumentlist 'Administrator', $adminpass

$adpass = Get-Content -path $adpassfile | ConvertTo-SecureString
$aduser = "$LabName.local\Administrator"
$DomainCred = new-object -typename System.Management.Automation.PSCredential -argumentlist $aduser, $adpass
#endregion

#region Tworzymy dysk bazowy i VM Kontrolera Domeny
If (!( Get-Module Convert-WindowsImage)) {
    try {
        Install-Module Convert-WindowsImage  -Force -ErrorAction Stop
    }
    catch {
        Throw $Error
    }
}
Else {Import-Module Convert-WindowsImage -force}

$dchost = "DC$LabName"
$VHDBasePath = "$LAbPath\$LabName\VHDs\base\LabServerBase.vhdx"
$VHDPath = "$LabPath\$LabName\VHDs\$dchost.vhdx"

Stop-VM -TurnOff -Name $dchost, Node1, Node2 -Force -ErrorAction SilentlyContinue
Remove-VM $dchost, Node1, Node2 -Force -ErrorAction SilentlyContinue

Remove-Item $VHDPath -Force -ErrorAction SilentlyContinue
Remove-Item $LabPath\$LabName\VHDs\Node1.vhdx -force -ErrorAction SilentlyContinue
Remove-Item $LabPath\$LabName\VHDs\Node2.vhdx -force -ErrorAction SilentlyContinue


$convertWindowsImageParams = @{
    SourcePath = "$ISOPath"
    SizeBytes = 25GB
    VHDFormat = "VHDx"
    UnattendPath = "$UnattendXml"
    Edition = "ServerDatacenterCore"
    VHDPath = $VHDBasePath
    DiskLayout = "UEFI"
}

If (!(Test-Path $LabPath\$LabName\VHDs\base\LabServerBase.vhdx)){
$VHDx = Convert-WindowsImage @convertWindowsImageParams -Passthru -Verbose
}

If (!(Get-VMSwitch | where Name -match 'SwitchLab')){
New-VMSwitch -Name 'SwitchLAB' -SwitchType Internal
}
New-VHD -Path $VHDPath -ParentPath $VHDBasePath -Differencing -OutVariable ChildVHD | out-null
$dcvm = New-VM -Name $dchost -VHDPath $VHDPath -MemoryStartupBytes 2GB -SwitchName 'SwitchLab' -Generation 2
Set-VM $dcvm -ProcessorCount 2
Start-VM $dcvm

$ip = (Get-VM -Name $dchost | Select-Object -ExpandProperty networkadapters).ipaddresses
While ($ip.count -lt 2)
    {
        $ip = (Get-VM -Name $dchost | Select-Object -ExpandProperty networkadapters).ipaddresses
        Write-Output "Czekam na podniesienie VM-ki $dchost"
        Start-Sleep -Seconds 5
    }
#endregion

#region konfiguracja Interfejsu wirtualizatora

$LocalAdapter = Get-NetAdapter "*SwitchLab*"
Write-Output "Konfiguruję interfejs $($LocalAdapter.Name)"
New-NetIPAddress -IPAddress '192.168.1.2' -DefaultGateway '192.168.1.1' -PrefixLength 24 -InterfaceIndex $LocalAdapter.InterfaceIndex -AddressFamily IPv4
Get-NetConnectionProfile -InterfaceIndex $LocalAdapter.InterfaceIndex | Set-NetConnectionProfile -NetworkCategory Private
Set-DnsClientServerAddress -InterfaceIndex $LocalAdapter.InterfaceIndex -ServerAddresses '192.168.1.1'
#endregion

#region Konfiguracja DC
Write-Output "Otwieram połączenie do $dchost przez szynę Hyper-V"

try {
$SesjaDC = New-PSSession -VMId $dcvm.id -Credential $admincred -ErrorAction Stop
}
catch {
 Throw $error
 #Throw "Nie mogę połączyć z $dchost"
}

Invoke-Command -Session $SesjaDC -ScriptBlock {
    $NetAdapter = (Get-Netadapter)[0].Name
    Write-Output "Ustawiam statyczny IP na interfejsie $netadapter"
    New-NetIPAddress -IPAddress '192.168.1.1' -PrefixLength 24 -InterfaceIndex (Get-Netadapter)[0].InterfaceIndex | out-null
    Write-Output "Uruchamiam PSRemoting"
    Enable-PSRemoting -Force
    Write-Output "Otwieram WSMan"
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value * -Force
}


Workflow Rename-DC {
Param(
    [string]$NewName
)
Rename-Computer -PSComputerName $PSComputername -PSCredential $PSCredential -NewName $NewName
Restart-Computer -wait -for PowerShell -Protocol WSMan
}
Write-Output "Zmieniam hostname na $dchost"
Rename-DC -PSComputerName '192.168.1.1' -PSCredential $admincred -NewName "$dchost"

Write-Output "Nawiązuje ponownie połączenie"
New-PSSession -ComputerName '192.168.1.1' -Credential $admincred -OutVariable SesjaDC | out-null


Write-Output "Instaluję rolę ADDS i tworzę las $LabName.local"
Invoke-Command -Session $SesjaDC -ScriptBlock {
    Write-Output "Instaluję ADDS"
    Install-WindowsFeature -Name AD-Domain-Services -IncludeAllSubFeature
    Write-Output "Instaluję las"
    Install-ADDSForest -DomainName $args[0] -SafeModeAdministratorPassword $args[1] -Force
} -ArgumentList "$LabName.local", $adpass


$ip = (Get-VM -Name $dchost | Select-Object -ExpandProperty networkadapters).ipaddresses
While ($ip.count -lt 2)
    {
        $ip = (Get-VM -Name $dchost | Select-Object -ExpandProperty networkadapters).ipaddresses
        Write-Output "Czekam na podniesienie VM-ki $dchost"
        Start-Sleep -Seconds 5 
    }

Write-Output "Restartuję serwer po zainstalowaniu ADDS"
Restart-Computer -Force -ComputerName '192.168.1.1' -Credential $DomainCred -Protocol WSMan -wait -for PowerShell

Write-Output "Nawiązuję połączenie na poświadczeniach domenowych"
try {
    $sesjaADDC = New-PSSession -VMId $dcvm.id -Credential $DomainCred
}
catch {
    throw "Nie mogę nawiązać połączenia "
}
$dhcpUri = "$dchost.$LabName.local"

$adcheck = Invoke-Command -Session $sesjaADDC -ScriptBlock { (Get-ADDomainController).Enabled}
While ($adcheck -ne $true) {
    $adcheck = Invoke-Command -Session $sesjaADDC -ScriptBlock { (Get-ADDomainController).Enabled}
    Write-Output "Czekam na dostępność ADDS"
    Start-Sleep -Seconds 10
}

Invoke-Command -Session $SesjaADDC -ScriptBlock {

    Write-Output "Przestawiam profil sieci"
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private
    Start-Sleep -Seconds 10
    Set-NetFirewallProfile -name Domain -Enabled False 
    Set-NetFirewallProfile -name Private -Enabled False
}



Install-WindowsFeature -ComputerName '192.168.1.1' -Credential $DomainCred -Name DHCP
Start-Sleep -Seconds 30
Write-Output "Restartuję serwer po zainstalowaniu DHCP"
Restart-Computer -ComputerName '192.168.1.1' -Credential $DomainCred -Protocol WSMan -wait -for PowerShell

Write-Output "Nawiązuję połączenie na poświadczeniach domenowych"
try {
    $sesjaADDC = New-PSSession -VMId $dcvm.id -Credential $DomainCred
}
catch {
    throw "Nie mogę nawiązać połączenia "
}
$dhcpUri = "$dchost.$LabName.local"

$adcheck = Invoke-Command -Session $sesjaADDC -ScriptBlock { (Get-ADDomainController).Enabled}
While ($adcheck -ne $true) {
    $adcheck = Invoke-Command -Session $sesjaADDC -ScriptBlock { (Get-ADDomainController).Enabled}
    Write-Output "Czekam na dostępność ADDS"
    Start-Sleep -Seconds 10
}


Invoke-Command -Session $sesjaADDC {
    $dhcpParams = @{
        StartRange = '192.168.1.100'
        EndRange = '192.168.1.200'
        Name = 'LabScope'
        State = 'Active'
        LeaseDuration = (New-TimeSpan -Days 365)
        SubnetMask = '255.255.255.0'
        Type = 'Dhcp'
    }
    Write-Output "Konfiguruję rolę DHCP"
    Add-DhcpServerv4Scope @dhcpParams
    Start-Sleep -Seconds 10
    Set-DhcpServerv4OptionValue -DnsServer '192.168.1.1'
    Start-Sleep -Seconds 10
    Set-DhcpServerv4OptionValue -Router '192.168.1.1'
    Start-Sleep -Seconds 10

}


Remove-PSSession * | Out-Null
Write-Output "Nawiązuję połączenie na poświadczeniach domenowych"
try {
    $sesjaADDC = New-PSSession -VMId $dcvm.id -Credential $DomainCred
}
catch {
    throw "Nie mogę nawiązać połączenia "
}

Write-Output "Autoryzuję DHCP w AD"
Try {
    Invoke-Command -Session $sesjaADDC -ScriptBlock {
        Add-DhcpServerInDC
    } -ErrorAction Stop
}
catch {
    Throw "Błąd autoryzacji DHCP w AD"
}

#endregion

#region Tworzymy maszyny klienckie
workflow Install-VM {
param (
    [Parameter(Mandatory,
               Position=0)]
    [ValidateNotNull()]
    [string]
    $SourceVhdPath,

    [Parameter(Mandatory,
               Position=1)]
    [ValidateNotNull()]
    [string]
    $DestinationVhdPath,

    [Parameter(Mandatory,
               Position=2)]
    [string[]]
    $Name,

    [Parameter(Mandatory,
              Position=3)]
    [string]$SwitchName
)

    $ipAddresses = foreach -parallel ($n in $Name)
    {
        $newVhdPath = "$DestinationVhdPath\$n.vhdx"

        Write-Output  "Tworzę dysk $n.vhdx na podstawie $SourceVhdPath"
        $null = New-VHD -Path $newVhdPath -ParentPath $SourceVhdPath -Differencing
        
        Write-Output  "Tworzę maszynę wirtualną $n"
        $null = New-VM -Name $n -VHDPath $newVhdPath -MemoryStartupBytes 512MB -SwitchName $switchName -Generation 2
        Write-Output  "Startuję $n"
        Start-VM -Name $n
     
        $ip = (Get-VM -Name $n | Select-Object -ExpandProperty networkadapters).ipaddresses
        while($ip.Count -lt 2) {
            $ip = (Get-VM -Name $n | Select-Object -ExpandProperty networkadapters).ipaddresses
            Write-Output "Proszę czekać..."
            Start-Sleep -Seconds 5;
        }
        $ip[0]
    }
    

}
Write-Output "Tworzę dodatkowe serwery"
Install-VM -SourceVhdPath $VHDBasePath -DestinationVhdPath $LabPath\$LAbName\VHDs -Name Node1, Node2 -SwitchName 'SwitchLab'
#endregion

#region Konfiguracja serwerów
Write-Output "Mapuję nazwy maszyn wirtualnych z ich adresami IP"

$nameToIP = foreach ($n in @('Node1', 'Node2')) {
    $v = Get-vm -name $n
    $props = @{
        Nazwa = $n
        Adres = $v.NetworkAdapters.IPAddresses[0]
    }
    $obj = New-Object -TypeName PSObject -Property $props
    Write-Output $obj
}


workflow Join-Domain {
param (
    [Parameter(Mandatory=$True, 
               Position=0)]
    [ValidateNotNull()]
    [System.Object]$nameToIp,
    [pscredential]$DomainCred,
    [string]$DomainName

)

    Foreach -parallel ($computer in $PSComputerName) {
        Start-Sleep -Seconds 10
        Add-Computer -DomainName $DomainName -NewName ($nameToIp | where Adres -eq $computer).nazwa -Credential $DomainCred
        Start-Sleep -Seconds 10
        Restart-Computer -wait -for PowerShell -Protocol WSMan
    }
}
Write-Output "Dodaję serwery do AD"
Join-Domain -nameToIp $nameToIP -DomainCred $DomainCred -DomainName "$LabName.local" -PSComputerName $nameToIP.Adres -PSCredential $admincred

New-PSSession -ComputerName ($nameToIP | where Nazwa -eq 'Node1').adres -Credential $DomainCred -OutVariable Sesja1
Invoke-Command -Session $Sesja1 {
    Install-WindowsFeature -Name web-server,web-asp,web-asp-net45 -Restart
}

New-PSSession -ComputerName ($nameToIP | where Nazwa -eq 'Node2').adres -Credential $DomainCred -OutVariable Sesja2
Invoke-Command -Session $Sesja2 {
    Install-WindowsFeature -Name File-Services,FS-FileServer -Restart
}

#endregion

#region Wypełnianie AD danymi z csv
$populateAD = {
Import-Module ActiveDirectory
$LabN = $using:LabName
$TABDEPARTMENT = @("Kadry","Zarzad","IT","Ksiegowosc","Handel","Marketing")
$TABTITLE = @("Pracownik","Kierownik","Dyrektor","Lider","Informatyk","Asystent","Prezes")

# Tworzę strukturę organizacyjną
$TABDEPARTMENT | % { New-ADOrganizationalUnit -Name $_ -Path "DC=$LabN,DC=local"}
$TABDEPARTMENT | % { New-ADOrganizationalUnit -Name komputery -Path "OU=$_,DC=$LabN,DC=local"}
$TABDEPARTMENT | % { New-ADOrganizationalUnit -Name uzytkownicy -Path "OU=$_,DC=$LabN,DC=local"}

$Lista = import-csv C:\names.csv 

@('Company','Department','Title','Name','SamAccountName','UserPrincipalName','Path') | % {$lista | Add-Member -NotePropertyName $_ -NotePropertyValue ''}

#dostosowanie danych z csv
$Lista | ForEach-Object {
    $_.GivenName = $_.GivenName.Trim()
    $_.Surname = $_.Surname.Trim()
    $_.Company = $LabN
    $_.Department = Get-Random $TABDEPARTMENT -OutVariable Dept
    $_.Title = Get-Random $TABTITLE
    $_.Name = $_.GivenName + ' ' + $_.Surname
    $_.SamAccountName = $_.GivenName + $_.Surname
    $_.UserPrincipalName = $_.SamAccountName + '@' + "$LabN" +'.local'
    $_.Path = 'OU=Uzytkownicy,OU=' + $Dept + ',DC=' + $LabN +',DC=local'
}

# Samaccountname nie może być dłuższe niż 20 znaków
$Lista | ForEach-Object {
    If ($_.SamAccountName.length -gt 20) {
        $l = $_.SamAccountName.length - 20
        $s = $_.Givenname.length - $l
        $_.SamAccountName = $_.GivenName.Substring(0,$s) + $_.Surname

    }
}

$Lista | New-ADUser | Out-Null
}

If (Test-Path $LabPath\names.csv) {
Write-Output "Nawiązuję połączenie na poświadczeniach domenowych"
$SesjaADDC = New-PSSession -VMId $dcvm.id -Credential $DomainCred

Copy-Item C:\lab\names.csv -Destination c:\names.csv -ToSession $SesjaADDC
Invoke-Command -Session $SesjaADDC -ScriptBlock $populateAD
}
#endregion

# testy
.$LabPath\Install-LAB.tests.ps1 -LabName $LabName -credential $DomainCred

