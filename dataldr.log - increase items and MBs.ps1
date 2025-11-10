# === KONFIGURACJA ===
$ServiceName = "SMS_EXECUTIVE"
$RegPath = "HKLM:\SOFTWARE\Microsoft\SMS\Tracing\SMS_INVENTORY_DATA_LOADER"
$MaxFileSizeMB = 10    # rozmiar jednego pliku logu
$MaxLogFiles = 14      # liczba rotacji (np. tydzień historii)

Write-Host "🔧 Ustawianie zwiększonej retencji logów dla SMS_INVENTORY_DATA_LOADER..." -ForegroundColor Cyan

# === Upewnij się, że klucz istnieje ===
if (-not (Test-Path $RegPath)) {
    Write-Host "📁 Tworzenie brakującego klucza rejestru..." -ForegroundColor Yellow
    New-Item -Path $RegPath -Force | Out-Null
}

# === Ustaw wartości w rejestrze ===
New-ItemProperty -Path $RegPath -Name "MaxFileSize" -Value ($MaxFileSizeMB * 1MB) -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $RegPath -Name "MaxLogFiles" -Value $MaxLogFiles -PropertyType DWord -Force | Out-Null

Write-Host "✅ Ustawiono:" -ForegroundColor Green
Write-Host "   MaxFileSize = $($MaxFileSizeMB * 1MB) bajtów ($MaxFileSizeMB MB)"
Write-Host "   MaxLogFiles = $MaxLogFiles"

# === Restart usługi SMS_EXECUTIVE ===
Write-Host "🔄 Restartowanie usługi $ServiceName ..." -ForegroundColor Yellow
try {
    Restart-Service -Name $ServiceName -Force -ErrorAction Stop
    Write-Host "✅ Usługa SMS_EXECUTIVE zrestartowana pomyślnie." -ForegroundColor Green
} catch {
    Write-Warning "⚠️ Nie udało się zrestartować usługi $ServiceName. Uruchom ręcznie w Services.msc."
}

# === Weryfikacja ustawień ===
Write-Host "`n🔍 Bieżące wartości rejestru:" -ForegroundColor Cyan
Get-ItemProperty -Path $RegPath | Select-Object MaxFileSize, MaxLogFiles | Format-List

Write-Host "`n📄 Po restarcie serwisu MECM zacznie tworzyć do $MaxLogFiles rotacji logów (~$MaxLogFiles × $MaxFileSizeMB MB = $(($MaxFileSizeMB * $MaxLogFiles)) MB historii)."
