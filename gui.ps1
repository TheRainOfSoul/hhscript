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

# raw.githubusercontent -> cdn.jsdelivr.net (зеркало на другом CDN), иначе $null.
function ConvertTo-JsDelivr {
    param([string]$Url)
    if ($Url -match '^https?://raw\.githubusercontent\.com/([^/]+)/([^/]+)/([^/]+)/(.+)$') {
        return "https://cdn.jsdelivr.net/gh/$($Matches[1])/$($Matches[2])@$($Matches[3])/$($Matches[4])"
    }
    return $null
}

# Текст удалённого скрипта: сперва raw, при сбое — зеркало jsDelivr. BOM срезаем.
function Get-RemoteText {
    param([string]$Url)
    $urls = @($Url); $alt = ConvertTo-JsDelivr $Url; if ($alt) { $urls += $alt }
    $lastErr = $null
    foreach ($u in $urls) {
        try { return ([string](Invoke-RestMethod -Uri $u -ErrorAction Stop)).TrimStart([char]0xFEFF) }
        catch { $lastErr = $_ }
    }
    throw $lastErr
}

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
# DPI-осознанность процесса ДО первого окна: иначе Windows растягивает окна
# битмапом на масштабе 125/150% (мыло). SetHighDpiMode в WinPS 5.1 недоступен,
# манифеста у irm-скрипта нет — поэтому System-DPI-aware через P/Invoke, а
# раскладку каждой формы масштабируем вручную в Initialize-DarkForm.
try {
    Add-Type -Namespace HH -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();' -ErrorAction Stop
    [void][HH.Dpi]::SetProcessDPIAware()
} catch { $null = $_ }
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
    Font        = New-Object System.Drawing.Font('Segoe UI', 9.75)                                  # база: кнопки, поля
    FontBold    = New-Object System.Drawing.Font('Segoe UI', 9.75, [System.Drawing.FontStyle]::Bold) # строка режима, главные кнопки
    FontHeader  = New-Object System.Drawing.Font('Segoe UI', 10.5, [System.Drawing.FontStyle]::Bold) # заголовки секций/групп
    Mono        = New-Object System.Drawing.Font('Consolas', 9.5)                                   # лог и поля вывода
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
    # High-DPI: авто-скейл WinForms для программных форм не срабатывает, а
    # Form.Scale() надёжно тянет раскладку и размеры. Масштабируем в Load —
    # когда все дочерние контролы уже добавлены. На 100% (96 DPI) фактор = 1.0
    # → Scale пропускается, поведение ровно как было.
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
    $form.Add_Load({
            param($s, $e)
            try {
                $g = $s.CreateGraphics(); $dpi = $g.DpiX; $g.Dispose()
                $factor = [double]$dpi / 96.0
                if ($factor -gt 1.01) { $s.Scale([System.Drawing.SizeF]::new($factor, $factor)) }
            } catch { $null = $_ }
        })
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
    $lbl.Font      = $script:Theme.FontHeader
    $lbl.ForeColor = $script:Theme.AccentText
    $lbl.AutoSize  = $false
    $lbl.Width     = 486
    $lbl.Height    = 26
    $lbl.TextAlign = 'BottomLeft'
    $lbl.Padding   = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)   # текст вровень с текстом кнопок
    $lbl.Margin    = New-Object System.Windows.Forms.Padding(0, 16, 0, 0)
    [void]$flow.Controls.Add($lbl)
    $div = New-Object System.Windows.Forms.Panel
    $div.Width     = 486
    $div.Height    = 1
    $div.BackColor = $script:Theme.Border
    $div.Margin    = New-Object System.Windows.Forms.Padding(0, 3, 0, 8)
    [void]$flow.Controls.Add($div)
    # Заголовок и разделитель занимают всю ширину строки, а кнопки секции
    # начинаются с новой строки — секция всегда стоит колонкой(ами) под шапкой.
    $flow.SetFlowBreak($lbl, $true)
    $flow.SetFlowBreak($div, $true)
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
        # Get-RemoteText: чистит BOM (иначе iex падает) и при сбое raw берёт jsDelivr.
        Invoke-Expression (Get-RemoteText $MenuUrl)
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
    # Пустой ImageList задаёт высоту строки — иначе строки с галочками слишком тесные.
    $il = New-Object System.Windows.Forms.ImageList
    $il.ImageSize     = New-Object System.Drawing.Size(1, 26)
    $lv.SmallImageList = $il
    [void]$lv.Columns.Add('', 590)

    # Состояние галочек храним отдельно от видимых строк: фильтр прячет строки,
    # но отметки скрытых пунктов не теряются. Ключ — исходный индекс пункта.
    $checkState = @{}
    for ($i = 0; $i -lt $Items.Count; $i++) { $checkState[$i] = $DefaultChecked }
    $st = @{ rebuilding = $false }

    # Перестроить список под текст фильтра. Группы создаём лениво — пустые
    # (без видимых пунктов) не показываем.
    $rebuild = {
        param($filter)
        $st.rebuilding = $true
        $lv.BeginUpdate()
        $lv.Items.Clear()
        $lv.Groups.Clear()
        $needle = ([string]$filter).Trim().ToLower()
        $grpText = $null; $grpObj = $null
        for ($i = 0; $i -lt $Items.Count; $i++) {
            if ($Headers -and $Headers.ContainsKey($i)) { $grpText = $Headers[$i]; $grpObj = $null }
            if ($needle -and ($Items[$i].ToLower().IndexOf($needle) -lt 0)) { continue }
            $row = New-Object System.Windows.Forms.ListViewItem($Items[$i])
            $row.Tag = $i
            if ($grpText) {
                if (-not $grpObj) { $grpObj = New-Object System.Windows.Forms.ListViewGroup($grpText); [void]$lv.Groups.Add($grpObj) }
                $row.Group = $grpObj
            }
            [void]$lv.Items.Add($row)
            $row.Checked = [bool]$checkState[$i]
        }
        $lv.EndUpdate()
        $st.rebuilding = $false
    }.GetNewClosure()

    # Пользователь щёлкнул галочку — запоминаем (но не во время перестройки списка).
    $lv.Add_ItemChecked({
        param($src, $e)
        if (-not $st.rebuilding) { $checkState[[int]$e.Item.Tag] = $e.Item.Checked }
    }.GetNewClosure())

    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock      = 'Bottom'
    $bar.Height    = 52
    $bar.Padding   = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)
    $bar.BackColor = $script:Theme.Bg

    $btnOk   = New-Object System.Windows.Forms.Button; $btnOk.Text   = 'Применить';    $btnOk.Width   = 112; $btnOk.Height   = 32
    $btnCan  = New-Object System.Windows.Forms.Button; $btnCan.Text  = 'Отмена';       $btnCan.Width  = 92;  $btnCan.Height  = 32
    $btnAll  = New-Object System.Windows.Forms.Button; $btnAll.Text  = 'Отметить всё'; $btnAll.Width  = 122; $btnAll.Height  = 32
    $btnNone = New-Object System.Windows.Forms.Button; $btnNone.Text = 'Снять всё';    $btnNone.Width = 102; $btnNone.Height = 32
    Set-FlatButton $btnOk -Primary
    Set-FlatButton $btnCan
    Set-FlatButton $btnAll
    Set-FlatButton $btnNone

    $btnOk.DialogResult  = [System.Windows.Forms.DialogResult]::OK
    $btnCan.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $btnAll.Add_Click({  foreach ($x in $lv.Items) { $x.Checked = $true } }.GetNewClosure())
    $btnNone.Add_Click({ foreach ($x in $lv.Items) { $x.Checked = $false } }.GetNewClosure())

    # Поле фильтра сверху: печатаешь — список сужается по подстроке.
    $top = New-Object System.Windows.Forms.Panel
    $top.Dock = 'Top'; $top.Height = 38; $top.BackColor = $script:Theme.Bg
    $lblF = New-Object System.Windows.Forms.Label
    $lblF.Text = 'Фильтр:'; $lblF.Left = 10; $lblF.Top = 9; $lblF.Width = 54; $lblF.Height = 22
    $lblF.TextAlign = 'MiddleLeft'; Set-DarkLabel $lblF
    $search = New-Object System.Windows.Forms.TextBox
    $search.Left = 66; $search.Top = 7; $search.Width = 548; $search.Height = 24
    $search.Anchor = 'Top, Left, Right'
    Set-DarkInput $search
    $search.Add_TextChanged({ & $rebuild $search.Text }.GetNewClosure())
    $top.Controls.AddRange(@($lblF, $search))

    $bar.Controls.AddRange(@($btnOk, $btnCan, $btnAll, $btnNone))
    & $rebuild ''                # первичное заполнение списка
    $form.Controls.Add($lv)      # Fill добавляем первым
    $form.Controls.Add($bar)     # Bottom
    $form.Controls.Add($top)     # Top — добавлен последним, окажется сверху
    $form.CancelButton = $btnCan  # AcceptButton не ставим: Enter в поле фильтра не должен «Применить»

    $res = $form.ShowDialog()
    $sel = @()
    if ($res -eq [System.Windows.Forms.DialogResult]::OK) {
        for ($i = 0; $i -lt $Items.Count; $i++) { if ($checkState[$i]) { $sel += $i } }
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
    $flow.FlowDirection = 'LeftToRight'   # кнопки идут слева направо и переносятся —
    $flow.WrapContents  = $true           # чем шире окно, тем больше столбцов
    $flow.AutoScroll    = $true
    $flow.BackColor     = $script:Theme.Bg
    $flow.Padding       = New-Object System.Windows.Forms.Padding(14, 10, 14, 12)

    foreach ($e in $Menu) {
        if ($e.Section) { Add-SectionHeader $flow $e.Section; continue }
        $btn = New-Object System.Windows.Forms.Button
        $btn.Text      = $e.Label
        $btn.Width     = 486   # стартовая ширина; дальше её пересчитывает $reflow
        $btn.Height    = 36
        $btn.TextAlign = 'MiddleLeft'
        $btn.Padding   = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        $btn.Margin    = New-Object System.Windows.Forms.Padding(0, 0, 8, 8)
        Set-FlatButton $btn
        $btn.Tag       = $e
        $btn.Add_Click({ Invoke-GuiAction $this.Tag })
        [void]$flow.Controls.Add($btn)
    }

    $isAdmin = Test-Admin
    $mode = if ($isAdmin) { 'АДМИН' } else { 'обычный пользователь' }
    $head = New-Object System.Windows.Forms.Label
    $head.Dock      = 'Top'
    $head.Height    = 34
    $head.TextAlign = 'MiddleLeft'
    $head.Text      = "   ●  Режим: $mode  ·  v$Version"
    $head.Font      = $script:Theme.FontBold
    $head.BackColor = $script:Theme.Bg
    $head.ForeColor = if ($isAdmin) { $script:Theme.AccentText } else { $script:Theme.TextDim }

    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock      = 'Bottom'
    $bar.Height    = 52
    $bar.Padding   = New-Object System.Windows.Forms.Padding(10, 10, 10, 10)
    $bar.BackColor = $script:Theme.Bg

    $btnAdm  = New-Object System.Windows.Forms.Button; $btnAdm.Text  = 'От администратора'; $btnAdm.Width = 160; $btnAdm.Height = 32
    $btnExit = New-Object System.Windows.Forms.Button; $btnExit.Text = 'Выход';             $btnExit.Width = 90;  $btnExit.Height = 32
    Set-FlatButton $btnAdm
    Set-FlatButton $btnExit
    $btnAdm.Add_Click({ Invoke-GuiAdminRestart })
    $btnExit.DialogResult = [System.Windows.Forms.DialogResult]::Cancel

    # Если включено — пункт уходит в своё окно консоли, GUI не блокируется.
    $chkCon = New-Object System.Windows.Forms.CheckBox
    $chkCon.Text      = 'Запускать в отдельной консоли'
    $chkCon.Width     = 220
    $chkCon.Height    = 32
    $chkCon.TextAlign = 'MiddleLeft'
    $chkCon.Margin    = New-Object System.Windows.Forms.Padding(8, 3, 3, 3)
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
    $btnClr.Text = 'Очистить лог'; $btnClr.Width = 120; $btnClr.Height = 32
    Set-FlatButton $btnClr
    $btnClr.Add_Click({ $log.Clear() }.GetNewClosure())
    $bar.Controls.Add($btnClr)

    # Подпись над журналом.
    $cap = New-Object System.Windows.Forms.Label
    $cap.Dock      = 'Bottom'
    $cap.Height    = 22
    $cap.Text      = '   Журнал'
    $cap.TextAlign = 'MiddleLeft'
    $cap.Font      = $script:Theme.FontBold
    $cap.ForeColor = $script:Theme.TextDim
    $cap.BackColor = $script:Theme.Bg

    $form.Controls.Add($flow)   # Fill — первым
    $form.Controls.Add($head)   # Top
    $form.Controls.Add($cap)    # Bottom — подпись, окажется над логом
    $form.Controls.Add($log)    # Bottom — над панелью кнопок
    $form.Controls.Add($bar)    # Bottom — последним, докается первым (самый низ)
    $form.CancelButton = $btnExit

    # --- Адаптивные столбцы: чем шире окно, тем больше кнопок в ряд ---
    # Заголовки/разделители тянутся на всю доступную ширину, а кнопки делят её
    # поровну между столбцами. $state.busy гасит повторный вход, когда изменение
    # размера кнопок само вызывает SizeChanged (напр. из-за полосы прокрутки).
    $state = @{ busy = $false }
    $reflow = {
        if ($state.busy) { return }
        $state.busy = $true
        $flow.SuspendLayout()
        $avail = $flow.ClientSize.Width - $flow.Padding.Horizontal
        if (-not $flow.VerticalScroll.Visible) {
            $avail -= [System.Windows.Forms.SystemInformation]::VerticalScrollBarWidth
        }
        if ($avail -lt 120) { $avail = 120 }
        $minBtn = 260; $gap = 8
        $cols = [int][Math]::Max(1, [Math]::Floor(($avail + $gap) / ($minBtn + $gap)))
        $btnW = [int][Math]::Floor($avail / $cols) - $gap
        if ($btnW -lt 120) { $btnW = 120 }
        foreach ($c in $flow.Controls) {
            if ($c -is [System.Windows.Forms.Button]) { $c.Width = $btnW }
            else { $c.Width = $avail - 2 }   # заголовок/разделитель — во всю ширину
        }
        $flow.ResumeLayout()
        $state.busy = $false
    }.GetNewClosure()
    $flow.Add_SizeChanged($reflow)
    $form.Add_Shown($reflow)

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
        $l.Text = $text; $l.Left = 18; $l.Top = $top; $l.Width = 158; $l.Height = 23
        $l.AutoSize = $false; $l.TextAlign = 'MiddleLeft'   # текст по центру строки поля
        Set-DarkLabel $l
        $f.Controls.Add($l)
    }.GetNewClosure()
    $num = {
        param($top, $min, $max, $val, $dec)
        $n = New-Object System.Windows.Forms.NumericUpDown
        $n.Left = 185; $n.Top = $top; $n.Width = 110
        $n.Minimum = $min; $n.Maximum = $max; $n.DecimalPlaces = $dec; $n.Value = $val
        Set-DarkInput $n
        $f.Controls.Add($n); $n
    }.GetNewClosure()
    $cmb = {
        param($top, $items, $idx)
        $c = New-Object System.Windows.Forms.ComboBox
        $c.Left = 185; $c.Top = $top; $c.Width = 150; $c.DropDownStyle = 'DropDownList'
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
    $f.Size          = New-Object System.Drawing.Size(900, 640)
    $f.MinimumSize   = New-Object System.Drawing.Size(660, 460)
    $f.StartPosition = 'CenterScreen'
    Initialize-DarkForm $f

    # Строка «Хост / IP» и «Порт» — отдельная панель сверху.
    $hostPanel = New-Object System.Windows.Forms.Panel
    $hostPanel.Dock = 'Top'; $hostPanel.Height = 44
    $hostPanel.BackColor = $script:Theme.Bg
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = 'Хост / IP:'; $lbl.Left = 12; $lbl.Top = 12; $lbl.Width = 72; $lbl.Height = 23
    $lbl.TextAlign = 'MiddleLeft'
    Set-DarkLabel $lbl
    $tbHost = New-Object System.Windows.Forms.TextBox
    $tbHost.Left = 88; $tbHost.Top = 10; $tbHost.Width = 200; $tbHost.Text = '8.8.8.8'
    Set-DarkInput $tbHost
    $lblPort = New-Object System.Windows.Forms.Label
    $lblPort.Text = 'Порт:'; $lblPort.Left = 302; $lblPort.Top = 12; $lblPort.Width = 42; $lblPort.Height = 23
    $lblPort.TextAlign = 'MiddleLeft'
    Set-DarkLabel $lblPort
    $tbPort = New-Object System.Windows.Forms.TextBox
    $tbPort.Left = 348; $tbPort.Top = 10; $tbPort.Width = 80; $tbPort.Text = '554'
    Set-DarkInput $tbPort
    $hostPanel.Controls.AddRange(@($lbl, $tbHost, $lblPort, $tbPort))

    # Ряд кнопок — FlowLayoutPanel с равными интервалами (переносится по ширине окна,
    # AutoScroll — на случай, если кнопок больше, чем влезает в высоту при узком окне).
    $btnRow = New-Object System.Windows.Forms.FlowLayoutPanel
    $btnRow.Dock = 'Top'; $btnRow.Height = 150; $btnRow.WrapContents = $true
    $btnRow.AutoScroll = $true
    $btnRow.BackColor = $script:Theme.Bg
    $btnRow.Padding = New-Object System.Windows.Forms.Padding(8, 6, 8, 6)

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

    # Быстрая проверка TCP-порта: TcpClient с таймаутом 2с. Test-NetConnection
    # на закрытом порту ждал бы до ~20с и морозил окно — здесь этого нет.
    $portCheck = {
        param($p)
        $h = $tbHost.Text.Trim()
        & $run "порт $h : $p" {
            $client = New-Object System.Net.Sockets.TcpClient
            try {
                $iar = $client.BeginConnect($h, [int]$p, $null, $null)
                if ($iar.AsyncWaitHandle.WaitOne(2000) -and $client.Connected) {
                    "Порт $p ОТКРЫТ на $h"
                } else {
                    "Порт $p закрыт или недоступен на $h (таймаут 2с)"
                }
            } catch { "Ошибка: $($_.Exception.Message)" }
            finally { $client.Close() }
        }.GetNewClosure()
    }.GetNewClosure()

    # Непрерывный «Ping -t»: раз в секунду один ping -n 1 (эквивалент -t), но с
    # чистой остановкой и без заморозки окна. $pingTimer.Enabled = флаг «идёт».
    $pingTimer = New-Object System.Windows.Forms.Timer
    $pingTimer.Interval = 1000
    $pingTimer.Add_Tick({
        $h = $tbHost.Text.Trim()
        if (-not $h) { return }
        # Строку ответа берём locale-независимо: первая непустая после заголовка
        # (работает и на русской, и на английской Windows).
        $lines = @(ping.exe -n 1 -w 800 $h 2>&1)
        # Среди непустых строк [0] — заголовок «Pinging…»/«Обмен пакетами…»,
        # [1] — сам ответ/таймаут. Берём [1] (locale-независимо), заголовок пропускаем.
        $body  = @($lines | Where-Object { $_.Trim() })
        $reply = if ($body.Count -ge 2) { ([string]$body[1]).Trim() }
                 elseif ($body.Count -eq 1) { ([string]$body[0]).Trim() }
                 else { '(нет ответа)' }
        $out.AppendText(('{0}  {1}' -f (Get-Date -Format 'HH:mm:ss'), $reply) + "`r`n")
        $out.SelectionStart = $out.TextLength
        $out.ScrollToCaret()
    }.GetNewClosure())

    $addBtn = {
        param($text, $width, $action)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text; $b.Width = $width; $b.Height = 30
        $b.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 4)
        Set-FlatButton $b
        $b.Add_Click($action)
        $btnRow.Controls.Add($b)
    }.GetNewClosure()

    # --- Диагностика ---
    & $addBtn 'ipconfig /all' 118 { & $run 'ipconfig /all' { ipconfig /all } }.GetNewClosure()
    & $addBtn 'Адаптеры' 96 {
        & $run 'Адаптеры' {
            Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -EQ 'Up' | ForEach-Object {
                $ip = (Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Select-Object -First 1).IPAddress
                '{0,-28} IP {1,-15} MAC {2}  {3}' -f $_.Name, $ip, $_.MacAddress, $_.LinkSpeed
            }
        }
    }.GetNewClosure()
    & $addBtn 'Конфигурация' 118 {
        & $run 'Get-NetIPConfiguration' { Get-NetIPConfiguration | Out-String -Stream }
    }.GetNewClosure()
    # ping.exe/tracert -d вместо Test-Connection: выводят построчно и без
    # медленного разрешения имён — результат идёт сразу, а не через 10-15 секунд.
    & $addBtn 'Ping' 78 {
        & $run "ping $($tbHost.Text)" { ping.exe -n 4 $tbHost.Text }
    }.GetNewClosure()
    & $addBtn 'Tracert' 88 {
        & $run "tracert $($tbHost.Text)" { tracert.exe -d $tbHost.Text }
    }.GetNewClosure()
    # «Ping -t» — отдельной кнопкой: нужна ссылка на неё, чтобы менять текст Старт/Стоп.
    $btnPingT = New-Object System.Windows.Forms.Button
    $btnPingT.Text = 'Ping -t'; $btnPingT.Width = 112; $btnPingT.Height = 30
    $btnPingT.Margin = New-Object System.Windows.Forms.Padding(0, 0, 6, 4)
    Set-FlatButton $btnPingT
    $btnPingT.Add_Click({
        if ($pingTimer.Enabled) {
            $pingTimer.Stop()
            $btnPingT.Text = 'Ping -t'
            $out.AppendText("=== ping -t остановлен ===`r`n")
        } else {
            $h = $tbHost.Text.Trim()
            $out.Text = "=== ping -t $h  (клик ещё раз — стоп) ===`r`n"
            $btnPingT.Text = 'Стоп ping -t'
            $pingTimer.Start()
        }
    }.GetNewClosure())
    $btnRow.Controls.Add($btnPingT)
    & $addBtn 'pathping' 92 {
        & $run "pathping $($tbHost.Text)" { pathping.exe -n $tbHost.Text }
    }.GetNewClosure()
    & $addBtn 'nslookup' 96 {
        & $run "nslookup $($tbHost.Text)" { nslookup.exe $tbHost.Text 2>&1 }
    }.GetNewClosure()
    & $addBtn 'netstat' 90 { & $run 'netstat -ano' { netstat.exe -ano } }.GetNewClosure()
    & $addBtn 'arp -a' 74 { & $run 'arp -a' { arp.exe -a } }.GetNewClosure()
    & $addBtn 'route' 74 { & $run 'route print' { route.exe print } }.GetNewClosure()
    & $addBtn 'getmac' 88 { & $run 'getmac /v' { getmac.exe /v /fo list } }.GetNewClosure()

    # --- Порт-чек (поле «Порт» + пресеты портов камер) ---
    & $addBtn 'Проверить порт' 130 { & $portCheck ($tbPort.Text.Trim()) }.GetNewClosure()
    & $addBtn 'RTSP 554' 92 { & $portCheck 554 }.GetNewClosure()
    & $addBtn 'HTTP 80' 88 { & $portCheck 80 }.GetNewClosure()
    & $addBtn 'Dahua 37777' 112 { & $portCheck 37777 }.GetNewClosure()
    & $addBtn 'Hik 8000' 92 { & $portCheck 8000 }.GetNewClosure()

    # --- DNS ---
    & $addBtn 'DNS → 1.1.1.1' 122 {
        Switch-Dns '1.1.1.1', '1.0.0.1'; & $run 'DNS' { Get-DnsClientServerAddress -AddressFamily IPv4 | Out-String -Stream }
    }.GetNewClosure()
    & $addBtn 'DNS → 8.8.8.8' 122 {
        Switch-Dns '8.8.8.8', '8.8.4.4'; & $run 'DNS' { Get-DnsClientServerAddress -AddressFamily IPv4 | Out-String -Stream }
    }.GetNewClosure()
    & $addBtn 'DNS → авто' 108 {
        Switch-Dns @(); & $run 'DNS' { Get-DnsClientServerAddress -AddressFamily IPv4 | Out-String -Stream }
    }.GetNewClosure()
    & $addBtn 'Очистить DNS' 118 { & $run 'ipconfig /flushdns' { ipconfig /flushdns } }.GetNewClosure()
    & $addBtn 'Показать кэш' 120 { & $run 'ipconfig /displaydns' { ipconfig /displaydns } }.GetNewClosure()

    # --- DHCP / Wi-Fi / прочее ---
    & $addBtn 'Обновить DHCP' 128 {
        & $run 'ipconfig /release + /renew' { ipconfig /release; ipconfig /renew }
    }.GetNewClosure()
    & $addBtn 'Wi-Fi' 74 { & $run 'netsh wlan show interfaces' { netsh wlan show interfaces } }.GetNewClosure()
    & $addBtn 'Внешний IP' 110 {
        & $run 'Внешний IP' {
            try { 'Внешний IP: ' + (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 6) }
            catch { 'Не удалось получить внешний IP: ' + $_.Exception.Message }
        }
    }.GetNewClosure()

    # Полный скан портов через RustScan + Nmap (версии сервисов) — в отдельной консоли.
    & $addBtn 'RustScan + Nmap' 140 { Invoke-RustScan $tbHost.Text }.GetNewClosure()

    & $addBtn 'Сброс сети (нужен админ)' 190 {
        Repair-Network; & $run 'Сброс сети' { 'Выполнено. Подробности — в окне консоли. Требуется перезагрузка.' }
    }.GetNewClosure()

    $f.Controls.Add($out)       # Fill — первым
    $f.Controls.Add($btnRow)    # Top — ряд кнопок
    $f.Controls.Add($hostPanel) # Top — добавлен последним, окажется сверху
    [void]$f.ShowDialog()
    $pingTimer.Stop(); $pingTimer.Dispose()   # непрерывный пинг не должен пережить окно
    $f.Dispose()
}

