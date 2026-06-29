# =====================================================================
#  HH Script — универсальный лаунчер
#  Запуск:  irm get.hhtdom.ru | iex
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
#  откроется в браузере, если winget недоступен или пакета нет.
# =====================================================================
$Programs = @(
    @{ Name = 'Google Chrome';        Winget = 'Google.Chrome';                 Url = 'https://www.google.com/chrome/' }
    @{ Name = '7-Zip';                Winget = '7zip.7zip';                     Url = 'https://www.7-zip.org/' }
    @{ Name = 'VLC media player';     Winget = 'VideoLAN.VLC';                  Url = 'https://www.videolan.org/vlc/' }
    @{ Name = 'qBittorrent';          Winget = 'qBittorrent.qBittorrent';       Url = 'https://www.qbittorrent.org/download' }
    @{ Name = 'AnyDesk';              Winget = 'AnyDeskSoftwareGmbH.AnyDesk';    Url = 'https://anydesk.com/download' }
    @{ Name = 'Advanced IP Scanner';  Winget = 'Famatech.AdvancedIPScanner';    Url = 'https://www.advanced-ip-scanner.com/' }
    # --- Dahua: пакетов winget нет, открывается официальная страница загрузки в браузере.
    #     Если ссылка устареет — обнови URL со страницы support.dahuasecurity.com -> Tools.
    @{ Name = 'Dahua ConfigTool';     Winget = '';  Url = 'https://support.dahuasecurity.com/en/toolsDownloadDetails?IsDpValue=Q93jdSLr94chjRuQ1y%2FcQQ%3D%3D' }
    @{ Name = 'Dahua SmartPSS Lite';  Winget = '';  Url = 'https://support.dahuasecurity.com/en/toolsDownloadDetails?IsDpValue=Azcw9DN0IRfyUn9i%2Fvq6qA%3D%3D' }
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
        Write-Host "`n  Открываю страницу загрузки '$($p.Name)' в браузере..." -ForegroundColor Yellow
        Start-Process $p.Url
    } else {
        Write-Host "`n  Нет данных для установки '$($p.Name)'." -ForegroundColor Red
    }
}

function Pause-Menu {
    Write-Host "`n  Нажми Enter для продолжения..." -ForegroundColor DarkGray
    [void](Read-Host)
}

function Write-Box {
    param([string]$Text, [string]$Color = 'Cyan')
    $inner = 44
    $pad   = $inner - $Text.Length
    $left  = [int]([math]::Floor($pad / 2))
    $line  = (' ' * $left) + $Text
    $line  = $line.PadRight($inner)
    Clear-Host
    Write-Host ""
    Write-Host ("  ╔" + ('═' * $inner) + "╗") -ForegroundColor $Color
    Write-Host ("  ║" + $line + "║")           -ForegroundColor $Color
    Write-Host ("  ╚" + ('═' * $inner) + "╝") -ForegroundColor $Color
    Write-Host ""
}

function Write-Kv {
    param([string]$Key, [string]$Value)
    Write-Host ("   {0,-16}" -f $Key) -NoNewline -ForegroundColor Gray
    Write-Host $Value -ForegroundColor White
}

# =====================================================================
#  Информация о ПК (всё локально, ничего не качается)
# =====================================================================
function Get-ActivationStatus {
    try {
        $p = Get-CimInstance -ClassName SoftwareLicensingProduct `
            -Filter "ApplicationID='55c92734-d682-4d71-983e-d6ec3f16059f' AND PartialProductKey IS NOT NULL" `
            -ErrorAction Stop | Select-Object -First 1
        if (-not $p) { return 'Не активирована (ключ не найден)' }
        switch ([int]$p.LicenseStatus) {
            1 { 'Активирована' }
            0 { 'Не активирована' }
            2 { 'Льготный период (Grace)' }
            5 { 'Требуется активация' }
            6 { 'Расширенный льготный период' }
            default { "Статус: $($p.LicenseStatus)" }
        }
    } catch { 'н/д' }
}

