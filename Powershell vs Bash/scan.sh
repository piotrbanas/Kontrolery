#!/bin/bash
mount -t nfs 10.101.33.31:/skany /mnt/skany

nmap -v -n -sn 10.101.34.103 10.101.34.105 10.101.34.106 | grep "Nmap scan report for" > TMP
sed 's/.*host down.*/BŁĄD/' TMP > TMP2
sed 's/.*Nmap.*/OK/' TMP2 > /mnt/skany/101nmap.txt
rm TMP TMP2
nmap -v -p 80 10.101.33.181 10.101.33.186 | grep -E "Discovered open port|host down" > TMP
sed 's/.*host down.*/BŁĄD/' TMP > TMP2
sed 's/.*Discovered open port.*/OK/' TMP2 >> /mnt/skany/101nmap.txt
rm TMP TMP2

umount /mnt/skany
exit 0
