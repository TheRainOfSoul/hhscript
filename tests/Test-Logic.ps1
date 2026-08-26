# =====================================================================
#  Тесты чистой логики (без сети/Windows-cmdlet'ов). Запуск в CI под pwsh 7.
#  Функции вытаскиваем из menu.ps1 через AST и выполняем точечно — top-level
#  код menu.ps1 не запускается, поэтому тест герметичен на любой платформе.
# =====================================================================
$ErrorActionPreference = 'Stop'
$menu = "$PSScriptRoot/../menu.ps1"
$src = [System.IO.File]::ReadAllText($menu, [System.Text.UTF8Encoding]::new($false))
$ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)

# Присваивания-данные, от которых зависит калькулятор и пресеты камер.
$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
    Where-Object { $_.Left.Extent.Text -in @('$script:DahuaBase', '$script:DahuaMin', '$script:CamPresets') } |
    ForEach-Object { Invoke-Expression $_.Extent.Text }

# Тестируемые функции.
foreach ($fn in 'Get-DahuaBitRate', 'Get-DahuaStorageKB', 'Get-DahuaDays', 'ConvertTo-JsDelivr', 'Get-CamPreset', 'New-CamUrl') {
    $f = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $fn }, $true)
    if (-not $f) { Write-Host "::error::функция $fn не найдена в menu.ps1"; exit 1 }
    Invoke-Expression $f.Extent.Text
}

$fail = 0
function Assert-Eq {
    param($Actual, $Expected, [string]$Name)
    if ("$Actual" -eq "$Expected") {
        Write-Host "  OK   $Name = $Actual"
    } else {
        Write-Host "::error::FAIL $Name -> получено '$Actual', ожидалось '$Expected'"
        $script:fail++
    }
}

# --- Калькулятор Dahua (эталоны из README, снятые с самого калькулятора) ---
Assert-Eq (Get-DahuaBitRate -Resolution '1080P' -FrameRate 25 -VideoStandard 'PAL' -Compression 'H.264') 4096 'Dahua bitrate 1080P/25/H.264 = 4096 Kbps'
Assert-Eq (Get-DahuaStorageKB -BitRateKbps 2048 -HoursPerDay 24 -Days 30) 737280000 'Dahua storage 1ch 1080P/H.265 30д = 737280000 KB (703.2 GB)'
Assert-Eq (Get-DahuaDays -BitRateKbps 8192 -HoursPerDay 24 -DiskKB (4 * 1024 * 1024 * 1024)) 43 'Dahua дней: 4ch 1080P/H.265 на 4 ТБ = 43'

# --- jsDelivr-фолбэк: трансформ raw -> зеркало ---
Assert-Eq (ConvertTo-JsDelivr 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/menu.ps1') 'https://cdn.jsdelivr.net/gh/TheRainOfSoul/hhscript@main/menu.ps1' 'jsDelivr raw -> зеркало'
Assert-Eq ([string](ConvertTo-JsDelivr 'https://example.com/file.ps1')) '' 'jsDelivr не-raw URL -> $null'

# --- Камеры: пресеты вендоров и сборка URL (снапшот/RTSP) ---
Assert-Eq (Get-CamPreset -Vendor 'Dahua' -Kind 'Snapshot') 'cgi-bin/snapshot.cgi?channel=1' 'Dahua snapshot preset'
Assert-Eq (Get-CamPreset -Vendor 'Hikvision' -Kind 'Rtsp') 'Streaming/Channels/101' 'Hikvision rtsp preset'
Assert-Eq ([string](Get-CamPreset -Vendor 'НетТакого' -Kind 'Snapshot')) '' 'неизвестный вендор -> пусто'
Assert-Eq (New-CamUrl -Scheme 'http' -IP '192.168.1.10' -Port 80 -User '' -Pass '' -Path '/cgi-bin/snapshot.cgi?channel=1') 'http://192.168.1.10:80/cgi-bin/snapshot.cgi?channel=1' 'снапшот-URL без учётки в адресе'
Assert-Eq (New-CamUrl -Scheme 'rtsp' -IP '10.0.0.5' -Port 554 -User 'admin' -Pass 'Admin#123' -Path 'Streaming/Channels/101') 'rtsp://admin:Admin%23123@10.0.0.5:554/Streaming/Channels/101' 'RTSP-URL: пароль Admin#123 экранирован'

if ($fail) { Write-Host "Провалено тестов: $fail" -ForegroundColor Red; exit 1 }
Write-Host "Все тесты логики пройдены." -ForegroundColor Green
