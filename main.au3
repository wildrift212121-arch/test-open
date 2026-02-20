#NoTrayIcon
#RequireAdmin
#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <StaticConstants.au3>
#include <File.au3>
#include <Misc.au3>
#include <TabConstants.au3>
#include <EditConstants.au3>
#include <ScrollBarsConstants.au3>
#include <ComboConstants.au3>

; ==== МОДУЛИ ====
#include "globals.au3"
#include "aion.au3"
#include "recorder.au3"
#include "playback.au3"
#include "battle.au3"


; --- DD / AION ---
Global $g_hDD = -1

; --- Mouse settings ---
Global $K_move = IniRead($INI, "Mouse", "K_move", 3.5)
Global $K_click = IniRead($INI, "Mouse", "K_click", 1.0)
Global $g_bInvX = (IniRead($INI, "Mouse", "InvX", 0) = 1)
Global $g_bInvY = (IniRead($INI, "Mouse", "InvY", 0) = 1)
Global $g_bSmooth = (IniRead($INI, "Mouse", "Smooth", 1) = 1)
Global $g_iMinMove = IniRead($INI, "Mouse", "MinMove", 1)

; --- Key state cache ---
Global $KeyState[700]

; --- Key map ---
Global $g_aKeyMap[10][2]

; --- GUI ---
Global $g_hMainGUI, $g_hTab
Global $g_hStatus

; Tab: Запись
Global $g_btnRecStart, $g_btnRecStop

; Tab: Воспроизведение
Global $g_btnLoadRoute, $g_btnSaveRoute, $g_btnPlayStart, $g_btnPlayStop
Global $g_cmbRouteSlot, $g_lblRouteInfo, $g_lblRouteFile

; Tab: Бой
Global $g_btnBattleStart, $g_btnBattleStop, $g_chkAutoBattle

; Tab: Отладка
Global $g_editLog, $g_btnClearLog

; ==== ТОЧКА ВХОДА ====
_Main()

; ================= MAIN =================
Func _Main()
    _InitKeyMap()
    _InitDD()
    Routes_Init() ; инициализация 5 слотов маршрутов и папки route

    _CreateGUI()
    _LoadGuiSettings() ; восстановить чекбоксы/слоты и т.д.

    If $g_hDD = -1 Then
        GUICtrlSetData($g_hStatus, "Ошибка: dd60300.dll (не инициализирован)")
    Else
        GUICtrlSetData($g_hStatus, "Готово (DD OK)")
    EndIf

    ; Хоткеи
    HotKeySet("{F6}", "_Hot_RecStart")
    HotKeySet("{F7}", "_Hot_RecStop")
    HotKeySet("{F9}", "_Hot_PlayStart")
    HotKeySet("{F10}", "_Hot_PlayStop")

    While 1
        Local $msg = GUIGetMsg()
        Switch $msg
            Case $GUI_EVENT_CLOSE
                _BotLog("GUI_EVENT_CLOSE: сохраняю настройки и выхожу")
                _SaveGuiSettings()
                _Exit()

            ; --- Запись ---
            Case $g_btnRecStart
                Recorder_Start()
            Case $g_btnRecStop
                Recorder_Stop()

            ; --- Воспроизведение / маршруты ---
            Case $g_cmbRouteSlot
                _OnRouteSlotChange()
            Case $g_btnLoadRoute
                _OnRouteLoad()
            Case $g_btnSaveRoute
                _OnRouteSave()
            Case $g_btnPlayStart
                Playback_Start()
            Case $g_btnPlayStop
                Playback_Stop()

            ; --- Бой ---
            Case $g_btnBattleStart
                Battle_Start()
            Case $g_btnBattleStop
                Battle_Stop()
            Case $g_chkAutoBattle
                Local $ena = (BitAND(GUICtrlRead($g_chkAutoBattle), $GUI_CHECKED) = $GUI_CHECKED)
                Battle_SetAutoAfterRoute($ena)

            ; --- Отладка ---
            Case $g_btnClearLog
                GUICtrlSetData($g_editLog, "")
        EndSwitch

        ; Фоновые процессы
        Recorder_Process()
        Playback_Process()
        Battle_Process()

        Sleep(5)
    WEnd
