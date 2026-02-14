; ============================
;   DD WRAPPER MODULE
;   dd.au3
; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf


; -----------------------------------------
; INIT DD
; -----------------------------------------
Func DD_Init()
    If Not FileExists($DD_DLL) Then
        _BotLog("DD_Init: dd60300.dll не найден")
        Return False
    EndIf

    $g_hDD = DllOpen($DD_DLL)
    If $g_hDD = -1 Then
        _BotLog("DD_Init: ошибка открытия dd60300.dll")
        Return False
    EndIf

    ; Инициализация DD
    DllCall($g_hDD, "int", "DD_btn", "int", 0)
    _BotLog("DD_Init: DD инициализирован")

    Return True
EndFunc


; -----------------------------------------
; SHUTDOWN DD
; -----------------------------------------
Func DD_Shutdown()
    If $g_hDD <> -1 Then
        DllClose($g_hDD)
        $g_hDD = -1
        _BotLog("DD_Shutdown: DLL закрыта")
    EndIf
EndFunc


; -----------------------------------------
; PRESS KEY (DOWN/UP)
; dd = DD-код
; mode = 1 (DOWN), 2 (UP)
; -----------------------------------------
Func DD_Key($dd, $mode)
    If $g_hDD = -1 Then Return

    DllCall($g_hDD, "int", "DD_key", "int", $dd, "int", $mode)
EndFunc


; -----------------------------------------
; CLICK MOUSE BUTTON
; code:
;   1 = LDOWN
;   2 = LUP
;   4 = RDOWN
;   8 = RUP
; -----------------------------------------
Func DD_Btn($code)
    If $g_hDD = -1 Then Return

    DllCall($g_hDD, "int", "DD_btn", "int", $code)
EndFunc


; -----------------------------------------
; MOVE MOUSE ABSOLUTE
; (используется в HumanClickDD)
; -----------------------------------------
Func DD_MoveAbs($x, $y)
    If $g_hDD = -1 Then Return

    DllCall($g_hDD, "int", "DD_mov", "int", $x, "int", $y)
EndFunc


; -----------------------------------------
; MOVE MOUSE RELATIVE
; (используется в воспроизведении маршрута)
; -----------------------------------------
Func DD_MoveRel($dx, $dy)
    If $g_hDD = -1 Then Return

    DllCall($g_hDD, "int", "DD_movR", "int", $dx, "int", $dy)
EndFunc
