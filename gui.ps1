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
        [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { $null = $_ }
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { $null = $_ }

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
Add-Type -AssemblyName Microsoft.VisualBasic   # InputBox — замена Read-Host в GUI
[System.Windows.Forms.Application]::EnableVisualStyles()

# =====================================================================
#  Тёмная тема: единый источник цветов + хелперы стилизации. Живёт ТОЛЬКО
#  в gui.ps1; menu.ps1 (консольное меню) не меняется. Все четыре окна берут
#  цвета из $script:Theme, поэтому вид везде одинаковый и правится в одном месте.
# =====================================================================
$script:Theme = @{
    Bg          = [System.Drawing.Color]::FromArgb(32, 32, 32)    # фон окна
    Surface     = [System.Drawing.Color]::FromArgb(45, 45, 48)    # кнопки, поля ввода
    Hover       = [System.Drawing.Color]::FromArgb(10, 90, 110)   # наведение на кнопку-пункт
    Accent      = [System.Drawing.Color]::FromArgb(0, 160, 175)   # заливка главных кнопок
    AccentText  = [System.Drawing.Color]::FromArgb(54, 190, 205)  # заголовки секций (ярче — читаемо на тёмном)
    AccentDown  = [System.Drawing.Color]::FromArgb(0, 130, 145)   # нажатие
    Text        = [System.Drawing.Color]::FromArgb(230, 230, 230)
    TextDim     = [System.Drawing.Color]::FromArgb(150, 150, 150)
    Border      = [System.Drawing.Color]::FromArgb(60, 60, 63)
    ConsoleBg   = [System.Drawing.Color]::FromArgb(24, 24, 24)     # лог и поля вывода
    PrimaryText = [System.Drawing.Color]::FromArgb(10, 22, 24)     # тёмный текст на бирюзовой кнопке
    Font        = New-Object System.Drawing.Font('Segoe UI', 9)
    FontBold    = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold)
    Mono        = New-Object System.Drawing.Font('Consolas', 9)
}

# Тёмная системная рамка/заголовок окна (Win10 2004+/Win11). Без этого над тёмным
# телом окна висела бы белая рамка. Обращение к .Handle создаёт нативный хэндл,
# атрибут применяется до показа окна, поэтому мигания светлой рамкой нет.
# [HH.Win32] определён ниже по файлу, но к моменту показа окон уже загружен.
function Set-DarkTitleBar {
    # Стайлинг окна, не системного состояния: ShouldProcess/-WhatIf тут не нужны.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param($form)
    try {
        $v = 1
        # 20 = DWMWA_USE_IMMERSIVE_DARK_MODE; 19 — на ранних сборках Win10.
        if ([HH.Win32]::DwmSetWindowAttribute($form.Handle, 20, [ref]$v, 4) -ne 0) {
            [void][HH.Win32]::DwmSetWindowAttribute($form.Handle, 19, [ref]$v, 4)
        }
    } catch { $null = $_ }
}

# Базовое оформление формы: фон, цвет текста, шрифт, тёмный заголовок.
function Initialize-DarkForm($form) {
    $form.BackColor = $script:Theme.Bg
    $form.ForeColor = $script:Theme.Text
    $form.Font      = $script:Theme.Font
    Set-DarkTitleBar $form
}

# Плоская кнопка. -Primary — заливка акцентом (главное действие в окне);
# без флага — «поверхность» с бирюзовой подсветкой при наведении.
function Set-FlatButton {
    # Стайлинг контрола в памяти, не системного состояния: ShouldProcess не нужен.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param($btn, [switch]$Primary)
    $btn.FlatStyle = 'Flat'
    $btn.FlatAppearance.BorderSize = 0
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    if ($Primary) {
        $btn.BackColor = $script:Theme.Accent
        $btn.ForeColor = $script:Theme.PrimaryText
        $btn.Font      = $script:Theme.FontBold
        $btn.FlatAppearance.MouseOverBackColor = $script:Theme.AccentText
        $btn.FlatAppearance.MouseDownBackColor = $script:Theme.AccentDown
    } else {
        $btn.BackColor = $script:Theme.Surface
        $btn.ForeColor = $script:Theme.Text
        $btn.FlatAppearance.MouseOverBackColor = $script:Theme.Hover
        $btn.FlatAppearance.MouseDownBackColor = $script:Theme.AccentDown
    }
}

