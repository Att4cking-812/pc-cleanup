$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()
$OutputEncoding = [Console]::OutputEncoding

function SizeMB([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return 0 }
    try {
        $sum = (Get-ChildItem -LiteralPath $path -Recurse -Force -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return 0 }
        return [math]::Round($sum / 1MB, 1)
    } catch { return 0 }
}

function Rub([double]$mb) { return ('{0:N1} МБ' -f $mb) }

$targets = @(
    @{ Name = 'Временные файлы пользователя (%TEMP%)'; Path = $env:TEMP },
    @{ Name = 'Временные файлы Windows';                 Path = "$env:SystemRoot\Temp" },
    @{ Name = 'Кэш установщиков (Windows\SoftwareDistribution\Download)'; Path = "$env:SystemRoot\SoftwareDistribution\Download" },
    @{ Name = 'Корзина'; Path = $null }
)

Clear-Host
Write-Host ''
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host '              УБОРКА КОМПЬЮТЕРА' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ''

$rows = @()
$total = 0
foreach ($t in $targets) {
    if ($t.Path) {
        $mb = SizeMB $t.Path
        $total += $mb
        $rows += [pscustomobject]@{ Name = $t.Name; MB = $mb }
    } else {
        $rows += [pscustomobject]@{ Name = $t.Name; MB = $null }
    }
}

foreach ($r in $rows) {
    if ($null -eq $r.MB) {
        Write-Host ("   {0,-62} {1,12}" -f $r.Name, 'по желанию') -ForegroundColor DarkGray
    } else {
        Write-Host ("   {0,-62} {1,12:N1} МБ" -f $r.Name, $r.MB)
    }
}
Write-Host ''
Write-Host ("   Итого к очистке: ~{0:N1} МБ" -f $total) -ForegroundColor Yellow
Write-Host ''
$dl = "$env:USERPROFILE\Downloads"
$dlOld = 0
$cut = (Get-Date).AddDays(-30)
try {
    $dlOld = [math]::Round(((Get-ChildItem -LiteralPath $dl -File -Force -ErrorAction SilentlyContinue |
             Where-Object { $_.LastWriteTime -lt $cut } |
             Measure-Object -Property Length -Sum).Sum) / 1MB, 1)
} catch {}
if ($null -eq $dlOld) { $dlOld = 0 }
Write-Host ("   В Downloads старше 30 дней: ~{0:N1} МБ" -f $dlOld) -ForegroundColor DarkGray
Write-Host ''
Write-Host '   Что будет удалено: временные файлы, кэш обновлений Windows,' -ForegroundColor Gray
Write-Host '   корзина. Личные файлы НЕ трогаются.' -ForegroundColor Gray
Write-Host ''
Write-Host '   Напиши ДА, чтобы начать (или Enter — отмена):' -ForegroundColor Yellow -NoNewline
Write-Host ' ' -NoNewline
$answer = Read-Host
if ($answer -ne 'ДА' -and $answer -ne 'да' -and $answer -ne 'Da') {
    Write-Host ''
    Write-Host '   Отменено. Ничего не удалено.' -ForegroundColor DarkGray
    Start-Sleep -Seconds 2
    exit
}

$before = 0
try { $before = (Get-PSDrive C).Free } catch {}

Write-Host ''
Write-Host '   Убираю...' -ForegroundColor Cyan

foreach ($t in @($env:TEMP, "$env:SystemRoot\Temp", "$env:SystemRoot\SoftwareDistribution\Download")) {
    if (-not $t -or -not (Test-Path -LiteralPath $t)) { continue }
    Get-ChildItem -LiteralPath $t -Force -ErrorAction SilentlyContinue | ForEach-Object {
        try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop } catch { }
    }
    Write-Host ("     очищено: {0}" -f $t) -ForegroundColor DarkGray
}

try {
    Clear-RecycleBin -Force -ErrorAction Stop
    Write-Host '     корзина очищена' -ForegroundColor DarkGray
} catch {
    Write-Host '     корзина: уже пуста или занята' -ForegroundColor DarkGray
}

$after = 0
try { $after = (Get-PSDrive C).Free } catch {}
$freed = [math]::Round(($after - $before) / 1MB, 1)
if ($freed -lt 0) { $freed = 0 }

Write-Host ''
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ("   Освобождено: ~{0:N1} МБ" -f $freed) -ForegroundColor Green
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ''

$logDir = Join-Path $env:LOCALAPPDATA 'CleanupLogs'
New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$logFile = Join-Path $logDir ("cleanup_{0}.txt" -f (Get-Date).ToString('yyyy-MM-dd_HH-mm'))
@(
    "Уборка: $(Get-Date -Format 'dd.MM.yyyy HH:mm')",
    "Освобождено: $freed МБ",
    "Свободно на C: $([math]::Round($after/1GB,2)) ГБ"
) | Set-Content -LiteralPath $logFile -Encoding UTF8

Read-Host '   Нажми Enter, чтобы закрыть'
