# =====================================================================
#  Тесты чистой логики (без сети/Windows-cmdlet'ов). Запуск в CI под pwsh 7.
#  Функции вытаскиваем из menu.ps1 через AST и выполняем точечно — top-level
#  код menu.ps1 не запускается, поэтому тест герметичен на любой платформе.
# =====================================================================
$ErrorActionPreference = 'Stop'
$menu = "$PSScriptRoot/../menu.ps1"
$src = [System.IO.File]::ReadAllText($menu, [System.Text.UTF8Encoding]::new($false))
$ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)

# Присваивания-данные, от которых зависит калькулятор.
$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) |
    Where-Object { $_.Left.Extent.Text -in @('$script:DahuaBase', '$script:DahuaMin') } |
    ForEach-Object { Invoke-Expression $_.Extent.Text }

# Тестируемые функции.
foreach ($fn in 'Get-DahuaBitRate', 'Get-DahuaStorageKB', 'Get-DahuaDays', 'ConvertTo-JsDelivr') {
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

if ($fail) { Write-Host "Провалено тестов: $fail" -ForegroundColor Red; exit 1 }
Write-Host "Все тесты логики пройдены." -ForegroundColor Green
