# =====================================================================
#  HH Script — стресс-тест ПК
#  Запуск отдельно:
#    irm https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/stresstest.ps1 | iex
#  Встроенный CPU-прожиг (чистый PowerShell) + запуск OCCT/FurMark/CrystalDiskMark/HWiNFO.
# =====================================================================
try { [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { $null = $_ }
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { $null = $_ }

# Температура CPU через WMI (на десктопах часто недоступна — тогда "н/д").
function Get-CpuTemp {
    try {
        $t = Get-CimInstance MSAcpi_ThermalZoneTemperature -Namespace root/WMI -ErrorAction Stop | Select-Object -First 1
        if ($t -and $t.CurrentTemperature) {
            $c = [math]::Round(($t.CurrentTemperature / 10) - 273.15, 0)
            return "Темп: $c°C"
        }
    } catch { $null = $_ }
    return "Темп: н/д (точнее в HWiNFO)"
}

# Встроенный CPU-прожиг: по одному busy-loop на каждое логическое ядро.
function Invoke-CpuStress {
    Clear-Host
    Write-Host "`n  === CPU-стресс (встроенный, 100% всех ядер) ===" -ForegroundColor Cyan
    Write-Host "  ВНИМАНИЕ: нагрузка может перегреть слабоохлаждаемое или" -ForegroundColor Yellow
    Write-Host "  неисправное железо. Останов — любой клавишей.`n" -ForegroundColor Yellow
    $m = (Read-Host "  Длительность, минут [5]").Trim()
    $min = 5
    if ($m -match '^\d+$' -and [int]$m -gt 0) { $min = [int]$m }
    if ((Read-Host "  Старт? (y/n)").Trim().ToLower() -ne 'y') { return }

    $cores = [Environment]::ProcessorCount
    $end   = (Get-Date).AddMinutes($min)
    Write-Host "`n  Нагрузка на $cores потоков, $min мин...`n" -ForegroundColor Green
    $jobs = 1..$cores | ForEach-Object {
        Start-Job -ScriptBlock {
            # $using: вместо param/-ArgumentList; результат в $null — считаем
            # ради нагрузки на ядро, само значение не нужно.
            while ((Get-Date) -lt $using:end) {
                for ($i = 1; $i -lt 2000000; $i++) { $null = [math]::Sqrt($i) * [math]::Sin($i) }
            }
        }
    }

    while ((Get-Date) -lt $end) {
        $load = (Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" -ErrorAction SilentlyContinue).PercentProcessorTime
        $remain = [int](($end - (Get-Date)).TotalSeconds)
        Write-Host ("`r  Загрузка CPU: {0,3}%   Осталось: {1,4} c   {2}   (клавиша — стоп)   " -f $load, $remain, (Get-CpuTemp)) -NoNewline
        if ([Console]::KeyAvailable) { [void][Console]::ReadKey($true); break }
        Start-Sleep -Seconds 1
    }
    $jobs | Stop-Job   -ErrorAction SilentlyContinue
    $jobs | Remove-Job -Force -ErrorAction SilentlyContinue
    Write-Host "`n`n  Тест завершён." -ForegroundColor Green
}

# Найти и запустить установленный инструмент (GUI — тест подтверждаешь в нём).
function Invoke-Tool {
    param([string]$Exe, [string]$Friendly)
    Write-Host "`n  Поиск $Friendly..." -ForegroundColor DarkGray
    $p = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}") |
        ForEach-Object { Get-ChildItem $_ -Recurse -Filter $Exe -ErrorAction SilentlyContinue | Select-Object -First 1 } |
        Where-Object { $_ } | Select-Object -First 1
    if ($p) {
        Start-Process $p.FullName
        Write-Host "  Запущен: $($p.FullName)" -ForegroundColor Green
    } else {
        Write-Host "  $Friendly не найден. Установи его в меню -> 'Установить программы'." -ForegroundColor Yellow
    }
}

do {
    Clear-Host
    Write-Host "`n  === Стресс-тест ПК ===`n" -ForegroundColor Cyan
    Write-Host "   [1] " -NoNewline -ForegroundColor Green; Write-Host "CPU-стресс (встроенный, N минут)"
    Write-Host "   [2] " -NoNewline -ForegroundColor Green; Write-Host "OCCT (CPU/GPU/RAM/БП)"
    Write-Host "   [3] " -NoNewline -ForegroundColor Green; Write-Host "FurMark (стресс GPU)"
    Write-Host "   [4] " -NoNewline -ForegroundColor Green; Write-Host "CrystalDiskMark (тест диска)"
    Write-Host "   [5] " -NoNewline -ForegroundColor Green; Write-Host "HWiNFO (мониторинг температур)"
    Write-Host "   [0] " -NoNewline -ForegroundColor Red;   Write-Host "Выход"
    Write-Host ""
    $c = (Read-Host "  Выбор").Trim()
    switch ($c) {
        '1' { Invoke-CpuStress }
        '2' { Invoke-Tool 'OCCT.exe'       'OCCT' }
        '3' { Invoke-Tool 'FurMark.exe'    'FurMark' }
        '4' { Invoke-Tool 'DiskMark64.exe' 'CrystalDiskMark' }
        '5' { Invoke-Tool 'HWiNFO64.exe'   'HWiNFO' }
        '0' { }
        default { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1 }
    }
    if ($c -ne '0') { Write-Host "`n  Нажми Enter..." -ForegroundColor DarkGray; [void](Read-Host) }
} while ($c -ne '0')
