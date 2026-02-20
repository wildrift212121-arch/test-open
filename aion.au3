; ============================
;   UNIVERSAL WINDOW MODULE
;   aion.au3
; ============================
If @ScriptName <> "main.au3" Then Exit

Global $g_hDD ; объявляем для Au3Check
; Импортируется $g_sWindowTitle из globals.au3

Func AION_FindWindow()
    Local $h = WinGetHandle("[REGEXPTITLE:^" & $g_sWindowTitle & "]")
    If $h = "" Then
        _BotLog("Окно не найдено по заголовку, начинающемуся с '" & $g_sWindowTitle & "'")
        Return 0
    EndIf
    _BotLog("Окно найдено: " & $h)
    Return $h
EndFunc

Func AION_Find()
    Return AION_FindWindow()
EndFunc

Func AION_Activate()
    Local $h = AION_FindWindow()
    If $h = 0 Then Return False
    WinActivate($h)
    Local $t = TimerInit()
    While TimerDiff($t) < 1500
        If WinActive($h) Then
            _BotLog("Окно активировано")
            Return True
        EndIf
        Sleep(50)
    WEnd
    _BotLog("Не удалось активировать окно")
    Return False
EndFunc

Func AION_IsActive()
    Local $h = WinGetHandle("[REGEXPTITLE:^" & $g_sWindowTitle & "]")
    If $h = "" Then Return False
    Return WinActive($h)
EndFunc

Func AION_EnsureFocus()
    If Not AION_IsActive() Then
        _BotLog("Окно не в фокусе — активирую")
        AION_Activate()
        Sleep(100)
    EndIf
EndFunc

Func AION_SendDDKey($dd)
    AION_EnsureFocus()
    DllCall($g_hDD, "int", "DD_key", "int", $dd, "int", 1)
    Sleep(Random(40, 70))
    DllCall($g_hDD, "int", "DD_key", "int", $dd, "int", 2)
EndFunc