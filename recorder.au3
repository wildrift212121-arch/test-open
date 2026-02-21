; recorder.au3
; Version: 4.4 full+hook (2026-02-22)
; --- Весь старый функционал 2.6 сохранён, интеграция WH_MOUSE_LL hook ---
; --- Исправлена ошибка инициализации массива для полной совместимости с AutoIt ---
; --- Для режима HOOK запись идет только через ловушку, весь pipeline маршрутов/слотов/файлов ---

If @ScriptName <> "main.au3" Then Exit

#include <Misc.au3>
#include <WinAPI.au3>
#include <WindowsConstants.au3>

Global Const $ROUTE_SLOTS = 5
Global Const $ROUTE_DIR = @ScriptDir & "\route"
Global Const $MOUSE_RECORD_INTERVAL = 15
Global $REC_MODE = "REC_HOOK" ; "REC_HOOK" — только через hook, "REC_NORMAL" — старая запись (MouseGetPos)

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

; --- HOOK record ---
Global $hHook = 0, $hStub_MouseProc = 0
Global $g_sRouteHookFile = @ScriptDir & "\route_hook.log"
Global $g_iLastAbsX = -1, $g_iLastAbsY = -1

Func Routes_Init()
    If Not FileExists($ROUTE_DIR) Then DirCreate($ROUTE_DIR)
    For $i = 0 To $ROUTE_SLOTS - 1
        Local $saved = IniRead($INI, "Routes", "Slot" & ($i + 1), "")
        If $saved <> "" And FileExists($saved) Then
            Recorder_LoadFromFile($i, $saved)
            $g_aRouteFiles[$i] = $saved
        Else
            Local $a[1] = [0]
            $g_aRoutes[$i] = $a
            $g_iRouteCounts[$i] = 0
            $g_aRouteFiles[$i] = ""
        EndIf
    Next
    Routes_SetCurrentSlot(0)
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
EndFunc

Func Recorder_Start()
    If $g_bRecording Then Return
    If $REC_MODE = "REC_HOOK" Then
        _BotLog("Recorder_Start: режим HOOK")
        $g_tRecordStart = TimerInit()
        FileDelete($g_sRouteHookFile)
        $hStub_MouseProc = DllCallbackRegister("_MouseProc_Hook", "long", "int;ptr;ptr")
        $hHook = _WinAPI_SetWindowsHookEx($WH_MOUSE_LL, DllCallbackGetPtr($hStub_MouseProc), _WinAPI_GetModuleHandle(0))
        $g_bRecording = True
    Else
        If Not AION_Activate() Then Return
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

        Local $pos = MouseGetPos()
        __Route_AddLine(StringFormat("0.000:MOUSE_ABS:%d:%d", $pos[0], $pos[1]))
        $g_iLastX = $pos[0]
        $g_iLastY = $pos[1]
    EndIf
EndFunc

Func Recorder_Stop()
    If Not $g_bRecording Then Return
    If $REC_MODE = "REC_HOOK" Then
        _WinAPI_UnhookWindowsHookEx($hHook)
        DllCallbackFree($hStub_MouseProc)
        $hHook = 0
        $hStub_MouseProc = 0
        $g_bRecording = False
        HookLog_ToRoute($g_sRouteHookFile, $g_aRoute)
        ; автоматическое сохранение после hook-записи
        Local $slot = $g_iCurrentRouteSlot
        $g_iRouteCounts[$slot] = $g_aRoute[0]
        If $g_aRoute[0] > 0 Then
            Local $file = Route_DefaultFileNameForSlot($slot)
            Recorder_SaveToFile($slot, $file)
        EndIf
    Else
        $g_bRecording = False
        Local $slot = $g_iCurrentRouteSlot
        $g_iRouteCounts[$slot] = $g_aRoute[0]
        If $g_aRoute[0] > 0 Then
            Local $file = Route_DefaultFileNameForSlot($slot)
            Recorder_SaveToFile($slot, $file)
        EndIf
    EndIf
EndFunc

Func __Route_AddLine($sLine)
    Local $n = $g_aRoute[0] + 1
    ReDim $g_aRoute[$n + 1]
    $g_aRoute[0] = $n
    $g_aRoute[$n] = $sLine
    $g_aRoutes[$g_iCurrentRouteSlot] = $g_aRoute
    $g_iRouteCounts[$g_iCurrentRouteSlot] = $n
EndFunc

