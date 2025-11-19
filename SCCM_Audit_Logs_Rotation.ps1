Write-Host "Konfigurowanie rotacji logów..." -ForegroundColor Cyan
# (1) KONFIGURACJA BACKUPU
# --------------------------------------------------------------
$BackupFolder = "C:\Temp\SCCM_Logs_APN"
if (-not (Test-Path $BackupFolder)) {
    New-Item -ItemType Directory -Path $BackupFolder -Force | Out-Null
}
$Timestamp = (Get-Date).ToString("yyyy-MM-dd_HH-mm-ss")
$BackupPath = Join-Path $BackupFolder "SCCM_LogBackup_$Timestamp.txt"
function Backup-RegistryKey {
    param(
        [string]$RegPath
    )

    if (Test-Path $RegPath) {
        Add-Content -Path $BackupPath -Value "`n==============================="
        Add-Content -Path $BackupPath -Value "KEY: $RegPath"
        Add-Content -Path $BackupPath -Value "-------------------------------"

        try {
            $values = Get-ItemProperty -Path $RegPath
            foreach ($name in $values.PSObject.Properties.Name) {
                $val = $values.$name
                Add-Content -Path $BackupPath -Value "$name = $val"
            }
        } catch {
            Add-Content -Path $BackupPath -Value "❌ Błąd odczytu wartości: $_"
        }

        Add-Content -Path $BackupPath -Value "==============================="
    }
    else {
        Add-Content -Path $BackupPath -Value "`n(BRAK KLUCZA W REJESTRZE) $RegPath"
    }
}
New-Item -ItemType File -Path $BackupPath -Force | Out-Null


# (2) KONFIGURACJA DLA SMS_INVENTORY_DATA_LOADER
# --------------------------------------------------------------

$DL_ComponentName = "SMS_INVENTORY_DATA_LOADER"
$DL_RegPath = "HKLM:\SOFTWARE\Microsoft\SMS\Tracing\$DL_ComponentName"

Backup-RegistryKey -RegPath $DL_RegPath

$DL_MaxSizeMB = 500
$DL_MaxSizeBytes = $DL_MaxSizeMB * 1MB  

Write-Host "`n Konfiguracja: $DL_ComponentName (dataldr.log)" -ForegroundColor Yellow
Write-Host "MaxFileSize = $DL_MaxSizeBytes bajtów (~$DL_MaxSizeMB MB)"

if (-not (Test-Path $DL_RegPath)) {
    Write-Host "Tworzę klucz rejestru: $DL_RegPath"
    New-Item -Path $DL_RegPath -Force | Out-Null
}

New-ItemProperty -Path $DL_RegPath -Name "MaxFileSize" -Value $DL_MaxSizeBytes -PropertyType DWord -Force | Out-Null

Write-Host "Ustawiono MaxFileSize dla dataldr.log"


# (3) KONFIGURACJA POZOSTAŁYCH KOMPONENTÓW
# --------------------------------------------------------------

$Components = @(
    @{
        Name = "SMS_DISTRIBUTION_MANAGER"
        LogName = "distmgr.log"
        MaxSizeMB = 100
        MaxHistory = 5
    },
    @{
        Name = "SMS_PACKAGE_TRANSFER_MANAGER"
        LogName = "pkgxfermgr.log"
        MaxSizeMB = 100
        MaxHistory = 5
    }
)

foreach ($comp in $Components) {

    $componentName = $comp.Name
    $logFile = $comp.LogName
    $sizeKB = $comp.MaxSizeMB * 1024
    $history = $comp.MaxHistory

    $RegPath = "HKLM:\SOFTWARE\Microsoft\SMS\Components\SMS_Executive\$componentName\Logging"

    Backup-RegistryKey -RegPath $RegPath

    Write-Host "`n Konfiguracja: $componentName ($logFile)" -ForegroundColor Yellow
    Write-Host "LogMaxSize     = $($comp.MaxSizeMB) MB ($sizeKB KB)"
    Write-Host "LogMaxHistory  = $history"

    if (-not (Test-Path $RegPath)) {
        Write-Host "Tworzę klucz rejestru $RegPath"
        New-Item -Path $RegPath -Force | Out-Null
    }

    New-ItemProperty -Path $RegPath -Name "LogMaxSize"    -Value $sizeKB -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $RegPath -Name "LogMaxHistory" -Value $history -PropertyType DWord -Force | Out-Null

    Write-Host "Zastosowano ustawienia."
}

Write-Host "`n Restart usługi SMS_EXECUTIVE..." -ForegroundColor Yellow
Stop-Service SMS_EXECUTIVE -Force
Start-Service SMS_EXECUTIVE

Write-Host "Gotowe! Zastosowano limity logów i utworzono backup: $BackupPath" -ForegroundColor Green