function Show-PCInfo {
    Write-Box 'Информация о ПК' 'Green'
    Write-Host "   Сбор данных..." -ForegroundColor DarkGray

    $os   = Get-CimInstance Win32_OperatingSystem      -ErrorAction SilentlyContinue
    $cs   = Get-CimInstance Win32_ComputerSystem       -ErrorAction SilentlyContinue
    $cpu  = Get-CimInstance Win32_Processor            -ErrorAction SilentlyContinue | Select-Object -First 1
    $bb   = Get-CimInstance Win32_BaseBoard            -ErrorAction SilentlyContinue
    $bios = Get-CimInstance Win32_BIOS                 -ErrorAction SilentlyContinue
    $ram  = Get-CimInstance Win32_PhysicalMemory       -ErrorAction SilentlyContinue
    $gpu  = (Get-CimInstance Win32_VideoController     -ErrorAction SilentlyContinue).Name -join ', '

    Write-Box 'Информация о ПК' 'Green'
    Write-Kv 'Имя ПК:'        $cs.Name
    Write-Kv 'Пользователь:'  "$env:USERDOMAIN\$env:USERNAME"
    Write-Kv 'ОС:'            "$($os.Caption) (сборка $($os.BuildNumber))"
    Write-Kv 'Разрядность:'   $os.OSArchitecture
    Write-Kv 'Активация:'     (Get-ActivationStatus)
    Write-Kv 'Производитель:' "$($cs.Manufacturer) $($cs.Model)"
    Write-Kv 'Мат. плата:'    "$($bb.Manufacturer) $($bb.Product)"
    Write-Kv 'BIOS:'          $bios.SMBIOSBIOSVersion
    Write-Kv 'Процессор:'     "$($cpu.Name.Trim()) ($($cpu.NumberOfCores) ядер / $($cpu.NumberOfLogicalProcessors) потоков)"

    $ramGb   = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
    $ramMhz  = ($ram | Select-Object -First 1 -ExpandProperty Speed -ErrorAction SilentlyContinue)
    $ramMods = ($ram | Measure-Object).Count
    Write-Kv 'ОЗУ:'           "$ramGb ГБ ($ramMods модулей, $ramMhz МГц)"
    Write-Kv 'Видеокарта:'    $gpu

    Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" -ErrorAction SilentlyContinue | ForEach-Object {
        $free = [math]::Round($_.FreeSpace / 1GB, 1)
        $size = [math]::Round($_.Size / 1GB, 1)
        Write-Kv ("Диск " + $_.DeviceID) "$free ГБ свободно из $size ГБ"
    }

    $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
    if ($cfg) {
        Write-Kv 'Локальный IP:' $cfg.IPv4Address.IPAddress
        Write-Kv 'Шлюз:'         $cfg.IPv4DefaultGateway.NextHop
    }
    $pub = try { (Invoke-RestMethod 'https://api.ipify.org' -TimeoutSec 5) } catch { 'н/д' }
    Write-Kv 'Внешний IP:'    $pub

    if ($os.LastBootUpTime) {
        $up = (Get-Date) - $os.LastBootUpTime
        Write-Kv 'Аптайм:'     "$($up.Days)д $($up.Hours)ч $($up.Minutes)м"
    }
}

# =====================================================================
#  Лёгкая чистка: удаление типовых лишних приложений + TEMP + DNS
# =====================================================================
function Invoke-LightClean {
    Write-Box 'Лёгкая чистка системы' 'Yellow'
    Write-Host "   Будут удалены типовые лишние приложения (их можно вернуть"
    Write-Host "   из Microsoft Store), очищена папка TEMP и сброшен кэш DNS.`n"
    if (-not (Test-Admin)) {
        Write-Host "   Совет: для удаления у всех пользователей запусти из меню" -ForegroundColor DarkYellow
        Write-Host "   пункт [A] (от администратора).`n" -ForegroundColor DarkYellow
    }
    if ((Read-Host "   Продолжить? (y/n)").Trim().ToLower() -ne 'y') { return }

    $bloat = @(
        'Microsoft.BingNews','Microsoft.BingWeather','Microsoft.GetHelp','Microsoft.Getstarted',
        'Microsoft.MicrosoftSolitaireCollection','Microsoft.People','Microsoft.WindowsFeedbackHub',
        'Microsoft.ZuneMusic','Microsoft.ZuneVideo','Microsoft.YourPhone','Microsoft.Todos',
        'Clipchamp.Clipchamp','Microsoft.WindowsMaps','Microsoft.MicrosoftOfficeHub',
        'Microsoft.OneConnect','Microsoft.3DBuilder','Microsoft.Microsoft3DViewer',
        'Microsoft.MixedReality.Portal','Microsoft.PowerAutomateDesktop','MicrosoftTeams',
        'Microsoft.XboxGameOverlay','Microsoft.XboxGamingOverlay','Microsoft.XboxSpeechToTextOverlay'
    )
    $admin = Test-Admin
    Write-Host "`n   Удаление приложений..." -ForegroundColor DarkGray
    foreach ($a in $bloat) {
        if ($admin) {
            Get-AppxPackage -Name $a -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
            Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                Where-Object DisplayName -EQ $a |
                Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
        } else {
            Get-AppxPackage -Name $a -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
        }
        Write-Host "   - $a" -ForegroundColor DarkGray
    }

    Write-Host "`n   Очистка TEMP..." -ForegroundColor DarkGray
    Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "   Сброс кэша DNS..." -ForegroundColor DarkGray
    ipconfig /flushdns | Out-Null

    Write-Host "`n   Готово." -ForegroundColor Green
}