Func Recorder_Process()
    If $REC_MODE = "REC_HOOK" Then
        ; hook-режим: всё логируется системой hook, здесь тикать ничего не надо!
        Return
    EndIf

    If Not $g_bRecording Then Return
    Static $g_tLastMouseRecorded = 0

    Local $t = TimerDiff($g_tRecordStart) / 1000.0
    Local $pos = MouseGetPos()

    Local $dx = $pos[0] - $g_iLastX
    Local $dy = $pos[1] - $g_iLastY

    If (Abs($dx) > 0 Or Abs($dy) > 0) And TimerDiff($g_tLastMouseRecorded) >= $MOUSE_RECORD_INTERVAL Then
        __Route_AddLine(StringFormat("%.3f:MOUSE:%d:%d", $t, $dx, $dy))
        $g_iLastX = $pos[0]
        $g_iLastY = $pos[1]
        $g_tLastMouseRecorded = TimerInit()
    EndIf

    Static $pressTimeL = -1, $pressTimeR = -1
    Local $bL = _IsPressed("01")
    Local $bR = _IsPressed("02")

    If $bL <> $g_bLastL Then
        Local $state = $bL ? "DOWN" : "UP"
        __Route_AddLine(StringFormat("%.3f:MOUSE_BTN:LEFT:%s", $t, $state))
        $pressTimeL = $bL ? $t : -1
        $g_bLastL = $bL
    EndIf
    If $bR <> $g_bLastR Then
        Local $state2 = $bR ? "DOWN" : "UP"
        __Route_AddLine(StringFormat("%.3f:MOUSE_BTN:RIGHT:%s", $t, $state2))
        $pressTimeR = $bR ? $t : -1
        $g_bLastR = $bR
    EndIf

    For $i = 0 To UBound($g_aKeyMap) - 1
        Local $vk = $g_aKeyMap[$i][0]
        Local $dd = $g_aKeyMap[$i][1]
        If $dd = 0 Then ContinueLoop
        Local $pressed = _IsPressed(Hex($vk, 2))
        Local $mode = $KeyState[$dd]
        If $pressed And $mode <> 1 Then
            __Route_AddLine(StringFormat("%.3f:%d:DOWN", $t, $dd))
            $KeyState[$dd] = 1
        ElseIf Not $pressed And $mode = 1 Then
            __Route_AddLine(StringFormat("%.3f:%d:UP", $t, $dd))
            $KeyState[$dd] = 2
        EndIf
    Next
EndFunc

Func _MouseProc_Hook($nCode, $wParam, $lParam)
    If $nCode >= 0 Then
        Local $tMSLL = DllStructCreate("int X;int Y;dword mouseData;dword flags;dword time;ulong_ptr dwExtraInfo", $lParam)
        Local $iX = DllStructGetData($tMSLL, "X")
        Local $iY = DllStructGetData($tMSLL, "Y")
        Local $timestamp = DllStructGetData($tMSLL, "time")
        Local $event = ""
        Switch $wParam
            Case $WM_MOUSEMOVE
                $event = StringFormat("%.3f:MOUSE_ABS:%d:%d", $timestamp / 1000.0, $iX, $iY)
            Case $WM_LBUTTONDOWN
                $event = StringFormat("%.3f:MOUSE_BTN:LEFT:DOWN", $timestamp / 1000.0)
            Case $WM_LBUTTONUP
                $event = StringFormat("%.3f:MOUSE_BTN:LEFT:UP", $timestamp / 1000.0)
            Case $WM_RBUTTONDOWN
                $event = StringFormat("%.3f:MOUSE_BTN:RIGHT:DOWN", $timestamp / 1000.0)
            Case $WM_RBUTTONUP
                $event = StringFormat("%.3f:MOUSE_BTN:RIGHT:UP", $timestamp / 1000.0)
        EndSwitch
        If $event <> "" Then FileWriteLine($g_sRouteHookFile, $event)
    EndIf
    Return _WinAPI_CallNextHookEx($hHook, $nCode, $wParam, $lParam)
EndFunc

Func HookLog_ToRoute($logFile, ByRef $routeArr)
    Local $aLines = StringSplit(FileRead($logFile), @CRLF, 1)
    If $aLines[0] < 2 Then Return
    Local $prevX = 0, $prevY = 0, $started = False
    Local $idx = 1
    ReDim $routeArr[1]
    $routeArr[0] = 0
    For $i = 1 To $aLines[0]
        Local $line = $aLines[$i]
        If StringInStr($line, "MOUSE_ABS") Then
            Local $p = StringSplit($line, ":", 1)
            If $p[0] >= 4 Then
                Local $x = Number($p[3])
                Local $y = Number($p[4])
                If Not $started Then
                    ReDim $routeArr[2]
                    $routeArr[1] = $line
                    $idx = 2
                    $prevX = $x
                    $prevY = $y
                    $started = True
                    $routeArr[0] = 1
                    ContinueLoop
                EndIf
                Local $dx = $x - $prevX
                Local $dy = $y - $prevY
                If Abs($dx) > 0 Or Abs($dy) > 0 Then
                    ReDim $routeArr[$idx + 1]
                    $routeArr[$idx] = StringFormat("%.3f:MOUSE:%d:%d", TimerDiff($g_tRecordStart)/1000, $dx, $dy)
                    $idx += 1
                    $prevX = $x
                    $prevY = $y
                    $routeArr[0] = $idx - 1
                EndIf
            EndIf
        ElseIf StringInStr($line, "MOUSE_BTN") Then
            ReDim $routeArr[$idx + 1]
            $routeArr[$idx] = $line
            $idx += 1
            $routeArr[0] = $idx - 1
        EndIf
    Next
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
    Return True
EndFunc

Func Route_MakeTimestamp()
    Return @YEAR & StringFormat("%02d", @MON) & StringFormat("%02d", @MDAY) & "-" & _
           StringFormat("%02d", @HOUR) & StringFormat("%02d", @MIN) & StringFormat("%02d", @SEC)
EndFunc

Func Route_DefaultFileNameForSlot($slot)
    Local $ts = Route_MakeTimestamp()
    Return $ROUTE_DIR & "\route_" & ($slot + 1) & "_" & $ts & ".log"
EndFunc

Func OnAutoItExit()
    If $hHook <> 0 Then _WinAPI_UnhookWindowsHookEx($hHook)
    If $hStub_MouseProc <> 0 Then DllCallbackFree($hStub_MouseProc)
EndFunc