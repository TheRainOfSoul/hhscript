# =====================================================================
#  HH Script — универсальный лаунчер
#  Запуск:  irm <короткая-ссылка> | iex
# =====================================================================

# --- Ссылка, по которой запускается это меню (для перезапуска от админа).
$LauncherUrl = 'https://get.hhtdom.ru'

# --- Совместимость со старыми системами + кириллица ------------------
try { [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$HasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)

# =====================================================================
#  СПИСОК ПРОГРАММ для подменю установки.
#  Winget — id пакета (ставится одной командой). Url — запасная ссылка,
#  откроется в браузере, если winget недоступен.
# =====================================================================
$Programs = @(
    @{ Name = 'Google Chrome';        Winget = 'Google.Chrome';                 Url = 'https://www.google.com/chrome/' }
    @{ Name = 'Brave Browser';        Winget = 'Brave.Brave';                   Url = 'https://brave.com/download/' }
    @{ Name = 'Mozilla Firefox';      Winget = 'Mozilla.Firefox';               Url = 'https://www.mozilla.org/firefox/' }
    @{ Name = '7-Zip';                Winget = '7zip.7zip';                     Url = 'https://www.7-zip.org/' }
    @{ Name = 'VLC media player';     Winget = 'VideoLAN.VLC';                  Url = 'https://www.videolan.org/vlc/' }
    @{ Name = 'Telegram Desktop';     Winget = 'Telegram.TelegramDesktop';      Url = 'https://desktop.telegram.org/' }
    @{ Name = 'Discord';              Winget = 'Discord.Discord';               Url = 'https://discord.com/download' }
    @{ Name = 'Steam';                Winget = 'Valve.Steam';                   Url = 'https://store.steampowered.com/about/' }
    @{ Name = 'Spotify';              Winget = 'Spotify.Spotify';               Url = 'https://www.spotify.com/download/' }
    @{ Name = 'Notepad++';            Winget = 'Notepad++.Notepad++';           Url = 'https://notepad-plus-plus.org/downloads/' }
    @{ Name = 'Visual Studio Code';   Winget = 'Microsoft.VisualStudioCode';    Url = 'https://code.visualstudio.com/' }
    @{ Name = 'qBittorrent';          Winget = 'qBittorrent.qBittorrent';       Url = 'https://www.qbittorrent.org/download' }
    @{ Name = 'OBS Studio';           Winget = 'OBSProject.OBSStudio';          Url = 'https://obsproject.com/download' }
    @{ Name = 'AnyDesk';              Winget = 'AnyDeskSoftwareGmbH.AnyDesk';    Url = 'https://anydesk.com/download' }
)

# =====================================================================
#  Вспомогательные функции
# =====================================================================
function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltinRole]::Administrator)
}

function Restart-AsAdmin {
    Write-Host "`n  Перезапуск от имени администратора..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile','-ExecutionPolicy','Bypass','-Command',"irm $LauncherUrl | iex")
    exit
}

