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
$Version   = '2026.07.11'                              # версия скрипта (в шапке меню)
$LogFile   = Join-Path $env:USERPROFILE 'HHToolbox.log' # лог действий (для истории/акта)

# =====================================================================
#  СПИСОК ПРОГРАММ для подменю установки.
#  Winget — id пакета (ставится одной командой). Url — запасная ссылка,
#  откроется в браузере, если winget недоступен или пакета нет.
# =====================================================================
$Programs = @(
    # --- Браузер / общее ---
    @{ Group = 'Браузер / общее'; Name = 'Google Chrome';        Winget = 'Google.Chrome';                   Url = 'https://www.google.com/chrome/' }
    @{ Name = '7-Zip';                Winget = '7zip.7zip';                       Url = 'https://www.7-zip.org/' }
    @{ Name = 'VLC media player';     Winget = 'VideoLAN.VLC';                    Url = 'https://www.videolan.org/vlc/' }
    @{ Name = 'qBittorrent';          Winget = 'qBittorrent.qBittorrent';         Url = 'https://www.qbittorrent.org/download' }
    @{ Name = 'Notepad++';            Winget = 'Notepad++.Notepad++';             Url = 'https://notepad-plus-plus.org/downloads/' }
    # --- Удалёнка / доступ ---
    @{ Group = 'Удалёнка / доступ'; Name = 'AnyDesk';              Winget = 'AnyDeskSoftwareGmbH.AnyDesk';      Url = 'https://anydesk.com/download' }
    @{ Name = 'TightVNC';             Winget = 'GlavSoft.TightVNC';               Url = 'https://www.tightvnc.com/download.php' }
    @{ Name = 'mRemoteNG';            Winget = 'mRemoteNG.mRemoteNG';             Url = 'https://mremoteng.org/download' }
    @{ Name = 'MobaXterm';            Winget = 'Mobatek.MobaXterm';               Url = 'https://mobaxterm.mobatek.net/download.html' }
    # --- Сеть / диагностика ---
    @{ Group = 'Сеть / диагностика'; Name = 'Advanced IP Scanner';  Winget = 'Famatech.AdvancedIPScanner';      Url = 'https://www.advanced-ip-scanner.com/' }
    @{ Name = 'Angry IP Scanner';     Winget = 'angryziber.AngryIPScanner';       Url = 'https://angryip.org/download/' }
    @{ Name = 'Nmap';                 Winget = 'Insecure.Nmap';                   Url = 'https://nmap.org/download.html' }
    @{ Name = 'Wireshark';            Winget = 'WiresharkFoundation.Wireshark';   Url = 'https://www.wireshark.org/download.html' }
    @{ Name = 'Winbox (MikroTik)';    Winget = 'Mikrotik.Winbox';                 Url = 'https://mikrotik.com/download' }
    @{ Name = 'PuTTY';                Winget = 'PuTTY.PuTTY';                     Url = 'https://www.putty.org/' }
    @{ Name = 'WinSCP';               Winget = 'WinSCP.WinSCP';                   Url = 'https://winscp.net/eng/download.php' }
    @{ Name = 'Speedtest CLI (Ookla)'; Winget = 'Ookla.Speedtest.CLI';            Url = 'https://www.speedtest.net/apps/cli' }
    # --- Система / диски / поиск ---
    @{ Group = 'Система / диски / поиск'; Name = 'Sysinternals Suite';   Winget = 'Microsoft.Sysinternals.Suite';    Url = 'https://learn.microsoft.com/sysinternals/downloads/sysinternals-suite' }
    @{ Name = 'HWiNFO (мониторинг)';  Winget = 'REALiX.HWiNFO';                   Url = 'https://www.hwinfo.com/download/' }
    @{ Name = 'CrystalDiskInfo';      Winget = 'CrystalDewWorld.CrystalDiskInfo'; Url = 'https://crystalmark.info/en/software/crystaldiskinfo/' }
    @{ Name = 'CrystalDiskMark';      Winget = 'CrystalDewWorld.CrystalDiskMark'; Url = 'https://crystalmark.info/en/software/crystaldiskmark/' }
    @{ Name = 'DiskGenius (разделы/восстановление)'; Winget = 'Eassos.DiskGenius'; Url = 'https://www.diskgenius.com/download.php' }
    @{ Name = 'TestDisk + PhotoRec (восстановление)'; Winget = 'CGSecurity.TestDisk'; Url = 'https://www.cgsecurity.org/wiki/TestDisk_Download' }
    @{ Name = 'WizTree (диск)';       Winget = 'AntibodySoftware.WizTree';        Url = 'https://diskanalyzer.com/download' }
    @{ Name = 'Everything (поиск)';   Winget = 'voidtools.Everything';            Url = 'https://www.voidtools.com/downloads/' }
    @{ Name = 'Glow (анализ системы)'; Winget = '';                               Url = 'https://github.com/turkaysoft/glow/releases' }
    # --- Стресс / бенчмарк ---
    @{ Group = 'Стресс / бенчмарк'; Name = 'OCCT (стресс-тест)';   Winget = 'OCBase.OCCT.Personal';            Url = 'https://www.ocbase.com/' }
    @{ Name = 'FurMark (стресс GPU)'; Winget = 'Geeks3D.FurMark.2';               Url = 'https://geeks3d.com/furmark/' }
    # --- Загрузочные USB ---
    @{ Group = 'Загрузочные USB'; Name = 'Rufus (загруз. USB)';  Winget = 'Rufus.Rufus';                     Url = 'https://rufus.ie/' }
    @{ Name = 'Ventoy (мультизагр.)'; Winget = 'Ventoy.Ventoy';                   Url = 'https://www.ventoy.net/' }
    # --- Безопасность ---
    @{ Group = 'Безопасность'; Name = 'Malwarebytes';         Winget = 'Malwarebytes.Malwarebytes';       Url = 'https://www.malwarebytes.com/' }
    @{ Name = 'KeePassXC (пароли)';   Winget = 'KeePassXCTeam.KeePassXC';         Url = 'https://keepassxc.org/download/' }
    # --- Оболочка ---
    @{ Group = 'Оболочка'; Name = 'PowerShell 7';         Winget = 'Microsoft.PowerShell';            Url = 'https://github.com/PowerShell/PowerShell/releases' }
    @{ Name = 'Windows Terminal';     Winget = 'Microsoft.WindowsTerminal';       Url = 'https://github.com/microsoft/terminal/releases' }
    # --- CCTV (в winget нет — открывается официальная страница загрузки) ---
    @{ Group = 'CCTV'; Name = 'Dahua ConfigTool'; Yadisk = 'https://disk.yandex.ru/d/c-K3fF2PNXBOmQ' }
    @{ Name = 'Dahua SmartPSS Lite';  Winget = '';  Url = 'https://support.dahuasecurity.com/en/toolsDownloadDetails?IsDpValue=Azcw9DN0IRfyUn9i%2Fvq6qA%3D%3D' }
    @{ Name = 'SADP (Hikvision)';     Winget = '';  Url = 'https://www.hikvision.com/en/support/tools/hitools/clc14d7e1a69a237dd/' }
    @{ Name = 'HiTools Delivery (Hikvision)'; Winget = ''; Url = 'https://www.hikvision.com/en/support/tools/hitools/cl7f0143d2c781a3e3/' }
    @{ Name = 'iVMS-4200 (Hikvision)'; Winget = ''; Url = 'https://www.hikvision.com/us-en/support/download/software/ivms4200-series/' }
)

