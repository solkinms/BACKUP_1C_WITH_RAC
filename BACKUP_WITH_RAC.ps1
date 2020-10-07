[console]::OutputEncoding = [System.Text.Encoding]::UTF8
Start-Transcript -Path D:\BACKUP1c.txt
clear
cd "C:\Program Files\1cv8\8.3.16.1359\bin\"


$strCluster = ""
$codeIB = ""
$nameIB = ""
$nameCodeHash = @{}
$sessionList = ""
$IB_USER="root"
$IB_PASS="root"
$UC="backup"
$message="Backup is in progress"

echo "1) Getting the cluster UUID"
$cluster = .\rac.exe cluster list | findstr cluster
$strCluster = $cluster -replace 'cluster                       : ',''
echo "2) Cluster UUID: $strCluster"
echo "3) Getting the UUID and Name of information databases"
$codeIB = .\rac.exe infobase --cluster=$strCluster summary list | findstr infobase
$nameIB = .\rac.exe infobase --cluster=$strCluster summary list | findstr name
$codeIB = $codeIB -replace 'infobase : ',''
$nameIB = $nameIB -replace 'name     : ',''
$codeIB = $codeIB -split '`n'
$nameIB = $nameIB -split '`n'
for ($i=0; $i -lt $codeIB.Count; $i++) {
##### For TEST
#    if ($nameIB[$i] -ieq 'UT') {
#        $nameCodeHash.Add($nameIB[$i],$codeIB[$i])
#    }
##### Working version
$nameCodeHash.Add($nameIB[$i],$codeIB[$i])
#####
}
echo "4) UUID and Name of information databases received successfully" $nameCodeHash
echo ""
echo "5) Starting a backup"

foreach ($Base in $nameCodeHash.Keys) {
    $countCheck = 1
    $ib = $nameCodeHash[$Base]
    $DtCheck = 0
    $PatchBackup = "\\thecus\backups\DT\$Base" + "\" + $Base + "_" + $DateTime + ".dt"
    $1cexe = '"C:\Program Files\1cv8\common\1cestart.exe"'
    $BaseServer = "/Ssrvdb\" + $Base
    $ArgumentBackup = " DESIGNER $BaseServer /N$IB_USER /P$IB_PASS /UC$UC /RunModeOrdinaryApplication /DumpIB" + $PatchBackup 

    echo "Copying the database №$countCheck Name:$Base UUID:$ib"
    $DateTime = Get-Date -UFormat "%d_%m_%Y_%H-%M"

    echo "Create\Checking the folder \\backups\DT\$Base"
    if (Test-Path -Path "\\backups\DT\$Base") {
        echo "The folder exists"
        }else{
        New-Item -Path "\\backups\DT\$Base" -ItemType Directory -Force
        echo "The folder is created"
    }    
    
    echo "Getting a list of sessions"
    $sessionList = .\rac.exe session list --cluster=$strCluster --infobase=$ib | Select-String -Pattern 'session                          : '
    $sessionList = $sessionList -replace 'session                          : ',''
    $sessionList = $sessionList -split '`n'
    $countSess = $sessionList.Count
    echo "Sessions in the database $Base $countSess"
    $sessionList
    echo "Disabling all users"
    if ($countSess -gt 0) {
        foreach($sessionId in $sessionList){
        .\rac.exe session terminate --cluster=$strCluster --session=$sessionId
        }
        Start-Sleep -Seconds 30
    }
    echo "Blocking access to $Base"
    .\rac.exe infobase update --cluster=$strCluster --infobase=$ib --sessions-deny=on --permission-code=$UC --denied-from="" --denied-to="" --denied-message=$message --scheduled-jobs-deny=on --infobase-user=$IB_USER --infobase-pwd=$IB_PASS
    Start-Sleep -Seconds 30
    echo "Disabling all users"
    echo "Getting a list of sessions"
    $sessionList = .\rac.exe session list --cluster=$strCluster --infobase=$ib | Select-String -Pattern 'session                          : '
    $sessionList = $sessionList -replace 'session                          : ',''
    $sessionList = $sessionList -split '`n'
    $countSess = $sessionList.Count
    echo "Sessions in the database $Base $countSess"
    $sessionList
    if ($countSess -gt 0) {
        foreach($sessionId in $sessionList){
        .\rac.exe session terminate --cluster=$strCluster --session=$sessionId
        }
        Start-Sleep -Seconds 30
    }
    echo "Creating a backup copy: $PatchBackup"
    Start-Process $1cexe $ArgumentBackup
    While($true) {
	if ($DtCheck -le 100) {
		$DtCheck++
		if (Test-Path $PatchBackup) {
            echo "It took $DtCheck checks of 60 seconds each to create a copy"
            echo "Backup copy created"
            echo "Removing the lock from $Base"
            .\rac.exe infobase update --cluster=$strCluster --infobase=$ib --sessions-deny=off --permission-code="" --denied-to="" --denied-message="" --scheduled-jobs-deny=off --infobase-user=$IB_USER --infobase-pwd=$IB_PASS
		    Start-Sleep -Seconds 30
            echo "Disabling all users"
            echo "Getting a list of sessions"
            $sessionList = .\rac.exe session list --cluster=$strCluster --infobase=$ib | Select-String -Pattern 'session                          : '
            $sessionList = $sessionList -replace 'session                          : ',''
            $sessionList = $sessionList -split '`n'
            $countSess = $sessionList.Count
            echo "Sessions in the database $Base $countSess"
            $sessionList
            if ($countSess -gt 0) {
                foreach($sessionId in $sessionList){
                    .\rac.exe session terminate --cluster=$strCluster --session=$sessionId
                }
                Start-Sleep -Seconds 30
            }
            echo "End of session"
			break
		}
		Start-Sleep -Seconds 60
	} else {
        echo "Error creating a backup"
        break
	}
}
    $countCheck++

}
echo "Stopping the 1C Server"
Stop service 1C
Stop-service -name '1C:Enterprise 8.3 Server Agent (x86-64)'
Restart service MSSQL
echo "Stopping The MsSql Server"
restart-service -name 'MSSQLSERVER'
Start-Sleep -Seconds 30
Start service 1C
echo "Launching the 1C Server"
Start-service -name '1C:Enterprise 8.3 Server Agent (x86-64)'
Start-Sleep -Seconds 30
Stop-Transcript
exit
