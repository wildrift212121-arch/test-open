
; ============================
;   MOUSE CONTROL MODULE
;   mouse.au3

; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf



; -----------------------------------------
; APPLY MOUSE SETTINGS (GUI → globals)
; -----------------------------------------
Func Mouse_ApplySettings()
    $K_move = Number(GUICtrlRead($g_inKMove))
    $K_click = Number(GUICtrlRead($g_inKClick))

    $g_bInvX = _IsChecked($g_chkInvX)
    $g_bInvY = _IsChecked($g_chkInvY)
    $g_bSmooth = _IsChecked($g_chkSmooth)

    $g_iMinMove = Int(GUICtrlRead($g_inMinMove))

    IniWrite($INI, "Mouse", "K_move", $K_move)
    IniWrite($INI, "Mouse", "K_click", $K_click)
    IniWrite($INI, "Mouse", "InvX", $g_bInvX ? 1 : 0)
    IniWrite($INI, "Mouse", "InvY", $g_bInvY ? 1 : 0)
    IniWrite($INI, "Mouse", "Smooth", $g_bSmooth ? 1 : 0)
    IniWrite($INI, "Mouse", "MinMove", $g_iMinMove)

    _Log("Настройки мыши применены")
EndFunc


; -----------------------------------------
; RELATIVE MOUSE MOVE (route playback)
; -----------------------------------------
Func Mouse_MoveRel($dx, $dy)
    Local $mx = Number($dx)
    Local $my = Number($dy)

    If $g_bInvX Then $mx = -$mx
    If $g_bInvY Then $my = -$my

    If $g_bSmooth Then
        If Abs($mx) < $g_iMinMove And Abs($my) < $g_iMinMove Then Return
    EndIf

    Local $moveX = Int($mx * $K_move)
    Local $moveY = Int($my * $K_move)

    If $moveX = 0 And $moveY = 0 Then Return

    DD_MoveRel($moveX, $moveY)
EndFunc


; -----------------------------------------
; MOUSE BUTTON HANDLER
; btn = "LEFT" / "RIGHT"
; state = "DOWN" / "UP"
; -----------------------------------------
Func Mouse_Btn($btn, $state)
    Local $code

    If $btn = "LEFT" Then
        $code = ($state = "DOWN") ? 1 : 2
    Else
        $code = ($state = "DOWN") ? 4 : 8
    EndIf

    DD_Btn($code)
EndFunc


; -----------------------------------------
; HUMAN-LIKE CLICK (absolute)
; used in death handler
; -----------------------------------------
Func Mouse_HumanClick($baseX, $baseY)
    Local $offsetX = Random(-3, 3, 1)
    Local $offsetY = Random(-3, 3, 1)

    Local $tx = $baseX + $offsetX
    Local $ty = $baseY + $offsetY

    Local $pos = MouseGetPos()
    Local $cx = $pos[0]
    Local $cy = $pos[1]

    Local $steps = Random(25, 40, 1)

    For $i = 1 To $steps
        Local $k = $i / $steps
        Local $nx = $cx + ($tx - $cx) * $k + Random(-1, 1, 1)
        Local $ny = $cy + ($ty - $cy) * $k + Random(-1, 1, 1)

        DD_MoveAbs($nx, $ny)
        Sleep(Random(5, 12))
    Next

    Sleep(Random(40, 80))

    DD_Btn(1) ; LDOWN
    Sleep(Random(110, 160))
    DD_Btn(2) ; LUP

    Sleep(Random(80, 140))
EndFunc
