# =====================================================================
#  HH Script — универсальный лаунчер
#  Запуск:  irm get.hhtdom.ru | iex
# =====================================================================

# --- Ссылка, по которой запускается это меню (для перезапуска от админа).
$LauncherUrl = 'https://get.hhtdom.ru'
$GuiUrl      = 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/gui.ps1'

# --- Совместимость со старыми системами + кириллица ------------------
try { [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { $null = $_ }
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { $null = $_ }

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
    @{ Group = 'Удалёнка / доступ'; Name = 'AnyDesk';              Winget = 'AnyDesk.AnyDesk';                  Url = 'https://anydesk.com/download' }
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
    @{ Name = 'Glow (анализ системы)'; Yadisk = 'https://disk.yandex.ru/d/yOWdlEZZlBDysw' }
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
    @{ Name = 'Dahua SmartPSS Lite';  Yadisk = 'https://disk.yandex.ru/d/5B04_1OvSR7ChQ' }
    @{ Name = 'SADP (Hikvision)';     Yadisk = 'https://disk.yandex.ru/d/E8HX0NivegXgRQ' }
    @{ Name = 'HiTools Delivery (Hikvision)'; Yadisk = 'https://disk.yandex.ru/d/3LJjK0CS-HZqwQ' }
    @{ Name = 'iVMS-4200 (Hikvision)'; Yadisk = 'https://disk.yandex.ru/d/U8nd7S3DwH8mtw' }
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
        # TrimStart: irm отдаёт BOM файла как символ U+FEFF (Encoding.GetString его
        # не срезает), и тогда iex падает на первом же токене. Чужие скрипты с BOM
        # нам не подконтрольны, поэтому чистим здесь.
        Invoke-Expression ([string](Invoke-RestMethod -Uri $Url)).TrimStart([char]0xFEFF)
    } catch {
        Write-Host "`n  Ошибка: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- Автоустановка winget (App Installer), если его нет --------------
# На чистой/LTSC Windows winget часто отсутствует и установки молча падают.
# Confirm-Winget вызывается перед winget-операциями: один раз за сеанс пытается
# поставить App Installer и обновляет $HasWinget. На системах без Appx-подсистемы
# (Server Core, часть LTSC) честно вернёт $false — вызвавший код уйдёт на Url/сайт.
$script:WingetTried = $false
function Install-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }

    # Архитектура ОС (для пакетов зависимостей). Именно ОС, а не процесса:
    # 32-битный PowerShell на x64 всё равно должен ставить x64-зависимости.
    $arch = if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -match 'ARM64') { 'arm64' }
    elseif ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }

    # 1) App Installer есть в системе, но не зарегистрирован для пользователя.
    try {
        $pkg = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($pkg -and $pkg.InstallLocation) {
            Add-AppxPackage -DisableDevelopmentMode -Register (Join-Path $pkg.InstallLocation 'AppXManifest.xml') -ErrorAction Stop
            if (Get-Command winget -ErrorAction SilentlyContinue) { return $true }
        }
    } catch { Write-Host "   (перерегистрация App Installer не помогла: $($_.Exception.Message))" -ForegroundColor DarkGray }

    # 2) Скачать App Installer с зависимостями и поставить. Ошибки НЕ глушим —
    #    иначе на объекте не понять, почему не встал.
    $tmp = Join-Path $env:TEMP 'hh-winget'
    try { New-Item -ItemType Directory -Force -Path $tmp | Out-Null } catch { $null = $_ }
    $wc  = New-Object System.Net.WebClient
    $get = {
        param($url, $file)
        $dst = Join-Path $tmp $file
        $wc.DownloadFile($url, $dst)
        return $dst
    }.GetNewClosure()

    # Зависимости: VCLibs (обязателен) + UI.Xaml 2.8 (нужен новым сборкам).
    $deps = @(
        @{ Url = "https://aka.ms/Microsoft.VCLibs.$arch.14.00.Desktop.appx"; File = 'vclibs.appx' }
        @{ Url = "https://github.com/microsoft/microsoft-ui-xaml/releases/download/v2.8.6/Microsoft.UI.Xaml.2.8.$arch.appx"; File = 'xaml.appx' }
    )
    foreach ($d in $deps) {
        try { Add-AppxPackage -Path (& $get $d.Url $d.File) -ErrorAction Stop }
        catch { Write-Host "   Зависимость $($d.File): $($_.Exception.Message)" -ForegroundColor DarkGray }
    }

    # Сам App Installer (msixbundle с официального редиректа aka.ms/getwinget).
    $bundle = $null
    try { $bundle = & $get 'https://aka.ms/getwinget' 'winget.msixbundle' }
    catch { Write-Host "   Не удалось скачать App Installer: $($_.Exception.Message)" -ForegroundColor Red; return $false }
    try {
        Add-AppxPackage -Path $bundle -ErrorAction Stop
    } catch {
        Write-Host "   Установка для пользователя не удалась: $($_.Exception.Message)" -ForegroundColor Yellow
        # Fallback: провизионинг для всех пользователей (нужен админ; надёжнее в elevated).
        if (Test-Admin) {
            try {
                Write-Host "   Пробую установить для всех (провизионинг, DISM)..." -ForegroundColor DarkGray
                Add-AppxProvisionedPackage -Online -PackagePath $bundle -SkipLicense -ErrorAction Stop | Out-Null
            } catch { Write-Host "   Провизионинг не удался: $($_.Exception.Message)" -ForegroundColor Red }
        }
    }

    # winget.exe появляется alias-ом в WindowsApps — добавим в PATH текущего сеанса,
    # чтобы Get-Command нашёл его без перезапуска PowerShell.
    $wa = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps'
    if (($env:Path -split ';') -notcontains $wa) { $env:Path = "$env:Path;$wa" }
    return [bool](Get-Command winget -ErrorAction SilentlyContinue)
}

