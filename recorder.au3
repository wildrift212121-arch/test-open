; recorder.au3
; Version: 2.0 (2026-02-22)
; - Запись маршраута мыши только целыми dx/dy ("сырые" шаги по 1 пикселю)
; - Максимум совпадения с playback движением при разложении
; - В остальном структура, слоты, статусы, автосохранение сохранены

If @ScriptName <> "main.au3" Then Exit

#include <Misc.au3>

Global Const $ROUTE_SLOTS = 5
Global Const $ROUTE_DIR = @ScriptDir & "\route"
Global Const $MOUSE_RECORD_INTERVAL = 7 ; ms: шаг по 1 пикселю = больше сообщений, меньше лагов

Global $g_aRoutes[$ROUTE_SLOTS]
Global $g_iRouteCounts[$ROUTE_SLOTS]
Global $g_iCurrentRouteSlot = 0

Global $g_aRoute[1] = [0]
Global $g_aRouteFiles[$ROUTE_SLOTS]
Global $g_bRecording = False
Global $g_tRecordStart = 0
Global $g_iLastX = -1, $g_iLastY = -1
Global $g_bLastL = False, $g_bLastR = False

Global $KeyState[700]
Global $g_aKeyMap[10][2]

Func Routes_Init()
    If Not FileExists($ROUTE_DIR) Then DirCreate($ROUTE_DIR)
    For $i = 0 To $ROUTE_SLOTS - 1
        Local $saved = IniRead($INI, "Routes", "Slot" & ($i + 1), "")
        If $saved <> "" And FileExists($saved) Then
            If Recorder_LoadFromFile($i, $saved) Then
                $g_aRouteFiles[$i] = $saved
                ContinueLoop
            EndIf
        EndIf
        Local $a[1] = [0]
        $g_aRoutes[$i] = $a
        $g_iRouteCounts[$i] = 0
        $g_aRouteFiles[$i] = ""
    Next
    Routes_SetCurrentSlot(0)
    _BotLog("Routes_Init: " & $ROUTE_SLOTS & " слотов, папка " & $ROUTE_DIR)
EndFunc

Func Routes_SetCurrentSlot($slot)
    If $slot < 0 Or $slot >= $ROUTE_SLOTS Then Return
    $g_iCurrentRouteSlot = $slot
    $g_aRoute = $g_aRoutes[$slot]
EndFunc

Func Routes_GetCurrentSlot()
    Return $g_iCurrentRouteSlot
EndFunc

Func Route_GetAssignedFile($slot)
    If $slot < 0 Or $slot >= $ROUTE_SLOTS Then Return ""
    Return $g_aRouteFiles[$slot]
EndFunc

Func Route_SetAssignedFile($slot, $file)
    If $slot < 0 Or $slot >= $ROUTE_SLOTS Then Return
    $g_aRouteFiles[$slot] = $file
    IniWrite($INI, "Routes", "Slot" & ($slot + 1), $file)
    _BotLog("Route_SetAssignedFile: slot " & ($slot + 1) & " -> " & $file)
EndFunc

Func Recorder_Start()
    If $g_bRecording Then Return

    If Not AION_Activate() Then
        _BotLog("Recorder_Start: не удалось активировать AION")
        Return
    EndIf

    $g_bRecording = True
    $g_tRecordStart = TimerInit()
    $g_iLastX = -1
    $g_iLastY = -1
    $g_bLastL = False
    $g_bLastR = False

    Local $slot = $g_iCurrentRouteSlot
    Local $a[1] = [0]
    $g_aRoutes[$slot] = $a
    $g_iRouteCounts[$slot] = 0
    $g_aRoute = $g_aRoutes[$slot]

    For $i = 0 To UBound($KeyState) - 1
        $KeyState[$i] = 0
    Next

    ; Сохраняем абсолютную позицию мыши первой строкой
    Local $pos = MouseGetPos()
    __Route_AddLine(StringFormat("0.000:MOUSE_ABS:%d:%d", $pos[0], $pos[1]))

    _BotLog("Запись маршрута начата (слот " & ($slot + 1) & ")")
EndFunc

Func Recorder_Stop()
    If Not $g_bRecording Then Return

    $g_bRecording = False
    Local $slot = $g_iCurrentRouteSlot
    $g_iRouteCounts[$slot] = $g_aRoute[0]

    _BotLog("Запись остановлена. Слот " & ($slot + 1) & ", строк: " & $g_aRoute[0])

    ; автосохранение
    If $g_aRoute[0] > 0 Then
        Local $file = Route_DefaultFileNameForSlot($slot)
        If Recorder_SaveToFile($slot, $file) Then _BotLog("Автосохранение: " & $file)
    EndIf
EndFunc

Func __Route_AddLine($sLine)
    Local $n = $g_aRoute[0] + 1
    ReDim $g_aRoute[$n + 1]
    $g_aRoute[0] = $n
    $g_aRoute[$n] = $sLine

    Local $slot = $g_iCurrentRouteSlot
    $g_aRoutes[$slot] = $g_aRoute
    $g_iRouteCounts[$slot] = $n
EndFunc