EndFunc

; ================= KEY MAP =================
Func _InitKeyMap()
    $g_aKeyMap[0][0] = 0x57 ; W
    $g_aKeyMap[0][1] = 302
    $g_aKeyMap[1][0] = 0x41 ; A
    $g_aKeyMap[1][1] = 401
    $g_aKeyMap[2][0] = 0x53 ; S
    $g_aKeyMap[2][1] = 402
    $g_aKeyMap[3][0] = 0x44 ; D
    $g_aKeyMap[3][1] = 403
    $g_aKeyMap[4][0] = 0x20 ; Space
    $g_aKeyMap[4][1] = 603
    $g_aKeyMap[5][0] = 0x10 ; Shift
    $g_aKeyMap[5][1] = 500
    $g_aKeyMap[6][0] = 0x11 ; Ctrl
    $g_aKeyMap[6][1] = 600
    $g_aKeyMap[7][0] = 0x12 ; Alt
    $g_aKeyMap[7][1] = 602
    $g_aKeyMap[8][0] = 0x52 ; R
    $g_aKeyMap[8][1] = 304
    $g_aKeyMap[9][0] = 0x56 ; V
    $g_aKeyMap[9][1] = 504
EndFunc

; ================= DD INIT (robust) =================
Func _InitDD()
    ; Если уже открыт — ничего не делаем
    If $g_hDD <> -1 Then
        _BotLog("_InitDD: DD уже инициализирован (handle=" & $g_hDD & ")")
        Return
    EndIf

    If Not FileExists($DD_DLL) Then
        _BotLog("dd60300.dll не найден: " & $DD_DLL)
        $g_hDD = -1
        Return
    EndIf

    ; Попытки открыть DLL с небольшими паузами (возможно DLL занят другим процессом)
    Local $attempts = 3
    Local $i
    For $i = 1 To $attempts
        $g_hDD = DllOpen($DD_DLL)
        If $g_hDD <> -1 Then ExitLoop
        _BotLog("_InitDD: DllOpen попытка " & $i & " не удалась, ожидаю 200ms")
        Sleep(200)
    Next

    If $g_hDD = -1 Then
        _BotLog("Ошибка: не удалось открыть dd60300.dll после " & $attempts & " попыток")
        Return
    EndIf

    ; Пробный вызов и проверка
    Local $res = DllCall($g_hDD, "int", "DD_btn", "int", 0)
    If @error Then
        _BotLog("_InitDD: DllCall(DD_btn) вернул ошибку. Закрываю дескриптор.")
        ; безопасно закроем и пометим как неинициализированный
        If $g_hDD <> -1 Then
            DllClose($g_hDD)
            $g_hDD = -1
        EndIf
        Return
    EndIf

    _BotLog("DD инициализирован, handle=" & $g_hDD)
EndFunc

; ================= GUI =================
Func _CreateGUI()
    $g_hMainGUI = GUICreate($SCRIPT_NAME, 560, 440, -1, -1, BitOR($WS_CAPTION, $WS_SYSMENU, $WS_MINIMIZEBOX))
    GUISetBkColor(0x2C2F33)
    GUISetFont(9, 400, 0, "Segoe UI")

    $g_hTab = GUICtrlCreateTab(10, 10, 540, 360, $TCS_FLATBUTTONS)
    GUICtrlSetBkColor(-1, 0x23272A)
    GUICtrlSetColor(-1, 0xE6E6E6)

    GUICtrlCreateTabItem("Запись")
    _CreateTabRecord()

    GUICtrlCreateTabItem("Воспроизведение")
    _CreateTabPlayback()

    GUICtrlCreateTabItem("Бой")
    _CreateTabBattle()

    GUICtrlCreateTabItem("Отладка")
    _CreateTabDebug()

    GUICtrlCreateTabItem("")

    $g_hStatus = GUICtrlCreateLabel("Инициализация...", 10, 380, 540, 20)
    GUICtrlSetColor(-1, 0xE6E6E6)

    GUISetState(@SW_SHOW, $g_hMainGUI)