# =====================================================================
#  2c. Сканер сети — окно со списком найденных устройств.
#  Считает теми же Get-LanBase / Get-LanDevices из menu.ps1.
# =====================================================================
function Show-GuiRtsp {
    param([string]$IP)
    $f = New-Object System.Windows.Forms.Form
    $f.Text = 'RTSP-поток в VLC'
    $f.Size = New-Object System.Drawing.Size(452, 330)
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false; $f.StartPosition = 'CenterParent'
    Initialize-DarkForm $f

    $tb = @{}
    $y = 18
    foreach ($r in @(@('IP камеры:', 'ip', [string]$IP), @('Логин:', 'user', 'admin'), @('Пароль:', 'pass', ''), @('Порт:', 'port', '554'))) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $r[0]; $l.Left = 16; $l.Top = $y + 2; $l.Width = 92; $l.Height = 22; $l.TextAlign = 'MiddleLeft'
        Set-DarkLabel $l; $f.Controls.Add($l)
        $t = New-Object System.Windows.Forms.TextBox
        $t.Left = 114; $t.Top = $y; $t.Width = 300; $t.Text = [string]$r[2]
        Set-DarkInput $t; $f.Controls.Add($t); $tb[$r[1]] = $t
        $y += 32
    }
    $lv = New-Object System.Windows.Forms.Label
    $lv.Text = 'Вендор:'; $lv.Left = 16; $lv.Top = $y + 2; $lv.Width = 92; $lv.Height = 22; $lv.TextAlign = 'MiddleLeft'
    Set-DarkLabel $lv; $f.Controls.Add($lv)
    $cb = New-Object System.Windows.Forms.ComboBox
    $cb.Left = 114; $cb.Top = $y; $cb.Width = 300; $cb.DropDownStyle = 'DropDownList'
    Set-DarkInput $cb
    [void]$cb.Items.AddRange(@('Dahua', 'Hikvision', 'Uniview', 'Свой путь'))
    $cb.SelectedIndex = 0; $f.Controls.Add($cb); $y += 32

    $lp = New-Object System.Windows.Forms.Label
    $lp.Text = 'Путь:'; $lp.Left = 16; $lp.Top = $y + 2; $lp.Width = 92; $lp.Height = 22; $lp.TextAlign = 'MiddleLeft'
    Set-DarkLabel $lp; $f.Controls.Add($lp)
    $tPath = New-Object System.Windows.Forms.TextBox
    $tPath.Left = 114; $tPath.Top = $y; $tPath.Width = 300; $tPath.Text = 'cam/realmonitor?channel=1&subtype=0'
    Set-DarkInput $tPath; $f.Controls.Add($tPath); $y += 42

    $presets = @{ 'Dahua' = 'cam/realmonitor?channel=1&subtype=0'; 'Hikvision' = 'Streaming/Channels/101'; 'Uniview' = 'unicast/c1/s0/live'; 'Свой путь' = '' }
    $cb.Add_SelectedIndexChanged({ $v = [string]$presets[[string]$cb.SelectedItem]; if ($v) { $tPath.Text = $v } }.GetNewClosure())

    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = 'Открыть в VLC'; $btn.Left = 114; $btn.Top = $y; $btn.Width = 150; $btn.Height = 30
    Set-FlatButton $btn -Primary; $f.Controls.Add($btn)
    $btn.Add_Click({
        $vlc = Get-VlcPath
        if (-not $vlc) {
            [void][System.Windows.Forms.MessageBox]::Show('VLC не найден. Установи VLC в разделе «Программы».', 'RTSP', 'OK', 'Warning'); return
        }
        $ip = $tb['ip'].Text.Trim()
        if (-not $ip) { return }
        # Логин/пароль экранируем: у камер часто пароли вида Admin#123 (@ : / # ? ломают URL).
        $auth = if ($tb['user'].Text) { "$([Uri]::EscapeDataString($tb['user'].Text)):$([Uri]::EscapeDataString($tb['pass'].Text))@" } else { '' }
        $path = $tPath.Text.TrimStart('/')
        $port = $tb['port'].Text.Trim(); if (-not $port) { $port = '554' }
        $url = "rtsp://$auth${ip}:$port/$path"
        try { Start-Process $vlc -ArgumentList $url; $f.Close() }
        catch { [void][System.Windows.Forms.MessageBox]::Show("Не удалось запустить VLC:`n$($_.Exception.Message)", 'RTSP', 'OK', 'Error') }
    }.GetNewClosure())

    $f.AcceptButton = $btn                       # Enter — открыть в VLC
    $f.KeyPreview = $true
    $f.Add_KeyDown({ if ($_.KeyCode -eq [System.Windows.Forms.Keys]::Escape) { $f.Close() } }.GetNewClosure())
    [void]$f.ShowDialog(); $f.Dispose()
}