# Гарантировать winget перед winget-операцией. Возвращает $true, если доступен.
function Confirm-Winget {
    if (Get-Command winget -ErrorAction SilentlyContinue) { $script:HasWinget = $true; return $true }
    if ($script:WingetTried) { return $false }   # уже пробовали в этом сеансе — не долбим
    $script:WingetTried = $true
    Write-Host "`n   winget не найден — пробую установить App Installer..." -ForegroundColor Yellow
    $ok = Install-Winget
    $script:HasWinget = $ok
    if ($ok) { Write-Host "   winget установлен." -ForegroundColor Green }
    else { Write-Host "   Не удалось поставить winget. Где возможно — установлю через сайт." -ForegroundColor Yellow }
    return $ok
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
    if ($ids.Count -and (Confirm-Winget)) {
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
        Out-File -FilePath $LogFile -Append -Encoding utf8 -ErrorAction SilentlyContinue } catch { $null = $_ }
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
    param([string]$Key, [string]$Value, [int]$Width = 16)
    Write-Host ("   {0,-$Width}" -f $Key) -NoNewline -ForegroundColor Gray
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

# Скачать (если нужно), распаковать и запустить Glow — портейбл-анализатор ПК.
# Отчёт сохраняется ИЗ интерфейса Glow (HTML / TXT / Markdown); CLI-экспорта у
# него нет, поэтому автоматически html-файл не создаём — Glow это делает кнопкой.
function Invoke-Glow {
    $url  = 'https://disk.yandex.ru/d/yOWdlEZZlBDysw'   # тот же архив, что в списке программ
    $dir  = Join-Path $env:LOCALAPPDATA 'HHToolbox\Glow'
    $arch = if ($env:PROCESSOR_ARCHITECTURE -match 'ARM64' -or $env:PROCESSOR_ARCHITEW6432 -match 'ARM64') { 'arm64' } else { 'x64' }
    $exe  = Get-ChildItem $dir -Recurse -Filter "Glow_$arch.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Host "`n   Скачиваю Glow с Яндекс.Диска..." -ForegroundColor Green
        try {
            $enc  = [uri]::EscapeDataString($url)
            $href = (Invoke-RestMethod "https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key=$enc").href
            $zip  = Join-Path $env:TEMP 'glow.zip'
            $wc = New-Object System.Net.WebClient
            try { $wc.DownloadFile($href, $zip) } finally { $wc.Dispose() }
            Expand-Archive -Path $zip -DestinationPath $dir -Force
            Remove-Item $zip -Force -ErrorAction SilentlyContinue
            $exe = Get-ChildItem $dir -Recurse -Filter "Glow_$arch.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
        } catch { Write-Host "   Ошибка загрузки Glow: $($_.Exception.Message)" -ForegroundColor Red; return }
    }
    if ($exe) {
        Write-Host "   Запускаю Glow. Внутри — сохранение отчёта в HTML (или TXT/Markdown)." -ForegroundColor Cyan
        Start-Process $exe.FullName
    } else {
        Write-Host "   Glow не найден после распаковки." -ForegroundColor Yellow
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
    $rowOf = @{}      # индекс пункта -> строка консоли (для точечной перерисовки)

    $interactive = $true
    try { $null = [Console]::KeyAvailable } catch { $interactive = $false }

    # Перерисовать ОДНУ строку пункта на её месте (без очистки экрана) — быстро.
    function DrawRow ($i) {
        if ($rowOf.ContainsKey($i)) { try { [Console]::SetCursorPosition(0, [int]$rowOf[$i]) } catch { $null = $_ } }
        $w    = try { [Console]::WindowWidth - 1 } catch { 70 }
        $mark = if ($state[$i]) { '[x]' } else { '[ ]' }
        if ($i -eq $cur) {
            Write-Host (("   > $mark " + $Items[$i]).PadRight($w)) -ForegroundColor Black -BackgroundColor Gray
        } else {
            $col = if ($state[$i]) { 'Green' } else { 'Gray' }
            Write-Host (("       $mark " + $Items[$i]).PadRight($w)) -ForegroundColor $col
        }
    }

    # Полная отрисовка списка (первый раз и после «A»).
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
            if ($interactive) {
                $rowOf[$i] = [Console]::CursorTop
                DrawRow $i
            } else {
                $mark = if ($state[$i]) { '[x]' } else { '[ ]' }
                $col  = if ($state[$i]) { 'Green' } else { 'Gray' }
                $num  = '{0,2}. ' -f ($i + 1)
                Write-Host ("   $num$mark " + $Items[$i]) -ForegroundColor $col
            }
        }
        if ($interactive) { $rowOf['end'] = [Console]::CursorTop }
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

    # Один полный Draw, дальше — только изменившиеся строки (нет мигания/лага).
    $prevCur = $true
    try { $prevCur = [Console]::CursorVisible } catch { $null = $_ }
    try {
        try { [Console]::CursorVisible = $false } catch { $null = $_ }
        Draw
        while ($true) {
            $k = [Console]::ReadKey($true)
            switch ($k.Key) {
                'UpArrow'   { $old = $cur; $cur = ($cur - 1 + $n) % $n; DrawRow $old; DrawRow $cur }
                'DownArrow' { $old = $cur; $cur = ($cur + 1) % $n; DrawRow $old; DrawRow $cur }
                'Spacebar'  { $state[$cur] = -not $state[$cur]; DrawRow $cur }
                'Enter'     { return ,@(0..($n - 1) | Where-Object { $state[$_] }) }
                'Escape'    { return $null }
                default {
                    $ch = ([string]$k.KeyChar).ToLower()
                    if ($ch -eq 'a' -or $ch -eq 'а') {
                        $allOn = -not ($state -contains $false)
                        for ($i = 0; $i -lt $n; $i++) { $state[$i] = -not $allOn }
                        Draw
                    }
                }
            }
        }
    } finally {
        try { [Console]::CursorVisible = $prevCur } catch { $null = $_ }
        if ($rowOf.ContainsKey('end')) { try { [Console]::SetCursorPosition(0, [int]$rowOf['end']) } catch { $null = $_ } }
        Write-Host ""
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
    if (-not (Confirm-Winget)) { Write-Host "   Нужен winget для Dell Command Update." -ForegroundColor Yellow; return }
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
    if (-not (Confirm-Winget)) { Write-Host "   Нужен winget для HP Image Assistant." -ForegroundColor Yellow; return }
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
    if (-not (Confirm-Winget)) { Write-Host "   Нужен winget для Lenovo Thin Installer." -ForegroundColor Yellow; return }
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
    if (-not (Confirm-Winget)) { Write-Host "   Нужен winget для Intel DSA." -ForegroundColor Yellow; return }
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
    if (Confirm-Winget) {
        foreach ($id in 'Google.Chrome', '7zip.7zip', 'AnyDesk.AnyDesk') {
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

function Read-NumberInRange {
    param([string]$Prompt, [double]$Default, [double]$Min, [double]$Max)
    while ($true) {
        $v = Read-Number $Prompt $Default
        if ($v -ge $Min -and $v -le $Max) { return $v }
        Write-Host ("   Допустимо {0}-{1} — повтори." -f $Min, $Max) -ForegroundColor DarkYellow
    }
}

function Read-Option {
    param([string]$Prompt, [string[]]$Options, [int]$DefaultIndex = 0)
    Write-Host "   $Prompt" -ForegroundColor Gray
    $line = ''
    for ($i = 0; $i -lt $Options.Count; $i++) {
        $line += ('[{0}] {1}   ' -f ($i + 1), $Options[$i])
        if (($i + 1) % 4 -eq 0) { Write-Host "    $line"; $line = '' }
    }
    if ($line -ne '') { Write-Host "    $line" }
    $in = (Read-Host ("   Выбор [{0}]" -f ($DefaultIndex + 1))).Trim()
    if ($in -eq '') { return $Options[$DefaultIndex] }
    $n = 0
    if ([int]::TryParse($in, [ref]$n) -and $n -ge 1 -and $n -le $Options.Count) { return $Options[$n - 1] }
    Write-Host "   Неверный выбор — беру $($Options[$DefaultIndex])" -ForegroundColor DarkYellow
    return $Options[$DefaultIndex]
}

# ---------------------------------------------------------------------
#  Движок калькулятора Dahua Disk & Bandwidth (Basic Mode).
#  Формулы сняты с официального калькулятора, а не подобраны:
#  dhtools.dahuasecurity.com/DiskBandwidthCalculator/#/basic
# ---------------------------------------------------------------------
$script:DahuaBase = [ordered]@{      # базовый битрейт по разрешению, Kbps
    'D1' = 1024; '720P' = 2048; '960P' = 2048; '1080P' = 4096; '3MP' = 4096; '4MP' = 5120
    '5MP' = 6144; '6MP' = 6144; '8MP' = 8192; '9MP' = 8192; '12MP' = 12288
}
$script:DahuaMin = @{                # минимальный битрейт по разрешению, Kbps
    'D1' = 128; '720P' = 384; '960P' = 384; '1080P' = 384; '3MP' = 640; '4MP' = 768
    '5MP' = 1024; '6MP' = 1152; '8MP' = 1536; '9MP' = 1536; '12MP' = 2304
}

function Get-DahuaBitRate {
    param(
        [string]$Resolution,
        [double]$FrameRate,
        [string]$VideoStandard = 'PAL',
        [string]$Compression   = 'H.264',
        [double]$Environment   = 0.5
    )
    $base = $script:DahuaBase[$Resolution]
    if (-not $base) { return 0 }

    $n = if ($VideoStandard -eq 'NTSC') { 30 } else { 25 }   # опорная частота стандарта
    $s = $FrameRate
    if ($Resolution -in @('D1', 'VGA', 'CIF')) { $s = [math]::Min([double]$FrameRate, [double]$n) }

    $u = [math]::Pow(0.8, 1 / ($n - 1))
    $m = $base / 6.4                                          # 6.4 = 8 * 0.8
    $f = 20 * $m / (9 + 2 * $n)
    $g = $f / 10

    if ($s -ge 25 -and $s -le 30) {
        $b = $f / 2 + $g * $n - $g / 2
        $d = 0.8                                              # == u^(n-1)
    } else {
        $b = $f / 2 + $g * $s - $g / 2
        $d = [math]::Pow($u, $s - 1)
    }
    $m = 8 * $b * $d

    switch ($Compression) {
        'H.265'       { $m = $m / 2 }
        'SmartH.264+' { $m = $m * $Environment }
        'SmartH.265+' { $m = $m / 2 * $Environment }
    }
    # округление вверх до кратного 256 — оригинал делает (m + 255) & ~255
    return [int](([int][math]::Truncate($m) + 255) -band -256)
}

function Get-DahuaStorageKB {
    param([double]$BitRateKbps, [double]$HoursPerDay, [double]$Days)
    return $BitRateKbps * $HoursPerDay * $Days * 3600 / 8 / 0.9   # 0.9 — заложенный Dahua запас 10%
}

function Get-DahuaDays {
    param([double]$BitRateKbps, [double]$HoursPerDay, [double]$DiskKB)
    if ($BitRateKbps -le 0 -or $HoursPerDay -le 0) { return 0 }
    return [int][math]::Floor($DiskKB * 0.9 * 8 / $BitRateKbps / 3600 / $HoursPerDay)
}

function Format-DahuaSize {
    # Единицы как на сайте: деление на 1024 и округление вверх до 0.1.
    param([double]$Value, [switch]$Bandwidth)
    $units = if ($Bandwidth) { @('Kbps', 'Mbps', 'Gbps', 'Tbps', 'Pbps', 'Ebps') }
             else            { @('KB', 'MB', 'GB', 'TB', 'PB', 'EB') }
    $i = 0
    while ($Value -gt 1024 -and $i -lt 5) { $Value = $Value / 1024; $i++ }
    $v = [math]::Ceiling($Value * 10) / 10
    return ([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.#} {1}', $v, $units[$i]))
}

function Show-StorageCalc {
    Write-Box 'Калькулятор диска Dahua (Basic)' 'Cyan'

    $channels = [int](Read-NumberInRange 'Кол-во каналов' 1 1 1024)
    $std      = Read-Option 'Стандарт:'   @('PAL', 'NTSC') 0
    $res      = Read-Option 'Разрешение:' @($script:DahuaBase.Keys) 3
    $codec    = Read-Option 'Кодек:'      @('H.264', 'H.265', 'SmartH.264+', 'SmartH.265+') 1

    $envFactor = 0.5
    if ($codec -like 'Smart*') {                     # на прочие кодеки сцена не влияет
        $envName   = Read-Option 'Сцена (environment):' @('Low', 'Medium', 'High') 1
        $envFactor = @{ 'Low' = 0.25; 'Medium' = 0.5; 'High' = 1.0 }[$envName]
    }

    $stdFps = if ($std -eq 'NTSC') { 30 } else { 25 }
    $fps    = [int](Read-NumberInRange 'Кадров в секунду' $stdFps 1 60)

    $auto = Get-DahuaBitRate -Resolution $res -FrameRate $fps -VideoStandard $std `
                             -Compression $codec -Environment $envFactor
    Write-Host ("   Расчётный битрейт: {0} Kbps" -f $auto) -ForegroundColor DarkGray
    $kbps = [int](Read-NumberInRange 'Битрейт, Kbps (Enter — принять)' $auto 1 65536)
    $min  = $script:DahuaMin[$res]
    if ($kbps -lt $min) {
        Write-Host ("   Ниже минимума Dahua для {0} ({1} Kbps) — считаю как есть." -f $res, $min) -ForegroundColor Yellow
    }

    $hours = Read-NumberInRange 'Часов записи в сутки' 24 1 24
    $sum   = [double]$kbps * $channels               # суммарный битрейт всех каналов = Bandwidth

    Write-Host "`n   Что посчитать:" -ForegroundColor Gray
    Write-Host "    [1] Объём диска на N дней   [по умолч.]"
    Write-Host "    [2] На сколько дней хватит диска"
    $mode = (Read-Host "   Выбор [1]").Trim()

    if ($mode -eq '2') {
        $unit   = Read-Option 'Единица объёма:' @('TB', 'GB') 0
        $size   = Read-NumberInRange "Объём диска, $unit" 4 0.1 100000
        $diskKB = if ($unit -eq 'TB') { $size * 1024 * 1024 * 1024 } else { $size * 1024 * 1024 }
        $result = '{0} Days' -f (Get-DahuaDays -BitRateKbps $sum -HoursPerDay $hours -DiskKB $diskKB)
        $label  = 'Storage Time'
    } else {
        $days   = Read-NumberInRange 'Срок хранения, дней' 30 1 3650
        $result = Format-DahuaSize (Get-DahuaStorageKB -BitRateKbps $sum -HoursPerDay $hours -Days $days)
        $label  = 'Required Disk Space'
    }

    Write-Host ""
    Write-Kv 'Channels'  ([string]$channels)                    21
    Write-Kv 'Bandwidth' (Format-DahuaSize $sum -Bandwidth)     21
    Write-Kv $label      $result                                21
    Write-Kv 'Параметры' ("{0}, {1}, {2}, {3} fps, {4} Kbps/канал, {5} ч/сутки" -f
                          $res, $codec, $std, $fps, $kbps, $hours) 21
    Write-Host "`n   Объём — без учёта RAID: покупаемая ёмкость должна быть больше." -ForegroundColor DarkGray
    Write-Host "   Формулы и запас 10% — как в калькуляторе Dahua." -ForegroundColor DarkGray
}

# =====================================================================
#  Утилиты: WinUtil / Win11Debloat / Sophia
# =====================================================================
# Скачать (если нужно), распаковать и запустить SophiApp — портейбл-GUI debloat.
# Всегда берём последний релиз (GitHub /latest/download/). Кэш в %LOCALAPPDATA%.
function Invoke-SophiApp {
    $dir = Join-Path $env:LOCALAPPDATA 'HHToolbox\SophiApp'
    $exe = Get-ChildItem $dir -Recurse -Filter 'SophiApp.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $exe) {
        Write-Host "`n   Скачиваю SophiApp..." -ForegroundColor Green
        try {
            $zip = Join-Path $env:TEMP 'sophiapp.zip'
            $wc = New-Object System.Net.WebClient
            try { $wc.DownloadFile('https://github.com/Sophia-Community/SophiApp/releases/latest/download/SophiApp.zip', $zip) } finally { $wc.Dispose() }
            Expand-Archive -Path $zip -DestinationPath $dir -Force
            Remove-Item $zip -Force -ErrorAction SilentlyContinue
            $exe = Get-ChildItem $dir -Recurse -Filter 'SophiApp.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
        } catch { Write-Host "   Ошибка загрузки SophiApp: $($_.Exception.Message)" -ForegroundColor Red; return }
    }
    if ($exe) { Write-Host "   Запускаю SophiApp..." -ForegroundColor Cyan; Start-Process $exe.FullName }
    else { Write-Host "   SophiApp.exe не найден после распаковки." -ForegroundColor Yellow }
}