# Тёмное поле ввода: TextBox / NumericUpDown / ComboBox.
function Set-DarkInput {
    # Стайлинг контрола в памяти, не системного состояния: ShouldProcess не нужен.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param($ctrl)
    $ctrl.BackColor = $script:Theme.Surface
    $ctrl.ForeColor = $script:Theme.Text
    if ($ctrl -is [System.Windows.Forms.ComboBox]) { $ctrl.FlatStyle = 'Flat' }
    else { try { $ctrl.BorderStyle = 'FixedSingle' } catch { $null = $_ } }
}

function Set-DarkLabel {
    # Стайлинг контрола в памяти, не системного состояния: ShouldProcess не нужен.
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param($lbl)
    $lbl.ForeColor = $script:Theme.Text
    $lbl.BackColor = [System.Drawing.Color]::Transparent
}

# Заголовок секции в главном меню: бирюзовый жирный + тонкая линия-разделитель.
function Add-SectionHeader($flow, $text) {
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text      = $text.ToUpper()
    $lbl.Font      = $script:Theme.FontBold
    $lbl.ForeColor = $script:Theme.AccentText
    $lbl.AutoSize  = $false
    $lbl.Width     = 480
    $lbl.Height    = 22
    $lbl.TextAlign = 'BottomLeft'
    $lbl.Margin    = New-Object System.Windows.Forms.Padding(2, 14, 2, 0)
    [void]$flow.Controls.Add($lbl)
    $div = New-Object System.Windows.Forms.Panel
    $div.Width     = 480
    $div.Height    = 1
    $div.BackColor = $script:Theme.Border
    $div.Margin    = New-Object System.Windows.Forms.Padding(2, 2, 2, 6)
    [void]$flow.Controls.Add($div)
}