# Скачать и выполнить удалённый скрипт в памяти (irm | iex)
function Invoke-Remote {
    param([string]$Url)
    try {
        Write-Host "`n  Загрузка: $Url`n" -ForegroundColor DarkGray
        Invoke-Expression (Invoke-RestMethod -Uri $Url)
    } catch {
        Write-Host "`n  Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Install-Program {
    param($p)
    if ($HasWinget -and $p.Winget) {
        Write-Host "`n  Установка '$($p.Name)' через winget...`n" -ForegroundColor Green
        winget install --id $p.Winget -e --source winget `
            --accept-package-agreements --accept-source-agreements
    } elseif ($p.Url) {
        Write-Host "`n  winget недоступен — открываю страницу загрузки '$($p.Name)'..." -ForegroundColor Yellow
        Start-Process $p.Url
    } else {
        Write-Host "`n  Нет данных для установки '$($p.Name)'." -ForegroundColor Red
    }
}

function Pause-Menu {
    Write-Host "`n  Нажми Enter для продолжения..." -ForegroundColor DarkGray
    [void](Read-Host)
}

# =====================================================================
#  Подменю: установка программ
# =====================================================================
function Show-Programs {
    do {
        Clear-Host
        Write-Host ""
        Write-Host "  ╔════════════════════════════════════════════╗" -ForegroundColor Magenta
        Write-Host "  ║            Установка программ              ║" -ForegroundColor Magenta
        Write-Host "  ╚════════════════════════════════════════════╝" -ForegroundColor Magenta
        if (-not $HasWinget) {
            Write-Host "   winget не найден — пункты откроют сайт загрузки.`n" -ForegroundColor Yellow
        } else { Write-Host "" }

        for ($i = 0; $i -lt $Programs.Count; $i++) {
            Write-Host ("   [{0,2}] " -f ($i + 1)) -NoNewline -ForegroundColor Green
            Write-Host $Programs[$i].Name
        }
        Write-Host ""
        Write-Host "   [V] " -NoNewline -ForegroundColor Cyan;   Write-Host "Установить ВСЁ"
        Write-Host "   [0] " -NoNewline -ForegroundColor Red;    Write-Host "Назад"
        Write-Host ""

        $sel = (Read-Host "  Выбор").Trim().ToUpper()
        if ($sel -eq '0') { return }
        elseif ($sel -eq 'V') {
            foreach ($p in $Programs) { Install-Program $p }
            Pause-Menu
        }
        elseif ($sel -match '^\d+$' -and [int]$sel -ge 1 -and [int]$sel -le $Programs.Count) {
            Install-Program $Programs[[int]$sel - 1]
            Pause-Menu
        }
        else { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1 }
    } while ($true)
}

# =====================================================================
#  Главное меню
# =====================================================================
function Show-Menu {
    Clear-Host
    $mode = if (Test-Admin) { 'АДМИН' } else { 'обычный пользователь' }
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║              HH Script Toolbox             ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "   Режим: $mode`n" -ForegroundColor DarkGray

    Write-Host "  --- Активация и настройка ---" -ForegroundColor DarkCyan
    Write-Host "   [1] " -NoNewline -ForegroundColor Green; Write-Host "MAS — активация Windows / Office (MassGrave)"
    Write-Host "   [2] " -NoNewline -ForegroundColor Green; Write-Host "WinUtil — настройка/чистка Windows (Chris Titus)"
    Write-Host "   [3] " -NoNewline -ForegroundColor Green; Write-Host "Win11Debloat — удаление мусора из Windows"
    Write-Host ""
    Write-Host "  --- Программы ---" -ForegroundColor DarkCyan
    Write-Host "   [4] " -NoNewline -ForegroundColor Green; Write-Host "Установить программы (подменю)"
    Write-Host ""
    Write-Host "  --- Мои скрипты ---" -ForegroundColor DarkCyan
    Write-Host "   [5] " -NoNewline -ForegroundColor Green; Write-Host "Мой скрипт №1 (пример)"
    Write-Host "   [6] " -NoNewline -ForegroundColor Green; Write-Host "Мой скрипт №2 (пример)"
    Write-Host ""
    Write-Host "   [A] " -NoNewline -ForegroundColor Yellow; Write-Host "Перезапустить от имени администратора"
    Write-Host "   [0] " -NoNewline -ForegroundColor Red;    Write-Host "Выход"
    Write-Host ""
}

do {
    Show-Menu
    $choice = (Read-Host "  Выбор").Trim().ToUpper()
    switch ($choice) {
        '1' { Invoke-Remote 'https://get.activated.win';  Pause-Menu }   # MAS
        '2' { Invoke-Remote 'https://christitus.com/win'; Pause-Menu }   # WinUtil
        '3' { Invoke-Remote 'https://debloat.raphi.re/';  Pause-Menu }   # Win11Debloat
        '4' { Show-Programs }
        '5' { Invoke-Remote 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/script1.ps1'; Pause-Menu }
        '6' { Invoke-Remote 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/script2.ps1'; Pause-Menu }
        'A' { Restart-AsAdmin }
        '0' { }
        default { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1 }
    }
} while ($choice -ne '0')

Write-Host "`n  Готово. До встречи!`n" -ForegroundColor Cyan