function Show-UtilityMenu {
    do {
        Write-Box 'Утилиты: debloat и твики' 'Magenta'
        Write-Host "   [1] " -NoNewline -ForegroundColor Green; Write-Host "WinUtil (Chris Titus)"
        Write-Host "   [2] " -NoNewline -ForegroundColor Green; Write-Host "Win11Debloat (Raphire)"
        Write-Host "   [3] " -NoNewline -ForegroundColor Green; Write-Host "SophiApp (GUI, галочки)"
        Write-Host "   [4] " -NoNewline -ForegroundColor Green; Write-Host "Sophia Script (выбор версии)"
        Write-Host "   [0] " -NoNewline -ForegroundColor Red;   Write-Host "Назад"
        Write-Host ""
        switch ((Read-Host "  Выбор").Trim()) {
            '1' { Invoke-Remote 'https://christitus.com/win'; Wait-Continue }
            '2' { Invoke-Remote 'https://debloat.raphi.re/';  Wait-Continue }
            '3' { Invoke-SophiApp; Wait-Continue }
            '4' { Start-Process 'https://github.com/farag2/Sophia-Script-for-Windows/releases'; Wait-Continue }
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
    if (Confirm-Winget) {
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
# =====================================================================
#  Сканер сети — найти устройства в подсети (IP / MAC / вендор / имя).
#  Вендор определяется по OUI (первые 3 байта MAC). Таблица — подборка под
#  CCTV/сети (Dahua, Hikvision, Uniview, Axis, TP-Link, MikroTik, Ubiquiti,
#  виртуалки), не полная база IEEE: неизвестный бренд покажет «—».
# =====================================================================
$script:OuiVendors = @{
    '3C:EF:8C' = 'Dahua'; '90:02:A9' = 'Dahua'; 'E0:50:8B' = 'Dahua'; 'BC:32:5F' = 'Dahua'; '4C:11:BF' = 'Dahua'
    '08:ED:ED' = 'Dahua'; '14:A7:8B' = 'Dahua'; 'A0:BD:1D' = 'Dahua'; '38:AF:29' = 'Dahua'; '24:52:6A' = 'Dahua'
    '44:19:B6' = 'Hikvision'; '4C:BD:8F' = 'Hikvision'; '28:57:BE' = 'Hikvision'; 'C0:56:E3' = 'Hikvision'
    'BC:AD:28' = 'Hikvision'; '54:C4:15' = 'Hikvision'; 'A4:14:37' = 'Hikvision'; '18:80:25' = 'Hikvision'
    '58:03:FB' = 'Hikvision'; 'E0:BA:AD' = 'Hikvision'; '24:28:FD' = 'Hikvision'
    '48:EA:63' = 'Uniview'
    '00:40:8C' = 'Axis'; 'AC:CC:8E' = 'Axis'; 'B8:A4:4F' = 'Axis'
    '50:C7:BF' = 'TP-Link'; 'F4:F2:6D' = 'TP-Link'; '14:CC:20' = 'TP-Link'; 'EC:08:6B' = 'TP-Link'
    '4C:5E:0C' = 'MikroTik'; '64:D1:54' = 'MikroTik'; 'CC:2D:E0' = 'MikroTik'; '48:8F:5A' = 'MikroTik'; 'DC:2C:6E' = 'MikroTik'
    '24:A4:3C' = 'Ubiquiti'; '44:D9:E7' = 'Ubiquiti'; '78:8A:20' = 'Ubiquiti'; 'FC:EC:DA' = 'Ubiquiti'; 'E0:63:DA' = 'Ubiquiti'
    '00:1B:21' = 'Intel'; '3C:FD:FE' = 'Intel'; 'A0:36:9F' = 'Intel'; '00:E0:4C' = 'Realtek'
    '00:0C:29' = 'VMware'; '00:50:56' = 'VMware'; '00:05:69' = 'VMware'; '00:15:5D' = 'Hyper-V'; '52:54:00' = 'QEMU/KVM'
}
# Полная база OUI (Wireshark manuf): скачивается один раз, кэш в %LOCALAPPDATA%,
# обновляется раз в 30 дней и парсится в память при первом обращении. Поддержаны
# блоки MA-L/MA-M/MA-S (маски /24, /28, /36). Нет интернета/файла — вернём пустую
# базу, и Get-MacVendor уйдёт на встроенную таблицу. Одна попытка загрузки за сеанс.
$script:OuiDb = $null
function Get-OuiDatabase {
    param([switch]$Force)
    $file = Join-Path (Join-Path $env:LOCALAPPDATA 'HHToolbox') 'manuf.txt'
    if ($Force) {
        try { if (Test-Path $file) { Remove-Item $file -Force -ErrorAction SilentlyContinue } } catch { $null = $_ }
        $script:OuiDb = $null
    }
    if ($null -ne $script:OuiDb) { return $script:OuiDb }
    $script:OuiDb = @{ Oui24 = @{}; Fine = @{} }   # непустой маркер => повторно за сеанс не качаем
    try {
        $stale = (-not (Test-Path $file)) -or (((Get-Date) - (Get-Item $file).LastWriteTime).TotalDays -gt 30)
        if ($stale) {
            New-Item -ItemType Directory -Force -Path (Split-Path $file -Parent) | Out-Null
            $oldPP = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
            try { Invoke-WebRequest -Uri 'https://www.wireshark.org/download/automated/data/manuf' -OutFile $file -TimeoutSec 20 -UseBasicParsing }
            finally { $ProgressPreference = $oldPP }
        }
        if (Test-Path $file) {
            foreach ($line in [IO.File]::ReadAllLines($file)) {
                if (-not $line -or $line[0] -eq '#') { continue }
                $p = $line -split "`t"
                if ($p.Count -lt 2 -or -not $p[1]) { continue }
                $name = if ($p.Count -ge 3 -and $p[2]) { $p[2].Trim() } else { $p[1].Trim() }
                $bits = 24
                if ($p[0] -match '/(\d+)\s*$') { $bits = [int]$Matches[1] }
                $hex = ((($p[0] -replace '/.*$', '') -replace '[:.\-]', '')).ToUpper()
                if ($hex.Length -lt 6) { continue }
                $grp = $hex.Substring(0, 6)
                if ($bits -le 24) {
                    $script:OuiDb.Oui24[$grp] = $name
                } else {
                    $nib = [int][math]::Floor($bits / 4)
                    if ($hex.Length -lt $nib) { continue }
                    if (-not $script:OuiDb.Fine.ContainsKey($grp)) { $script:OuiDb.Fine[$grp] = New-Object System.Collections.Generic.List[object] }
                    $script:OuiDb.Fine[$grp].Add([pscustomobject]@{ Len = $nib; Prefix = $hex.Substring(0, $nib); Vendor = $name })
                }
            }
        }
    } catch { $null = $_ }
    return $script:OuiDb
}

# Число записей в загруженной базе (для статуса в окне сканера).
function Get-OuiCount {
    $db = Get-OuiDatabase
    $fine = 0; foreach ($v in $db.Fine.Values) { $fine += $v.Count }
    return ($db.Oui24.Count + $fine)
}

# Вендор по MAC: сперва встроенная таблица (чистые имена Dahua/Hikvision/...),
# затем полная база Wireshark, иначе «—».
function Get-MacVendor {
    param([string]$Mac)
    if (-not $Mac) { return '' }
    $norm = ($Mac -replace '[-.: ]', '').ToUpper()
    if ($norm.Length -lt 6) { return '—' }
    $grp = $norm.Substring(0, 6)
    $key = $grp.Substring(0, 2) + ':' + $grp.Substring(2, 2) + ':' + $grp.Substring(4, 2)
    if ($script:OuiVendors.ContainsKey($key)) { return $script:OuiVendors[$key] }
    $db = Get-OuiDatabase
    if ($db.Fine.ContainsKey($grp)) {
        foreach ($e in ($db.Fine[$grp] | Sort-Object Len -Descending)) {
            if ($norm.Length -ge $e.Len -and $norm.Substring(0, $e.Len) -eq $e.Prefix) { return $e.Vendor }
        }
    }
    if ($db.Oui24.ContainsKey($grp)) { return $db.Oui24[$grp] }
    return '—'
}

# База подсети (первые три октета) активного адаптера, напр. "192.168.1".
function Get-LanBase {
    try {
        $cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue |
            Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
        $ip = ($cfg.IPv4Address | Select-Object -First 1).IPAddress
        if ($ip -match '^(\d+\.\d+\.\d+)\.\d+$') { return $Matches[1] }
    } catch { $null = $_ }
    try {
        $ip = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
            Select-Object -First 1).IPAddress
        if ($ip -match '^(\d+\.\d+\.\d+)\.\d+$') { return $Matches[1] }
    } catch { $null = $_ }
    return '192.168.1'
}

# Просканировать /24 и вернуть устройства: IP / MAC / Vendor / Name.
function Get-LanDevices {
    param([string]$Base)
    if (-not $Base) { $Base = Get-LanBase }
    $Base = $Base.Trim().TrimEnd('.')
    # 1) асинхронный ping всех адресов — находит живых и наполняет ARP-кэш.
    $pings = 1..254 | ForEach-Object {
        [pscustomobject]@{ IP = "$Base.$_"; Task = (New-Object System.Net.NetworkInformation.Ping).SendPingAsync("$Base.$_", 500) }
    }
    try { [System.Threading.Tasks.Task]::WaitAll(@($pings.Task), 4000) | Out-Null } catch { $null = $_ }
    $alive = New-Object System.Collections.Generic.HashSet[string]
    foreach ($x in $pings) {
        try { if ($x.Task.Status -eq 'RanToCompletion' -and $x.Task.Result.Status -eq 'Success') { [void]$alive.Add($x.IP) } } catch { $null = $_ }
    }
    # 2) MAC из таблицы соседей (или arp -a). Часть камер молчит на ICMP, но после
    #    запроса всё равно оседает в ARP — их тоже покажем. ВАЖНО: берём только
    #    записи с реальным MAC (Reachable/Stale/Permanent) — иначе пинг-свип
    #    оставит по записи на каждый адрес с нулевым MAC. Плюс отсекаем
    #    нулевой/широковещательный/мультикастовый MAC.
    $mac = @{}
    $bad = @('00:00:00:00:00:00', 'FF:FF:FF:FF:FF:FF')
    try {
        Get-NetNeighbor -AddressFamily IPv4 -ErrorAction Stop |
            Where-Object { $_.IPAddress -like "$Base.*" -and (([string]$_.State) -in @('Reachable', 'Stale', 'Permanent')) } |
            ForEach-Object {
                $m = (([string]$_.LinkLayerAddress) -replace '-', ':').ToUpper()
                if ($m -match '^[0-9A-F]{2}(:[0-9A-F]{2}){5}$' -and $bad -notcontains $m -and $m -notlike '01:00:5E:*') { $mac[$_.IPAddress] = $m }
            }
    } catch {
        arp.exe -a | ForEach-Object {
            if ($_ -match '^\s*(\d+\.\d+\.\d+\.\d+)\s+([0-9A-Fa-f]{2}(?:-[0-9A-Fa-f]{2}){5})') {
                $ip = $Matches[1]; $m = ($Matches[2] -replace '-', ':').ToUpper()
                if ($ip -like "$Base.*" -and $bad -notcontains $m -and $m -notlike '01:00:5E:*') { $mac[$ip] = $m }
            }
        }
    }
    # 3) объединить IP из ping и из ARP, отсортировать по адресу.
    foreach ($k in $mac.Keys) { [void]$alive.Add($k) }
    $ips = @($alive) | Sort-Object { [version]$_ }
    if (-not $ips) { return @() }
    # 4) обратный DNS — асинхронно, общий лимит ~1.5с (кто не успел — без имени).
    $dns = foreach ($ip in $ips) { [pscustomobject]@{ IP = $ip; Task = [System.Net.Dns]::GetHostEntryAsync($ip) } }
    try { [System.Threading.Tasks.Task]::WaitAll(@($dns.Task), 1500) | Out-Null } catch { $null = $_ }
    $name = @{}
    foreach ($d in $dns) { try { if ($d.Task.Status -eq 'RanToCompletion') { $name[$d.IP] = $d.Task.Result.HostName } } catch { $null = $_ } }
    foreach ($ip in $ips) {
        $m = [string]$mac[$ip]
        [pscustomobject]@{ IP = $ip; MAC = $m; Vendor = (Get-MacVendor $m); Name = [string]$name[$ip] }
    }
}

# CLI-версия сканера (в GUI подменяется окном Show-GuiNetworkScan).
function Show-NetworkScan {
    $base = Get-LanBase
    $inp = (Read-Host "   Подсеть [$base]").Trim()
    if ($inp) { $base = $inp }
    Write-Host "`n   Сканирую $base.1-254 (несколько секунд)..." -ForegroundColor Green
    $devs = Get-LanDevices -Base $base
    if (-not $devs) { Write-Host "   Устройств не найдено." -ForegroundColor Yellow; return }
    Write-Host ("`n   {0,-16}{1,-20}{2,-12}{3}" -f 'IP', 'MAC', 'Вендор', 'Имя') -ForegroundColor Cyan
    foreach ($d in $devs) {
        $macShow = if ($d.MAC) { $d.MAC } else { '—' }
        Write-Host ("   {0,-16}{1,-20}{2,-12}{3}" -f $d.IP, $macShow, $d.Vendor, $d.Name)
    }
    Write-Host "`n   Найдено устройств: $($devs.Count)" -ForegroundColor Green
}

# Полный скан портов устройства через RustScan в ОТДЕЛЬНОЙ консоли: скан всех
# 65535 портов ~30с — окно утилит им не блокируем. Если rustscan нет — ставим
# через winget (bee-san.RustScan). Хост передаём переменной окружения (данные,
# не код — без инъекций). Флаг -g: только порты, без nmap.
function Invoke-RustScan {
    param($HostTarget)
    $h = ([string]$HostTarget).Trim()
    if (-not $h) { Write-Host "   Укажи хост/IP." -ForegroundColor Yellow; return }
    $env:HH_RSHOST = $h
    $inner = @'
$ErrorActionPreference = 'Continue'
$rs = (Get-Command rustscan -ErrorAction SilentlyContinue).Source
if (-not $rs) {
    Write-Host 'Устанавливаю RustScan (winget)...' -ForegroundColor Yellow
    winget install --id bee-san.RustScan -e --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
    $rs = (Get-Command rustscan -ErrorAction SilentlyContinue).Source
}
$nmap = (Get-Command nmap -ErrorAction SilentlyContinue)
if (-not $nmap) {
    Write-Host 'Устанавливаю Nmap (winget)...' -ForegroundColor Yellow
    winget install --id Insecure.Nmap -e --source winget --accept-package-agreements --accept-source-agreements
    $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')
    $nmap = (Get-Command nmap -ErrorAction SilentlyContinue)
}
if ($rs) {
    if ($nmap) {
        Write-Host "RustScan + Nmap $env:HH_RSHOST - порты и версии сервисов..." -ForegroundColor Cyan
        & $rs -a $env:HH_RSHOST --ulimit 5000 -- -sV -Pn
    } else {
        Write-Host "Nmap недоступен - только порты (rustscan -g)..." -ForegroundColor Yellow
        & $rs -a $env:HH_RSHOST -g --ulimit 5000
    }
} else { Write-Host 'RustScan установить не удалось.' -ForegroundColor Red }
Write-Host ''; Write-Host 'Готово. Окно можно закрыть.' -ForegroundColor Green
'@
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($inner))
    Start-Process powershell -ArgumentList '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc
}

$Menu = @(
    @{ Section = 'Диагностика и сеть' }
    @{ Label = 'Информация о ПК';                                 Action = { Show-PCInfo; Wait-Continue } }
    @{ Label = 'Анализ ПК — Glow (сохранение в HTML)';            Action = { Invoke-Glow; Wait-Continue } }
    @{ Label = 'Сетевые утилиты (DNS, ping, сброс сети)';         Action = { Show-NetworkMenu } }
    @{ Label = 'Сканер сети (найти камеры/устройства)';           Action = { Show-NetworkScan; Wait-Continue } }
    @{ Label = 'Калькулятор диска и полосы (клон Dahua Basic)';   Action = { Show-StorageCalc; Wait-Continue } }
    @{ Label = 'Стресс-тест ПК (CPU-прожиг + OCCT/FurMark/диск)'; Action = { Invoke-Remote 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/scripts/stresstest.ps1'; Wait-Continue } }
    @{ Section = 'Программы' }
    @{ Label = 'Установить winget (App Installer)';              Action = {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-Host "`n   winget уже установлен: $(winget --version)" -ForegroundColor Green
            } else {
                Write-Host "`n   Устанавливаю winget (App Installer)..." -ForegroundColor Cyan
                if (Install-Winget) { $script:HasWinget = $true; Write-Host "   Готово: $(winget --version)" -ForegroundColor Green }
                else { Write-Host "   Не удалось установить winget — подробности выше." -ForegroundColor Yellow }
            }
            Wait-Continue
        }; Admin = $true }
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

# По умолчанию открывается ОКОННЫЙ интерфейс (gui.ps1). Консольное меню —
# только если GUI невозможен: не STA-поток (pwsh 7), нет рабочего стола
# (SSH/Server Core) или ошибка загрузки. Принудительно консоль: $ForceCli = $true.
# gui.ps1 выставляет $SkipCliMenu = $true, когда грузит этот файл ради данных.
if (-not $SkipCliMenu) {
    $GuiStarted = $false
    if (-not $ForceCli -and [Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA') {
        Write-Host "`n  HH Toolbox — загрузка интерфейса..." -ForegroundColor Cyan
        try { Invoke-Expression ([string](Invoke-RestMethod -Uri $GuiUrl)).TrimStart([char]0xFEFF) }
        catch {
            Write-Host "`n  GUI не запустился ($($_.Exception.Message))." -ForegroundColor DarkYellow
            Write-Host "  Открываю консольное меню.`n" -ForegroundColor DarkYellow
        }
    }
    # Окно закрыли — закрываем и консольный сеанс, чтобы не оставалось лишнего окна.
    if ($GuiStarted) { exit }
}

if (-not $SkipCliMenu -and -not $GuiStarted) {
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
}
