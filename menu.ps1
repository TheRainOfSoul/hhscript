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
    @{ Name = 'Winbox (MikroTik)';    Winget = 'Mikrotik.Winbox';                Url = 'https://mikrotik.com/download' }
    @{ Name = 'Speedtest CLI (Ookla)'; Winget = 'Ookla.Speedtest.CLI';            Url = 'https://www.speedtest.net/apps/cli' }
    @{ Name = 'CrystalDiskInfo';      Winget = 'CrystalDewWorld.CrystalDiskInfo'; Url = 'https://crystalmark.info/en/software/crystaldiskinfo/' }
    @{ Name = 'HWiNFO (мониторинг)';  Winget = 'REALiX.HWiNFO';                  Url = 'https://www.hwinfo.com/download/' }
    @{ Name = 'OCCT (стресс-тест)';   Winget = 'OCBase.OCCT.Personal';           Url = 'https://www.ocbase.com/' }
    @{ Name = 'FurMark (стресс GPU)'; Winget = 'Geeks3D.FurMark.2';              Url = 'https://geeks3d.com/furmark/' }
    @{ Name = 'CrystalDiskMark';      Winget = 'CrystalDewWorld.CrystalDiskMark'; Url = 'https://crystalmark.info/en/software/crystaldiskmark/' }
    @{ Name = 'VC++ Redist 2015-2022 (x64)'; Winget = 'Microsoft.VCRedist.2015+.x64'; Url = 'https://aka.ms/vs/17/release/vc_redist.x64.exe' }
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