# =====================================================================
#  Базовые твики (только HKCU — права админа не нужны)
# =====================================================================
function Invoke-LightTweaks {
    Write-Box 'Базовые твики' 'Yellow'
    Write-Host "   Будут применены безопасные настройки текущего пользователя:"
    Write-Host "    - показывать расширения файлов"
    Write-Host "    - показывать скрытые файлы"
    Write-Host "    - тёмная тема оформления"
    Write-Host "    - классическое контекстное меню (Windows 11)`n"
    if ((Read-Host "   Применить? (y/n)").Trim().ToLower() -ne 'y') { return }

    $adv   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $theme = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-ItemProperty $adv   -Name HideFileExt        -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $adv   -Name Hidden             -Value 1 -ErrorAction SilentlyContinue
    Set-ItemProperty $theme -Name AppsUseLightTheme  -Value 0 -ErrorAction SilentlyContinue
    Set-ItemProperty $theme -Name SystemUsesLightTheme -Value 0 -ErrorAction SilentlyContinue

    # Классическое меню Win11 (чтобы вернуть — удали этот ключ CLSID)
    $clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
    New-Item -Path $clsid -Force | Out-Null
    Set-ItemProperty $clsid -Name '(default)' -Value '' -ErrorAction SilentlyContinue

    Write-Host "`n   Перезапуск проводника для применения..." -ForegroundColor DarkGray
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-Host "   Готово." -ForegroundColor Green
}

# =====================================================================
#  Подменю: установка программ
# =====================================================================
function Show-Programs {
    do {
        Write-Box 'Установка программ' 'Magenta'
        if (-not $HasWinget) {
            Write-Host "   winget не найден — пункты откроют сайт загрузки.`n" -ForegroundColor Yellow
        }
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

    Write-Host "  --- Система ---" -ForegroundColor DarkCyan
    Write-Host "   [1] " -NoNewline -ForegroundColor Green; Write-Host "Информация о ПК"
    Write-Host "   [2] " -NoNewline -ForegroundColor Green; Write-Host "MAS — активация Windows / Office"
    Write-Host "   [3] " -NoNewline -ForegroundColor Green; Write-Host "Лёгкая чистка (удалить лишнее + TEMP + DNS)"
    Write-Host "   [4] " -NoNewline -ForegroundColor Green; Write-Host "Базовые твики (расширения, тёмная тема, меню)"
    Write-Host ""
    Write-Host "  --- Программы ---" -ForegroundColor DarkCyan
    Write-Host "   [5] " -NoNewline -ForegroundColor Green; Write-Host "Установить программы (подменю)"
    Write-Host ""
    Write-Host "  --- Мои скрипты ---" -ForegroundColor DarkCyan
    Write-Host "   [6] " -NoNewline -ForegroundColor Green; Write-Host "Мой скрипт №1 (пример)"
    Write-Host "   [7] " -NoNewline -ForegroundColor Green; Write-Host "Мой скрипт №2 (пример)"
    Write-Host ""
    Write-Host "   [A] " -NoNewline -ForegroundColor Yellow; Write-Host "Перезапустить от имени администратора"
    Write-Host "   [0] " -NoNewline -ForegroundColor Red;    Write-Host "Выход"
    Write-Host ""
}

do {
    Show-Menu
    $choice = (Read-Host "  Выбор").Trim().ToUpper()
    switch ($choice) {
        '1' { Show-PCInfo;        Pause-Menu }
        '2' { Invoke-Remote 'https://get.activated.win'; Pause-Menu }    # MAS
        '3' { Invoke-LightClean;  Pause-Menu }
        '4' { Invoke-LightTweaks; Pause-Menu }
        '5' { Show-Programs }
        '6' { Invoke-Remote 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/script1.ps1'; Pause-Menu }
        '7' { Invoke-Remote 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/script2.ps1'; Pause-Menu }
        'A' { Restart-AsAdmin }
        '0' { }
        default { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1 }
    }
} while ($choice -ne '0')

Write-Host "`n  Готово. До встречи!`n" -ForegroundColor Cyan
