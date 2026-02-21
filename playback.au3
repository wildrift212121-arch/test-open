; playback.au3
; Version: 2026-02-22-fast-drag
; Быстрый drag: любое движение мыши через DD_movR(dx, dy), независимо от состояния кнопок

If @ScriptName <> "main.au3" Then Exit

Global $g_hDD, $g_bInvX, $g_bInvY, $g_bSmooth, $g_iMinMove, $K_move
Global $g_hStatus, $g_aRoute

Global $g_bPlayback = False
Global $g_iPlaybackIndex = 1
Global $g_tPlaybackStart = 0
Global $g_iLastWaitingIndex = -1

Global $BtnHeld[3] = [False, False, False]
Global Const $PLAYBACK_DEBUG = True

Func Min($a, $b)
    Return ($a < $b) ? $a : $b
EndFunc
Func Max($a, $b)
    Return ($a > $b) ? $a : $b
EndFunc

Func Playback_Start()
    If $g_bPlayback Then Return
    If Not IsArray($g_aRoute) Or $g_aRoute[0] = 0 Then Return
    If Not AION_Activate() Then Return

    $g_bPlayback = True
    $g_iPlaybackIndex = 1
    $g_tPlaybackStart = TimerInit()
    $g_iLastWaitingIndex = -1

    For $i = 0 To 2
        $BtnHeld[$i] = False
    Next

    If IsDeclared("g_hStatus") And $g_hStatus <> 0 Then GUICtrlSetData($g_hStatus, "Воспроизведение...")
EndFunc

Func Playback_Stop()
    If Not $g_bPlayback Then Return
    $g_bPlayback = False
    Key_ReleaseAll()
    For $i = 0 To 2
        If $BtnHeld[$i] Then
            _Playback_MouseBtnByIdx($i, "UP")
            $BtnHeld[$i] = False
        EndIf
    Next
    If IsDeclared("g_hStatus") And $g_hStatus <> 0 Then GUICtrlSetData($g_hStatus, "Остановлено")
EndFunc

Func Playback_Process()
    If Not $g_bPlayback Then Return
    If Not IsArray($g_aRoute) Or $g_aRoute[0] = 0 Then
        Playback_Stop()
        Return
    EndIf

    If $g_iPlaybackIndex > $g_aRoute[0] Then
        Playback_Stop()
        Return
    EndIf

    Local $line = $g_aRoute[$g_iPlaybackIndex]
    If StringStripWS($line, 8) = "" Or StringLeft($line, 1) = "[" Then
        $g_iPlaybackIndex += 1
        $g_iLastWaitingIndex = -1
        Return
    EndIf

    Local $p = StringSplit($line, ":", 1)
    If $p[0] < 2 Then
        $g_iPlaybackIndex += 1
        $g_iLastWaitingIndex = -1
        Return
    EndIf
    Local $t = Number($p[1])
    Local $now = TimerDiff($g_tPlaybackStart) / 1000.0
    Local $delta = $t - $now
    If $delta > 0.02 Then
        Local $sleepMs = Int(Max(($delta - 0.01) * 1000, 10))
        Sleep($sleepMs)
        Return
    EndIf
    $g_iLastWaitingIndex = -1

    Local $type = $p[2]
    Switch $type
        Case "MOUSE_ABS"
            ; Начальная абсолютная позиция — перемещаем мышь DD_mov
            If $p[0] >= 4 Then
                Local $absX = Number($p[3])
                Local $absY = Number($p[4])
                If $g_hDD <> -1 Then DllCall($g_hDD, "int", "DD_mov", "int", $absX, "int", $absY)
            EndIf
        Case "MOUSE"
            ; — ВСЕГДА двигай мышь через DD_movR (быстро), независимо от кнопок!
            If $p[0] >= 4 Then _Playback_MouseMove($p[3], $p[4])
        Case "MOUSE_BTN"
            If $p[0] >= 4 Then _Playback_MouseBtn($p[3], $p[4])
        Case Else
            If $p[0] >= 3 Then _Playback_Key(Number($p[2]), $p[3])
    EndSwitch

    $g_iPlaybackIndex += 1
EndFunc

Func _Playback_Key($dd, $state)
    Local $mode = ($state = "DOWN") ? 1 : 2
    If $g_hDD <> -1 Then DllCall($g_hDD, "int", "DD_key", "int", $dd, "int", $mode)
EndFunc

Func _Playback_MouseMove($dx, $dy)
    Local $mx = Number($dx)
    Local $my = Number($dy)
    If $g_bInvX Then $mx = -$mx
    If $g_bInvY Then $my = -$my
    ; — ВСЕГДА DD_movR (быстро)! Даже если кнопка мыши удержана
    If ($mx <> 0 Or $my <> 0) And $g_hDD <> -1 Then
        DllCall($g_hDD, "int", "DD_movR", "int", $mx, "int", $my)
    EndIf
EndFunc

Func _Playback_MouseBtn($btn, $state)
    Local $idx = ($btn = "LEFT") ? 0 : (($btn = "RIGHT") ? 1 : 2)
    Local $code = 0
    Switch $btn
        Case "LEFT"
            $code = ($state = "DOWN") ? 1 : 2
        Case "RIGHT"
            $code = ($state = "DOWN") ? 4 : 8
        Case "MIDDLE"
            $code = ($state = "DOWN") ? 16 : 32
    EndSwitch
    $BtnHeld[$idx] = ($state = "DOWN")
    If $g_hDD <> -1 Then DllCall($g_hDD, "int", "DD_btn", "int", $code)
EndFunc

Func _Playback_MouseBtnByIdx($idx, $state)
    Local $code = 0
    Switch $idx
        Case 0
            $code = ($state = "DOWN") ? 1 : 2
        Case 1
            $code = ($state = "DOWN") ? 4 : 8
        Case 2
            $code = ($state = "DOWN") ? 16 : 32
    EndSwitch
    If $g_hDD <> -1 Then DllCall($g_hDD, "int", "DD_btn", "int", $code)
EndFunc