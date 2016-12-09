<#
.SYNOPSIS             
    Skrypt generuje środowisko testowe
.DESCRIPTION
    Skrypt generuje wirtualne laoratorium: Kontroler domeny, serwer ISS oraz serwer plików. Wszystkie w edycji Core.
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


$dchost = "DC$LabName"
$VHDBasePath = "$LAbPath\$LabName\VHDs\base\LabServerBase.vhdx"
$VHDPath = "$LabPath\$LabName\VHDs\$dchost.vhdx"

$convertWindowsImageParams = @{
    SourcePath = "$ISOPath"
    SizeBytes = 25GB
    VHDFormat = "VHDx"
    UnattendPath = "$UnattendXml"
    Edition = "ServerDatacenterCore"
    VHDPath = $VHDBasePath
    DiskLayout = "UEFI"
}
$VHDx = Convert-WindowsImage @convertWindowsImageParams -Passthru -Verbose

If (!(Get-VMSwitch | where Name -match 'SwitchLab')){
New-VMSwitch -Name 'SwitchLAB' -SwitchType Internal
}
New-VHD -Path $VHDPath -ParentPath $VHDBasePath -Differencing -OutVariable ChildVHD | out-null
New-VM -Name $dchost -VHDPath $VHDPath -MemoryStartupBytes 1GB -SwitchName 'SwitchLab' -Generation 2 | out-null
Start-VM -Name $dchost

$ip = (Get-VM -Name $dchost | Select-Object -ExpandProperty networkadapters).ipaddresses
While ($ip.count -lt 2)
    {
        $ip = (Get-VM -Name $dchost | Select-Object -ExpandProperty networkadapters).ipaddresses
        Write-Output "Czekam na podniesienie VM-ki $dchost"
        Start-Sleep -Seconds 5 -Verbose
    }
#endregion

#region Konfiguracja DC
Write-Output "Otwieram połączenie do $dchost przez szynę Hyper-V"

try {
New-PSSession -VMName "$dchost" -Credential $admincred -OutVariable SesjaDC -ErrorAction Stop | out-null
}
catch {
 Throw "Nie mogę połączyć z $dchost"
}

Invoke-Command -ScriptBlock {
    $NetAdapter = (Get-Netadapter)[0].Name
    Write-Output "Ustawiam statyczny IP na interfejsie $netadapter"
    New-NetIPAddress -IPAddress '192.168.1.1' -PrefixLength 24 -InterfaceIndex (Get-Netadapter)[0].InterfaceIndex | out-null
    Write-Output "Uruchamiam PSRemoting"
    Enable-PSRemoting -Force
    Write-Output "Otwieram WSMan"
    Set-Item WSMan:\localhost\Client\TrustedHosts -Value * -Force
} -Session $SesjaDC

$LocalAdapter = Get-NetAdapter "*SwitchLab*"
Write-Output "Konfiguruję interfejs $($LocalAdapter.Name)"
New-NetIPAddress -IPAddress '192.168.1.2' -DefaultGateway '192.168.1.1' -PrefixLength 24 -InterfaceIndex $LocalAdapter.InterfaceIndex
Get-NetConnectionProfile -InterfaceIndex $LocalAdapter.InterfaceIndex | Set-NetConnectionProfile -NetworkCategory Private
Set-DnsClientServerAddress -InterfaceIndex $LocalAdapter.InterfaceIndex -ServerAddresses '192.168.1.1'

Workflow Rename-DC {
Param(
    [string]$NewName
)
Rename-Computer -PSComputerName $PSComputername -PSCredential $PSCredential -NewName $NewName
Restart-Computer -wait -for PowerShell -Protocol WSMan
}
Write-Output "Zmieniam hostname na $dchost"
Rename-DC -PSComputerName '192.168.1.1' -PSCredential $admincred -NewName "$dchost"

Checkpoint-VM -Name $dchost -SnapshotName BeforeADDS

Write-Output "Nawiązuje ponownie połączenie"
New-PSSession -ComputerName '192.168.1.1' -Credential $admincred -OutVariable SesjaDC | out-null


