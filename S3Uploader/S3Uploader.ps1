#requires -module AWSPowershell
[CmdletBinding()]
Param (
    [Parameter(ValueFromPipeline=$true, Mandatory)]
    [string]$bucket
)


Function Crawl-Filesystem {
# Graphically crawl and select file[s] from the filesystem.
Param (
    [Parameter(ValueFromPipeline=$true)]
    [ValidateScript({Test-Path $_})]
    [string]$StartFolder = "."
)

$selection = $(
    Get-Item (Get-Item $StartFolder).psparentpath
    Get-Item $startFolder
    Get-ChildItem $startfolder
) | Out-GridView -PassThru


While ($selection[0].PSIsContainer) {

    $selection = $(
        If ($selection.name -ne $selection.Root.Name) {
            Get-Item $selection.PSParentPath
        }
        Get-Item $selection.PSPath
        Get-ChildItem $selection.PSPath
    ) | Out-GridView -PassThru
}

$selection

}

Function Key-Handler {

If (! (Test-Path (Split-Path $profile))) {
    New-Item (Split-Path $profile) -ItemType Directory
}

$passfile = Join-Path (Split-Path $profile) AWSkeys.xml
if (!(Test-Path $passfile)) {
    $accesskey = Read-Host "Enter AWS Access Key"
    $secretKey = Read-Host "Enter Secret Key for $accesskey" -AsSecureString | ConvertFrom-SecureString
    $cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $accesskey, ($secretKey | ConvertTo-SecureString)

    $cred | Export-Clixml $passfile
}
Import-Clixml $passfile


}

Function Upload-S3Object {
# Authenticates to AWS and uploads the requested objects to inforcrm bucket
# Returns a link to the object
# Get-ChildItem .\ICRMDeploy* | Upload-S3Object
[CmdletBinding(SupportsShouldProcess)]
Param (
    [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
    [ValidateScript({$_ | Test-Path})]
    [System.IO.FileInfo[]]$file, 
    [string]$keyprefix = 'Images',
    [string]$bucket
)
BEGIN {
    Import-Module AWSPowerShell -Verbose:$false
    $keys = Key-Handler
    $accessKey = $keys.UserName
    $secretKey = ($keys.GetNetworkCredential()).password
}
PROCESS {
    Foreach ($F in $File) {
        Write-Verbose "Uploading $($F.fullname)"
        $RemoteKey = $keyprefix + '/' + $F.Name
        Write-S3Object -BucketName $bucket -AccessKey $accessKey -SecretKey $secretKey -File $($F.fullname) -Key $RemoteKey -ErrorAction Stop
        Write-Output https://$bucket.s3.amazonaws.com/$keyprefix/$F
        }
}
END {
    Start-Sleep -Seconds 2
}
}

Crawl-Filesystem | Upload-S3Object -keyprefix images -bucket $bucket
