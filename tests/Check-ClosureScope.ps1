# =====================================================================
#  Страж от баг-класса «$script: внутри .GetNewClosure()».
#  В замыкании, созданном ВНУТРИ функции, $script: указывает на модуль
#  замыкания, а не на скоуп скрипта → там переменная = $null. Именно это
#  однажды уронило сканер сети (ForeColor = $null). Проверка падает, если
#  такой шаблон найден — используй локальную копию перед замыканием.
# =====================================================================
param([string[]]$Files = @("$PSScriptRoot/../gui.ps1", "$PSScriptRoot/../menu.ps1"))

$bad = 0
foreach ($f in $Files) {
    if (-not (Test-Path $f)) { continue }
    $src = [System.IO.File]::ReadAllText($f, [System.Text.UTF8Encoding]::new($false))
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($src, [ref]$null, [ref]$null)

    # Все вызовы .GetNewClosure()
    $calls = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.InvokeMemberExpressionAst] -and
            "$($n.Member.Extent.Text)" -eq 'GetNewClosure'
        }, $true)

    foreach ($c in $calls) {
        $sb = $c.Expression
        # $script:-переменные внутри самого скриптблока замыкания
        $vars = $sb.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $n.VariablePath.IsScript
            }, $true)
        foreach ($v in $vars) {
            $ln = $v.Extent.StartLineNumber
            Write-Host "::error::$([System.IO.Path]::GetFileName($f)):$ln — `$script: внутри .GetNewClosure() (в замыкании = `$null; сделай локальную копию перед замыканием)"
            Write-Host "      $($v.Extent.Text)"
            $bad++
        }
    }
}

if ($bad) {
    Write-Host "Найдено нарушений: $bad." -ForegroundColor Red
    exit 1
}
Write-Host "Замыкания чисты: `$script: внутри .GetNewClosure() не найдено."
