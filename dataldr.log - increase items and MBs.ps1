$Component = "SMS_INVENTORY_DATA_LOADER"
$RegPath = "HKLM:\SOFTWARE\Microsoft\SMS\Components\SMS_Executive\$Component\Logging"

$MaxFileSizeMB = 1   # tu ustawiasz MB
$MaxLogFiles = 14

$MaxFileSizeKB = $MaxFileSizeMB * 1024   # <-- KLUCZOWA ZMIANA

Write-Host "🔧 Ustawiam rotację logów ($MaxFileSizeMB MB, $MaxLogFiles plików)..."

if (-not (Test-Path $RegPath)) {
    New-Item -Path $RegPath -Force | Out-Null
}

New-ItemProperty -Path $RegPath -Name "LogMaxSize" -Value $MaxFileSizeKB -PropertyType DWord -Force | Out-Null
New-ItemProperty -Path $RegPath -Name "LogMaxHistory" -Value $MaxLogFiles -PropertyType DWord -Force | Out-Null

Restart-Service SMS_EXECUTIVE -Force