# --- Ядро: данные ($Menu, $Programs, ...) и функции из menu.ps1 ---
# Если gui.ps1 вызван из menu.ps1, всё уже загружено — повторно не тянем
# (иначе получилась бы циклическая загрузка).
if (-not $Menu) {
    # $SkipCliMenu читается кодом menu.ps1, который грузится через iex ниже.
    # Задаём через Set-Variable: обычное присваивание PSScriptAnalyzer считает
    # «переменная назначена, но не используется» (чтения через iex он не видит).
    Set-Variable -Name SkipCliMenu -Value $true
    try {
        # TrimStart: BOM файла приходит от irm как символ U+FEFF и ломает iex.
        Invoke-Expression ([string](Invoke-RestMethod -Uri $MenuUrl)).TrimStart([char]0xFEFF)
    } catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Не удалось загрузить menu.ps1:`n$($_.Exception.Message)", 'HH Toolbox', 'OK', 'Error')
        return
    }
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
    Initialize-DarkForm $form

    $lv = New-Object System.Windows.Forms.ListView
    $lv.Dock          = 'Fill'
    $lv.View          = 'Details'
    $lv.CheckBoxes    = $true
    $lv.FullRowSelect = $true
    $lv.HeaderStyle   = 'None'
    $lv.BorderStyle   = 'None'
    $lv.BackColor     = $script:Theme.ConsoleBg
    $lv.ForeColor     = $script:Theme.Text
    $lv.Font          = $script:Theme.Font
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
    $bar.Dock      = 'Bottom'
    $bar.Height    = 46
    $bar.Padding   = New-Object System.Windows.Forms.Padding(8, 8, 8, 8)
    $bar.BackColor = $script:Theme.Bg

    $btnOk   = New-Object System.Windows.Forms.Button; $btnOk.Text   = 'Применить';    $btnOk.Width   = 110; $btnOk.Height   = 30
    $btnCan  = New-Object System.Windows.Forms.Button; $btnCan.Text  = 'Отмена';       $btnCan.Width  = 90;  $btnCan.Height  = 30
    $btnAll  = New-Object System.Windows.Forms.Button; $btnAll.Text  = 'Отметить всё'; $btnAll.Width  = 120; $btnAll.Height  = 30
    $btnNone = New-Object System.Windows.Forms.Button; $btnNone.Text = 'Снять всё';    $btnNone.Width = 100; $btnNone.Height = 30
    Set-FlatButton $btnOk -Primary
    Set-FlatButton $btnCan
    Set-FlatButton $btnAll
    Set-FlatButton $btnNone

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

# Запустить пункт меню в ОТДЕЛЬНОМ окне консоли: окно GUI остаётся свободным,
# а действие получает полноценную интерактивную консоль (MAS, winget, DISM...).
function Invoke-GuiItemInConsole {
    param($item)
    $idx = [array]::IndexOf($Menu, $item)
    if ($idx -lt 0) { return }
    $cmd = '$SkipCliMenu=$true; iex (irm ''{0}''); & ($Menu[{1}]).Action; Write-Host ""; Write-Host "Готово. Окно можно закрыть." -ForegroundColor Cyan' -f $MenuUrl, $idx
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    $psArgs = @('-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc)
    if ($item.Admin -and -not (Test-Admin)) {
        Start-Process powershell -Verb RunAs -ArgumentList $psArgs
    } else {
        Start-Process powershell -ArgumentList $psArgs
    }
}

function Invoke-GuiAction {
    param($item)
    if ($item.Admin -and -not (Test-Admin) -and -not ($script:RunInConsole -and $script:RunInConsole.Checked)) {
        $ask = [System.Windows.Forms.MessageBox]::Show(
            "Пункт «$($item.Label)» требует прав администратора.`nПерезапустить от имени администратора?",
            'HH Toolbox', 'YesNo', 'Question')
        if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) { Invoke-GuiAdminRestart; return }
    }
    Write-Log "GUI: $($item.Label)"

    # Режим «в отдельной консоли» — GUI не блокируется вообще.
    if ($script:RunInConsole -and $script:RunInConsole.Checked) {
        Invoke-GuiItemInConsole $item
        return
    }

    # Иначе выполняем в этом же процессе, показывая, что идёт работа.
    $frm      = $script:GuiForm
    $oldTitle = if ($frm) { $frm.Text } else { $null }
    if ($frm) {
        $frm.Text    = "Выполняется: $($item.Label)"
        $frm.Cursor  = [System.Windows.Forms.Cursors]::WaitCursor
        $frm.Enabled = $false
        [System.Windows.Forms.Application]::DoEvents()
    }
    try {
        # Вывод внешних утилит (winget, DISM, sfc, netsh, dcu-cli...) попадает
        # в пайплайн — перехватываем построчно и льём во внутреннюю консоль,
        # поэтому настоящее окно консоли показывать не нужно.
        & $item.Action 2>&1 | ForEach-Object {
            if ($null -ne $_ -and $script:LogBox) { $script:LogBox.AppendText(([string]$_) + "`r`n") }
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
    catch {
        [void][System.Windows.Forms.MessageBox]::Show(
            "Ошибка: $($_.Exception.Message)", 'HH Toolbox', 'OK', 'Error')
    }
    finally {
        if ($frm) {
            $frm.Enabled = $true
            $frm.Cursor  = [System.Windows.Forms.Cursors]::Default
            $frm.Text    = $oldTitle
            $frm.Activate()
        }
    }
}

function Show-GuiMain {
    $form = New-Object System.Windows.Forms.Form
    $form.Text          = "HH Toolbox v$Version"
    $form.Size          = New-Object System.Drawing.Size(560, 720)
    $form.MinimumSize   = New-Object System.Drawing.Size(460, 400)
    $form.StartPosition = 'CenterScreen'
    $script:GuiForm     = $form
    Initialize-DarkForm $form

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.Dock          = 'Fill'
    $flow.FlowDirection = 'TopDown'
    $flow.WrapContents  = $false
    $flow.AutoScroll    = $true
    $flow.BackColor     = $script:Theme.Bg
    $flow.Padding       = New-Object System.Windows.Forms.Padding(12, 8, 12, 8)

    foreach ($e in $Menu) {
        if ($e.Section) { Add-SectionHeader $flow $e.Section; continue }
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text      = $e.Label
        $btn.Width     = 480
        $btn.Height    = 34
        $btn.TextAlign = 'MiddleLeft'
        $btn.Padding   = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
        $btn.Margin    = New-Object System.Windows.Forms.Padding(2, 2, 2, 2)
        Set-FlatButton $btn
        $btn.Tag       = $e
        $btn.Add_Click({ Invoke-GuiAction $this.Tag })
        [void]$flow.Controls.Add($btn)
    }

    $isAdmin = Test-Admin
    $mode = if ($isAdmin) { 'АДМИН' } else { 'обычный пользователь' }
    $head = New-Object System.Windows.Forms.Label
    $head.Dock      = 'Top'
    $head.Height    = 30
    $head.TextAlign = 'MiddleLeft'
    $head.Text      = "   ●  Режим: $mode  ·  v$Version"
    $head.Font      = $script:Theme.FontBold
    $head.BackColor = $script:Theme.Bg
    $head.ForeColor = if ($isAdmin) { $script:Theme.AccentText } else { $script:Theme.TextDim }

    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock      = 'Bottom'
    $bar.Height    = 46
    $bar.Padding   = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
    $bar.BackColor = $script:Theme.Bg

    $btnAdm  = New-Object System.Windows.Forms.Button; $btnAdm.Text  = 'От администратора'; $btnAdm.Width = 160; $btnAdm.Height = 28
    $btnExit = New-Object System.Windows.Forms.Button; $btnExit.Text = 'Выход';             $btnExit.Width = 90;  $btnExit.Height = 28
    Set-FlatButton $btnAdm
    Set-FlatButton $btnExit
    $btnAdm.Add_Click({ Invoke-GuiAdminRestart })
    $btnExit.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    # Если включено — пункт уходит в своё окно консоли, GUI не блокируется.
    $chkCon = New-Object System.Windows.Forms.CheckBox
    $chkCon.Text      = 'Запускать в отдельной консоли'
    $chkCon.Width     = 220
    $chkCon.Height    = 28
    $chkCon.ForeColor = $script:Theme.Text
    $chkCon.BackColor = $script:Theme.Bg
    $script:RunInConsole = $chkCon

    $bar.Controls.AddRange(@($btnAdm, $btnExit, $chkCon))

    # Встроенная «консоль»: сюда уходит весь вывод Write-Host из скрипта.
    $log = New-Object System.Windows.Forms.TextBox
    $log.Dock       = 'Bottom'
    $log.Height     = 180
    $log.Multiline  = $true
    $log.ReadOnly   = $true
    $log.ScrollBars = 'Vertical'
    $log.BorderStyle = 'FixedSingle'
    $log.BackColor  = $script:Theme.ConsoleBg
    $log.ForeColor  = $script:Theme.Text
    $log.Font       = $script:Theme.Mono
    $script:LogBox  = $log

    $btnClr = New-Object System.Windows.Forms.Button
    $btnClr.Text = 'Очистить лог'; $btnClr.Width = 120; $btnClr.Height = 28
    Set-FlatButton $btnClr
    $btnClr.Add_Click({ $log.Clear() }.GetNewClosure())
    $bar.Controls.Add($btnClr)

    $form.Controls.Add($flow)   # Fill — первым
    $form.Controls.Add($head)   # Top
    $form.Controls.Add($log)    # Bottom (над панелью кнопок)
    $form.Controls.Add($bar)    # Bottom — последним, докается первым
    $form.CancelButton = $btnExit

    # Пока открыт GUI, консольного окна не видно.
    Hide-ConsoleWindow
    [void]$form.ShowDialog()
    $form.Dispose()
    # Вернуть консоль: menu.ps1 после этого делает exit, а при отдельном
    # запуске gui.ps1 сеанс не должен остаться с невидимым окном.
    Show-ConsoleWindow
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
    Initialize-DarkForm $f

    $mk = {
        param($text, $top)
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $text; $l.Left = 16; $l.Top = $top + 3; $l.Width = 155
        Set-DarkLabel $l
        $f.Controls.Add($l)
    }.GetNewClosure()
    $num = {
        param($top, $min, $max, $val, $dec)
        $n = New-Object System.Windows.Forms.NumericUpDown
        $n.Left = 180; $n.Top = $top; $n.Width = 110
        $n.Minimum = $min; $n.Maximum = $max; $n.DecimalPlaces = $dec; $n.Value = $val
        Set-DarkInput $n
        $f.Controls.Add($n); $n
    }.GetNewClosure()
    $cmb = {
        param($top, $items, $idx)
        $c = New-Object System.Windows.Forms.ComboBox
        $c.Left = 180; $c.Top = $top; $c.Width = 150; $c.DropDownStyle = 'DropDownList'
        foreach ($i in $items) { [void]$c.Items.Add($i) }
        $c.SelectedIndex = $idx
        Set-DarkInput $c
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
    $btnAuto.Text = 'Пересчитать битрейт'; $btnAuto.Left = 300; $btnAuto.Top = 192; $btnAuto.Width = 165; $btnAuto.Height = 26
    Set-FlatButton $btnAuto
    $f.Controls.Add($btnAuto)

    $grp = New-Object System.Windows.Forms.GroupBox
    $grp.Text = 'Что посчитать'; $grp.Left = 16; $grp.Top = 258; $grp.Width = 590; $grp.Height = 92
    $grp.ForeColor = $script:Theme.AccentText
    $rbSpace = New-Object System.Windows.Forms.RadioButton
    $rbSpace.Text = 'Объём диска на N дней'; $rbSpace.Left = 14; $rbSpace.Top = 22; $rbSpace.Width = 200; $rbSpace.Checked = $true
    $rbSpace.ForeColor = $script:Theme.Text
    $nDays = New-Object System.Windows.Forms.NumericUpDown
    $nDays.Left = 220; $nDays.Top = 20; $nDays.Width = 90; $nDays.Minimum = 1; $nDays.Maximum = 3650; $nDays.Value = 30
    Set-DarkInput $nDays
    $rbTime = New-Object System.Windows.Forms.RadioButton
    $rbTime.Text = 'На сколько дней хватит'; $rbTime.Left = 14; $rbTime.Top = 54; $rbTime.Width = 200
    $rbTime.ForeColor = $script:Theme.Text
    $nSize = New-Object System.Windows.Forms.NumericUpDown
    $nSize.Left = 220; $nSize.Top = 52; $nSize.Width = 90; $nSize.Minimum = 0.1; $nSize.Maximum = 100000
    $nSize.DecimalPlaces = 1; $nSize.Value = 4
    Set-DarkInput $nSize
    $cUnit = New-Object System.Windows.Forms.ComboBox
    $cUnit.Left = 320; $cUnit.Top = 52; $cUnit.Width = 70; $cUnit.DropDownStyle = 'DropDownList'
    [void]$cUnit.Items.AddRange(@('TB', 'GB')); $cUnit.SelectedIndex = 0
    Set-DarkInput $cUnit
    $grp.Controls.AddRange(@($rbSpace, $nDays, $rbTime, $nSize, $cUnit))
    $f.Controls.Add($grp)

    $out = New-Object System.Windows.Forms.TextBox
    $out.Left = 16; $out.Top = 360; $out.Width = 590; $out.Height = 148
    $out.Multiline = $true; $out.ReadOnly = $true; $out.ScrollBars = 'Vertical'
    $out.BorderStyle = 'FixedSingle'
    $out.BackColor = $script:Theme.ConsoleBg
    $out.ForeColor = $script:Theme.Text
    $out.Font = $script:Theme.Mono
    $f.Controls.Add($out)

    $btnCalc = New-Object System.Windows.Forms.Button
    $btnCalc.Text = 'Посчитать'; $btnCalc.Left = 16; $btnCalc.Top = 518; $btnCalc.Width = 120; $btnCalc.Height = 28
    Set-FlatButton $btnCalc -Primary
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Закрыть'; $btnClose.Left = 490; $btnClose.Top = 518; $btnClose.Width = 116; $btnClose.Height = 28
    Set-FlatButton $btnClose
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $f.Controls.AddRange(@($btnCalc, $btnClose))
    $f.CancelButton = $btnClose

    # ВАЖНО: внутри .GetNewClosure() область $script: — это модуль замыкания, а не
    # скрипт, поэтому $script:DahuaMin там был бы $null. Берём локальную копию —
    # она попадает в замыкание как обычная переменная.
    $dahuaMin = $script:DahuaMin

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
            $min  = $dahuaMin[[string]$cRes.SelectedItem]
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
    Initialize-DarkForm $f

    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Top'; $bar.Height = 92
    $bar.BackColor = $script:Theme.Bg

    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = 'Хост / IP:'; $lbl.Left = 12; $lbl.Top = 16; $lbl.Width = 70
    Set-DarkLabel $lbl
    $tbHost = New-Object System.Windows.Forms.TextBox
    $tbHost.Left = 84; $tbHost.Top = 13; $tbHost.Width = 190; $tbHost.Text = '8.8.8.8'
    Set-DarkInput $tbHost
    $bar.Controls.AddRange(@($lbl, $tbHost))

    $out = New-Object System.Windows.Forms.TextBox
    $out.Dock = 'Fill'; $out.Multiline = $true; $out.ReadOnly = $true
    $out.ScrollBars = 'Both'; $out.WordWrap = $false
    $out.BorderStyle = 'None'
    $out.BackColor = $script:Theme.ConsoleBg
    $out.ForeColor = $script:Theme.Text
    $out.Font = $script:Theme.Mono

    # Вывод идёт ПОТОКОМ, построчно (как в консоли): окно не «висит», результат
    # виден по мере поступления, а DoEvents оставляет форму отзывчивой.
    $run = {
        param($title, $sb)
        $out.Text = "=== $title ===`r`n"
        $f.Refresh()
        try {
            & $sb 2>&1 | ForEach-Object {
                $out.AppendText(([string]$_) + "`r`n")
                [System.Windows.Forms.Application]::DoEvents()
            }
        } catch {
            $out.AppendText('Ошибка: ' + $_.Exception.Message + "`r`n")
        }
        $out.AppendText("=== готово ===`r`n")
    }.GetNewClosure()

    $addBtn = {
        param($text, $left, $top, $width, $action)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text; $b.Left = $left; $b.Top = $top; $b.Width = $width; $b.Height = 26
        Set-FlatButton $b
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
    # ping.exe/tracert -d вместо Test-Connection: выводят построчно и без
    # медленного разрешения имён — результат идёт сразу, а не через 10-15 секунд.
    & $addBtn 'Ping' 244 52 80 {
        & $run "ping $($tbHost.Text)" { ping.exe -n 4 $tbHost.Text }
    }.GetNewClosure()
    & $addBtn 'Tracert' 330 52 90 {
        & $run "tracert $($tbHost.Text)" { tracert.exe -d $tbHost.Text }
    }.GetNewClosure()
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

# --- Управление окном консоли (скрыть/показать) ---
if (-not ('HH.Win32' -as [type])) {
    Add-Type -Namespace HH -Name Win32 -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
[DllImport("user32.dll")]   public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("dwmapi.dll")]   public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);
'@ -ErrorAction SilentlyContinue
}
function Hide-ConsoleWindow {
    try { $h = [HH.Win32]::GetConsoleWindow(); if ($h -ne [IntPtr]::Zero) { [void][HH.Win32]::ShowWindow($h, 0) } } catch { $null = $_ }
}
function Show-ConsoleWindow {
    try { $h = [HH.Win32]::GetConsoleWindow(); if ($h -ne [IntPtr]::Zero) { [void][HH.Win32]::ShowWindow($h, 5) } } catch { $null = $_ }
}

# Ввод: пока открыт GUI — окно ввода вместо консольного Read-Host.
function Read-Host {
    param([Parameter(Position = 0)]$Prompt, [switch]$AsSecureString)
    # Пароль через InputBox не спрашиваем: он был бы обычным текстом, а потом
    # его пришлось бы «превращать» в SecureString — это лишь видимость защиты.
    # Отдаём настоящему Read-Host, временно показав консоль.
    if ($AsSecureString) {
        Show-ConsoleWindow
        try { return Microsoft.PowerShell.Utility\Read-Host @PSBoundParameters }
        finally { Hide-ConsoleWindow }
    }
    if (-not $script:LogBox) { return Microsoft.PowerShell.Utility\Read-Host @PSBoundParameters }
    return [Microsoft.VisualBasic.Interaction]::InputBox([string]$Prompt, 'HH Toolbox', '')
}

# --- «Консоль» внутри окна: весь Write-Host скрипта уходит в лог-панель GUI ---
function Write-Host {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromPipeline = $true, ValueFromRemainingArguments = $true)]$Object,
        [switch]$NoNewline,
        $Separator,
        $ForegroundColor,
        $BackgroundColor
    )
    process {
        if ($script:LogBox) {
            $script:LogBox.AppendText(($Object -join ' ') + $(if ($NoNewline) { '' } else { "`r`n" }))
            [System.Windows.Forms.Application]::DoEvents()
        } else {
            # Панели ещё нет (старт) — пишем в настоящую консоль.
            Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
        }
    }
}

