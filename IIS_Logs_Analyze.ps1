
<#
.SYNOPSIS
  Analiza logów IIS: parsuje logi, liczy statystyki requestów (w tym time-taken),
  eksportuje CSV i generuje raport HTML z zestawieniem dziennym.

.PARAMETER LogPath
  Ścieżka do logów IIS (np. C:\inetpub\logs\LogFiles).

.PARAMETER SinceDays
  Ile dni wstecz analizować (0 = cała historia).

.PARAMETER OutputCsv
  Ścieżka do surowego CSV (np. C:\Temp\IIS_Analysis\iis_parsed.csv).

.PARAMETER HtmlReportPath
  Ścieżka do raportu HTML (np. C:\Temp\IIS_Analysis\iis_report.html).
#>

param(
    [string]$LogPath = "C:\inetpub\logs\LogFiles",
    [int]$SinceDays = 7,
    [string]$OutputCsv = "C:\Temp\IIS_Analysis\iis_parsed.csv",
    [string]$HtmlReportPath = "C:\Temp\IIS_Analysis\iis_report.html",
    [int]$TopN = 25
)

# --- Przygotowanie katalogu wyników ---
$outDir = Split-Path -Path $OutputCsv -Parent
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

# --- Helpers ---
function Normalize-FieldName { param($n) ($n -replace '[\(\)\-\/\. ]','_' -replace '[^0-9A-Za-z_]','') }

function Percentile([double[]]$data, [double]$p) {
    if (-not $data -or $data.Count -eq 0) { return [double]::NaN }
    $sorted = $data | Sort-Object
    $n = $sorted.Count
    if ($n -eq 1) { return $sorted[0] }
    $rank = ($p/100.0) * ($n - 1)
    $low = [math]::Floor($rank)
    $high = [math]::Ceiling($rank)
    if ($low -eq $high) { return $sorted[$low] }
    $weight = $rank - $low
    return $sorted[$low]*(1-$weight) + $sorted[$high]*$weight
}

function Html-Escape($s) {
    if ($null -eq $s) { return "" }
    try { return [System.Text.Encodings.Web.HtmlEncoder]::Default.Encode([string]$s) } catch { return [string]$s }
}

