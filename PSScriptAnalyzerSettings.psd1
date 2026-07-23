@{
    # Правила, отключённые осознанно: для ЭТОГО проекта они срабатывают на
    # архитектурные решения, а не на дефекты. Остальные правила активны.
    ExcludeRules = @(

        # Это интерактивное цветное консольное меню. Write-Host здесь —
        # правильный инструмент (Write-Output/Write-Information не дают цвета и
        # ломают вёрстку). Более того, GUI перехватывает именно Write-Host и
        # перенаправляет вывод во встроенную лог-панель.
        'PSAvoidUsingWriteHost',

        # Вся модель доставки — `irm <url> | iex`: скрипт скачивается в память и
        # выполняется, ничего не пишется на диск. Без Invoke-Expression это
        # невозможно. Загружаются только собственный репозиторий и официальные
        # источники, заданные в коде.
        'PSAvoidUsingInvokeExpression',

        # Ложное срабатывание: параметры Show-CheckList (Title/Color/Headers)
        # используются во вложенных функциях Draw/DrawRow через динамическую
        # область видимости PowerShell, которую анализатор не отслеживает.
        'PSReviewUnusedParameter',

        # gui.ps1 НАМЕРЕННО переопределяет Write-Host / Read-Host / Clear-Host —
        # на этом построена встроенная консоль: вывод уходит в лог-панель окна,
        # а вопросы задаются окном ввода. Без подмены GUI работать не может.
        'PSAvoidOverwritingBuiltInCmdlets',

        # menu.ps1 / gui.ps1 / scripts/*.ps1 доставляются как `irm <url> | iex`.
        # Invoke-RestMethod декодирует ответ через Encoding.GetString, который BOM
        # НЕ срезает: он приходит символом U+FEFF в начало строки, и iex падает
        # («The term '<BOM>#' is not recognized»). То есть BOM здесь ломает саму
        # модель доставки, поэтому файлы намеренно без BOM. Проверяется тестом
        # tests/Test-Delivery.ps1 в CI.
        'PSUseBOMForUnicodeEncodedFile',

        # Ложные/безобидные срабатывания на именах: Switch-Dns (DNS — аббревиатура,
        # а не множественное число) и Get-DahuaDays (термин самого калькулятора
        # Dahua: результат вкладки «Storage Time» измеряется в Days).
        'PSUseSingularNouns'
    )
}
