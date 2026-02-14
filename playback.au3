; ============================
;   ROUTE PLAYBACK MODULE
;   playback.au3
; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf

#include <Array.au3>




; -----------------------------------------
; START PLAYBACK
; -----------------------------------------
Func Playback_Start()
    If $g_bPlayback Then Return

    If UBound($g_aRoute) = 0 Then
        _BotLog("Ошибка: маршрут пустой, воспроизведение невозможно")
        Return
    EndIf

    $g_bPlayback = True
    $g_iPlaybackIndex = 0

    _BotLog("Воспроизведение маршрута начато")
EndFunc


; -----------------------------------------
; STOP PLAYBACK
; -----------------------------------------
Func Playback_Stop()
    If Not $g_bPlayback Then Return

    $g_bPlayback = False
    Key_ReleaseAll()

    _BotLog("Воспроизведение маршрута остановлено")
EndFunc


; -----------------------------------------
; PROCESS ONE STEP
; -----------------------------------------
Func Playback_Process()
    If Not $g_bPlayback Then Return
    If $g_iPlaybackIndex >= UBound($g_aRoute) Then
        _BotLog("Маршрут завершён")
        Playback_Stop()
        Return
    EndIf

    Local $e = $g_aRoute[$g_iPlaybackIndex]

    ; Тип события
    Switch $e[0]

        Case "M" ; Mouse move
            MouseMove($e[1], $e[2], 0)
            _BotLog("Воспроизведение: мышь → " & $e[1] & ", " & $e[2])

        Case "K" ; Key press
            Key_Send($e[1], "DOWN")
            Sleep(Random(40, 70))
            Key_Send($e[1], "UP")
            _BotLog("Воспроизведение: клавиша → " & $e[1])

    EndSwitch

    $g_iPlaybackIndex += 1
EndFunc


; -----------------------------------------
; LOAD ROUTE BEFORE PLAYBACK
; -----------------------------------------
Func Playback_Load($file)
    If Not FileExists($file) Then
        _BotLog("Файл маршрута не найден: " & $file)
        Return False
    EndIf

    Local $h = FileOpen($file, 0)
    If $h = -1 Then
        _BotLog("Ошибка открытия файла маршрута: " & $file)
        Return False
    EndIf

    ReDim $g_aRoute[0]

    While 1
        Local $line = FileReadLine($h)
        If @error Then ExitLoop

        Local $parts = StringSplit($line, "|")
        If $parts[0] < 2 Then ContinueLoop

        If $parts[1] = "M" Then
            Local $entry[3]
            $entry[0] = "M"
            $entry[1] = Number($parts[2])
            $entry[2] = Number($parts[3])
            _ArrayAdd($g_aRoute, $entry)

        ElseIf $parts[1] = "K" Then
            Local $entry[2]
            $entry[0] = "K"
            $entry[1] = $parts[2]
            _ArrayAdd($g_aRoute, $entry)
        EndIf
    WEnd

    FileClose($h)

    _BotLog("Маршрут загружен для воспроизведения: " & $file & " (точек: " & UBound($g_aRoute) & ")")
    Return True
EndFunc
