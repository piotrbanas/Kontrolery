<#
.SYNOPSIS
Narzędzie podmiany plików konfiguracyjnych etykiet na wagach marki [***DELETED***]
.DESCRIPTION
Z podfolderu \label\ przesyła pliki .xml, których nie ma na wadze, albo mające inną zawartość (na podstawie hashy).
Narzędzie wyświetla menu wyboru sklepów. 
Jeśli użytkownik wybierze wszystkie sklepy (ctrl+a), pliki zostaną wysłane do wszystkich wag. 
W przeciwnym przypadku zostanie zaprezentowane okno wyboru wag wybranego sklepu (również można zaznaczyć wszystkie),
Wymagane pliki tekstowe z listami IP wag: wagi[nr_sklepu].txt
Przy pierwszym użyciu zapyta o hasło administratora wag. 
.PARAMETER sklepy
Jeden, lub więcej numerów sklepów. 
Standardowo zostanie wyświetlone okno wyboru, jednak można przekazać jako parametr.
.EXAMPLE
.\podmiana-xmlWag.ps1 -Verbose
.EXAMPLE
.\podmiana-xmlWag.ps1 -sklepy 10, 20
.NOTES
Autor: piotrbanas@xper.pl
.LINK
https://github.com/piotrbanas/kontrolery
#>
	
	[cmdletbinding()]
	param (
		$sklepy = $null
	)
	#region Przygotowania i user input
	Set-Location $PSScriptRoot
	
	# Sprawdzenie podfolderu \Label
	if (!(Test-Path -path .\Label\))
	{
		Write-Output "============================================"
		Write-Output "Brak folderu $PSScriptRoot\Label"
		Write-Output "============================================"
		Start-Sleep -Seconds 10
		return
	}
	
	# Jeśli nie przekazano sklepu jako argumentu, zostanie zaprezentowane okno wyboru
	if ($sklepy -eq $null)
	{
		$sklepy = @(10, 20, 30, 40, 50, 60, 70, 80) | Out-GridView -PassThru -Title "Wybierz numer sklepu"
		Write-Verbose "użytkownik wybrał sklepy $sklepy"
		if ($sklepy -eq $null) { Write-Output "Anulowano"; return }
	}
	
	# Jeśli wybrano wszystkie sklepy, zakładamy synchronizację globalną
	$wszystkie = @(10, 20, 30, 40, 50, 60, 70, 80)
	$porownanie = @(Compare-Object $sklepy $wszystkie).length -eq 0
	
	if ($porownanie)
	{
		$uwaga = Read-Host "UWAGA! Zamierzasz podmienić pliki na wszystkich wagach, we wszystkich sklepach. TAK/NIE"
		if ($uwaga -ne 'TAK') { Write-Output "Anulowano"; Start-Sleep 5;  return }
	}
	
	# Budowanie poświadczeń
	If (!(Test-Path .\WagiPass.txt))
	{
		Write-Verbose "Nie znalazłem pliku z hasłem."
		Read-Host "Podaj hasło administratora wag" -AsSecureString | ConvertFrom-SecureString | Out-File ".\WagiPass.txt"
	}
	$user = '[***DELETED***]'
	$passfile = '.\WagiPass.txt'
	$pass = Get-Content -path $passfile | ConvertTo-SecureString
	$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $user, $pass
	#endregion
	#region montowanie i operacje plikowe
	foreach ($sklep in $sklepy)
	{
		# sprawdzanie list IP
		if (!(Test-Path .\wagi$sklep.txt))
		{
			Write-Output "============================================"
			Write-Output "Brak listy wag."
			Write-Output "Umieść w moim folderze plik wagi$sklep.txt"
			Write-Output "============================================"
			Start-Sleep -Seconds 10
			Return
		}
		
		# Jeśli operujemy na wszystkich sklepach, bierzemy wszystkie wagi
		if ($porownanie)
		{
			Write-Verbose "Importuję wszystkie wagi z pliku wagi$sklep.txt "
			$wagi = Get-Content .\wagi$sklep.txt
		}
		# Jeśli operujemy na niektórych sklepach, prezentujemy okno wyboru
		else
		{
			$wagi = Get-Content .\wagi$sklep.txt | Out-GridView -PassThru -Title "Wybierz wagi"
		}
		
		Foreach ($waga in $wagi)
		{
			
			Write-Verbose "Montuję wagę $waga"
			[string]$dysk = 'waga' + $waga.split('.')[3]
			try
			{
				New-PSDrive -PSProvider FileSystem -Name $dysk -Root "\\$waga\[***DELETED***]\label" -Credential $cred -ErrorAction Stop | out-null
				
				$pliki = (Get-ChildItem ".\label\*.xml").name
				foreach ($plik in $pliki)
				{
					# kopiuję plik, którego nie ma wadze
					$desplik = Join-Path $dysk`: $plik -ErrorAction SilentlyContinue
					Write-Verbose "Sprawdzam czy $plik istnieje na wadze."
					if (!(Test-Path $desplik))
					{
						Write-Verbose "Brak $plik na wadze. Kopiuję"
						Copy-Item .\label\$plik -Destination $desplik
					}
					
					# Porównuję zawartość (hash) pliku lokalnego oraz docelowego
					$sourcehash = Get-ChildItem ".\label\$plik" | Get-FileHash
					$desthash = Get-ChildItem $desplik | Get-FileHash
					Write-Verbose "Sprawdzam czy $plik jest identyczny."
					if (Compare-Object -ReferenceObject $sourceHash.hash -DifferenceObject $destHash.hash)
					{
						# Wprzypadku rozbieżności, nadpisuję
						Write-Verbose "Różnice w $plik - nadpisuję"
						Copy-Item -Path $sourcehash.path -Destination $desthash.path -force
					}
				}
				# Przechowuję adres wagi do raportu końcowego
				$powodzenie += "$waga`n"
			}
			catch
			{
				# Przechowuję adres wagi do raportu końcowego
				Write-output "Błąd połączenia z $waga"
				$niepowodzenie += "$waga`n"
				
			}
			Finally
			{
				# Odmontowuję
				if (Test-Path $dysk`:)
				{
					Write-Verbose "Odmontowuję $waga"
					Remove-PSDrive -Name $dysk -Force
				}
			}
		} # end foreach wagi
		
	} # end foreach sklepy
	#endregion
	#region raport końcowy
	Write-Output "============================================"
	Write-Output "Podsumowanie operacji:"
	Write-Output "============================================"
	if ($powodzenie)
	{
		Write-Output "Pliki zsynchornizowane na:"
		$powodzenie
	}
	
	if ($niepowodzenie)
	{
		Write-Output "Nie udało się zmapować:"
		$niepowodzenie
	}
	#endregion

# pozostawiam okno otwarte
pause