EndFunc

Func _CreateTabRecord()
    GUICtrlCreateLabel("Управление записью маршрута:", 30, 40, 300, 20)
    GUICtrlSetColor(-1, 0xE6E6E6)

    $g_btnRecStart = GUICtrlCreateButton("Начать запись (F6)", 30, 70, 180, 35)
    GUICtrlSetBkColor(-1, 0x43B581)
    GUICtrlSetColor(-1, 0xFFFFFF)

    $g_btnRecStop = GUICtrlCreateButton("Остановить запись (F7)", 230, 70, 180, 35)
    GUICtrlSetBkColor(-1, 0xF04747)
    GUICtrlSetColor(-1, 0xFFFFFF)

    GUICtrlCreateLabel("Записываются: мышь (dx/dy), ЛКМ/ПКМ, WASD, Space, Shift, Ctrl, Alt, R, V.", 30, 120, 480, 40)
    GUICtrlSetColor(-1, 0x99AAB5)
EndFunc

Func _CreateTabPlayback()
    GUICtrlCreateLabel("Слоты маршрутов:", 30, 40, 120, 20)
    GUICtrlSetColor(-1, 0xE6E6E6)

    $g_cmbRouteSlot = GUICtrlCreateCombo("", 160, 36, 200, 24, BitOR($CBS_DROPDOWNLIST, $WS_VSCROLL))
    GUICtrlSetData($g_cmbRouteSlot, "1|2|3|4|5")
    GUICtrlSetData($g_cmbRouteSlot, "1")

    $g_lblRouteInfo = GUICtrlCreateLabel("Активный слот: 1, строк: 0", 30, 70, 480, 20)
    GUICtrlSetColor(-1, 0x99AAB5)

    $g_lblRouteFile = GUICtrlCreateLabel("Файл: (не назначен)", 30, 95, 480, 18)
    GUICtrlSetColor(-1, 0x99AAB5)

    $g_btnLoadRoute = GUICtrlCreateButton("Загрузить маршрут", 30, 120, 180, 35)
    GUICtrlSetBkColor(-1, 0x7289DA)
    GUICtrlSetColor(-1, 0xFFFFFF)

    $g_btnSaveRoute = GUICtrlCreateButton("Сохранить маршрут", 230, 120, 180, 35)
    GUICtrlSetBkColor(-1, 0x99AAB5)
    GUICtrlSetColor(-1, 0xFFFFFF)

    $g_btnPlayStart = GUICtrlCreateButton("Старт (F9)", 30, 170, 150, 35)
    GUICtrlSetBkColor(-1, 0x43B581)
    GUICtrlSetColor(-1, 0xFFFFFF)

    $g_btnPlayStop = GUICtrlCreateButton("Стоп (F10)", 200, 170, 150, 35)
    GUICtrlSetBkColor(-1, 0xF04747)
    GUICtrlSetColor(-1, 0xFFFFFF)

    GUICtrlCreateLabel("Маршрут воспроизводится по таймингам, как был записан.", 30, 220, 480, 40)
    GUICtrlSetColor(-1, 0x99AAB5)
EndFunc

Func _CreateTabBattle()
    $g_btnBattleStart = GUICtrlCreateButton("Старт боя", 30, 50, 150, 35)
    GUICtrlSetBkColor(-1, 0x43B581)
    GUICtrlSetColor(-1, 0xFFFFFF)

    $g_btnBattleStop = GUICtrlCreateButton("Стоп боя", 200, 50, 150, 35)
    GUICtrlSetBkColor(-1, 0xF04747)
    GUICtrlSetColor(-1, 0xFFFFFF)

    $g_chkAutoBattle = GUICtrlCreateCheckbox("Авто-бой после завершения маршрута", 30, 100, 300, 20)
    GUICtrlSetColor(-1, 0xE6E6E6)
