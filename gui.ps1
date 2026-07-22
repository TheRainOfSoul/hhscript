# =====================================================================
#  HH Toolbox — GUI (WinForms)
#  Запуск:
#    irm https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/gui.ps1 | iex
#
#  Данные и функции берутся из menu.ps1 (один источник правды): он грузится
#  с $SkipCliMenu = $true, поэтому консольное меню не запускается.
#  Вывод выполнения (winget, DISM, MAS и т.п.) идёт в окно консоли позади.
# =====================================================================
try { [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$MenuUrl = 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/menu.ps1'
$GuiUrl  = 'https://raw.githubusercontent.com/TheRainOfSoul/hhscript/main/gui.ps1'

# --- WinForms требует STA-поток (в Windows PowerShell 5.1 он по умолчанию) ---
if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    Write-Host "`n  GUI требует STA-потока, а текущий сеанс — MTA (обычно это pwsh 7)." -ForegroundColor Yellow
    Write-Host "  Запусти в Windows PowerShell (powershell.exe) или так:" -ForegroundColor Yellow
    Write-Host "  powershell -STA -NoProfile -Command `"irm $GuiUrl | iex`"`n" -ForegroundColor Cyan
    return
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# --- Загружаем ядро: данные ($Menu, $Programs, ...) и функции, без CLI-меню ---
$SkipCliMenu = $true
try {
    Invoke-Expression (Invoke-RestMethod -Uri $MenuUrl)
} catch {
    [void][System.Windows.Forms.MessageBox]::Show(
        "Не удалось загрузить menu.ps1:`n$($_.Exception.Message)", 'HH Toolbox', 'OK', 'Error')
    return
}

# =====================================================================
#  Оконный чек-лист ВМЕСТО консольного. Контракт тот же (массив индексов
#  или $null), поэтому Show-ProgramMenu / Invoke-LightTweak / ... не меняются.
# =====================================================================
function Show-CheckList {
    param([string]$Title, [string[]]$Items, [string]$Color = 'Yellow', [bool]$DefaultChecked = $true, [hashtable]$Headers = $null)

    $form = New-Object System.Windows.Forms.Form
    $form.Text          = $Title
    $form.Size          = New-Object System.Drawing.Size(640, 660)
    $form.MinimumSize   = New-Object System.Drawing.Size(480, 400)
    $form.StartPosition = 'CenterScreen'

    $lv = New-Object System.Windows.Forms.ListView
    $lv.Dock          = 'Fill'
    $lv.View          = 'Details'
    $lv.CheckBoxes    = $true
    $lv.FullRowSelect = $true
    $lv.HeaderStyle   = 'None'
    [void]$lv.Columns.Add('', 590)

    $group = $null
    for ($i = 0; $i -lt $Items.Count; $i++) {
        if ($Headers -and $Headers.ContainsKey($i)) {
            $group = New-Object System.Windows.Forms.ListViewGroup($Headers[$i])
            [void]$lv.Groups.Add($group)
        }
        $row = New-Object System.Windows.Forms.ListViewItem($Items[$i])
        $row.Tag     = $i
        $row.Checked = $DefaultChecked
        if ($group) { $row.Group = $group }
        [void]$lv.Items.Add($row)
    }

    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock    = 'Bottom'
    $bar.Height  = 46
    $bar.Padding = New-Object System.Windows.Forms.Padding(8, 8, 8, 8)

    $btnOk   = New-Object System.Windows.Forms.Button; $btnOk.Text   = 'Применить';    $btnOk.Width   = 110
    $btnCan  = New-Object System.Windows.Forms.Button; $btnCan.Text  = 'Отмена';       $btnCan.Width  = 90
    $btnAll  = New-Object System.Windows.Forms.Button; $btnAll.Text  = 'Отметить всё'; $btnAll.Width  = 120
    $btnNone = New-Object System.Windows.Forms.Button; $btnNone.Text = 'Снять всё';    $btnNone.Width = 100

    $btnOk.DialogResult  = [System.Windows.Forms.DialogResult]::OK
    $btnCan.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $btnAll.Add_Click({  foreach ($x in $lv.Items) { $x.Checked = $true } }.GetNewClosure())
    $btnNone.Add_Click({ foreach ($x in $lv.Items) { $x.Checked = $false } }.GetNewClosure())

    $bar.Controls.AddRange(@($btnOk, $btnCan, $btnAll, $btnNone))
    $form.Controls.Add($lv)      # Fill добавляем первым
    $form.Controls.Add($bar)     # Bottom — последним (докается первым)
    $form.AcceptButton = $btnOk
    $form.CancelButton = $btnCan

    $res = $form.ShowDialog()
    $sel = @()
    if ($res -eq [System.Windows.Forms.DialogResult]::OK) {
        foreach ($x in $lv.CheckedItems) { $sel += [int]$x.Tag }
    }
    $form.Dispose()
    if ($res -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return , @($sel | Sort-Object)
}

# В GUI «нажми Enter» не нужен — вывод остаётся в консоли позади окна.
function Wait-Continue { }

# =====================================================================
#  Главное окно
# =====================================================================
function Invoke-GuiAdminRestart {
    Start-Process powershell -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-Command', "irm $GuiUrl | iex")
    [System.Windows.Forms.Application]::Exit()
}

function Invoke-GuiAction {
    param($item)
    if ($item.Admin -and -not (Test-Admin)) {
        $ask = [System.Windows.Forms.MessageBox]::Show(
            "Пункт «$($item.Label)» требует прав администратора.`nПерезапустить от имени администратора?",
            'HH Toolbox', 'YesNo', 'Question')
        if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) { Invoke-GuiAdminRestart; return }
    }
    Write-Log "GUI: $($item.Label)"
    try { & $item.Action }
    catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Ошибка: $($_.Exception.Message)", 'HH Toolbox', 'OK', 'Error')
    }
}

function Show-GuiMain {
    $form = New-Object System.Windows.Forms.Form
    $form.Text          = "HH Toolbox v$Version"
    $form.Size          = New-Object System.Drawing.Size(560, 720)
    $form.MinimumSize   = New-Object System.Drawing.Size(460, 400)
    $form.StartPosition = 'CenterScreen'

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.Dock          = 'Fill'
    $flow.FlowDirection = 'TopDown'
    $flow.WrapContents  = $false
    $flow.AutoScroll    = $true
    $flow.Padding       = New-Object System.Windows.Forms.Padding(12, 8, 12, 8)

    foreach ($e in $Menu) {
        if ($e.Section) {
            $lbl = New-Object System.Windows.Forms.Label
            $lbl.Text      = $e.Section
            $lbl.Font      = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
            $lbl.ForeColor = [System.Drawing.Color]::FromArgb(0, 90, 140)
            $lbl.Width     = 480
            $lbl.Height    = 26
            $lbl.TextAlign = 'BottomLeft'
            [void]$flow.Controls.Add($lbl)
            continue
        }
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text      = $e.Label
        $btn.Width     = 480
        $btn.Height    = 32
        $btn.TextAlign = 'MiddleLeft'
        $btn.Tag       = $e
        $btn.Add_Click({ Invoke-GuiAction $this.Tag })
        [void]$flow.Controls.Add($btn)
    }

    $mode = if (Test-Admin) { 'АДМИН' } else { 'обычный пользователь' }
    $head = New-Object System.Windows.Forms.Label
    $head.Dock      = 'Top'
    $head.Height    = 26
    $head.TextAlign = 'MiddleLeft'
    $head.Text      = "   Режим: $mode · v$Version"
    $head.ForeColor = [System.Drawing.Color]::DimGray

    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock    = 'Bottom'
    $bar.Height  = 46
    $bar.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)

    $btnAdm  = New-Object System.Windows.Forms.Button; $btnAdm.Text  = 'От администратора'; $btnAdm.Width = 160
    $btnExit = New-Object System.Windows.Forms.Button; $btnExit.Text = 'Выход';             $btnExit.Width = 90
    $btnAdm.Add_Click({ Invoke-GuiAdminRestart })
    $btnExit.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bar.Controls.AddRange(@($btnAdm, $btnExit))

    $form.Controls.Add($flow)   # Fill — первым
    $form.Controls.Add($head)   # Top
    $form.Controls.Add($bar)    # Bottom
    $form.CancelButton = $btnExit

    [void]$form.ShowDialog()
    $form.Dispose()
}

