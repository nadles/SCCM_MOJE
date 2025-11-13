# ============================================
#   UNIWERSALNA KONFIGURACJA ROTACJI LOGÓW
#   RÓŻNE USTAWIENIA PER KOMPONENT
# ============================================

# !!! WAŻNE !!!
# LogMaxSize musi być podany w KB, nie bajtach!

$Components = @(
    @{
        Name = "SMS_INVENTORY_DATA_LOADER"
        LogName = "dataldr.log"
        MaxSizeMB = 40      # 1 MB
        MaxHistory = 14
    },
    @{
        Name = "SMS_DISTRIBUTION_MANAGER"
        LogName = "distmgr.log"
        MaxSizeMB = 40      # 5 MB
        MaxHistory = 14
    },
    @{
        Name = "SMS_PACKAGE_TRANSFER_MANAGER"
        LogName = "pkgxfermgr.log"
        MaxSizeMB = 40      # 3 MB
        MaxHistory = 14
    }
)

Write-Host "🔧 Ustawianie rotacji logów dla wybranych komponentów..." -ForegroundColor Cyan

foreach ($comp in $Components) {

    $componentName = $comp.Name
    $logFile = $comp.LogName
    $sizeKB = $comp.MaxSizeMB * 1024
    $history = $comp.MaxHistory

    $RegPath = "HKLM:\SOFTWARE\Microsoft\SMS\Components\SMS_Executive\$componentName\Logging"

    Write-Host "`n📌 Konfiguracja: $componentName ($logFile)" -ForegroundColor Yellow
    Write-Host "    → LogMaxSize     = $($comp.MaxSizeMB) MB ($sizeKB KB)"
    Write-Host "    → LogMaxHistory  = $history"

    # Utwórz klucz jeśli nie istnieje
    if (-not (Test-Path $RegPath)) {
        Write-Host "📁 Tworzenie klucza rejestru $RegPath"
        New-Item -Path $RegPath -Force | Out-Null
    }

    # Ustawienia rejestru
    New-ItemProperty -Path $RegPath -Name "LogMaxSize"    -Value $sizeKB -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $RegPath -Name "LogMaxHistory" -Value $history -PropertyType DWord -Force | Out-Null

    Write-Host "   ✔️ Zastosowano ustawienia."
}

Write-Host "`n🔄 Restart usługi SMS_EXECUTIVE..." -ForegroundColor Yellow
Restart-Service SMS_EXECUTIVE -Force

Write-Host "✅ Gotowe! Wszystkie komponenty mają ustawione indywidualne limity logów." -ForegroundColor Green