function Invoke-AdminRestart {
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

function Wait-Continue {
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
#  Чек-лист с галочками.
#  Управление: ↑/↓ — навигация, Пробел — вкл/выкл, A — все/никого,
#  Enter — применить, Esc — отмена. Если консоль не даёт читать клавиши
#  (например, перенаправлённый ввод) — резервный режим с вводом номеров.
#  Возвращает массив индексов отмеченных пунктов или $null при отмене.
# =====================================================================
function Show-CheckList {
    param([string]$Title, [string[]]$Items, [string]$Color = 'Yellow', [bool]$DefaultChecked = $true)

    $n     = $Items.Count
    $state = @($Items | ForEach-Object { $DefaultChecked })   # стартовое состояние галочек
    $cur   = 0

    $interactive = $true
    try { $null = [Console]::KeyAvailable } catch { $interactive = $false }

    function Draw {
        Write-Box $Title $Color
        if ($interactive) {
            Write-Host "   ↑/↓ — выбор   Пробел — вкл/выкл   A — все   Enter — применить   Esc — отмена`n" -ForegroundColor DarkGray
        } else {
            Write-Host "   Номера через пробел — переключить, all/none, пусто — применить, 0 — отмена`n" -ForegroundColor DarkGray
        }
        for ($i = 0; $i -lt $n; $i++) {
            $mark = if ($state[$i]) { '[x]' } else { '[ ]' }
            if ($interactive -and $i -eq $cur) {
                Write-Host ("   > $mark " + $Items[$i]) -ForegroundColor Black -BackgroundColor Gray
            } else {
                $col = if ($state[$i]) { 'Green' } else { 'Gray' }
                $num = if ($interactive) { '    ' } else { '{0,2}. ' -f ($i + 1) }
                Write-Host ("   $num$mark " + $Items[$i]) -ForegroundColor $col
            }
        }
    }

    if (-not $interactive) {
        Draw
        while ($true) {
            $in = (Read-Host "   >").Trim().ToLower()
            if ($in -eq '0')    { return $null }
            if ($in -eq '')     { break }
            if ($in -eq 'all')  { for ($i=0; $i -lt $n; $i++) { $state[$i] = $true };  Draw; continue }
            if ($in -eq 'none') { for ($i=0; $i -lt $n; $i++) { $state[$i] = $false }; Draw; continue }
            foreach ($t in ($in -split '[ ,]+')) {
                if ($t -match '^\d+$' -and [int]$t -ge 1 -and [int]$t -le $n) { $state[[int]$t - 1] = -not $state[[int]$t - 1] }
            }
            Draw
        }
        return ,@(0..($n - 1) | Where-Object { $state[$_] })
    }

    while ($true) {
        Draw
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'UpArrow'   { $cur = ($cur - 1 + $n) % $n }
            'DownArrow' { $cur = ($cur + 1) % $n }
            'Spacebar'  { $state[$cur] = -not $state[$cur] }
            'Enter'     { return ,@(0..($n - 1) | Where-Object { $state[$_] }) }
            'Escape'    { return $null }
            default {
                $ch = ([string]$k.KeyChar).ToLower()
                if ($ch -eq 'a' -or $ch -eq 'а') {
                    $allOn = -not ($state -contains $false)
                    for ($i = 0; $i -lt $n; $i++) { $state[$i] = -not $allOn }
                }
            }
        }
    }
}

# =====================================================================
#  Лёгкая чистка: выбор пунктов галочками (приложения + TEMP + DNS)
# =====================================================================
function Invoke-LightClean {
    if (-not (Test-Admin)) {
        Write-Box 'Лёгкая чистка системы' 'Yellow'
        Write-Host "   Без прав администратора приложения удалятся только для"
        Write-Host "   текущего пользователя. Для всех — выйди и запусти [A].`n" -ForegroundColor DarkYellow
        if ((Read-Host "   Продолжить? (y/n)").Trim().ToLower() -ne 'y') { return }
    }

    # Пункты: приложения (Appx) и действия (Action). Правится свободно.
    $items = @(
        @{ Label = 'Bing Новости';          Appx = 'Microsoft.BingNews' }
        @{ Label = 'Bing Погода';           Appx = 'Microsoft.BingWeather' }
        @{ Label = 'Получить помощь';        Appx = 'Microsoft.GetHelp' }
        @{ Label = 'Советы (Get Started)';   Appx = 'Microsoft.Getstarted' }
        @{ Label = 'Microsoft Solitaire';    Appx = 'Microsoft.MicrosoftSolitaireCollection' }
        @{ Label = 'Люди (People)';          Appx = 'Microsoft.People' }
        @{ Label = 'Центр отзывов';          Appx = 'Microsoft.WindowsFeedbackHub' }
        @{ Label = 'Groove Музыка';          Appx = 'Microsoft.ZuneMusic' }
        @{ Label = 'Кино и ТВ';              Appx = 'Microsoft.ZuneVideo' }
        @{ Label = 'Связь с телефоном';      Appx = 'Microsoft.YourPhone' }
        @{ Label = 'To Do';                  Appx = 'Microsoft.Todos' }
        @{ Label = 'Clipchamp';              Appx = 'Clipchamp.Clipchamp' }
        @{ Label = 'Карты';                  Appx = 'Microsoft.WindowsMaps' }
        @{ Label = 'Office Hub';             Appx = 'Microsoft.MicrosoftOfficeHub' }
        @{ Label = 'Teams (личный)';         Appx = 'MicrosoftTeams' }
        @{ Label = 'Power Automate';         Appx = 'Microsoft.PowerAutomateDesktop' }
        @{ Label = 'Xbox Game Overlay';      Appx = 'Microsoft.XboxGameOverlay' }
        @{ Label = 'Xbox Gaming Overlay';    Appx = 'Microsoft.XboxGamingOverlay' }
        @{ Label = 'Очистить папку TEMP';    Action = 'temp' }
        @{ Label = 'Сбросить кэш DNS';       Action = 'dns' }
    )

    $sel = Show-CheckList 'Лёгкая чистка — отметь пункты' @($items | ForEach-Object { $_.Label })
    if ($null -eq $sel)   { Write-Host "`n   Отменено." -ForegroundColor DarkGray; return }
    if ($sel.Count -eq 0) { Write-Host "`n   Ничего не выбрано." -ForegroundColor DarkGray; return }

    $admin = Test-Admin
    Write-Host "`n   Выполняю..." -ForegroundColor DarkGray
    foreach ($idx in $sel) {
        $it = $items[$idx]
        if ($it.Appx) {
            if ($admin) {
                Get-AppxPackage -Name $it.Appx -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
                Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
                    Where-Object DisplayName -EQ $it.Appx |
                    Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
            } else {
                Get-AppxPackage -Name $it.Appx -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
            }
            Write-Host "   - удалено: $($it.Label)" -ForegroundColor DarkGray
        }
        elseif ($it.Action -eq 'temp') {
            Get-ChildItem $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "   - очищен TEMP" -ForegroundColor DarkGray
        }
        elseif ($it.Action -eq 'dns') {
            ipconfig /flushdns | Out-Null
            Write-Host "   - сброшен кэш DNS" -ForegroundColor DarkGray
        }
    }
    Write-Host "`n   Готово." -ForegroundColor Green
}

# =====================================================================
#  Базовые твики: выбор пунктов галочками (только HKCU, без админа)
# =====================================================================
function Invoke-LightTweak {
    $adv    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $theme  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    $search = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    $clsid  = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'

    $tweaks = @(
        @{ Label = 'Показывать расширения файлов';            Do = { Set-ItemProperty $adv -Name HideFileExt -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Показывать скрытые файлы';                Do = { Set-ItemProperty $adv -Name Hidden -Value 1 -ErrorAction SilentlyContinue } }
        @{ Label = 'Тёмная тема оформления';                  Do = { Set-ItemProperty $theme -Name AppsUseLightTheme -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty $theme -Name SystemUsesLightTheme -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Классическое контекстное меню (Win11)';   Do = { New-Item -Path $clsid -Force | Out-Null; Set-ItemProperty $clsid -Name '(default)' -Value '' -ErrorAction SilentlyContinue } }
        @{ Label = 'Отключить веб-поиск Bing в меню Пуск';    Do = { Set-ItemProperty $search -Name BingSearchEnabled -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty $search -Name CortanaConsent -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Панель задач: значки слева (Win11)';      Do = { Set-ItemProperty $adv -Name TaskbarAl -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Скрыть кнопку «Виджеты» (Win11)';         Do = { Set-ItemProperty $adv -Name TaskbarDa -Value 0 -ErrorAction SilentlyContinue } }
    )

    $sel = Show-CheckList 'Базовые твики — отметь пункты' @($tweaks | ForEach-Object { $_.Label })
    if ($null -eq $sel)   { Write-Host "`n   Отменено." -ForegroundColor DarkGray; return }
    if ($sel.Count -eq 0) { Write-Host "`n   Ничего не выбрано." -ForegroundColor DarkGray; return }

    Write-Host "`n   Применяю..." -ForegroundColor DarkGray
    foreach ($idx in $sel) {
        & $tweaks[$idx].Do
        Write-Host "   - $($tweaks[$idx].Label)" -ForegroundColor DarkGray
    }
    Write-Host "`n   Перезапуск проводника для применения..." -ForegroundColor DarkGray
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-Host "   Готово." -ForegroundColor Green
}

# =====================================================================
#  Подменю: установка программ
# =====================================================================
function Show-ProgramMenu {
    # Метки: пункты без winget откроют сайт загрузки — помечаем «(сайт)»
    $labels = @($Programs | ForEach-Object {
        if ($HasWinget -and $_.Winget) { $_.Name } else { $_.Name + '  (сайт)' }
    })
    $sel = Show-CheckList 'Установка программ — отметь нужное' $labels 'Magenta' $false
    if ($null -eq $sel)   { return }
    if ($sel.Count -eq 0) { Write-Host "`n   Ничего не выбрано." -ForegroundColor DarkGray; Wait-Continue; return }

    foreach ($idx in $sel) { Install-Program $Programs[$idx] }
    Write-Host "`n   Установка завершена." -ForegroundColor Green
    Wait-Continue
}

# =====================================================================
#  Новый ПК — первичная настройка
#  Программы + иконка «Этот компьютер» + откл. виджетов + драйверы.
#  Драйверы: официальные CLI — Dell (dcu-cli) / HP (HPIA) / Lenovo (Thin
#  Installer); Intel-платы — Intel DSA; AMD/прочее — страница вендора.
#  Без Windows Update. Та же логика в пункте [D] «Обновление драйверов».
# =====================================================================
function Open-DriverPage {
    param([string]$Maker, [string]$Model)
    $map = @{
        'asus'     = 'https://www.asus.com/support/'
        'gigabyte' = 'https://www.gigabyte.com/Support'
        'msi'      = 'https://www.msi.com/support/'
        'asrock'   = 'https://www.asrock.com/support/index.asp'
        'biostar'  = 'https://www.biostar.com.tw/app/en/support/'
    }
    $url = $null
    foreach ($k in $map.Keys) { if ($Maker -match $k) { $url = $map[$k]; break } }
    if (-not $url) { $url = 'https://www.google.com/search?q=' + [uri]::EscapeDataString("$Maker $Model drivers") }
    Write-Host "   Модель для поиска: $Maker $Model" -ForegroundColor Cyan
    Write-Host "   Открываю официальную страницу: $url" -ForegroundColor DarkGray
    Start-Process $url
}

function Install-DellDriver {
    if (-not $HasWinget) { Write-Host "   Нужен winget для Dell Command Update." -ForegroundColor Yellow; return }
    Write-Host "   Установка Dell Command Update (официальный инструмент Dell)..." -ForegroundColor DarkGray
    winget install --id Dell.CommandUpdate.Universal -e --source winget --accept-package-agreements --accept-source-agreements
    $dcu = @("$env:ProgramFiles\Dell\CommandUpdate\dcu-cli.exe", "${env:ProgramFiles(x86)}\Dell\CommandUpdate\dcu-cli.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $dcu) { Write-Host "   dcu-cli не найден — запусти Dell Command Update вручную." -ForegroundColor Yellow; return }
    Write-Host "   Поиск и установка драйверов с сайта Dell..." -ForegroundColor DarkGray
    & $dcu /scan
    & $dcu /applyUpdates -reboot=disable
}

function Install-HpDriver {
    if (-not $HasWinget) { Write-Host "   Нужен winget для HP Image Assistant." -ForegroundColor Yellow; return }
    Write-Host "   Установка HP Image Assistant (HPIA)..." -ForegroundColor DarkGray
    winget install --id HP.ImageAssistant -e --source winget --accept-package-agreements --accept-source-agreements
    $hpia = @("$env:ProgramFiles\HP\HPIA\HPImageAssistant.exe", "${env:ProgramFiles(x86)}\HP\HPIA\HPImageAssistant.exe", "$env:ProgramData\HP\HPIA\HPImageAssistant.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $hpia) {
        $hpia = (Get-ChildItem "$env:ProgramFiles\HP", "${env:ProgramFiles(x86)}\HP" -Recurse -Filter 'HPImageAssistant.exe' -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
    }
    if (-not $hpia) {
        Write-Host "   HPImageAssistant.exe не найден — открываю страницу драйверов HP." -ForegroundColor Yellow
        Start-Process 'https://support.hp.com/us-en/drivers'
        return
    }
    Write-Host "   Анализ и установка драйверов с сайта HP (HPIA)..." -ForegroundColor DarkGray
    & $hpia /Operation:Analyze /Category:Drivers /Selection:All /Action:Install /Silent /ReportFolder:"$env:TEMP\HPIA"
}

function Install-LenovoDriver {
    if (-not $HasWinget) { Write-Host "   Нужен winget для Lenovo Thin Installer." -ForegroundColor Yellow; return }
    Write-Host "   Установка Lenovo Thin Installer..." -ForegroundColor DarkGray
    winget install --id Lenovo.ThinInstaller -e --source winget --accept-package-agreements --accept-source-agreements
    $ti = @("${env:ProgramFiles(x86)}\Lenovo\ThinInstaller\ThinInstaller.exe", "$env:ProgramFiles\Lenovo\ThinInstaller\ThinInstaller.exe") |
        Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $ti) {
        Write-Host "   ThinInstaller.exe не найден — открываю страницу драйверов Lenovo." -ForegroundColor Yellow
        Start-Process 'https://support.lenovo.com/solutions/ht003029'
        return
    }
    Write-Host "   Поиск и установка драйверов с сайта Lenovo (Thin Installer)..." -ForegroundColor DarkGray
    & $ti /CM -search A -action INSTALL -includerebootpackages 1, 3, 4 -noreboot -noicon
}

function Install-IntelDriver {
    if (-not $HasWinget) { Write-Host "   Нужен winget для Intel DSA." -ForegroundColor Yellow; return }
    Write-Host "   Установка Intel Driver & Support Assistant..." -ForegroundColor DarkGray
    winget install --id Intel.IntelDriverAndSupportAssistant -e --source winget --accept-package-agreements --accept-source-agreements
    Write-Host "   У Intel нет тихого CLI — открываю DSA для сканирования и установки..." -ForegroundColor Yellow
    Start-Process 'https://www.intel.com/content/www/us/en/support/detect.html'
}

function Invoke-DriverUpdate {
    Write-Box 'Обновление драйверов' 'Cyan'
    if (-not (Test-Admin)) {
        Write-Host "   Установка драйверов требует прав администратора." -ForegroundColor Yellow
        Write-Host "   Лучше выйти и запустить [A].`n" -ForegroundColor Yellow
    }
    $bb = Get-CimInstance Win32_BaseBoard -ErrorAction SilentlyContinue
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    $vendor = "$($cs.Manufacturer)"
    Write-Kv 'Система:'    "$vendor $($cs.Model)"
    Write-Kv 'Мат. плата:' "$($bb.Manufacturer) $($bb.Product)"

    $missing = @(Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -ne 'OK' -and $_.Class -notin 'SoftwareDevice', 'SoftwareComponent' })
    if ($missing.Count) {
        Write-Host "`n   Устройства с проблемой драйвера ($($missing.Count)):" -ForegroundColor Yellow
        $missing | Select-Object -Unique FriendlyName | ForEach-Object {
            Write-Host "    - $($_.FriendlyName)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "`n   Устройств без драйвера не обнаружено." -ForegroundColor Green
    }

    Write-Host ""
    $v = $vendor.ToLower()
    if     ($v -match 'dell')       { Write-Host "   Инструмент: Dell Command | Update`n" -ForegroundColor Cyan; Install-DellDriver }
    elseif ($v -match 'hp|hewlett') { Write-Host "   Инструмент: HP Image Assistant`n"   -ForegroundColor Cyan; Install-HpDriver }
    elseif ($v -match 'lenovo')     { Write-Host "   Инструмент: Lenovo Thin Installer`n" -ForegroundColor Cyan; Install-LenovoDriver }
    else {
        $cpu = "$((Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Manufacturer)"
        if ($cpu -match 'Intel') {
            Write-Host "   Инструмент: Intel Driver & Support Assistant`n" -ForegroundColor Cyan
            Install-IntelDriver
            Write-Host "   Драйверы чипсета/звука самой платы — на официальной странице вендора." -ForegroundColor DarkGray
        } else {
            Write-Host "   Сборка не Dell/HP/Lenovo и не Intel — официального CLI нет." -ForegroundColor Yellow
            Open-DriverPage $bb.Manufacturer $bb.Product
        }
    }
}

function Invoke-NewPC {
    Write-Box 'Новый ПК — первичная настройка' 'Green'
    if (-not (Test-Admin)) {
        Write-Host "   Часть шагов (драйверы, машинная установка, политика виджетов)" -ForegroundColor Yellow
        Write-Host "   требует прав администратора. Лучше выйти и запустить [A].`n" -ForegroundColor Yellow
    }
    if ((Read-Host "   Начать настройку нового ПК? (y/n)").Trim().ToLower() -ne 'y') { return }

    # 1/4 — программы
    Write-Host "`n  [1/4] Установка программ (Chrome, 7-Zip, AnyDesk)..." -ForegroundColor Cyan
    if ($HasWinget) {
        foreach ($id in 'Google.Chrome', '7zip.7zip', 'AnyDeskSoftwareGmbH.AnyDesk') {
            Write-Host "   winget: $id" -ForegroundColor DarkGray
            winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements
        }
    } else { Write-Host "   winget не найден — пропускаю установку программ." -ForegroundColor Yellow }

    # 2/4 — иконка «Этот компьютер»
    Write-Host "`n  [2/4] Иконка «Этот компьютер» на рабочий стол..." -ForegroundColor Cyan
    $ns = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\HideDesktopIcons\NewStartPanel'
    New-Item -Path $ns -Force | Out-Null
    Set-ItemProperty $ns -Name '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' -Value 0 -Type DWord -ErrorAction SilentlyContinue

    # 3/4 — отключить виджеты
    Write-Host "`n  [3/4] Отключение виджетов..." -ForegroundColor Cyan
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name TaskbarDa -Value 0 -ErrorAction SilentlyContinue
    if (Test-Admin) {
        $dsh = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
        New-Item -Path $dsh -Force | Out-Null
        Set-ItemProperty $dsh -Name AllowNewsAndInterests -Value 0 -Type DWord -ErrorAction SilentlyContinue
    }

    # 4/4 — драйверы
    Write-Host "`n  [4/4] Драйверы (официальный CLI вендора, без Windows Update)..." -ForegroundColor Cyan
    Invoke-DriverUpdate

    Write-Host "`n  Перезапуск проводника для применения иконок и виджетов..." -ForegroundColor DarkGray
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-Host "`n  Готово. Новый ПК настроен." -ForegroundColor Green
}

# =====================================================================
#  Сетевые утилиты
# =====================================================================
function Switch-Dns {
    param([string[]]$Servers)   # пусто = вернуть автоматический (DHCP)
    if (-not (Test-Admin)) {
        Write-Host "`n   Нужны права администратора — выйди и запусти [A]." -ForegroundColor Yellow
        return
    }
    $a = Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object Status -EQ 'Up' | Select-Object -First 1
    if (-not $a) { Write-Host "`n   Активный адаптер не найден." -ForegroundColor Red; return }
    if ($Servers -and $Servers.Count) {
        Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ServerAddresses $Servers -ErrorAction SilentlyContinue
        Write-Host "`n   DNS на '$($a.Name)' -> $($Servers -join ', ')" -ForegroundColor Green
    } else {
        Set-DnsClientServerAddress -InterfaceIndex $a.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        Write-Host "`n   DNS на '$($a.Name)' -> автоматический (DHCP)" -ForegroundColor Green
    }
    ipconfig /flushdns | Out-Null
}

function Repair-Network {
    if (-not (Test-Admin)) {
        Write-Host "`n   Нужны права администратора — выйди и запусти [A]." -ForegroundColor Yellow
        return
    }
    Write-Host "`n   Сброс Winsock и стека TCP/IP..." -ForegroundColor DarkGray
    netsh winsock reset | Out-Host
    netsh int ip reset   | Out-Host
    ipconfig /flushdns   | Out-Null
    Write-Host "`n   Готово. Перезагрузи ПК, чтобы изменения вступили в силу." -ForegroundColor Green
}

function Show-AdapterInfo {
    Write-Box 'Сетевые адаптеры' 'Cyan'
    Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -EQ 'Up' | ForEach-Object {
        $ip = (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1).IPAddress
        Write-Kv $_.Name "IP $ip   MAC $($_.MacAddress)   $($_.LinkSpeed)"
    }
}

function Show-NetworkMenu {
    do {
        Write-Box 'Сетевые утилиты' 'Cyan'
        Write-Host "   [1] " -NoNewline -ForegroundColor Green; Write-Host "Конфигурация сети (ipconfig /all)"
        Write-Host "   [2] " -NoNewline -ForegroundColor Green; Write-Host "Адаптеры: IP / MAC / скорость"
        Write-Host "   [3] " -NoNewline -ForegroundColor Green; Write-Host "Ping хоста"
        Write-Host "   [4] " -NoNewline -ForegroundColor Green; Write-Host "Трассировка (tracert)"
        Write-Host "   [5] " -NoNewline -ForegroundColor Green; Write-Host "DNS -> Cloudflare (1.1.1.1)        [админ]"
        Write-Host "   [6] " -NoNewline -ForegroundColor Green; Write-Host "DNS -> Google (8.8.8.8)            [админ]"
        Write-Host "   [7] " -NoNewline -ForegroundColor Green; Write-Host "DNS -> автоматический (DHCP)       [админ]"
        Write-Host "   [8] " -NoNewline -ForegroundColor Green; Write-Host "Сброс сети (Winsock + TCP/IP)      [админ]"
        Write-Host "   [0] " -NoNewline -ForegroundColor Red;   Write-Host "Назад"
        Write-Host ""
        $c = (Read-Host "  Выбор").Trim()
        switch ($c) {
            '1' { ipconfig /all | Out-Host; Wait-Continue }
            '2' { Show-AdapterInfo; Wait-Continue }
            '3' { $h = Read-Host "   Хост или IP"; if ($h) { Test-Connection -ComputerName $h -Count 4 -ErrorAction SilentlyContinue | Format-Table -AutoSize | Out-Host }; Wait-Continue }
            '4' { $h = Read-Host "   Хост или IP"; if ($h) { tracert $h | Out-Host }; Wait-Continue }
            '5' { Switch-Dns '1.1.1.1', '1.0.0.1'; Wait-Continue }
            '6' { Switch-Dns '8.8.8.8', '8.8.4.4'; Wait-Continue }
            '7' { Switch-Dns @();                  Wait-Continue }
            '8' { Repair-Network;                  Wait-Continue }
            '0' { return }
            default { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1 }
        }
    } while ($true)
}

# =====================================================================
#  Калькуляторы для камер
# =====================================================================
function Read-Number {
    param([string]$Prompt, [double]$Default)
    $in = (Read-Host "   $Prompt [$Default]").Trim().Replace(',', '.')
    if ($in -eq '') { return $Default }
    $val = 0.0
    if ([double]::TryParse($in, [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$val)) { return $val }
    Write-Host "   Не число — беру $Default" -ForegroundColor DarkYellow
    return $Default
}

function Read-Bitrate {
    Write-Host "   Битрейт на камеру:" -ForegroundColor Gray
    Write-Host "    [1] 2 МП / 1080p  (~4 Mbps)   [по умолч.]"
    Write-Host "    [2] 4 МП          (~6 Mbps)"
    Write-Host "    [3] 5 МП          (~8 Mbps)"
    Write-Host "    [4] 8 МП / 4K     (~12 Mbps)"
    Write-Host "    [5] ввести вручную"
    switch ((Read-Host "   Выбор [1]").Trim()) {
        '2'     { $b = 6 }
        '3'     { $b = 8 }
        '4'     { $b = 12 }
        '5'     { $b = Read-Number 'Битрейт, Mbps' 4 }
        default { $b = 4 }
    }
    if ((Read-Host "   Кодек: [1] H.265 (по умолч.)  [2] H.264 (битрейт x2)").Trim() -eq '2') { $b = $b * 2 }
    return $b
}

function Show-RetentionCalc {
    Write-Box 'HDD -> на сколько дней хватит' 'Cyan'
    $tb    = Read-Number 'Объём диска, ТБ' 4
    $cams  = Read-Number 'Кол-во камер' 4
    $mbps  = Read-Bitrate
    $hours = Read-Number 'Часов записи в сутки (24 = круглосуточно)' 24
    $factor = 1.0
    if ((Read-Host "   Режим: [1] постоянно (по умолч.)  [2] по движению").Trim() -eq '2') {
        $factor = (Read-Number 'Активность, % (доля времени с движением)' 30) / 100.0
    }

    $gbPerDay = $cams * $mbps * 0.45 * $hours * $factor
    if ($gbPerDay -le 0) { Write-Host "`n   Некорректные данные." -ForegroundColor Red; return }
    $days = ($tb * 1000 * 0.93) / $gbPerDay

    Write-Host ""
    Write-Kv 'Расход:'    ("{0:N1} ГБ/сутки (все камеры)" -f $gbPerDay)
    Write-Kv 'Хватит на:' ("{0:N1} дней  (~{1:N1} мес.)" -f $days, ($days / 30))
    Write-Host "`n   Учтён запас ~7% (форматирование/резерв NVR). Реальные цифры" -ForegroundColor DarkGray
    Write-Host "   зависят от сцены и кодека." -ForegroundColor DarkGray
}

function Show-InternetCalc {
    Write-Box 'Сеть -> нужный интернет (upload)' 'Cyan'
    $cams = Read-Number 'Кол-во камер' 4
    Write-Host "   Поток для удалённого просмотра:" -ForegroundColor Gray
    Write-Host "    [1] дополнительный / substream (~1 Mbps, телефон) [по умолч.]"
    Write-Host "    [2] основной / mainstream (по пресетам)"
    if ((Read-Host "   Выбор [1]").Trim() -eq '2') { $mbps = Read-Bitrate }
    else { $mbps = Read-Number 'Битрейт substream, Mbps' 1 }
    $viewed  = Read-Number 'Камер смотрят одновременно' $cams
    $viewers = Read-Number 'Зрителей одновременно' 1

    $upload = $viewed * $mbps * $viewers * 1.2
    $plan   = [math]::Ceiling($upload / 5) * 5
    Write-Host ""
    Write-Kv 'Нужно upload:' ("{0:N1} Mbps (исходящая на объекте)" -f $upload)
    Write-Kv 'Тариф:'        ("от ~{0:N0} Mbps upload (с запасом)" -f $plan)
    Write-Host "`n   Важно: удалённый просмотр ограничивает ОТДАЧА (upload) на" -ForegroundColor DarkGray
    Write-Host "   стороне камер/регистратора, а не download. Тариф выбирай по upload." -ForegroundColor DarkGray
}

function Show-CalcMenu {
    do {
        Write-Box 'Калькуляторы для камер' 'Cyan'
        Write-Host "   [1] " -NoNewline -ForegroundColor Green; Write-Host "HDD -> на сколько дней хватит диска"
        Write-Host "   [2] " -NoNewline -ForegroundColor Green; Write-Host "Сеть -> какой интернет (upload) нужен"
        Write-Host "   [0] " -NoNewline -ForegroundColor Red;   Write-Host "Назад"
        Write-Host ""
        switch ((Read-Host "  Выбор").Trim()) {
            '1' { Show-RetentionCalc; Wait-Continue }
            '2' { Show-InternetCalc;  Wait-Continue }
            '0' { return }
            default { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1 }
        }
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
    Write-Host "   [5] " -NoNewline -ForegroundColor Green; Write-Host "Сетевые утилиты (DNS, ping, сброс сети)"
    Write-Host ""
    Write-Host "  --- Программы ---" -ForegroundColor DarkCyan
    Write-Host "   [6] " -NoNewline -ForegroundColor Green; Write-Host "Установить программы (галочками)"
    Write-Host "   [7] " -NoNewline -ForegroundColor Green; Write-Host "Обновить весь софт (winget upgrade)"
    Write-Host ""
    Write-Host "  --- Мои скрипты ---" -ForegroundColor DarkCyan
    Write-Host "   [8] " -NoNewline -ForegroundColor Green; Write-Host "Мой скрипт №1 (пример)"
    Write-Host "   [9] " -NoNewline -ForegroundColor Green; Write-Host "Мой скрипт №2 (пример)"
    Write-Host ""
    Write-Host "   [C] " -NoNewline -ForegroundColor Cyan;    Write-Host "Калькуляторы для камер (HDD / интернет)"
    Write-Host "   [D] " -NoNewline -ForegroundColor Green;   Write-Host "Обновление драйверов (Dell/HP/Lenovo/Intel)"
    Write-Host "   [N] " -NoNewline -ForegroundColor Magenta; Write-Host "Новый ПК — первичная настройка (программы, драйверы, иконки)"
    Write-Host "   [A] " -NoNewline -ForegroundColor Yellow;  Write-Host "Перезапустить от имени администратора"
    Write-Host "   [0] " -NoNewline -ForegroundColor Red;     Write-Host "Выход"
    Write-Host ""
}

do {
    Show-Menu
    $choice = (Read-Host "  Выбор").Trim().ToUpper()
    switch ($choice) {
        '1' { Show-PCInfo;        Wait-Continue }
        '2' { Invoke-Remote 'https://get.activated.win'; Wait-Continue }    # MAS
        '3' { Invoke-LightClean;  Wait-Continue }
        '4' { Invoke-LightTweak;  Wait-Continue }
        '5' { Show-NetworkMenu }
        '6' { Show-ProgramMenu }
        '7' {
            if ($HasWinget) {
                Write-Host "`n   Обновление всего установленного софта..." -ForegroundColor Green
                winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements
            } else { Write-Host "`n   winget не найден." -ForegroundColor Yellow }
            Wait-Continue
        }
        '8' { Invoke-Remote 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/script1.ps1'; Wait-Continue }
        '9' { Invoke-Remote 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/script2.ps1'; Wait-Continue }
        'C' { Show-CalcMenu }
        'D' { Invoke-DriverUpdate; Wait-Continue }
        'N' { Invoke-NewPC; Wait-Continue }
        'A' { Invoke-AdminRestart }
        '0' { }
        default { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1 }
    }
} while ($choice -ne '0')

Write-Host "`n  Готово. До встречи!`n" -ForegroundColor Cyan
