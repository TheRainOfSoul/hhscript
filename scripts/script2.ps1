# Пример твоего личного скрипта №2.
# Скачивается и выполняется в памяти по ссылке из menu.ps1.

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Write-Host "`n  >> Это пример скрипта №2. Замени содержимое на своё.`n" -ForegroundColor Green

# Пример: очистка временных файлов пользователя
$temp = $env:TEMP
Write-Host "  Очищаю $temp ..." -ForegroundColor DarkGray
Get-ChildItem -Path $temp -Recurse -Force -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "  Готово." -ForegroundColor Green
