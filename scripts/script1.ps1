# Пример твоего личного скрипта №1.
# Сюда можно положить что угодно: установку программ, твики реестра и т.д.
# Этот файл скачивается и выполняется в памяти по ссылке из menu.ps1.

try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

Write-Host "`n  >> Это пример скрипта №1. Замени содержимое на своё.`n" -ForegroundColor Green

# Пример: показать инфо о системе
Get-ComputerInfo -Property CsName, OsName, OsVersion, OsArchitecture |
    Format-List