Write-Output "Instaluję rolę ADDS i tworzę las $LabName.local"
Invoke-Command -Session $SesjaDC -ScriptBlock {
    Write-Output "Instaluję ADDS"
    Install-WindowsFeature -Name AD-Domain-Services | out-null
    Write-Output "Instaluję las"
    Install-ADDSForest -DomainName $args[0] -SafeModeAdministratorPassword $args[1] -Force | out-null
} -ArgumentList "$LabName.local", $adpass


$ip = (Get-VM -Name $dchost | Select-Object -ExpandProperty networkadapters).ipaddresses
While ($ip.count -lt 2)
    {
        $ip = (Get-VM -Name $dchost | Select-Object -ExpandProperty networkadapters).ipaddresses
        Write-Output "Czekam na podniesienie VM-ki $dchost"
        Start-Sleep -Seconds 5 -Verbose
    }


Write-Output "Nawiązuję połączenie na poświadczeniach domenowych"
New-PSSession -VMName $dchost -Credential $DomainCred -OutVariable SesjaADDC

$dhcpUri = "$dchost.$LabName.local"
Invoke-Command -Session $SesjaADDC -ScriptBlock {

    Write-Output "Przestawiam profil sieci"
    Get-NetConnectionProfile | Set-NetConnectionProfile -NetworkCategory Private  

    Write-Output "Instaluję rolę DHCP"
    Install-WindowsFeature -Name DHCP -IncludeManagementTools | out-null
    
    $dhcpParams = @{
        StartRange = '192.168.1.100'
        EndRange = '192.168.1.200'
        Name = $using:LabName+'Scope'
        State = 'Active'
        LeaseDuration = (New-TimeSpan -Days 365)
        SubnetMask = '255.255.255.0'
        Type = 'Dhcp'
    }
    Write-Output "Konfiguruję rolę DHCP"
    Add-DhcpServerv4Scope @dhcpParams
    Set-DhcpServerv4OptionValue -DnsServer '192.168.1.1'
    Set-DhcpServerv4OptionValue -Router '192.168.1.1'
    Write-Output "Autoryzuję $using:dhcpUri w AD"
    Add-DhcpServerInDC -DnsName $using:dhcpUri
} -verbose
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
            Start-Sleep -Seconds 3;
        }
        $ip[0]
    }
    
    # Return the IPs of the newly created VMs
    $ipAddresses

}
Write-Output "Tworzę dodatkowe serwery"
Install-VM -SourceVhdPath $VHDBasePath -DestinationVhdPath $LabPath\$LAbName\VHDs -Name Node1, Node2 -SwitchName 'SwitchLab'
#endregion

#region Konfiguracja serwerów
Write-Output "Mapuję nazwy maszyn wirtualnych z ich adresami IP"
$IpToNameMapping = @{}
Get-VM -Name NODE1,NODE2 | ForEach-Object { $IpToNameMapping.Add($_.NetworkAdapters.IPAddresses[0],$_.name) }


workflow Join-Domain {
param (
    [Parameter(Mandatory=$True, 
               Position=0)]
    [ValidateNotNull()]
    [hashtable]$IpToNameMapping,
    [pscredential]$DomainCred,
    [string]$DomainName

)

    Foreach -parallel ($computer in $PSComputerName) {

        Add-Computer -DomainName $DomainName -NewName $IpToNameMapping[$computer] -Credential $DomainCred
        Restart-Computer -wait -for PowerShell -Protocol WSMan
    }
}
Write-Output "Dodaję serwery do AD"
Join-Domain -IpToNameMapping $IpToNameMapping -DomainCred $DomainCred -DomainName "$LabName.local" -PSComputerName $IpToNameMapping.keys -PSCredential $admincred

New-PSSession -ComputerName ($IpToNameMapping | Select-Object -ExpandProperty keys | Sort-Object)[0] -Credential $DomainCred -OutVariable Sesja1
Invoke-Command -Session $Sesja1 {
    Install-WindowsFeature -Name web-server,web-asp,web-asp-net45 -Restart
}

New-PSSession -ComputerName ($IpToNameMapping | Select-Object -ExpandProperty keys | Sort-Object)[1] -Credential $DomainCred -OutVariable Sesja2
Invoke-Command -Session $Sesja2 {
    Install-WindowsFeature -Name File-Services,FS-FileServer -Restart
}


#endregion