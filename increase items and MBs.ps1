# ============================================
#   UNIWERSALNA KONFIGURACJA ROTACJI LOGÓW
#   RÓŻNE USTAWIENIA PER KOMPONENT
# ============================================

Write-Host "🔧 Konfigurowanie rotacji logów..." -ForegroundColor Cyan

# 🔵 1) KONFIGURACJA DLA SMS_INVENTORY_DATA_LOADER (dataldr.log)
# --------------------------------------------------------------
$DL_ComponentName = "SMS_INVENTORY_DATA_LOADER"
$DL_RegPath = "HKLM:\SOFTWARE\Microsoft\SMS\Tracing\$DL_ComponentName"

$DL_MaxSizeMB = 500
$DL_MaxSizeBytes = $DL_MaxSizeMB * 1MB   # DataLoader używa BAJTÓW!

Write-Host "`n📌 Konfiguracja: $DL_ComponentName (dataldr.log)" -ForegroundColor Yellow
Write-Host "    → MaxFileSize = $DL_MaxSizeBytes bajtów (~$DL_MaxSizeMB MB)"
Write-Host "    → LogMaxHistory = tylko 1 (plik .lo_) — tryb domyślny"

if (-not (Test-Path $DL_RegPath)) {
    Write-Host "📁 Tworzę klucz rejestru: $DL_RegPath"
    New-Item -Path $DL_RegPath -Force | Out-Null
}

New-ItemProperty -Path $DL_RegPath -Name "MaxFileSize" -Value $DL_MaxSizeBytes -PropertyType DWord -Force | Out-Null

Write-Host "   ✔️ Ustawiono MaxFileSize dla dataldr.log"


# 🔵 2) KONFIGURACJA DLA POZOSTAŁYCH KOMPONENTÓW
# ----------------------------------------------

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

    Write-Host "`n📌 Konfiguracja: $componentName ($logFile)" -ForegroundColor Yellow
    Write-Host "    → LogMaxSize     = $($comp.MaxSizeMB) MB ($sizeKB KB)"
    Write-Host "    → LogMaxHistory  = $history"

    if (-not (Test-Path $RegPath)) {
        Write-Host "📁 Tworzę klucz rejestru $RegPath"
        New-Item -Path $RegPath -Force | Out-Null
    }

    New-ItemProperty -Path $RegPath -Name "LogMaxSize"    -Value $sizeKB -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $RegPath -Name "LogMaxHistory" -Value $history -PropertyType DWord -Force | Out-Null

    Write-Host "   ✔️ Zastosowano ustawienia."
}


# 🔄 Restart usług
Write-Host "`n🔄 Restart usługi SMS_EXECUTIVE..." -ForegroundColor Yellow
Stop-Service SMS_EXECUTIVE -Force
Start-Service SMS_EXECUTIVE

Write-Host "✅ Gotowe! Zastosowano indywidualne limity logów." -ForegroundColor Green
