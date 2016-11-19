
param(
    $sklep
)
switch ($sklep)
    {
        24 {$nr=47}
        35 {$nr=48}
        36 {$nr=45}
        54 {$nr=50}
        91 {$nr=44}
        102 {$nr=46}
        134 {$nr=49}
         
        default {"Nieprawid³owy numer sklepu"
                  Break
                 }
    } # End switch



Describe "Dzia³anie us³ug APP1" {
    It "Us³uga MYSQL_APP1" {
        (Get-Service RDMSQL_APP1).Status | Should Be 'Running'
    }
}
Describe "Serwer Filezilla" {
    It "Us³uga Filezilla Server" {
        (Get-Service 'Filezilla Server').Status | Should be 'Running'
    }
}
Describe "Serwer Apache" {
  Context "Us³uga Apache" {
    Get-Service -DisplayName "Apache*" | ForEach-Object {
        It "Us³uga $($_.displayNAme)" {
            $_.Status | Should be 'Running'
        }
    }
  }
  Context "OdpowiedŸ z serwera Apache" {
    $web = Invoke-WebRequest -Uri localhost/rdm
        It "Poprawna nazwa w tytule strony" {
            $web.ParsedHtml.title | Should belike "Application1*"
        }
    }
}
Describe "Us³ugi APP2" {
    Get-Service -DisplayName "!APP2*" | ForEach-Object {
        It "Us³uga $($_.DisplayName)" {
            $_.Status | Should be 'Running'
        }
    }
}
Describe "Baza Firebird" {
    Get-Service -Name "Firebird*" | ForEach-Object {

        It "Us³uga $($_.DisplayName)" {
            $_.Status | Should be 'Running'
        }
    }
}
Describe "Zadanie w harmonogramie" {
    It "Zadanie APPUPDATE" {
        (Get-ScheduledTask -TaskName APPUPDATE).State | Should not be 'Disabled'
    }
}

Describe "£¹cznoœæ z SRVSK" {
    $ipsk = "192.168.34.$nr"
    $skhostname = "SRVSK$sklep"
    It "£¹cznoœæ z BOK po IP" {
        Test-Connection -ComputerName "$ipsk" -count 1 -Quiet | Should be 'True'
    }
    It "£¹cznoœæ z BOK po nazwie" {
        Test-Connection -ComputerName $skhostname -Count 1 -Quiet | Should be 'True'
    }

}

