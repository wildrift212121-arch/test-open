; playback.au3
; Version: 5.0 (2026-02-22)
; - Для drag (при зажатии любой кнопки мыши) — DD_mov (абсолютное движение)
; - Для обычных движений мыши — DD_movR (относительное)
; - Сохраняются все функции, оригинальная логика и статусы

If @ScriptName <> "main.au3" Then Exit

Global $g_hDD, $g_bInvX, $g_bInvY, $g_bSmooth, $g_iMinMove, $K_move
Global $g_hStatus, $g_aRoute

Global $g_bPlayback = False
Global $g_iPlaybackIndex = 1
Global $g_tPlaybackStart = 0
Global $g_iLastWaitingIndex = -1

Global $BtnHeld[3] = [False, False, False]
Global $MustSleepAfterBtn = False
Global Const $PLAYBACK_DEBUG = True

Global $LastAbsX = -1, $LastAbsY = -1

Func _dbg($s)
    If $PLAYBACK_DEBUG Then _BotLog("[PLAYBACK] " & $s)
EndFunc

Func Min($a, $b)
    Return ($a < $b) ? $a : $b
EndFunc
Func Max($a, $b)
    Return ($a > $b) ? $a : $b
EndFunc

Func Playback_Start()
    If $g_bPlayback Then
        _dbg("Playback_Start: уже идёт воспроизведение, игнорирую")
        Return
    EndIf

    If Not IsArray($g_aRoute) Or $g_aRoute[0] = 0 Then
        _BotLog("Playback_Start: маршрут пустой")
        Return
    EndIf

    If Not AION_Activate() Then
        _BotLog("Playback_Start: не удалось активировать AION")
        Return
    EndIf

    $g_bPlayback = True
    $g_iPlaybackIndex = 1
    $g_tPlaybackStart = TimerInit()
    $g_iLastWaitingIndex = -1

    For $i = 0 To 2
        $BtnHeld[$i] = False
    Next

    $LastAbsX = -1
    $LastAbsY = -1
    $MustSleepAfterBtn = False

    If IsDeclared("g_hStatus") And $g_hStatus <> 0 Then GUICtrlSetData($g_hStatus, "Воспроизведение...")
    _BotLog("Playback: старт, строк: " & $g_aRoute[0] & " (slot=" & (Routes_GetCurrentSlot() + 1) & ")")
    _dbg("Начинаю с индекса " & $g_iPlaybackIndex)
EndFunc

Func Playback_Stop()
    If Not $g_bPlayback Then
        Key_ReleaseAll()
        _BotLog("Playback_Stop: вызван при уже остановленном воспроизведении")
        Return
    EndIf

    $g_bPlayback = False
    _BotLog("Playback: остановлено")
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

    If Not IsArray($g_aRoute) Then
        _BotLog("Playback_Process: ошибка — $g_aRoute не массив")
        Playback_Stop()
        Return
    EndIf

    If $g_aRoute[0] = 0 Then
        _BotLog("Playback_Process: маршрут пустой")
        Playback_Stop()
        Return
    EndIf

    If $g_iPlaybackIndex > $g_aRoute[0] Then
        _BotLog("Playback_Process: завершение маршрута")
        Playback_Stop()
        If IsDeclared("Battle_MaybeStartAfterRoute") Then Battle_MaybeStartAfterRoute()
        Return
    EndIf

    Local $line = $g_aRoute[$g_iPlaybackIndex]
    _dbg("Индекс=" & $g_iPlaybackIndex & " | Строка='" & StringStripWS($line, 3) & "'")

    If StringStripWS($line, 8) = "" Then
        $g_iPlaybackIndex += 1
        $g_iLastWaitingIndex = -1
        Return
    EndIf

    If StringLeft($line, 1) = "[" Then
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
    Local $nextT = ($g_iPlaybackIndex < $g_aRoute[0]) ? Number(StringSplit($g_aRoute[$g_iPlaybackIndex + 1], ":", 1)[1]) : $t
    Local $interval = $nextT - $t
    Local $now = TimerDiff($g_tPlaybackStart) / 1000.0
    Local $delta = $t - $now

    If $delta > 0.02 Then
        Local $sleepMs = Int(Min(Max(($delta - 0.01) * 1000, 10), 200))
        If $delta < 0.5 Or $g_iLastWaitingIndex <> $g_iPlaybackIndex Then
            _dbg(StringFormat("До выполнения строки index=%d осталось %.3f сек, сплю %d ms", $g_iPlaybackIndex, $delta, $sleepMs))
            $g_iLastWaitingIndex = $g_iPlaybackIndex
        EndIf
        Sleep($sleepMs)
        Return
    EndIf

    $g_iLastWaitingIndex = -1

    Local $type = $p[2]
    Switch $type
        Case "MOUSE_ABS"
            If $p[0] >= 4 Then
                Local $absX = Number($p[3])
                Local $absY = Number($p[4])
                If $g_hDD <> -1 Then DllCall($g_hDD, "int", "DD_mov", "int", $absX, "int", $absY)
                $LastAbsX = $absX
                $LastAbsY = $absY
                Sleep(10)
            EndIf
        Case "MOUSE"
            If $p[0] >= 4 Then _Playback_MouseMove($p[3], $p[4], $interval)
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

Func _Playback_MouseMove($dx, $dy, $interval)
    Local $mx = Number($dx)
    Local $my = Number($dy)
    If $g_bInvX Then $mx = -$mx
    If $g_bInvY Then $my = -$my

    ; Инициализация LastAbsX/Y по первой точке маршрута
    If $LastAbsX = -1 Or $LastAbsY = -1 Then
        ; Найти первую MOUSE_ABS в маршруте
        For $i = 1 To $g_aRoute[0]
            Local $pl = StringSplit($g_aRoute[$i], ":", 1)
            If $pl[0] >= 4 And $pl[2] = "MOUSE_ABS" Then
                $LastAbsX = Number($pl[3])
                $LastAbsY = Number($pl[4])
                ExitLoop
            EndIf
        Next
        If $LastAbsX = -1 Or $LastAbsY = -1 Then
            $LastAbsX = 0
            $LastAbsY = 0
        EndIf
    EndIf

    If $BtnHeld[0] Or $BtnHeld[1] Or $BtnHeld[2] Then
        ; --- DRAG: абсолютное движение DD_mov ---
        Local $newX = $LastAbsX + $mx
        Local $newY = $LastAbsY + $my
        If $g_hDD <> -1 Then DllCall($g_hDD, "int", "DD_mov", "int", $newX, "int", $newY)
        $LastAbsX = $newX
        $LastAbsY = $newY
        Sleep(Max(1, $interval * 1000))
    Else
        ; --- Обычное движение: относительное DD_movR ---
        If ($mx <> 0 Or $my <> 0) And $g_hDD <> -1 Then
            DllCall($g_hDD, "int", "DD_movR", "int", $mx, "int", $my)
        EndIf
        $LastAbsX += $mx
        $LastAbsY += $my
        Sleep(Max(1, $interval * 1000))
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
        Case Else
            Return
    EndSwitch
    $BtnHeld[$idx] = ($state = "DOWN")
    If $g_hDD <> -1 Then DllCall($g_hDD, "int", "DD_btn", "int", $code)
    If $state = "DOWN" Then $MustSleepAfterBtn = True
    Sleep(10)
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
        Case Else
            Return
    EndSwitch
    If $g_hDD <> -1 Then DllCall($g_hDD, "int", "DD_btn", "int", $code)
    Sleep(10)
EndFunc