# =====================================================================
#  2a. Калькулятор диска Dahua — оконная форма.
#  Считает ТЕМИ ЖЕ функциями из menu.ps1 (Get-DahuaBitRate / Get-DahuaStorageKB /
#  Get-DahuaDays / Format-DahuaSize) — цифры совпадают с CLI один в один.
# =====================================================================
function Show-GuiStorageCalc {
    $f = New-Object System.Windows.Forms.Form
    $f.Text            = 'Калькулятор диска Dahua (Basic)'
    $f.Size            = New-Object System.Drawing.Size(640, 600)
    $f.StartPosition   = 'CenterScreen'
    $f.FormBorderStyle = 'FixedDialog'
    $f.MaximizeBox     = $false

    $mk = {
        param($text, $top)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text; $l.Left = 16; $l.Top = $top + 3; $l.Width = 155
        $f.Controls.Add($l)
    }.GetNewClosure()
    $num = {
        param($top, $min, $max, $val, $dec)
        $n = New-Object System.Windows.Forms.NumericUpDown
        $n.Left = 180; $n.Top = $top; $n.Width = 110
        $n.Minimum = $min; $n.Maximum = $max; $n.DecimalPlaces = $dec; $n.Value = $val
        $f.Controls.Add($n); $n
    }.GetNewClosure()
    $cmb = {
        param($top, $items, $idx)
        $c = New-Object System.Windows.Forms.ComboBox
        $c.Left = 180; $c.Top = $top; $c.Width = 150; $c.DropDownStyle = 'DropDownList'
        foreach ($i in $items) { [void]$c.Items.Add($i) }
        $c.SelectedIndex = $idx
        $f.Controls.Add($c); $c
    }.GetNewClosure()

    & $mk 'Кол-во каналов' 14;       $nCh   = & $num 14  1 1024 1 0
    & $mk 'Стандарт' 44;             $cStd  = & $cmb 44  @('PAL', 'NTSC') 0
    & $mk 'Разрешение' 74;           $cRes  = & $cmb 74  @($script:DahuaBase.Keys) 3
    & $mk 'Кодек' 104;               $cCod  = & $cmb 104 @('H.264', 'H.265', 'SmartH.264+', 'SmartH.265+') 1
    & $mk 'Сцена (environment)' 134; $cEnv  = & $cmb 134 @('Low', 'Medium', 'High') 1
    & $mk 'Кадров в секунду' 164;    $nFps  = & $num 164 1 60 25 0
    & $mk 'Битрейт, Kbps' 194;       $nKbps = & $num 194 1 65536 4096 0
    & $mk 'Часов записи в сутки' 224; $nHrs = & $num 224 1 24 24 0

    $btnAuto = New-Object System.Windows.Forms.Button
    $btnAuto.Text = 'Пересчитать битрейт'; $btnAuto.Left = 300; $btnAuto.Top = 193; $btnAuto.Width = 165
    $f.Controls.Add($btnAuto)

    $grp = New-Object System.Windows.Forms.GroupBox
    $grp.Text = 'Что посчитать'; $grp.Left = 16; $grp.Top = 258; $grp.Width = 590; $grp.Height = 92
    $rbSpace = New-Object System.Windows.Forms.RadioButton
    $rbSpace.Text = 'Объём диска на N дней'; $rbSpace.Left = 14; $rbSpace.Top = 22; $rbSpace.Width = 200; $rbSpace.Checked = $true
    $nDays = New-Object System.Windows.Forms.NumericUpDown
    $nDays.Left = 220; $nDays.Top = 20; $nDays.Width = 90; $nDays.Minimum = 1; $nDays.Maximum = 3650; $nDays.Value = 30
    $rbTime = New-Object System.Windows.Forms.RadioButton
    $rbTime.Text = 'На сколько дней хватит'; $rbTime.Left = 14; $rbTime.Top = 54; $rbTime.Width = 200
    $nSize = New-Object System.Windows.Forms.NumericUpDown
    $nSize.Left = 220; $nSize.Top = 52; $nSize.Width = 90; $nSize.Minimum = 0.1; $nSize.Maximum = 100000
    $nSize.DecimalPlaces = 1; $nSize.Value = 4
    $cUnit = New-Object System.Windows.Forms.ComboBox
    $cUnit.Left = 320; $cUnit.Top = 52; $cUnit.Width = 70; $cUnit.DropDownStyle = 'DropDownList'
    [void]$cUnit.Items.AddRange(@('TB', 'GB')); $cUnit.SelectedIndex = 0
    $grp.Controls.AddRange(@($rbSpace, $nDays, $rbTime, $nSize, $cUnit))
    $f.Controls.Add($grp)

    $out = New-Object System.Windows.Forms.TextBox
    $out.Left = 16; $out.Top = 360; $out.Width = 590; $out.Height = 148
    $out.Multiline = $true; $out.ReadOnly = $true; $out.ScrollBars = 'Vertical'
    $out.Font = New-Object System.Drawing.Font('Consolas', 9)
    $f.Controls.Add($out)

    $btnCalc = New-Object System.Windows.Forms.Button
    $btnCalc.Text = 'Посчитать'; $btnCalc.Left = 16; $btnCalc.Top = 518; $btnCalc.Width = 120; $btnCalc.Height = 28
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Закрыть'; $btnClose.Left = 490; $btnClose.Top = 518; $btnClose.Width = 116; $btnClose.Height = 28
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $f.Controls.AddRange(@($btnCalc, $btnClose))
    $f.CancelButton = $btnClose

    # Сцена влияет только на Smart-кодеки.
    $syncUi = { $cEnv.Enabled = ([string]$cCod.SelectedItem -like 'Smart*') }.GetNewClosure()

    $autoBitrate = {
        $envF = @{ 'Low' = 0.25; 'Medium' = 0.5; 'High' = 1.0 }[[string]$cEnv.SelectedItem]
        $v = Get-DahuaBitRate -Resolution ([string]$cRes.SelectedItem) -FrameRate ([double]$nFps.Value) `
            -VideoStandard ([string]$cStd.SelectedItem) -Compression ([string]$cCod.SelectedItem) -Environment $envF
        if ($v -ge $nKbps.Minimum -and $v -le $nKbps.Maximum) { $nKbps.Value = $v }
    }.GetNewClosure()

    $cCod.Add_SelectedIndexChanged({ & $syncUi; & $autoBitrate }.GetNewClosure())
    $cRes.Add_SelectedIndexChanged($autoBitrate)
    $cEnv.Add_SelectedIndexChanged($autoBitrate)
    $nFps.Add_ValueChanged($autoBitrate)
    $cStd.Add_SelectedIndexChanged({
            $nFps.Value = if ([string]$cStd.SelectedItem -eq 'NTSC') { 30 } else { 25 }
            & $autoBitrate
        }.GetNewClosure())
    $btnAuto.Add_Click($autoBitrate)

    $btnCalc.Add_Click({
            $ch    = [int]$nCh.Value
            $kbps  = [double]$nKbps.Value
            $hours = [double]$nHrs.Value
            $sum   = $kbps * $ch
            if ($rbTime.Checked) {
                $diskKB = if ([string]$cUnit.SelectedItem -eq 'TB') { [double]$nSize.Value * 1024 * 1024 * 1024 }
                          else { [double]$nSize.Value * 1024 * 1024 }
                $label  = 'Storage Time'
                $result = '{0} Days' -f (Get-DahuaDays -BitRateKbps $sum -HoursPerDay $hours -DiskKB $diskKB)
            } else {
                $label  = 'Required Disk Space'
                $result = Format-DahuaSize (Get-DahuaStorageKB -BitRateKbps $sum -HoursPerDay $hours -Days ([double]$nDays.Value))
            }
            $min  = $script:DahuaMin[[string]$cRes.SelectedItem]
            $warn = if ($kbps -lt $min) { "`r`nВнимание: ниже минимума Dahua для $($cRes.SelectedItem) ($min Kbps)." } else { '' }
            $out.Text = (@(
                    ('Channels            : {0}' -f $ch)
                    ('Bandwidth           : {0}' -f (Format-DahuaSize $sum -Bandwidth))
                    ('{0,-20}: {1}' -f $label, $result)
                    ('Параметры           : {0}, {1}, {2}, {3} fps, {4} Kbps/канал, {5} ч/сутки' -f
                        $cRes.SelectedItem, $cCod.SelectedItem, $cStd.SelectedItem, [int]$nFps.Value, [int]$kbps, [int]$hours)
                    ''
                    'Объём — без учёта RAID. Формулы и запас 10% — как в калькуляторе Dahua.'
                ) -join "`r`n") + $warn
        }.GetNewClosure())

    & $syncUi
    & $autoBitrate
    [void]$f.ShowDialog()
    $f.Dispose()
}

# =====================================================================
#  2b. Сетевые утилиты — окно с выводом в текстовое поле.
# =====================================================================
function Show-GuiNetwork {
    $f = New-Object System.Windows.Forms.Form
    $f.Text          = 'Сетевые утилиты'
    $f.Size          = New-Object System.Drawing.Size(840, 620)
    $f.MinimumSize   = New-Object System.Drawing.Size(660, 460)
    $f.StartPosition = 'CenterScreen'

    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Top'; $bar.Height = 92

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = 'Хост / IP:'; $lbl.Left = 12; $lbl.Top = 16; $lbl.Width = 70
    $tbHost = New-Object System.Windows.Forms.TextBox
    $tbHost.Left = 84; $tbHost.Top = 13; $tbHost.Width = 190; $tbHost.Text = '8.8.8.8'
    $bar.Controls.AddRange(@($lbl, $tbHost))

    $out = New-Object System.Windows.Forms.TextBox
    $out.Dock = 'Fill'; $out.Multiline = $true; $out.ReadOnly = $true
    $out.ScrollBars = 'Both'; $out.WordWrap = $false
    $out.Font = New-Object System.Drawing.Font('Consolas', 9)

    $run = {
        param($title, $sb)
        $out.Text = "=== $title ===`r`nвыполняется..."
        $f.Refresh()
        $text = try { (& $sb | Out-String) } catch { "Ошибка: $($_.Exception.Message)" }
        $out.Text = "=== $title ===`r`n" + $text
    }.GetNewClosure()

    $addBtn = {
        param($text, $left, $top, $width, $action)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text; $b.Left = $left; $b.Top = $top; $b.Width = $width; $b.Height = 26
        $b.Add_Click($action)
        $bar.Controls.Add($b)
    }.GetNewClosure()

    & $addBtn 'ipconfig /all' 12 52 120 { & $run 'ipconfig /all' { ipconfig /all } }.GetNewClosure()
    & $addBtn 'Адаптеры' 138 52 100 {
        & $run 'Адаптеры' {
            Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -EQ 'Up' | ForEach-Object {
                $ip = (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Select-Object -First 1).IPAddress
                '{0,-28} IP {1,-15} MAC {2}  {3}' -f $_.Name, $ip, $_.MacAddress, $_.LinkSpeed
            }
        }
    }.GetNewClosure()
    & $addBtn 'Ping' 244 52 80 {
        & $run "ping $($tbHost.Text)" { Test-Connection -ComputerName $tbHost.Text -Count 4 -ErrorAction SilentlyContinue | Format-Table -AutoSize }
    }.GetNewClosure()
    & $addBtn 'Tracert' 330 52 90 { & $run "tracert $($tbHost.Text)" { tracert $tbHost.Text } }.GetNewClosure()
    & $addBtn 'DNS → 1.1.1.1' 426 52 125 {
        Switch-Dns '1.1.1.1', '1.0.0.1'; & $run 'DNS' { Get-DnsClientServerAddress -AddressFamily IPv4 | Format-Table -AutoSize }
    }.GetNewClosure()
    & $addBtn 'DNS → 8.8.8.8' 557 52 125 {
        Switch-Dns '8.8.8.8', '8.8.4.4'; & $run 'DNS' { Get-DnsClientServerAddress -AddressFamily IPv4 | Format-Table -AutoSize }
    }.GetNewClosure()
    & $addBtn 'DNS → авто' 688 52 110 {
        Switch-Dns @(); & $run 'DNS' { Get-DnsClientServerAddress -AddressFamily IPv4 | Format-Table -AutoSize }
    }.GetNewClosure()
    & $addBtn 'Сброс сети (нужен админ)' 300 12 190 {
        Repair-Network; & $run 'Сброс сети' { 'Выполнено. Подробности — в окне консоли. Требуется перезагрузка.' }
    }.GetNewClosure()

    $f.Controls.Add($out)
    $f.Controls.Add($bar)
    [void]$f.ShowDialog()
    $f.Dispose()
}

# --- Подменяем консольные версии оконными ($Menu менять не нужно) ---
function Show-StorageCalc { Show-GuiStorageCalc }
function Show-NetworkMenu { Show-GuiNetwork }

Show-GuiMain
