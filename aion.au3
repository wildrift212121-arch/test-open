; ============================
;   AION WINDOW MODULE
;   aion.au3
; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf




; -----------------------------------------
; FIND AION WINDOW
; -----------------------------------------
Func AION_FindWindow()
    Local $h = WinGetHandle($g_sAionTitle)

    If $h = "" Then
        _BotLog("Окно AION не найдено")
        Return 0
    EndIf

    _BotLog("Окно AION найдено: " & $h)
    Return $h
EndFunc


; -----------------------------------------
; FIND AION WINDOW (Alias for compatibility)
; Returns: window handle or 0
; -----------------------------------------
Func AION_Find()
    Local $h = WinGetHandle($g_sAionTitle)
    If @error Then
        Return 0
    EndIf
    Return $h
EndFunc


; -----------------------------------------
; ACTIVATE AION WINDOW
; -----------------------------------------
Func AION_Activate()
    Local $h = AION_FindWindow()
    If $h = 0 Then Return False

    WinActivate($h)
    Sleep(150)

    If WinActive($h) Then
        _BotLog("Окно AION активировано")
        Return True
    Else
        _BotLog("Не удалось активировать окно AION")
        Return False
    EndIf
EndFunc


; -----------------------------------------
; CHECK IF AION IS ACTIVE
; -----------------------------------------
Func AION_IsActive()
    Local $h = WinGetHandle($g_sAionTitle)
    If $h = "" Then Return False

    Return WinActive($h)
EndFunc


; -----------------------------------------
; FORCE FOCUS (if needed)
; -----------------------------------------
Func AION_EnsureFocus()
    If Not AION_IsActive() Then
        _BotLog("AION не в фокусе — активирую")
        AION_Activate()
        Sleep(100)
    EndIf
EndFunc


; -----------------------------------------
; SEND KEY TO AION
; -----------------------------------------
Func AION_SendKey($key)
    AION_EnsureFocus()
    Key_Send($key, "DOWN")
    Sleep(Random(40, 70))
    Key_Send($key, "UP")

    _BotLog("Отправлена клавиша в AION: " & $key)
EndFunc


; -----------------------------------------
; CLICK INSIDE AION
; -----------------------------------------
Func AION_Click($x, $y)
    AION_EnsureFocus()
    MouseClick("left", $x, $y, 1, 0)

    _BotLog("Клик в AION: " & $x & ", " & $y)
EndFunc


; -----------------------------------------
; GET AION WINDOW RECT
; Returns: array [left, top, right, bottom] or 0
; -----------------------------------------
Func AION_GetRect()
    Local $h = AION_FindWindow()
    If $h = 0 Then Return 0

    Local $pos = WinGetPos($h)
    If Not IsArray($pos) Or UBound($pos) < 4 Then Return 0

    Local $rect[4]
    $rect[0] = $pos[0]         ; left
    $rect[1] = $pos[1]         ; top
    $rect[2] = $pos[0] + $pos[2] ; right
    $rect[3] = $pos[1] + $pos[3] ; bottom

    Return $rect
EndFunc
