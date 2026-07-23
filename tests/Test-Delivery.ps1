# =====================================================================
#  Проверка модели доставки: `irm <url> | iex`
#
#  Скрипты не запускаются с диска — они скачиваются в память и выполняются.
#  Invoke-RestMethod декодирует ответ через Encoding.GetString, который BOM
#  НЕ срезает: он приходит символом U+FEFF в начало строки, и iex падает с
#  «The term '<BOM>#' is not recognized».
#
#  ВАЖНО: обычный синтаксический разбор такую поломку НЕ ловит —
#  Parser::ParseInput ведущий U+FEFF принимает молча. Поэтому нужна отдельная
#  проверка первого символа: именно она отделяет «файл разбирается» от
#  «файл реально выполнится после скачивания».
#
#  Правило репозитория: файл доставляется по сети -> БЕЗ BOM (иначе iex падает);
#  файл только для локального запуска (как этот тест) -> С BOM, иначе Windows
#  PowerShell 5.1 прочитает его как cp1251 и покалечит кириллицу.
#  Поэтому папка tests из проверки исключена — она никуда не доставляется.
# =====================================================================
$root  = Split-Path $PSScriptRoot -Parent
$sep   = [IO.Path]::DirectorySeparatorChar
$files = Get-ChildItem $root -Recurse -Filter *.ps1 |
    Where-Object { $_.DirectoryName -ne $PSScriptRoot -and $_.FullName -notlike "*${sep}tests${sep}*" } |
    Sort-Object FullName
$fail  = 0

foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\', '/')

    # Ровно то, что получит клиент: байты файла, декодированные как UTF-8.
    $asIrm = [Text.Encoding]::UTF8.GetString([IO.File]::ReadAllBytes($f.FullName))

    if ([int][char]$asIrm[0] -eq 0xFEFF) {
        Write-Host "::error::$rel сохранён с BOM — irm отдаст U+FEFF и iex упадёт на первом токене"
        $fail++
        continue
    }

    $err = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($asIrm, [ref]$null, [ref]$err)
    if ($err) {
        Write-Host "::error::$rel не разбирается после скачивания"
        $err | ForEach-Object { Write-Host "  $($_.Message)" }
        $fail++
        continue
    }

    Write-Host "OK: $rel"
}

if ($fail) {
    Write-Host "`nПригодность к доставке: ПРОВАЛ ($fail из $($files.Count))"
    exit 1
}
Write-Host "`nПригодность к доставке: OK (проверено файлов: $($files.Count))"