# Write-Box вызывает Clear-Host — чистим лог-панель, а не консоль.
function Clear-Host {
    if ($script:LogBox) { $script:LogBox.Clear() } else { try { [Console]::Clear() } catch { $null = $_ } }
}

# Внешние консольные скрипты (MAS, Win11Debloat, стресс-тест) рисуют собственное
# меню и читают клавиши напрямую — в TextBox их не затащить. Поэтому открываем
# им ОТДЕЛЬНОЕ окно консоли, а главную консоль так и держим скрытой.
function Invoke-Remote {
    param([string]$Url)
    $cmd = "irm '$Url' | iex"
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($cmd))
    Start-Process powershell -ArgumentList @(
        '-NoExit', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-EncodedCommand', $enc)
    Write-Host "   Запущено в отдельном окне консоли: $Url"
}

# Обёртка над оригинальным Install-Item: после каждого пакета отдаём время UI,
# чтобы окно не выглядело зависшим между установками.
$OrigInstallItem = ${function:Install-Item}
function Install-Item {
    param($p)
    $r = & $OrigInstallItem $p
    [System.Windows.Forms.Application]::DoEvents()
    return $r
}

Show-GuiMain

# Флаг для menu.ps1: окно отработало — консольное меню не нужно. Ставим ПОСЛЕ
# показа окна: если GUI упадёт, флаг останется $false и menu.ps1 откроет консоль.
# Через Set-Variable: читает его вызывающий скрипт, PSScriptAnalyzer этого не видит.
Set-Variable -Name GuiStarted -Value $true
