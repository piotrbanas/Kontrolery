# Skrypt wywo³ywany przez post-commit.bat.

$enc = [System.Text.Encoding]::GetEncoding($Host.CurrentCulture.TextInfo.OEMCodePage)
$bytes = [System.IO.File]::ReadAllBytes('C:\temp\msg.txt')
$body = $enc.GetString($bytes)

$odbiorcy = @('piotrbanas@xper.pl'; 'administrator@xper.pl')


function send-smtp {
  PARAM(
        $SerwerSMTP,
        $nadawca,
        [string[]]$odbiorca,
        $temat,
        $tresc
  ) 
foreach ($adres in $odbiorca){
    $smtp = New-Object Net.Mail.SmtpClient("$SerwerSMTP")
    $smtp.Send("$nadawca","$adres","$temat","$tresc")
    } 
}

# Nie informujemy o commitach jkowalskiego:
if (!($body -match "jkowalski")) {
send-smtp -SerwerSMTP 'mail.xper.pl' -nadawca 'svn_mailer@xper.pl' -odbiorca $odbiorcy -temat 'Aktualizacja repozytorium SVN' -tresc $body
}