EndFunc

Func _CreateTabDebug()
    $g_editLog = GUICtrlCreateEdit("", 30, 50, 500, 230, BitOR($ES_AUTOVSCROLL, $WS_VSCROLL, $ES_READONLY))
    GUICtrlSetBkColor(-1, 0x23272A)
    GUICtrlSetColor(-1, 0xE6E6E6)

    $g_btnClearLog = GUICtrlCreateButton("Очистить лог", 30, 290, 120, 30)
    GUICtrlSetBkColor(-1, 0x7289DA)
    GUICtrlSetColor(-1, 0xFFFFFF)
EndFunc

; ================== ROUTE GUI HANDLERS ==================
Func _UpdateRouteInfoLabel()
    Local $slot = Routes_GetCurrentSlot()
    Local $a = $g_aRoutes[$slot]
    Local $cnt = 0
    If IsArray($a) Then $cnt = $a[0]
    GUICtrlSetData($g_lblRouteInfo, "Активный слот: " & ($slot + 1) & ", строк: " & $cnt)

    Local $file = Route_GetAssignedFile($slot)
    If $file = "" Then
        GUICtrlSetData($g_lblRouteFile, "Файл: (не назначен)")
    Else
        GUICtrlSetData($g_lblRouteFile, "Файл: " & $file)
    EndIf
EndFunc

Func _OnRouteSlotChange()
    Local $sel = GUICtrlRead($g_cmbRouteSlot)
    If $sel = "" Then Return
    Local $slot = Number($sel) - 1
    Routes_SetCurrentSlot($slot)
    _UpdateRouteInfoLabel()
EndFunc

Func _OnRouteLoad()
    Local $slot = Routes_GetCurrentSlot()
    Local $ROUTE_DIR = @ScriptDir & "\route"
    Local $file = FileOpenDialog("Загрузить маршрут в слот " & ($slot + 1), _
                                 $ROUTE_DIR, "Log (*.log)", 1)
    If @error Or $file = "" Then Return

    If Recorder_LoadFromFile($slot, $file) Then
        GUICtrlSetData($g_hStatus, "Маршрут загружен в слот " & ($slot + 1) & ": " & $file)
        _UpdateRouteInfoLabel()
    Else
        GUICtrlSetData($g_hStatus, "Ошибка загрузки маршрута")
    EndIf
EndFunc

Func _OnRouteSave()
    Local $slot = Routes_GetCurrentSlot()
    Local $ROUTE_DIR = @ScriptDir & "\route"
    Local $defFull = Route_DefaultFileNameForSlot($slot)
    Local $defName = StringRegExpReplace($defFull, "^.*\\", "") ; только имя файла

    Local $file = FileSaveDialog("Сохранить маршрут (слот " & ($slot + 1) & ")", _
                                 $ROUTE_DIR, "Log (*.log)", 16, $defName)
    If @error Or $file = "" Then Return

    If Recorder_SaveToFile($slot, $file) Then
        GUICtrlSetData($g_hStatus, "Маршрут слота " & ($slot + 1) & " сохранён: " & $file)
        _UpdateRouteInfoLabel()
    Else
        GUICtrlSetData($g_hStatus, "Ошибка сохранения маршрута")
    EndIf
EndFunc

; ================= HOTKEYS =================
Func _Hot_RecStart()
    Recorder_Start()
EndFunc

Func _Hot_RecStop()
    Recorder_Stop()
    _FocusBotWindow()
EndFunc

Func _Hot_PlayStart()
    Playback_Start()
EndFunc

Func _Hot_PlayStop()
    _BotLog("Hotkey F10 pressed")
    ; единая “паник-кнопка”: стоп маршрута и боя
    Playback_Stop()
    Battle_Stop()
    _FocusBotWindow()