# =====================================================================
#  Библиотеки и среды выполнения (runtime). WingetList — набор пакетов
#  одним пунктом; Action='netfx3' — включение .NET 3.5 через DISM.
# =====================================================================
$Runtimes = @(
    @{ Name = 'Visual C++ Redist (2005-2022, x86+x64)'; WingetList = @(
            'Microsoft.VCRedist.2015+.x64', 'Microsoft.VCRedist.2015+.x86',
            'Microsoft.VCRedist.2013.x64', 'Microsoft.VCRedist.2013.x86',
            'Microsoft.VCRedist.2012.x64', 'Microsoft.VCRedist.2012.x86',
            'Microsoft.VCRedist.2010.x64', 'Microsoft.VCRedist.2010.x86',
            'Microsoft.VCRedist.2008.x64', 'Microsoft.VCRedist.2008.x86',
            'Microsoft.VCRedist.2005.x64', 'Microsoft.VCRedist.2005.x86') }
    @{ Name = '.NET Desktop Runtime 8 (LTS)';  Winget = 'Microsoft.DotNet.DesktopRuntime.8' }
    @{ Name = '.NET Desktop Runtime 6 (LTS)';  Winget = 'Microsoft.DotNet.DesktopRuntime.6' }
    @{ Name = '.NET Framework 3.5 (DISM)';     Action = 'netfx3' }
    @{ Name = 'DirectX End-User Runtime';      Winget = 'Microsoft.DirectX' }
    @{ Name = 'Edge WebView2 Runtime';         Winget = 'Microsoft.EdgeWebView2Runtime' }
    @{ Name = 'Windows App Runtime (WinUI 3)'; Winget = 'Microsoft.WindowsAppRuntime.1.5' }
    @{ Name = 'Java Temurin JRE 8';            Winget = 'EclipseAdoptium.Temurin.8.JRE' }
    @{ Name = 'Java Temurin JRE 17 (LTS)';     Winget = 'EclipseAdoptium.Temurin.17.JRE' }
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

# Установить один пункт: winget (Winget или WingetList), сайт (Url) или DISM
# (Action='netfx3'). Возвращает $true при успехе, $false при проблеме — для сводки.
function Install-Item {
    param($p)
    if ($p.Action -eq 'netfx3') {
        Write-Host "`n   .NET Framework 3.5 (DISM, тянет из Windows Update)..." -ForegroundColor Green
        DISM /Online /Enable-Feature /FeatureName:NetFx3 /All /NoRestart | Out-Null
        return ($LASTEXITCODE -eq 0)
    }
    if ($p.Yadisk) {
        Write-Host "`n   '$($p.Name)' — загрузка с Яндекс.Диска..." -ForegroundColor Green
        return (Get-YadiskFile -PublicUrl $p.Yadisk -Name $p.File)
    }
    $ids = if ($p.WingetList) { $p.WingetList } elseif ($p.Winget) { @($p.Winget) } else { @() }
    if ($ids.Count -and $HasWinget) {
        $ok = $true
        Write-Host "`n   Установка '$($p.Name)'..." -ForegroundColor Green
        foreach ($id in $ids) {
            Write-Host "    winget: $id" -ForegroundColor DarkGray
            winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements
            if ($LASTEXITCODE -ne 0) { $ok = $false }
        }
        return $ok
    }
    if ($p.Url) {
        Write-Host "`n   Открываю страницу загрузки '$($p.Name)' в браузере..." -ForegroundColor Yellow
        Start-Process $p.Url
        return $true
    }
    Write-Host "`n   Нет данных для установки '$($p.Name)'." -ForegroundColor Red
    return $false
}

# Скачать и запустить файл по публичной ссылке Яндекс.Диска. Свежая прямая
# ссылка берётся через публичный API (не протухает, авторизация не нужна).
function Get-YadiskFile {
    param([string]$PublicUrl, [string]$Name)
    try {
        $enc = [uri]::EscapeDataString($PublicUrl)
        if (-not $Name) { $Name = (Invoke-RestMethod -Uri "https://cloud-api.yandex.net/v1/disk/public/resources?public_key=$enc").name }
        $href = (Invoke-RestMethod -Uri "https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=$enc").href
        $out  = Join-Path ([Environment]::GetFolderPath('UserProfile')) "Downloads\$Name"
        Write-Host "   Скачивание '$Name' (несколько секунд)..." -ForegroundColor DarkGray
        # WebClient, а не Invoke-WebRequest: у IWR в PS 5.1 прогресс-бар тормозит
        # скачивание в разы. WebClient качает на полной скорости.
        $wc = New-Object System.Net.WebClient
        try { $wc.DownloadFile($href, $out) } finally { $wc.Dispose() }
        Write-Host "   Сохранено: $out — запускаю." -ForegroundColor Green
        Start-Process $out
        return $true
    } catch {
        Write-Host "   Ошибка загрузки с Яндекс.Диска: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Лог действий в файл (для истории/акта на объекте).
function Write-Log {
    param([string]$Message)
    try { ("{0}  {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message) |
        Out-File -FilePath $LogFile -Append -Encoding utf8 -ErrorAction SilentlyContinue } catch {}
}

# Точка восстановления перед разрушающими действиями. Нужен админ;
# система сама троттлит создание (обычно раз в ~24 ч) — это нормально.
function Add-RestorePoint {
    param([string]$Description = 'HH Toolbox')
    if (-not (Test-Admin)) { return }
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description $Description -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Host "   Точка восстановления создана." -ForegroundColor DarkGray
    } catch {
        Write-Host "   Точку восстановления создать не удалось (пропуск)." -ForegroundColor DarkYellow
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
    param([string]$Title, [string[]]$Items, [string]$Color = 'Yellow', [bool]$DefaultChecked = $true, [hashtable]$Headers = $null)

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
            if ($Headers -and $Headers.ContainsKey($i)) {
                Write-Host ("   ── " + $Headers[$i] + " ──") -ForegroundColor DarkCyan
            }
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

    Add-RestorePoint 'Перед лёгкой чисткой (HH Toolbox)'
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
    $expl   = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'
    $cab    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\CabinetState'
    $cdm    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    $desk   = 'HKCU:\Control Panel\Desktop'
    $vfx    = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    $wmet   = 'HKCU:\Control Panel\Desktop\WindowMetrics'

    $tweaks = @(
        @{ Label = 'Показывать расширения файлов';            Do = { Set-ItemProperty $adv -Name HideFileExt -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Показывать скрытые файлы';                Do = { Set-ItemProperty $adv -Name Hidden -Value 1 -ErrorAction SilentlyContinue } }
        @{ Label = 'Тёмная тема оформления';                  Do = { Set-ItemProperty $theme -Name AppsUseLightTheme -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty $theme -Name SystemUsesLightTheme -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Классическое контекстное меню (Win11)';   Do = { New-Item -Path $clsid -Force | Out-Null; Set-ItemProperty $clsid -Name '(default)' -Value '' -ErrorAction SilentlyContinue } }
        @{ Label = 'Отключить веб-поиск Bing в меню Пуск';    Do = { Set-ItemProperty $search -Name BingSearchEnabled -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty $search -Name CortanaConsent -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Панель задач: значки слева (Win11)';      Do = { Set-ItemProperty $adv -Name TaskbarAl -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Скрыть кнопку «Виджеты» (Win11)';         Do = { Set-ItemProperty $adv -Name TaskbarDa -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Проводник открывать на «Этот компьютер»'; Do = { Set-ItemProperty $adv -Name LaunchTo -Value 1 -ErrorAction SilentlyContinue } }
        @{ Label = 'Полный путь в заголовке проводника';      Do = { New-Item -Path $cab -Force | Out-Null; Set-ItemProperty $cab -Name FullPath -Value 1 -ErrorAction SilentlyContinue } }
        @{ Label = 'Секунды в часах панели задач';            Do = { Set-ItemProperty $adv -Name ShowSecondsInSystemClock -Value 1 -ErrorAction SilentlyContinue } }
        @{ Label = 'Убрать поиск с панели задач (Win11)';     Do = { Set-ItemProperty $search -Name SearchboxTaskbarMode -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Скрыть кнопку «Чат» (Win11)';             Do = { Set-ItemProperty $adv -Name TaskbarMn -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Чистый «Быстрый доступ» (без недавних)';  Do = { Set-ItemProperty $expl -Name ShowRecent -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty $expl -Name ShowFrequent -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Отключить прозрачность';                  Do = { Set-ItemProperty $theme -Name EnableTransparency -Value 0 -ErrorAction SilentlyContinue } }
        @{ Label = 'Убрать рекомендации/рекламу Windows';     Do = {
                Set-ItemProperty $adv -Name Start_IrisRecommendations -Value 0 -ErrorAction SilentlyContinue
                foreach ($n in 'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-353694Enabled', 'SystemPaneSuggestionsEnabled', 'SilentInstalledAppsEnabled') {
                    Set-ItemProperty $cdm -Name $n -Value 0 -ErrorAction SilentlyContinue
                }
            } }
        @{ Label = 'Эффекты: быстродействие (кроме шрифтов/эскизов/перетаскивания)'; Do = {
                Set-ItemProperty $vfx  -Name VisualFXSetting -Value 3 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty $desk -Name UserPreferencesMask -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -Type Binary -ErrorAction SilentlyContinue
                Set-ItemProperty $wmet -Name MinAnimate -Value '0' -Type String -ErrorAction SilentlyContinue
                Set-ItemProperty $adv  -Name ListviewAlphaSelect -Value 0 -ErrorAction SilentlyContinue
                Set-ItemProperty $adv  -Name ListviewShadow -Value 0 -ErrorAction SilentlyContinue
                Set-ItemProperty $adv  -Name TaskbarAnimations -Value 0 -ErrorAction SilentlyContinue
                # исключения — оставляем включёнными:
                Set-ItemProperty $desk -Name DragFullWindows -Value '1' -Type String -ErrorAction SilentlyContinue    # содержимое окна при перетаскивании
                Set-ItemProperty $desk -Name FontSmoothing -Value '2' -Type String -ErrorAction SilentlyContinue      # сглаживание шрифтов
                Set-ItemProperty $desk -Name FontSmoothingType -Value 2 -Type DWord -ErrorAction SilentlyContinue
                Set-ItemProperty $adv  -Name IconsOnly -Value 0 -ErrorAction SilentlyContinue                         # эскизы вместо значков
            } }
    )

    $sel = Show-CheckList 'Базовые твики — отметь пункты' @($tweaks | ForEach-Object { $_.Label })
    if ($null -eq $sel)   { Write-Host "`n   Отменено." -ForegroundColor DarkGray; return }
    if ($sel.Count -eq 0) { Write-Host "`n   Ничего не выбрано." -ForegroundColor DarkGray; return }

    Add-RestorePoint 'Перед твиками (HH Toolbox)'
    Write-Host "`n   Применяю..." -ForegroundColor DarkGray
    foreach ($idx in $sel) {
        & $tweaks[$idx].Do
        Write-Host "   - $($tweaks[$idx].Label)" -ForegroundColor DarkGray
    }
    Write-Host "`n   Перезапуск проводника для применения..." -ForegroundColor DarkGray
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer
    Write-Host "   Готово. Часть эффектов применится после перезахода в систему." -ForegroundColor Green
}

# =====================================================================
#  Подменю: установка программ
# =====================================================================
function Show-ProgramMenu {
    # Метки: пункты без winget откроют сайт загрузки — помечаем «(сайт)»
    $labels = @($Programs | ForEach-Object {
        if ($HasWinget -and $_.Winget) { $_.Name }
        elseif ($_.Yadisk) { $_.Name + '  (Я.Диск)' }
        else { $_.Name + '  (сайт)' }
    })
    # Заголовки групп: у стартовой записи каждой группы задано поле Group
    $headers = @{}
    for ($i = 0; $i -lt $Programs.Count; $i++) { if ($Programs[$i].Group) { $headers[$i] = $Programs[$i].Group } }
    $sel = Show-CheckList 'Установка программ — отметь нужное' $labels 'Magenta' $false $headers
    if ($null -eq $sel)   { return }
    if ($sel.Count -eq 0) { Write-Host "`n   Ничего не выбрано." -ForegroundColor DarkGray; Wait-Continue; return }

    $ok = 0; $bad = 0
    foreach ($idx in $sel) { if (Install-Item $Programs[$idx]) { $ok++ } else { $bad++ } }
    Write-Host ("`n   Готово: успешно {0}, с проблемами {1} (уже стоит/ошибка — см. вывод выше)." -f $ok, $bad) -ForegroundColor Green
    Wait-Continue
}

function Show-RuntimeMenu {
    if (-not (Test-Admin)) {
        Write-Box 'Библиотеки и среды выполнения' 'Magenta'
        Write-Host "   Установка библиотек требует прав администратора." -ForegroundColor Yellow
        Write-Host "   Лучше выйти и запустить [A].`n" -ForegroundColor Yellow
        if ((Read-Host "   Продолжить всё равно? (y/n)").Trim().ToLower() -ne 'y') { return }
    }
    $labels = @($Runtimes | ForEach-Object { $_.Name })
    $sel = Show-CheckList 'Библиотеки и среды выполнения — отметь нужное' $labels 'Magenta' $true
    if ($null -eq $sel)   { return }
    if ($sel.Count -eq 0) { Write-Host "`n   Ничего не выбрано." -ForegroundColor DarkGray; Wait-Continue; return }

    $ok = 0; $bad = 0
    foreach ($idx in $sel) { if (Install-Item $Runtimes[$idx]) { $ok++ } else { $bad++ } }
    Write-Host ("`n   Готово: успешно {0}, с проблемами {1} (уже стоит/ошибка — см. выше)." -f $ok, $bad) -ForegroundColor Green
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
    Add-RestorePoint 'Перед обновлением драйверов (HH Toolbox)'
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

    Add-RestorePoint 'Перед настройкой Новый ПК (HH Toolbox)'
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

function Read-CamBitrate {
    # Возвращает битрейт в Kbps (как поле Bit Rate у Dahua).
    Write-Host "   Битрейт: [1] по разрешению+кодеку   [2] ввести вручную (Kbps)" -ForegroundColor Gray
    if ((Read-Host "   Выбор [1]").Trim() -eq '2') { return Read-Number 'Битрейт, Kbps' 4096 }

    Write-Host "   Разрешение:" -ForegroundColor Gray
    Write-Host "    [1] 2 МП / 1080p   [2] 4 МП   [3] 5 МП   [4] 6 МП   [5] 8 МП / 4K"
    switch ((Read-Host "   Выбор [1]").Trim()) {   # база — H.264, Kbps
        '2'     { $h264 = 6144 }
        '3'     { $h264 = 8192 }
        '4'     { $h264 = 10240 }
        '5'     { $h264 = 12288 }
        default { $h264 = 4096 }
    }
    Write-Host "   Кодек: [1] H.264   [2] H.265 (x0.5)   [3] H.265+ (x0.25)" -ForegroundColor Gray
    switch ((Read-Host "   Выбор [1]").Trim()) {
        '2'     { return [math]::Round($h264 / 2) }
        '3'     { return [math]::Round($h264 / 4) }
        default { return $h264 }
    }
}

function Show-StorageCalc {
    Write-Box 'Калькулятор диска (модель Dahua)' 'Cyan'
    $cams  = Read-Number 'Кол-во камер (каналов)' 1
    $kbps  = Read-CamBitrate
    $hours = Read-Number 'Часов записи в сутки (24 = круглосуточно)' 24
    $factor = 1.0
    if ((Read-Host "   Запись: [1] постоянно (по умолч.)  [2] по движению").Trim() -eq '2') {
        $factor = (Read-Number 'Активность, %' 30) / 100.0
    }

    $mbps     = $kbps / 1000.0
    $K        = 0.476875                            # ГБ на (Mbps*ч) — как у Dahua (~10% запас + бинарный ГБ)
    $gbCamDay = $mbps * $K * $hours * $factor         # ГБ/сутки на камеру
    $gbAllDay = $gbCamDay * $cams                      # ГБ/сутки всего
    $bwMbps   = $mbps * $cams                           # суммарный битрейт (Bandwidth)
    if ($gbAllDay -le 0) { Write-Host "`n   Некорректные данные." -ForegroundColor Red; return }

    Write-Host "`n   Что посчитать:" -ForegroundColor Gray
    Write-Host "    [1] Сколько диска нужно на N дней   [по умолч.]"
    Write-Host "    [2] На сколько дней хватит диска"
    $mode = (Read-Host "   Выбор [1]").Trim()
    if ($mode -eq '2') { $tb = Read-Number 'Объём диска, ТБ' 4 }
    else               { $days = Read-Number 'Срок хранения, дней' 30 }

    Write-Host ""
    Write-Kv 'Битрейт/камера:' ("{0:N0} Kbps ({1:N2} Mbps)" -f $kbps, $mbps)
    Write-Kv 'Bandwidth:'      ("{0:N1} Mbps (всего по {1:N0} камерам)" -f $bwMbps, $cams)
    Write-Kv 'Расход:'         ("{0:N1} ГБ/сутки/камера, {1:N1} ГБ/сутки всего" -f $gbCamDay, $gbAllDay)
    if ($mode -eq '2') {
        $d = [math]::Floor(($tb * 1024) / $gbAllDay)
        Write-Kv 'Хватит на:'   ("{0:N0} дней  (~{1:N1} мес.)" -f $d, ($d / 30))
    } else {
        $gb = $gbAllDay * $days
        Write-Kv 'Нужно диска:' ("{0:N1} ГБ  (~{1:N2} ТБ)" -f $gb, ($gb / 1024))
    }
    Write-Host "`n   Коэффициент и запас как в калькуляторе Dahua (~10% + бинарный ТБ)." -ForegroundColor DarkGray
    Write-Host "   Реальные цифры зависят от сцены и кодека." -ForegroundColor DarkGray
}

# =====================================================================
#  Утилиты: WinUtil / Win11Debloat / Sophia
# =====================================================================
function Show-UtilityMenu {
    do {
        Write-Box 'Утилиты: debloat и твики' 'Magenta'
        Write-Host "   [1] " -NoNewline -ForegroundColor Green; Write-Host "WinUtil (Chris Titus)"
        Write-Host "   [2] " -NoNewline -ForegroundColor Green; Write-Host "Win11Debloat (Raphire)"
        Write-Host "   [3] " -NoNewline -ForegroundColor Green; Write-Host "SophiApp (GUI, галочки)"
        Write-Host "   [4] " -NoNewline -ForegroundColor Green; Write-Host "Sophia Script (PowerShell)"
        Write-Host "   [0] " -NoNewline -ForegroundColor Red;   Write-Host "Назад"
        Write-Host ""
        switch ((Read-Host "  Выбор").Trim()) {
            '1' { Invoke-Remote 'https://christitus.com/win'; Wait-Continue }
            '2' { Invoke-Remote 'https://debloat.raphi.re/';  Wait-Continue }
            '3' { $null = Install-Item @{ Name = 'SophiApp';      Winget = 'TeamSophia.SophiApp';    Url = 'https://github.com/Sophia-Community/SophiApp/releases' }; Wait-Continue }
            '4' { $null = Install-Item @{ Name = 'Sophia Script'; Winget = 'TeamSophia.SophiaScript'; Url = 'https://github.com/farag2/Sophia-Script-for-Windows/releases' }; Wait-Continue }
            '0' { return }
            default { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1 }
        }
    } while ($true)
}

# =====================================================================
#  Проверка и восстановление системных файлов (DISM + SFC)
# =====================================================================
function Repair-System {
    Write-Box 'Проверка и восстановление системы' 'Yellow'
    if (-not (Test-Admin)) {
        Write-Host "   Требуются права администратора — выйди и запусти [A]." -ForegroundColor Yellow
        return
    }
    Write-Host "   Будут запущены DISM /RestoreHealth и sfc /scannow." -ForegroundColor Gray
    Write-Host "   Может занять 10-30 минут, нужен интернет. Не закрывай окно.`n" -ForegroundColor Gray
    if ((Read-Host "   Начать? (y/n)").Trim().ToLower() -ne 'y') { return }

    Write-Host "`n   [1/2] DISM /Online /Cleanup-Image /RestoreHealth ..." -ForegroundColor Cyan
    DISM /Online /Cleanup-Image /RestoreHealth
    Write-Host "`n   [2/2] sfc /scannow ..." -ForegroundColor Cyan
    sfc /scannow
    Write-Host "`n   Готово. Если остались ошибки — перезагрузи ПК и запусти повторно." -ForegroundColor Green
}

function Invoke-WingetUpgrade {
    if ($HasWinget) {
        Write-Host "`n   Обновление всего установленного софта..." -ForegroundColor Green
        winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements
    } else { Write-Host "`n   winget не найден." -ForegroundColor Yellow }
}

# =====================================================================
#  ГЛАВНОЕ МЕНЮ — описание данными. Добавить пункт = одна строка ниже;
#  номера проставляются автоматически, перенумерация не нужна.
#  Поля: Section — заголовок; Label + Action — пункт; Admin=$true — нужен
#  админ (предложит перезапуск); Color — цвет номера.
# =====================================================================
$Menu = @(
    @{ Section = 'Диагностика и сеть' }
    @{ Label = 'Информация о ПК';                                 Action = { Show-PCInfo; Wait-Continue } }
    @{ Label = 'Сетевые утилиты (DNS, ping, сброс сети)';         Action = { Show-NetworkMenu } }
    @{ Label = 'Калькулятор диска для камер (модель Dahua)';      Action = { Show-StorageCalc; Wait-Continue } }
    @{ Label = 'Стресс-тест ПК (CPU-прожиг + OCCT/FurMark/диск)'; Action = { Invoke-Remote 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/stresstest.ps1'; Wait-Continue } }
    @{ Section = 'Программы' }
    @{ Label = 'Установить программы (галочками)';                Action = { Show-ProgramMenu } }
    @{ Label = 'Обновить весь софт (winget upgrade)';            Action = { Invoke-WingetUpgrade; Wait-Continue } }
    @{ Label = 'Утилиты: WinUtil / Win11Debloat / Sophia';        Action = { Show-UtilityMenu } }
    @{ Label = 'Библиотеки и среды выполнения (галочками)';       Action = { Show-RuntimeMenu } }
    @{ Section = 'Обслуживание Windows' }
    @{ Label = 'Лёгкая чистка (лишнее + TEMP + DNS)';            Action = { Invoke-LightClean; Wait-Continue }; Admin = $true }
    @{ Label = 'Базовые твики (расширения, тёмная тема, меню)';  Action = { Invoke-LightTweak; Wait-Continue } }
    @{ Label = 'Проверка/восстановление системы (DISM + SFC)';   Action = { Repair-System; Wait-Continue }; Admin = $true }
    @{ Label = 'Обновление драйверов (Dell/HP/Lenovo/Intel)';    Action = { Invoke-DriverUpdate; Wait-Continue }; Admin = $true }
    @{ Section = 'Установка и активация' }
    @{ Label = 'MAS — активация Windows / Office';               Action = { Invoke-Remote 'https://get.activated.win'; Wait-Continue } }
    @{ Label = 'Новый ПК — первичная настройка';                Action = { Invoke-NewPC; Wait-Continue }; Admin = $true; Color = 'Magenta' }
)

# Рендер меню: печатает секции и авто-номера, возвращает карту «номер -> пункт».
function Show-Menu {
    Clear-Host
    $mode = if (Test-Admin) { 'АДМИН' } else { 'обычный пользователь' }
    Write-Host ""
    Write-Host "  ╔════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║                  HH Toolbox                ║" -ForegroundColor Cyan
    Write-Host "  ╚════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host "   Режим: $mode · v$Version`n" -ForegroundColor DarkGray

    $map = @{}
    $num = 0
    $first = $true
    foreach ($e in $Menu) {
        if ($e.Section) {
            if (-not $first) { Write-Host "" }
            Write-Host "  ━━ $($e.Section) ━━" -ForegroundColor DarkCyan
            $first = $false
            continue
        }
        $num++
        $map["$num"] = $e
        $col = if ($e.Color) { $e.Color } else { 'Green' }
        $pad = if ($num -lt 10) { "[$num]  " } else { "[$num] " }
        Write-Host "   $pad" -NoNewline -ForegroundColor $col
        Write-Host $e.Label
    }
    Write-Host ""
    Write-Host "   [A]  " -NoNewline -ForegroundColor Yellow; Write-Host "Перезапустить от имени администратора"
    Write-Host "   [0]  " -NoNewline -ForegroundColor Red;    Write-Host "Выход"
    Write-Host ""
    return $map
}

do {
    $map = Show-Menu
    $choice = (Read-Host "  Выбор").Trim().ToUpper()
    if ($choice -eq '0') { break }
    if ($choice -eq 'A') { Invoke-AdminRestart; continue }
    $item = $map[$choice]
    if (-not $item) { Write-Host "`n  Неверный выбор." -ForegroundColor Yellow; Start-Sleep 1; continue }

    if ($item.Admin -and -not (Test-Admin)) {
        Write-Host "`n  Пункт «$($item.Label)» требует прав администратора." -ForegroundColor Yellow
        if ((Read-Host "  Перезапустить меню от админа? (y/n)").Trim().ToLower() -eq 'y') { Invoke-AdminRestart }
    }
    Write-Log "Запуск: $($item.Label)"
    & $item.Action
} while ($true)

Write-Host "`n  Готово. До встречи!`n" -ForegroundColor Cyan