function Show-GuiNetworkScan {
    $f = New-Object System.Windows.Forms.Form
    $f.Text          = 'Сканер сети'
    $f.Size          = New-Object System.Drawing.Size(800, 560)
    $f.MinimumSize   = New-Object System.Drawing.Size(600, 400)
    $f.StartPosition = 'CenterScreen'
    Initialize-DarkForm $f

    $bar = New-Object System.Windows.Forms.Panel
    $bar.Dock = 'Top'; $bar.Height = 44; $bar.BackColor = $script:Theme.Bg
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = 'Подсеть:'; $lbl.Left = 12; $lbl.Top = 12; $lbl.Width = 62; $lbl.Height = 23; $lbl.TextAlign = 'MiddleLeft'
    Set-DarkLabel $lbl
    $tb = New-Object System.Windows.Forms.TextBox
    $tb.Left = 78; $tb.Top = 10; $tb.Width = 150; $tb.Text = (Get-LanBase)
    Set-DarkInput $tb
    $suffix = New-Object System.Windows.Forms.Label
    $suffix.Text = '.1-254'; $suffix.Left = 230; $suffix.Top = 12; $suffix.Width = 52; $suffix.Height = 23; $suffix.TextAlign = 'MiddleLeft'
    Set-DarkLabel $suffix
    $btnScan = New-Object System.Windows.Forms.Button
    $btnScan.Text = 'Сканировать'; $btnScan.Left = 290; $btnScan.Top = 9; $btnScan.Width = 100; $btnScan.Height = 28
    Set-FlatButton $btnScan -Primary
    $btnDb = New-Object System.Windows.Forms.Button
    $btnDb.Text = 'Обновить базу'; $btnDb.Left = 396; $btnDb.Top = 9; $btnDb.Width = 110; $btnDb.Height = 28
    Set-FlatButton $btnDb
    $btnRtsp = New-Object System.Windows.Forms.Button
    $btnRtsp.Text = 'RTSP в VLC'; $btnRtsp.Left = 512; $btnRtsp.Top = 9; $btnRtsp.Width = 92; $btnRtsp.Height = 28
    Set-FlatButton $btnRtsp
    $btnRtsp.Add_Click({ Show-GuiRtsp -IP '' }.GetNewClosure())
    $status = New-Object System.Windows.Forms.Label
    $status.Left = 610; $status.Top = 12; $status.Width = 170; $status.Height = 23; $status.TextAlign = 'MiddleLeft'
    $status.Anchor = 'Top, Left, Right'
    Set-DarkLabel $status
    $status.Text = 'ПКМ — меню · 2× — веб'
    $tip = New-Object System.Windows.Forms.ToolTip
    $tip.AutoPopDelay = 12000; $tip.InitialDelay = 400
    $tip.SetToolTip($btnScan, 'Пинг-скан подсети + проба портов камер (камеры выделяются цветом)')
    $tip.SetToolTip($btnRtsp, 'Открыть RTSP-поток камеры в VLC (можно ввести IP вручную)')
    $tip.SetToolTip($btnDb, 'Перекачать базу вендоров по MAC (OUI) — удобно заранее в офисе')
    # Принудительно перекачать базу вендоров (удобно скачать заранее в офисе).
    $btnDb.Add_Click({
        $status.Text = 'Обновляю базу вендоров...'
        $btnDb.Enabled = $false
        $f.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $f.Refresh(); [System.Windows.Forms.Application]::DoEvents()
        try {
            Get-OuiDatabase -Force | Out-Null
            $status.Text = "База вендоров: $(Get-OuiCount) записей"
        } catch {
            $status.Text = 'Не удалось обновить базу'
        } finally {
            $btnDb.Enabled = $true
            $f.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    }.GetNewClosure())
    $bar.Controls.AddRange(@($lbl, $tb, $suffix, $btnScan, $btnDb, $btnRtsp, $status))

    $lv = New-Object System.Windows.Forms.ListView
    $lv.Dock = 'Fill'; $lv.View = 'Details'; $lv.FullRowSelect = $true
    $lv.BorderStyle = 'None'; $lv.BackColor = $script:Theme.ConsoleBg; $lv.ForeColor = $script:Theme.Text; $lv.Font = $script:Theme.Font
    [void]$lv.Columns.Add('IP', 150)
    [void]$lv.Columns.Add('MAC', 175)
    [void]$lv.Columns.Add('Вендор', 110)
    [void]$lv.Columns.Add('Имя', 200)
    [void]$lv.Columns.Add('Порты', 130)

    # Копирование: ПКМ — ячейка под курсором или вся строка; Ctrl+C — строка.
    $hit = @{ item = $null; sub = $null }
    $lv.Add_MouseDown({
        if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Right) {
            $h = $lv.HitTest($_.Location); $hit.item = $h.Item; $hit.sub = $h.SubItem
        }
    }.GetNewClosure())
    $copy = {
        param($t)
        if ($t) { try { [System.Windows.Forms.Clipboard]::SetText([string]$t) } catch { $null = $_ } }
    }.GetNewClosure()
    $rowText = { param($it) ($it.SubItems | ForEach-Object { $_.Text }) -join "`t" }.GetNewClosure()
    $cm = New-Object System.Windows.Forms.ContextMenuStrip
    $miWeb = $cm.Items.Add('Открыть веб-интерфейс')
    $miWeb.Add_Click({ if ($hit.item) { Start-Process ('http://' + $hit.item.SubItems[0].Text) } }.GetNewClosure())
    $miRtsp = $cm.Items.Add('Открыть RTSP в VLC')
    $miRtsp.Add_Click({ if ($hit.item) { Show-GuiRtsp -IP $hit.item.SubItems[0].Text } }.GetNewClosure())
    [void]$cm.Items.Add((New-Object System.Windows.Forms.ToolStripSeparator))
    $miCell = $cm.Items.Add('Копировать ячейку')
    $miCell.Add_Click({ if ($hit.sub) { & $copy $hit.sub.Text } }.GetNewClosure())
    $miRow = $cm.Items.Add('Копировать строку')
    $miRow.Add_Click({ if ($hit.item) { & $copy (& $rowText $hit.item) } }.GetNewClosure())
    # Меню могли открыть с клавиатуры (Menu/Shift+F10) или после пересканирования —
    # тогда $hit устарел. Обновляем из выделения, если ссылка мертва.
    $cm.Add_Opening({
        if ((-not $hit.item) -or (-not $lv.Items.Contains($hit.item))) {
            if ($lv.SelectedItems.Count) { $hit.item = $lv.SelectedItems[0]; $hit.sub = $null }
            else { $hit.item = $null; $hit.sub = $null }
        }
    }.GetNewClosure())
    $lv.ContextMenuStrip = $cm
    $lv.Add_KeyDown({
        if ($_.Control -and $_.KeyCode -eq [System.Windows.Forms.Keys]::C -and $lv.SelectedItems.Count) {
            & $copy (& $rowText $lv.SelectedItems[0])
        }
    }.GetNewClosure())
    $tip.SetToolTip($lv, 'Камеры выделены цветом · 2× клик — веб-интерфейс · ПКМ — RTSP/копировать · клик по заголовку — сортировка')
    # Двойной клик по устройству — открыть его веб-интерфейс.
    $lv.Add_DoubleClick({ if ($lv.SelectedItems.Count) { Start-Process ('http://' + $lv.SelectedItems[0].SubItems[0].Text) } }.GetNewClosure())
    # Сортировка по клику на заголовок: IP — по версии, порты — по первому числу, прочее — строкой.
    $sortState = @{ col = -1; asc = $true }
    $lv.Add_ColumnClick({
        $col = $_.Column
        if ($sortState.col -eq $col) { $sortState.asc = -not $sortState.asc } else { $sortState.col = $col; $sortState.asc = $true }
        $keyed = @($lv.Items | ForEach-Object { [pscustomobject]@{ It = $_; Key = $_.SubItems[$col].Text } })
        if ($col -eq 0) {
            $sorted = @($keyed | Sort-Object -Property @{ Expression = { try { [version]$_.Key } catch { $_.Key } } })
        } elseif ($col -eq 4) {
            $sorted = @($keyed | Sort-Object -Property @{ Expression = { $n = (($_.Key -split ',')[0] -replace '\D'); if ($n) { [int]$n } else { 999999 } } })
        } else {
            $sorted = @($keyed | Sort-Object Key)
        }
        if (-not $sortState.asc) { [array]::Reverse($sorted) }
        $lv.BeginUpdate(); $lv.Items.Clear(); foreach ($s in $sorted) { [void]$lv.Items.Add($s.It) }; $lv.EndUpdate()
    }.GetNewClosure())

    # Локальная копия: $script: внутри .GetNewClosure() указывает на модуль замыкания,
    # а не на скоуп скрипта (подвох проекта) — там $script:Theme = $null и ForeColor
    # упал бы на первой же камере. Захватываем цвет в локальную переменную.
    $accent = $script:Theme.AccentText
    $btnScan.Add_Click({
        $base = $tb.Text.Trim()
        $status.Text = "Сканирую $base.1-254 ..."
        $btnScan.Enabled = $false; $btnDb.Enabled = $false; $btnRtsp.Enabled = $false
        $f.Cursor = [System.Windows.Forms.Cursors]::WaitCursor
        $f.Refresh(); [System.Windows.Forms.Application]::DoEvents()
        try {
            # Прогресс-колбэк пампит DoEvents — окно остаётся отзывчивым во время скана.
            $prog = { param($m) $status.Text = $m; [System.Windows.Forms.Application]::DoEvents() }.GetNewClosure()
            $devs = Get-LanDevices -Base $base -Progress $prog
            $portMap = Get-CameraPortMap -IPs @($devs.IP) -Progress $prog
            $lv.BeginUpdate(); $lv.Items.Clear()
            $camCount = 0
            foreach ($d in $devs) {
                $it = New-Object System.Windows.Forms.ListViewItem($d.IP)
                [void]$it.SubItems.Add($(if ($d.MAC) { $d.MAC } else { '—' }))
                [void]$it.SubItems.Add($d.Vendor)
                [void]$it.SubItems.Add($d.Name)
                $ports = $portMap[$d.IP]
                [void]$it.SubItems.Add($(if ($ports) { ($ports -join ',') } else { '' }))
                # Камера: открыт RTSP(554) или вендор — известный камерный.
                $isCam = ($ports -contains 554) -or (@('Dahua', 'Hikvision', 'Uniview', 'Axis') -contains $d.Vendor)
                if ($isCam) { $it.ForeColor = $accent; $camCount++ }
                [void]$lv.Items.Add($it)
            }
            $lv.EndUpdate()
            $status.Text = "Найдено: $($devs.Count), камер: $camCount"
        } catch {
            $status.Text = 'Ошибка: ' + $_.Exception.Message
        } finally {
            $btnScan.Enabled = $true; $btnDb.Enabled = $true; $btnRtsp.Enabled = $true
            $f.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    }.GetNewClosure())

    $f.Controls.Add($lv)
    $f.Controls.Add($bar)
    [void]$f.ShowDialog()
    $f.Dispose()
}

# =====================================================================
#  Утилиты debloat/твики — модальное окно выбора. Клик запускает утилиту
#  (в отдельной консоли / приложением / браузером), окно просто закрываешь.
# =====================================================================
function Show-GuiUtilityMenu {
    $f = New-Object System.Windows.Forms.Form
    $f.Text            = 'Утилиты: debloat и твики'
    $f.Size            = New-Object System.Drawing.Size(440, 270)
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition   = 'CenterScreen'
    Initialize-DarkForm $f

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.Dock = 'Fill'; $flow.FlowDirection = 'TopDown'; $flow.WrapContents = $false
    $flow.Padding = New-Object System.Windows.Forms.Padding(16, 14, 16, 14)
    $flow.BackColor = $script:Theme.Bg
    $mk = {
        param($text, $action)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text; $b.Width = 384; $b.Height = 42; $b.TextAlign = 'MiddleLeft'
        $b.Padding = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
        $b.Margin = New-Object System.Windows.Forms.Padding(2, 3, 2, 3)
        Set-FlatButton $b
        $b.Add_Click($action)
        [void]$flow.Controls.Add($b)
    }.GetNewClosure()
    & $mk 'WinUtil (Chris Titus)'          { Invoke-Remote 'https://christitus.com/win' }.GetNewClosure()
    & $mk 'Win11Debloat (Raphire)'         { Invoke-Remote 'https://debloat.raphi.re/' }.GetNewClosure()
    & $mk 'SophiApp (GUI, галочки)'         { Invoke-SophiApp }.GetNewClosure()

    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock = 'Bottom'; $bar.Height = 50; $bar.Padding = New-Object System.Windows.Forms.Padding(16, 8, 16, 8)
    $bar.BackColor = $script:Theme.Bg
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Закрыть'; $btnClose.Width = 120; $btnClose.Height = 32
    Set-FlatButton $btnClose
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bar.Controls.Add($btnClose)

    $f.Controls.Add($flow)
    $f.Controls.Add($bar)
    $f.CancelButton = $btnClose
    [void]$f.ShowDialog()
    $f.Dispose()
}

# =====================================================================
#  Проверка на вирусы/майнеры — модальное окно. Клик запускает сканер
#  (Defender — в консоли; портейбл-сканеры качаются свежими и стартуют),
#  окно просто закрываешь.
# =====================================================================
function Show-GuiSecurityScan {
    $f = New-Object System.Windows.Forms.Form
    $f.Text            = 'Проверка на вирусы / майнеры'
    $f.Size            = New-Object System.Drawing.Size(460, 470)
    $f.FormBorderStyle = 'FixedDialog'; $f.MaximizeBox = $false; $f.MinimizeBox = $false
    $f.StartPosition   = 'CenterScreen'
    Initialize-DarkForm $f

    $flow = New-Object System.Windows.Forms.FlowLayoutPanel
    $flow.Dock = 'Fill'; $flow.FlowDirection = 'TopDown'; $flow.WrapContents = $false
    $flow.Padding = New-Object System.Windows.Forms.Padding(16, 14, 16, 14)
    $flow.BackColor = $script:Theme.Bg
    $mk = {
        param($text, $action)
        $b = New-Object System.Windows.Forms.Button
        $b.Text = $text; $b.Width = 404; $b.Height = 40; $b.TextAlign = 'MiddleLeft'
        $b.Padding = New-Object System.Windows.Forms.Padding(12, 0, 0, 0)
        $b.Margin = New-Object System.Windows.Forms.Padding(2, 3, 2, 3)
        Set-FlatButton $b
        $b.Add_Click($action)
        [void]$flow.Controls.Add($b)
    }.GetNewClosure()
    & $mk 'Defender — быстрый скан (встроен)' { Invoke-DefenderScan -Type Quick }.GetNewClosure()
    & $mk 'Defender — полный скан (встроен)'  { Invoke-DefenderScan -Type Full }.GetNewClosure()
    & $mk 'KVRT — Kaspersky Virus Removal Tool' { Invoke-SecurityTool 'https://devbuilds.s.kaspersky-labs.com/devbuilds/KVRT/latest/full/KVRT.exe' 'KVRT.exe' }.GetNewClosure()
    & $mk 'Emsisoft Emergency Kit'            { Invoke-SecurityTool 'https://dl.emsisoft.com/EmsisoftEmergencyKit.exe' 'EmsisoftEmergencyKit.exe' }.GetNewClosure()
    & $mk 'AdwCleaner — реклама/PUP/тулбары'   { Invoke-SecurityTool 'https://downloads.malwarebytes.com/file/adwcleaner' 'AdwCleaner.exe' }.GetNewClosure()
    & $mk 'Dr.Web CureIt! (сайт)'             { Start-Process 'https://free.drweb.com/cureit/' }.GetNewClosure()
    # Триаж печатает отчёт через Write-Host, а он здесь уходит в лог-панель
    # главного окна — за модальным диалогом её не видно. Поэтому кнопка только
    # помечает форму и закрывает окно, а сам запуск идёт после ShowDialog.
    # Метку кладём в $f.Tag, а НЕ в $script:-переменную: кнопки создаются через
    # .GetNewClosure(), и у замыкания своя область $script: — запись туда наружу
    # не видна, кнопка молча ничего бы не делала. Форма же общая по ссылке.
    & $mk 'Триаж — искать то, что сканеры не видят' { $f.Tag = 'triage'; $f.Close() }.GetNewClosure()

    $bar = New-Object System.Windows.Forms.FlowLayoutPanel
    $bar.Dock = 'Bottom'; $bar.Height = 50; $bar.Padding = New-Object System.Windows.Forms.Padding(16, 8, 16, 8)
    $bar.BackColor = $script:Theme.Bg
    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = 'Закрыть'; $btnClose.Width = 120; $btnClose.Height = 32
    Set-FlatButton $btnClose
    $btnClose.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $bar.Controls.Add($btnClose)

    $f.Controls.Add($flow)
    $f.Controls.Add($bar)
    $f.CancelButton = $btnClose
    [void]$f.ShowDialog()
    $runTriage = ($f.Tag -eq 'triage')
    $f.Dispose()

    if ($runTriage) {
        # Триаж читает HKLM, службы, задачи и журналы — без админа половина
        # проверок молча вернёт пустоту, что хуже честного отказа. Спрашиваем
        # тем же способом, что и остальные админские пункты GUI.
        if (-not (Test-Admin)) {
            $ask = [System.Windows.Forms.MessageBox]::Show(
                "Триаж читает системный реестр, службы и журналы — нужны права администратора.`nПерезапустить от имени администратора?",
                'HH Toolbox', 'YesNo', 'Question')
            if ($ask -eq [System.Windows.Forms.DialogResult]::Yes) { Invoke-GuiAdminRestart }
            return
        }
        Write-Log 'GUI: Триаж'
        Invoke-Triage
    }
}

# --- Подменяем консольные версии оконными ($Menu менять не нужно) ---
function Show-StorageCalc { Show-GuiStorageCalc }
function Show-NetworkMenu { Show-GuiNetwork }
function Show-NetworkScan { Show-GuiNetworkScan }
function Show-UtilityMenu { Show-GuiUtilityMenu }
function Show-SecurityScan { Show-GuiSecurityScan }

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