Func Recorder_Process()
    If Not $g_bRecording Then Return

    Static $g_tLastMouseRecorded = 0
    Local $t = TimerDiff($g_tRecordStart) / 1000.0

    Local $pos = MouseGetPos()
    If $g_iLastX = -1 Then
        $g_iLastX = $pos[0]
        $g_iLastY = $pos[1]
    EndIf

    Local $dx = $pos[0] - $g_iLastX
    Local $dy = $pos[1] - $g_iLastY

    ; ------ ГЛАВНОЕ: разбивать движение на "сырые" dx/dy по 1 пикселю ------
    While $dx <> 0 Or $dy <> 0
        If Abs($dx) >= Abs($dy) Then
            ; x сдвиг больше
            Local $stepX = ($dx > 0) ? 1 : -1
            Local $stepY = ($dy <> 0) ? Round($dy / Abs($dx)) : 0
        Else
            ; y сдвиг больше
            Local $stepY = ($dy > 0) ? 1 : -1
            Local $stepX = ($dx <> 0) ? Round($dx / Abs($dy)) : 0
        EndIf

        ; Учитываем минимальный шаг (если вдруг dx и dy оба 0)
        If $stepX = 0 And $dx <> 0 Then $stepX = ($dx > 0) ? 1 : -1
        If $stepY = 0 And $dy <> 0 Then $stepY = ($dy > 0) ? 1 : -1

        __Route_AddLine(StringFormat("%.3f:MOUSE:%d:%d", $t, $stepX, $stepY))
        $g_iLastX += $stepX
        $g_iLastY += $stepY
        $dx = $pos[0] - $g_iLastX
        $dy = $pos[1] - $g_iLastY
        ; Фильтруем сообщения (не чаще чем интервал MOUSE_RECORD_INTERVAL)
        Sleep($MOUSE_RECORD_INTERVAL)
    WEnd

    ; --- удержание мыши (без изменений) ---
    Static $pressTimeL = -1, $pressTimeR = -1
    Local $bL = _IsPressed("01")
    Local $bR = _IsPressed("02")

    If $bL <> $g_bLastL Then
        Local $state = $bL ? "DOWN" : "UP"
        __Route_AddLine(StringFormat("%.3f:MOUSE_BTN:LEFT:%s", $t, $state))
        If $bL Then
            $pressTimeL = $t
        Else
            $pressTimeL = -1
        EndIf
        $g_bLastL = $bL
        _BotLog("Записана ЛКМ: " & $state)
    EndIf

    If $bR <> $g_bLastR Then
        Local $state2 = $bR ? "DOWN" : "UP"
        __Route_AddLine(StringFormat("%.3f:MOUSE_BTN:RIGHT:%s", $t, $state2))
        If $bR Then
            $pressTimeR = $t
        Else
            $pressTimeR = -1
        EndIf
        $g_bLastR = $bR
        _BotLog("Записана ПКМ: " & $state2)
    EndIf

    ; --- запись клавиш ---
    For $i = 0 To UBound($g_aKeyMap) - 1
        Local $vk = $g_aKeyMap[$i][0]
        Local $dd = $g_aKeyMap[$i][1]
        If $dd = 0 Then ContinueLoop

        Local $pressed = _IsPressed(Hex($vk, 2))
        Local $mode = $KeyState[$dd]
        If $pressed And $mode <> 1 Then
            __Route_AddLine(StringFormat("%.3f:%d:DOWN", $t, $dd))
            $KeyState[$dd] = 1
            _BotLog("Записана клавиша: " & $dd & " DOWN")
        ElseIf Not $pressed And $mode = 1 Then
            __Route_AddLine(StringFormat("%.3f:%d:UP", $t, $dd))
            $KeyState[$dd] = 2
            _BotLog("Записана клавиша: " & $dd & " UP")
        EndIf
    Next
EndFunc

Func Route_MakeTimestamp()
    Return @YEAR & StringFormat("%02d", @MON) & StringFormat("%02d", @MDAY) & "-" & _
           StringFormat("%02d", @HOUR) & StringFormat("%02d", @MIN) & StringFormat("%02d", @SEC)
EndFunc

Func Route_DefaultFileNameForSlot($slot)
    Local $ts = Route_MakeTimestamp()
    Return $ROUTE_DIR & "\route_" & ($slot + 1) & "_" & $ts & ".log"
EndFunc

Func Recorder_SaveToFile($slot, $sFile = "")
    If $slot < 0 Or $slot >= $ROUTE_SLOTS Then Return False
    Local $a = $g_aRoutes[$slot]
    If Not IsArray($a) Or $a[0] = 0 Then Return False
    If $sFile = "" Then $sFile = Route_DefaultFileNameForSlot($slot)
    Local $dir = StringLeft($sFile, StringInStr($sFile, "\", 0, -1) - 1)
    If Not FileExists($dir) Then DirCreate($dir)
    Local $h = FileOpen($sFile, 2)
    If $h = -1 Then Return False
    For $i = 1 To $a[0]
        FileWriteLine($h, $a[$i])
    Next
    FileClose($h)
    Route_SetAssignedFile($slot, $sFile)
    _BotLog("Маршрут слота " & ($slot + 1) & " сохранён: " & $sFile & " (строк: " & $a[0] & ")")
    Return True
EndFunc

Func Recorder_LoadFromFile($slot, $sFile)
    If $slot < 0 Or $slot >= $ROUTE_SLOTS Then Return False
    If Not FileExists($sFile) Then Return False
    Local $h = FileOpen($sFile, 0)
    If $h = -1 Then Return False
    Local $all = FileRead($h)
    FileClose($h)
    Local $a = StringSplit(StringStripCR($all), @LF, 1)
    If @error Or $a[0] = 0 Then Return False
    $g_aRoutes[$slot] = $a
    $g_iRouteCounts[$slot] = $a[0]
    If $g_iCurrentRouteSlot = $slot Then $g_aRoute = $a
    Route_SetAssignedFile($slot, $sFile)
    _BotLog("Маршрут загружен в слот " & ($slot + 1) & ": " & $sFile & " (строк: " & $a[0] & ")")
    Return True
EndFunc