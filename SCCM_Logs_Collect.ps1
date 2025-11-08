<# 
.SYNOPSIS
  Zbiera logi SCCM, WSUS, SUP, DP, MP oraz IIS z lokalnego serwera
  (uwzględniając dyski C–H) i kopiuje je do C:\Temp\SCCM_Logs_APN\<Logs_YYYYMMDD_HHmmss>.
#>

# --- Ustawienia główne ---
$BaseFolder = "C:\Temp\SCCM_Logs_APN"
$DateStamp  = Get-Date -Format "yyyyMMdd_HHmmss"
$DestFolder = Join-Path $BaseFolder "Logs_$DateStamp"

# --- Sprawdź czy folder bazowy istnieje, jeśli nie to utwórz ---
if (-not (Test-Path $BaseFolder)) {
    Write-Host ("📁 Folder bazowy {0} nie istnieje — tworzę..." -f $BaseFolder) -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $BaseFolder -Force | Out-Null
} else {
    Write-Host ("📂 Wykryto istniejący folder bazowy: {0}" -f $BaseFolder) -ForegroundColor Cyan
}

# --- Tworzenie podfolderu z datą ---
Write-Host ("🕒 Tworzę nowy podfolder dla bieżącej sesji: {0}" -f $DestFolder) -ForegroundColor Cyan
New-Item -ItemType Directory -Path $DestFolder -Force | Out-Null

# --- Partycje do sprawdzenia ---
$Drives = "C","D","E","F","G","H"

# --- Potencjalne ścieżki logów (z placeholderem {drive}) ---
$LogLocations = @(
    "{drive}:\Program Files\Microsoft Configuration Manager\Logs",          # Primary site
    "{drive}:\Program Files (x86)\Microsoft Configuration Manager\Logs",    # czasem w x86
    "{drive}:\SMS_CCM\Logs",                                                # MP
    "{drive}:\Program Files\SMS_CCM\Logs",                                  # MP alternate
    "{drive}:\SMS_DP$\Logs",                                                # DP
    "{drive}:\Program Files\Update Services\LogFiles",                      # WSUS / SUP
    "{drive}:\Program Files\Microsoft Configuration Manager\WSUS\Logs",     # WSUS pod SCCM
    "{drive}:\inetpub\logs\LogFiles"                                        # IIS
)

# --- Tworzymy listę istniejących folderów ---
$ExistingPaths = @()
foreach ($drive in $Drives) {
    foreach ($loc in $LogLocations) {
        $path = $loc.Replace("{drive}", $drive)
        if (Test-Path $path) { $ExistingPaths += $path }
    }
}

if ($ExistingPaths.Count -eq 0) {
    Write-Warning "⚠️  Nie znaleziono żadnych folderów z logami SCCM lub IIS na dyskach C–H."
    exit 0
} else {
    Write-Host ("🔍 Znaleziono {0} lokalizacji z logami:" -f $ExistingPaths.Count) -ForegroundColor Green
    $ExistingPaths | ForEach-Object { Write-Host (" - {0}" -f $_) -ForegroundColor DarkGray }
}

# --- Kopiowanie logów ---
$patterns = '*.log','*.lo_','*.old','*.bak','*.txt'
foreach ($path in $ExistingPaths) {
    try {
        $componentName       = ($path -split '\\')[-2..-1] -join "_"
        $safeName            = $componentName -replace '[^a-zA-Z0-9_-]', '_'
        $destComponentFolder = Join-Path $DestFolder $safeName

        Write-Host ("`n➡️  Kopiowanie logów z: {0}" -f $path) -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $destComponentFolder -Force | Out-Null

        Get-ChildItem -Path $path -Recurse -Include $patterns -File -ErrorAction SilentlyContinue |
            Copy-Item -Destination $destComponentFolder -Force -ErrorAction Stop

    } catch {
        $msg = if ($_.Exception) { $_.Exception.Message } else { $_.ToString() }
        Write-Warning ("❌ Błąd przy kopiowaniu z {0}: {1}" -f $path, $msg)
    }
}

# --- Informacja końcowa ---
Write-Host "`n✅ Zbieranie logów zakończone pomyślnie." -ForegroundColor Green
Write-Host ("📦 Logi zapisane w: {0}" -f $DestFolder)
