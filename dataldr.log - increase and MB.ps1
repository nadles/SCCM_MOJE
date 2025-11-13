# === KONFIGURACJA ===
$ComponentName = "SMS_INVENTORY_DATA_LOADER"
$RegPath       = "HKLM:\SOFTWARE\Microsoft\SMS\Tracing\$ComponentName"

$MaxFileSizeMB = 1       # ile MB na 1 plik logu
$MaxHistory    = 14      # ile plików historii trzymać

# Uwaga: MaxFileSize jest w BAJTACH
$MaxFileSizeBytes = $MaxFileSizeMB * 1MB   # 1MB = 1 048 576 bajtów

Write-Host "🔧 Ustawiam logowanie dla $ComponentName..." -ForegroundColor Cyan
Write-Host "   MaxFileSize   = $MaxFileSizeBytes bajtów (~$MaxFileSizeMB MB)"
Write-Host "   LogMaxHistory = $MaxHistory"

# Utwórz klucz, jeśli nie istnieje
if (-not (Test-Path $RegPath)) {
    Write-Host "📁 Tworzę klucz rejestru: $RegPath" -ForegroundColor Yellow
    New-Item -Path $RegPath -Force | Out-Null
}

# Ustawienia
New-ItemProperty -Path $RegPath -Name "MaxFileSize"   -Value $MaxFileSizeBytes -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $RegPath -Name "LogMaxHistory" -Value $MaxHistory       -PropertyType DWord -Force | Out-Null

Write-Host "✅ Wpisy w rejestrze ustawione." -ForegroundColor Green

Write-Host "`n🔄 Twardy restart usługi SMS_EXECUTIVE..." -ForegroundColor Yellow
Stop-Service SMS_EXECUTIVE -Force
Start-Service SMS_EXECUTIVE

Write-Host "📄 Opcjonalnie: usuń stare dataldr.log / dataldr.lo_ przed startem, żeby mieć czysty test." -ForegroundColor DarkYellow
Write-Host "✅ Po kilku nowych wpisach w logu powinieneś zobaczyć rotację (nowy dataldr.log + plik historii)." -ForegroundColor Green