EndFunc

Func _FocusBotWindow()
    If $g_hMainGUI <> 0 Then
        WinActivate($g_hMainGUI)
    EndIf
EndFunc

; ================= KEY RELEASE =================
Func Key_ReleaseAll()
    Local $keys[] = [ _
        302,401,402,403, _
        301,303,304,404, _
        501,502,503,504, _
        201,202,203,204, _
        603,500,600,602, _
        205,206 _
    ]

    ; если DD не инициализирован, не выполняем DllCall, но всё равно сбрасываем локальные KeyState
    If $g_hDD = -1 Then
        For $i = 0 To UBound($keys) - 1
            If IsDeclared("KeyState") Then $KeyState[$keys[$i]] = 0
        Next
        _BotLog("Key_ReleaseAll: DD не инициализирован, только локальный сброс состояний")
        Return
    EndIf

    For $i = 0 To UBound($keys) - 1
        DllCall($g_hDD, "int", "DD_key", "int", $keys[$i], "int", 2)
        If IsDeclared("KeyState") Then $KeyState[$keys[$i]] = 0
    Next

    DllCall($g_hDD, "int", "DD_btn", "int", 2)
    DllCall($g_hDD, "int", "DD_btn", "int", 8)

    _BotLog("Все клавиши и мышь отпущены")
EndFunc

; ================= GUI SETTINGS SAVE/LOAD =================
Func _LoadGuiSettings()
    ; слот маршрута
    Local $slot = Number(IniRead($INI, "GUI", "RouteSlot", 1))
    If $slot < 1 Or $slot > 5 Then $slot = 1
    GUICtrlSetData($g_cmbRouteSlot, String($slot))
    Routes_SetCurrentSlot($slot - 1)
    _UpdateRouteInfoLabel()

    ; авто-бой
    Local $autoBattle = (IniRead($INI, "GUI", "AutoBattleAfterRoute", 0) = 1)
    If $autoBattle Then GUICtrlSetState($g_chkAutoBattle, $GUI_CHECKED)
    Battle_SetAutoAfterRoute($autoBattle)
EndFunc

Func _SaveGuiSettings()
    ; слот маршрута
    Local $sel = GUICtrlRead($g_cmbRouteSlot)
    Local $slot = Number($sel)
    If $slot < 1 Or $slot > 5 Then $slot = 1
    IniWrite($INI, "GUI", "RouteSlot", $slot)

    ; авто-бой
    Local $auto = (BitAND(GUICtrlRead($g_chkAutoBattle), $GUI_CHECKED) = $GUI_CHECKED)
    IniWrite($INI, "GUI", "AutoBattleAfterRoute", $auto ? 1 : 0)

    _BotLog("GUI settings saved: RouteSlot=" & $slot & " AutoBattle=" & ($auto ? "1" : "0"))
EndFunc

; ================= LOG =================
Func _BotLog($s)
    If Not IsDeclared("g_editLog") Or $g_editLog = 0 Then
        ConsoleWrite("[" & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $s & @CRLF)
        Return
    EndIf

    Local $old = GUICtrlRead($g_editLog)
    GUICtrlSetData($g_editLog, $old & "[" & @HOUR & ":" & @MIN & ":" & @SEC & "] " & $s & @CRLF)
EndFunc

; ================= EXIT =================
Func _Exit()
    ; на всякий случай — ещё раз сохранить (если не было ранее)
    _SaveGuiSettings()

    ; Сброс клавиш (локально / через DD если доступен)
    Key_ReleaseAll()

    ; Закрываем DD если он открыт
    If $g_hDD <> -1 Then
        Local $rc = DllClose($g_hDD)
        If @error Then
            _BotLog("_Exit: DllClose вернул ошибку")
        Else
            _BotLog("_Exit: DllClose успешно, prev handle=" & $g_hDD)
        EndIf
        $g_hDD = -1
    EndIf

    Exit
EndFunc