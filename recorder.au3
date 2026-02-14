; ============================
;   ROUTE RECORDER MODULE
;   recorder.au3
; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf

#include <Array.au3>




; -----------------------------------------
; START RECORDING
; -----------------------------------------
Func Recorder_Start()
    If $g_bRecording Then Return

    $g_bRecording = True
    $g_aRoute = []
    $g_tRecord = TimerInit()

    _BotLog("Запись маршрута начата")
EndFunc


; -----------------------------------------
; STOP RECORDING
; -----------------------------------------
Func Recorder_Stop()
    If Not $g_bRecording Then Return

    $g_bRecording = False

    _BotLog("Запись маршрута остановлена. Записано точек: " & UBound($g_aRoute))
EndFunc


; -----------------------------------------
; ADD MOUSE POSITION
; -----------------------------------------
Func Recorder_AddMouse()
    If Not $g_bRecording Then Return

    Local $pos = MouseGetPos()
    Local $t = TimerDiff($g_tRecord)

    Local $entry[3]
    $entry[0] = "M"          ; Mouse
    $entry[1] = $pos[0]      ; X
    $entry[2] = $pos[1]      ; Y

    _ArrayAdd($g_aRoute, $entry)

    _BotLog("Записана точка мыши: " & $pos[0] & ", " & $pos[1])
EndFunc


; -----------------------------------------
; ADD KEY PRESS
; -----------------------------------------
Func Recorder_AddKey($key)
    If Not $g_bRecording Then Return

    Local $entry[2]
    $entry[0] = "K"      ; Key
    $entry[1] = $key

    _ArrayAdd($g_aRoute, $entry)

    _BotLog("Записана клавиша: " & $key)
EndFunc


; -----------------------------------------
; PROCESS (called from main loop)
; -----------------------------------------
Func Recorder_Process()
    If Not $g_bRecording Then Return

    ; Запись мыши по таймеру
    If TimerDiff($g_tRecord) > 250 Then
        Recorder_AddMouse()
        $g_tRecord = TimerInit()
    EndIf
EndFunc


; -----------------------------------------
; SAVE ROUTE TO FILE
; -----------------------------------------
Func Recorder_Save($file)
    Local $h = FileOpen($file, 2)
    If $h = -1 Then
        _BotLog("Ошибка сохранения маршрута: " & $file)
        Return False
    EndIf

    For $i = 0 To UBound($g_aRoute) - 1
        Local $e = $g_aRoute[$i]
        If $e[0] = "M" Then
            FileWriteLine($h, "M|" & $e[1] & "|" & $e[2])
        ElseIf $e[0] = "K" Then
            FileWriteLine($h, "K|" & $e[1])
        EndIf
    Next

    FileClose($h)

    _BotLog("Маршрут сохранён: " & $file)
    Return True
EndFunc


; -----------------------------------------
; LOAD ROUTE FROM FILE
; -----------------------------------------
Func Recorder_Load($file)
    If Not FileExists($file) Then
        _BotLog("Файл маршрута не найден: " & $file)
        Return False
    EndIf

    Local $h = FileOpen($file, 0)
    If $h = -1 Then
        _BotLog("Ошибка открытия файла маршрута: " & $file)
        Return False
    EndIf

    $g_aRoute = []

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

    _BotLog("Маршрут загружен: " & $file & " (точек: " & UBound($g_aRoute) & ")")
    Return True
EndFunc