function Html-Table($rows, $cols) {
    $thead = ($cols | ForEach-Object { "<th>$_</th>" }) -join ""
    $trs = foreach ($r in $rows) {
        $tds = foreach ($c in $cols) { "<td>$(Html-Escape $($r.$c))</td>" }
        "<tr>$($tds -join '')</tr>"
    }
    "<table><thead><tr>$thead</tr></thead><tbody>$($trs -join "`n")</tbody></table>"
}

# --- Parsowanie logów ---
Write-Host "Skanuję pliki w $LogPath (ostatnie $SinceDays dni)" -ForegroundColor Yellow
$cutoff = (Get-Date).AddDays(-$SinceDays)
$logFiles = Get-ChildItem -Path $LogPath -Recurse -Filter *.log -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -ge $cutoff } |
    Sort-Object LastWriteTime

if (-not $logFiles) { Write-Warning "Brak plików .log w zakresie!"; exit }

$all = [System.Collections.Generic.List[object]]::new()
foreach ($f in $logFiles) {
    $fs = $null
    $reader = $null
    try {
        # Otwórz plik z FileShare.ReadWrite, by nie blokował IIS
        $fs = [System.IO.File]::Open($f.FullName,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite)
        $reader = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8, $true)

        $header = $null
        while (-not $reader.EndOfStream) {
            $line = $reader.ReadLine()
            if ([string]::IsNullOrWhiteSpace($line)) { continue }

            if ($line[0] -eq '#') {
                if ($line -match '^#Fields:\s*(?<flds>.+)$') {
    $raw = $matches['flds'].Trim()
    $header = $raw -split '\s+'
    $header = $header | ForEach-Object { Normalize-FieldName $_ }
    Write-Host "DEBUG: Złapano nagłówek pól w $($f.Name): $($header -join ', ')" -ForegroundColor DarkGray
}

                continue
            }

            if (-not $header) { continue }
            $parts = $line.Split(' ', [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($parts.Length -lt $header.Count) { continue }

            $obj = [ordered]@{}
            for ($i=0; $i -lt $header.Count; $i++) { $obj[$header[$i]] = $parts[$i] }
            $obj['_LogFile'] = $f.Name
            $all.Add([pscustomobject]$obj)
        }
    }
    catch [System.IO.IOException] {
        Write-Warning "Plik zablokowany przez inny proces (pomijam): $($f.FullName)"
        continue
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($fs)     { $fs.Dispose() }
    }
}

Write-Host "Zparsowano $($all.Count) rekordów." -ForegroundColor Green

# --- Dopasowanie nazw pól ---
$fields = ($all | Select-Object -First 1).PSObject.Properties.Name
# ZASTĄP swoją FindField TĄ wersją:
function FindFieldExact($fields, $candidates) {
    # Zbuduj mapę: znormalizowana_nazwa -> oryginalna_nazwa_pola
    $map = @{}
    foreach ($f in $fields) {
        $norm = (Normalize-FieldName $f).ToLower()
        if (-not $map.ContainsKey($norm)) { $map[$norm] = $f }
    }

    # Szukaj kandydata po tej samej normalizacji (ignoruje -, _, spacje, kropki, nawiasy)
    foreach ($cand in $candidates) {
        $key = (Normalize-FieldName $cand).ToLower()
        if ($map.ContainsKey($key)) { return $map[$key] }
    }
    return $null
}




$uriF = FindFieldExact $fields @('cs-uri-stem','cs_uri_stem','cs_uri','uri_stem','uri-stem')
$ttF  = FindFieldExact $fields @('time-taken','time_taken','timetaken','sc-time-taken','sc_time_taken')
Write-Host "DEBUG: Wykryte pola:" -ForegroundColor Cyan
Write-Host "  URI Field: $uriF"
Write-Host "  TimeTaken Field: $ttF"
Write-Host "  Wszystkie pola: $($fields -join ', ')"

# --- Uzupełnij dane ---
$enriched = foreach ($r in $all) {
    $tt = $null
    if ($ttF -and $r.$ttF -match '^\d+$') { $tt = [double]$r.$ttF }
    $dt = $null
    if ($r.PSObject.Properties.Name -contains 'date' -and $r.PSObject.Properties.Name -contains 'time') {
        try { $dt = [datetime]::ParseExact("$($r.date) $($r.time)",'yyyy-MM-dd HH:mm:ss',[cultureinfo]::InvariantCulture) } catch {}
    }
    [pscustomobject]@{
        DateTime    = $dt
        URI         = if ($uriF) { $r.$uriF } else { '' }
        Status      = if ($r.PSObject.Properties.Name -contains 'sc_status') { $r.sc_status } else { '' }
        TimeTakenMs = $tt
    }
}

$enriched | Export-Csv -NoTypeInformation -Encoding UTF8 -Path $OutputCsv
Write-Host "Zapisano CSV: $OutputCsv" -ForegroundColor Cyan

# --- Globalne statystyki ---
$vals = @($enriched | Where-Object { $_.TimeTakenMs -ne $null } | Select-Object -ExpandProperty TimeTakenMs)
$avg = ($vals | Measure-Object -Average).Average
$med = Percentile $vals 50
$p95 = Percentile $vals 95
$max = ($vals | Measure-Object -Maximum).Maximum

# proste i bezpieczne formatowanie (bez nawiasów przy if)
$avgTT = if ($avg -ne $null -and -not [double]::IsNaN($avg)) { '{0:N1}' -f $avg } else { 'n/a' }
$medTT = if ($med -ne $null -and -not [double]::IsNaN($med)) { '{0:N1}' -f $med } else { 'n/a' }
$p95TT = if ($p95 -ne $null -and -not [double]::IsNaN($p95)) { '{0:N1}' -f $p95 } else { 'n/a' }
$maxTT = if ($max -ne $null -and -not [double]::IsNaN($max)) { '{0:N0}' -f $max } else { 'n/a' }

# --- Grupowanie dzienne ---
$recordsByDay = $enriched | Group-Object { if ($_.DateTime) { $_.DateTime.ToString('yyyy-MM-dd') } else { $_._LogFile } }
$dailyStats = @()
$dailySections = ""

foreach ($grp in ($recordsByDay | Sort-Object Name)) {
    $day = $grp.Name
    $vals = @($grp.Group | Where-Object { $_.TimeTakenMs -ne $null } | Select-Object -ExpandProperty TimeTakenMs)
    if (-not $vals.Count) { continue }

    $avgD = ($vals | Measure-Object -Average).Average
    $medD = Percentile $vals 50
    $p95D = Percentile $vals 95
    $maxD = ($vals | Measure-Object -Maximum).Maximum
    $dailyStats += [pscustomobject]@{
        Day = $day; Count=$grp.Count
        Avg=[math]::Round($avgD,1); Med=[math]::Round($medD,1); P95=[math]::Round($p95D,1); Max=[math]::Round($maxD,0)
    }

    # Top URI i statusy dla danego dnia
    $topUri = $grp.Group | Group-Object URI | Sort-Object Count -Descending | Select-Object -First 5
    $topStatus = $grp.Group | Group-Object Status | Sort-Object Count -Descending | Select-Object -First 5

    $dailySections += "<h3>$day</h3>"
    $dailySections += Html-Table @([pscustomobject]@{Day=$day;Count=$grp.Count;Avg=$avgD;Med=$medD;P95=$p95D;Max=$maxD}) @('Day','Count','Avg','Med','P95','Max')
    $dailySections += "<h4>Top 5 URI</h4>"
    $dailySections += Html-Table ($topUri | ForEach-Object { [pscustomobject]@{URI=$_.Name;Count=$_.Count} }) @('URI','Count')
    $dailySections += "<h4>Top 5 Statusów</h4>"
    $dailySections += Html-Table ($topStatus | ForEach-Object { [pscustomobject]@{Status=$_.Name;Count=$_.Count} }) @('Status','Count')
    $dailySections += "<hr/>"
}

# --- HTML raport ---
$gen = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$dailyTable = if ($dailyStats.Count -gt 0) { Html-Table $dailyStats @('Day','Count','Avg','Med','P95','Max') } else { "<div>Brak danych dziennych.</div>" }

$html = @"
<!doctype html>
<html lang="pl">
<head>
<meta charset="utf-8">
<title>IIS Request Analysis</title>
<style>
body {font-family:Segoe UI,Roboto,Arial,sans-serif;margin:24px;color:#111;}
h1{font-size:22px;margin-bottom:4px;}
h2{font-size:18px;margin-top:28px;margin-bottom:8px;}
h3{font-size:16px;margin-top:20px;margin-bottom:4px;color:#003366;}
table{border-collapse:collapse;width:100%;margin-top:8px;}
th,td{border:1px solid #ddd;padding:4px 6px;text-align:left;font-size:13px;}
th{background:#fafafa;}
</style>
</head>
<body>
<h1>Analiza logów IIS – ostatnie $SinceDays dni</h1>
<div>Wygenerowano: $gen | Rekordów: $($enriched.Count)</div>

<h2>Globalne podsumowanie (ms)</h2>
<table><tr><th>Średnia</th><th>Mediana</th><th>P95</th><th>Max</th></tr>
<tr><td>$avgTT</td><td>$medTT</td><td>$p95TT</td><td>$maxTT</td></tr></table>

<h2>Statystyki dzienne</h2>
$dailyTable

<h2>Szczegóły dzienne</h2>
$dailySections

<div class="muted">Plik CSV: $OutputCsv</div>
</body>
</html>
"@

$html | Out-File -Encoding UTF8 -FilePath $HtmlReportPath
Write-Host "Zapisano raport HTML: $HtmlReportPath" -ForegroundColor Green
