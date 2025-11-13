# === KONFIGURACJA ===
$Component = "SMS_INVENTORY_DATA_LOADER"
$BaseRegPath = "HKLM:\SOFTWARE\Microsoft\SMS\Components\SMS_Executive"
$RegPath = "$BaseRegPath\$Component\Logging"

$MaxFileSizeMB = 10
$MaxLogFiles = 14

Write-Host "🔧 Ustawianie rotacji logów dla $Component..." -ForegroundColor Cyan

# Utwórz brakujący klucz
if (-not (Test-Path $RegPath)) {
    Write-Host "📁 Tworzenie klucza rejestru $RegPath..." -ForegroundColor Yellow
    New-Item -Path $RegPath -Force | Out-Null
}

# Ustaw prawidłowe klucze rotacji
New-ItemProperty -Path $RegPath -Name "LogMaxSize" -Value ($MaxFileSizeMB * 1MB) -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $RegPath -Name "LogMaxHistory" -Value $MaxLogFiles -PropertyType DWord -Force | Out-Null

Write-Host "✅ Ustawiono rotację:" -ForegroundColor Green
Write-Host "   LogMaxSize = $($MaxFileSizeMB * 1MB) bajtów"
Write-Host "   LogMaxHistory = $MaxLogFiles"

Write-Host "🔄 Restartowanie SMS_EXECUTIVE..."
Restart-Service SMS_EXECUTIVE -Force

Write-Host "📄 Po restarcie komponent zacznie tworzyć:"
Write-Host "   → $MaxLogFiles plików rotacyjnych"
Write-Host "   → każdy do $MaxFileSizeMB MB"
