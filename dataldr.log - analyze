# === Konfiguracja ===
$LogFolder  = "D:\Program Files\Microsoft Configuration Manager\Logs"
$TempFolder = "C:\Temp\SCCM_Logs_Extracted"
$OutputCsv  = "C:\Temp\HWInventory_Full_Report.csv"

# === Przygotowanie ===
if (!(Test-Path $TempFolder)) { New-Item -ItemType Directory -Path $TempFolder | Out-Null }
Get-ChildItem -Path $TempFolder -File | Remove-Item -Force -ErrorAction SilentlyContinue

# Zbierz wszystkie pliki dataldr.log*
$srcLogs = Get-ChildItem -Path $LogFolder -Filter "dataldr*" -File | Sort-Object LastWriteTime
Write-Host ("🔍 Znaleziono {0} plik(ów) logów do przetworzenia..." -f $srcLogs.Count)

foreach ($lf in $srcLogs) {
    $timeStamp = $lf.LastWriteTime.ToString("yyyyMMdd_HHmmss")
    $dst = Join-Path $TempFolder ("{0}_{1}.log" -f $lf.BaseName, $timeStamp)
    if ($lf.Extension -eq ".lo_") {
        Write-Host "📦 Rozpakowywanie $($lf.Name) → $(Split-Path $dst -Leaf)..."
        try { expand $lf.FullName $dst | Out-Null } catch { Copy-Item $lf.FullName $dst -Force }
    } else {
        Copy-Item $lf.FullName $dst -Force
    }
}

# === Regexy dla Twojego formatu ===
$reStart = [regex]'Processing Inventory for Machine:\s+(?<Machine>[A-Za-z0-9\-_]+).*?Generated:\s+(?<Gen>\d{2}/\d{2}/\d{4}\s+\d{2}:\d{2}:\d{2})'
$reDone  = [regex]'Done:\s*(?:\r?\n)?\s*Machine=(?<Machine>[A-Za-z0-9\-_]+).*?\$\$<SMS_INVENTORY_DATA_LOADER><(?<End>\d{2}-\d{2}-\d{4}\s+\d{2}:\d{2}:\d{2}\.\d{3})'

# === Pomocnicze funkcje ===
$cult = [System.Globalization.CultureInfo]::InvariantCulture
function Parse-Date([string]$s, [string[]]$formats) {
    foreach ($f in $formats) {
        try { return [datetime]::ParseExact($s, $f, $cult) } catch {}
    }
    return $null
}

$dateFormatsStart = @("dd/MM/yyyy HH:mm:ss", "MM/dd/yyyy HH:mm:ss")
$dateFormatsEnd   = @("dd-MM-yyyy HH:mm:ss.fff", "dd-MM-yyyy HH:mm:ss")

$entries = New-Object System.Collections.Generic.List[object]
$openStarts = @{}

# === Przetwarzanie logów ===
$allLogs = Get-ChildItem $TempFolder -Filter "dataldr*.log" -File | Sort-Object LastWriteTime
foreach ($log in $allLogs) {
    Write-Host "➡️  Przetwarzanie: $($log.Name)"
    try { $lines = Get-Content $log.FullName -Encoding Unicode -Raw -ErrorAction Stop } catch { $lines = Get-Content $log.FullName -Raw }

    foreach ($m1 in $reStart.Matches($lines)) {
        $machine = $m1.Groups['Machine'].Value
        $genTime = Parse-Date $m1.Groups['Gen'].Value $dateFormatsStart
        if ($genTime) {
            if (-not $openStarts.ContainsKey($machine)) { $openStarts[$machine] = New-Object System.Collections.Generic.List[datetime] }
            $openStarts[$machine].Add($genTime)
        }
    }

    foreach ($m2 in $reDone.Matches($lines)) {
        $machine = $m2.Groups['Machine'].Value
        $endTime = Parse-Date $m2.Groups['End'].Value $dateFormatsEnd
        if ($endTime -and $openStarts.ContainsKey($machine) -and $openStarts[$machine].Count -gt 0) {
            $startTime = $openStarts[$machine][$openStarts[$machine].Count - 1]
            $openStarts[$machine].RemoveAt($openStarts[$machine].Count - 1)
            $dur = [math]::Round(($endTime - $startTime).TotalMinutes, 2)
            $entries.Add([pscustomobject]@{
                LogFile         = $log.Name
                ComputerName    = $machine
                StartTime       = $startTime
                EndTime         = $endTime
                DurationMinutes = $dur
            })
        }
    }
}

# === Wynik ===
if ($entries.Count -eq 0) {
    Write-Host "⚠️  Brak dopasowań w logach." -ForegroundColor Yellow
} else {
    $entries | Sort-Object EndTime -Descending | Export-Csv $OutputCsv -NoTypeInformation -Encoding UTF8
    Write-Host "✅ Raport zapisany do: $OutputCsv" -ForegroundColor Green
    Write-Host "📊 Łącznie rekordów: $($entries.Count)"
}
