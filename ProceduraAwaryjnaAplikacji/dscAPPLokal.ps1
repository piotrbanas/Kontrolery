<#
    Wstępna DSC serwera aplikacyjnego. Po wygenerowaniu mof-ów należy je zastosować:
    start-DscConfiguration -ComputerName 'APP1SRV140' -Credential (Get-Credential) -path C:\Skrypty\DSC -Verbose -Wait
#>

$configData = @{
    AllNodes = @(
        @{
            NodeName = "APP1SRV140";
            PSDscAllowPlainTextPassword = $true
        }
    )
}

#region poswiadczenia
$adminpassfile = "C:\Skrypty\adminpass.txt"
if (!(Test-Path $adminpassfile)) {
    Read-Host "Podaj hasło dla lokalnego administratora" -AsSecureString | ConvertFrom-SecureString | Out-File "$adminpassfile"
}
$adminpass = Get-Content -path $adminpassfile | ConvertTo-SecureString
$admincred = new-object -typename System.Management.Automation.PSCredential -argumentlist 'localAdmin', $adminpass

$sdpassfile = "C:\skrypty\sdpass.txt"
if (!(Test-Path $sdpassfile)) {
    Read-Host "Podaj hasło dla ServiceDesk" -AsSecureString | ConvertFrom-SecureString | Out-File "$sdpassfile"
}
$sdpass = Get-Content -path $sdpassfile | ConvertTo-SecureString
$sdcred = new-object -typename System.Management.Automation.PSCredential -argumentlist 'Servicedesk', $sdpass

$vendor1passfile = "C:\skrypty\vendor1pass.txt"
if (!(Test-Path $vendor1passfile)) {
    Read-Host "Podaj hasło dla dostawcy Vendor1" -AsSecureString | ConvertFrom-SecureString | Out-File "$vendor1passfile"
}
$vendor1pass = Get-Content -path $vendor1passfile | ConvertTo-SecureString
$vendor1cred = new-object -typename System.Management.Automation.PSCredential -argumentlist 'Vendor1', $vendor1pass
#endregion

Configuration KonfiguracjaSerweraRDM {

Param (
    $computername = $env:COMPUTERNAME,
    [pscredential]$admincred,
    [pscredential]$sdcred,
    [pscredential]$vendor1cred
)
Import-DscResource –ModuleName 'PSDesiredStateConfiguration'


    node $computername {
        file WagiInFolder {
            DestinationPath = "C:\APP1\in"
            Ensure = "Present"
            Type = "Directory"
        }

        user localadmin {
            UserName = "localAdmin"
            Ensure = "Present"
            Password = $admincred
            PasswordChangeNotAllowed = $true
            PasswordNeverExpires = $true
            PasswordChangeRequired = $false
        }

        user Servicedesk {
            Username = "ServiceDesk"
            Ensure = "Present"
            Password = $sdcred
            PasswordChangeNotAllowed = $true
            PasswordNeverExpires = $true
            PasswordChangeRequired = $false
            DependsOn = '[user]localadmin'
        }
        user Vendor1 {
            USername = "Vendor1"
            Ensure = "Present"
            Password = $vendor1cred
            PasswordNeverExpires = $true
            PasswordChangeRequired = $false
            DependsOn = '[user]localadmin'
        }
        group Admini {
            GroupName = 'Administratorzy'
            MembersToInclude = @("adminlocal", "Administrator", "Vendor1")
            Ensure = "Present"
            DependsOn = '[user]Vendor1'
            
        }
    }

}

KonfiguracjaSerweraRDM -computername APP1SRV140 -OutputPath C:\skrypty\DSC -ConfigurationData $configData `
-admincred $admincred -sdcred $sdcred -vendor1cred $vendor1cred