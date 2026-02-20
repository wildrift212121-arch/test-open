; ============================
;   BATTLE MODULE
;   battle.au3
; ============================
If @ScriptName <> "main.au3" Then Exit

; --- Battle state ---
Global $g_bBattle = False
Global $g_bAutoBattleAfterRoute = False

Global $g_tBattleStart = 0
Global $g_tQ = 0, $g_tF = 0, $g_tE = 0, $g_t5 = 0, $g_t6 = 0

; PUBLIC API
Func Battle_SetAutoAfterRoute($enabled)
    $g_bAutoBattleAfterRoute = $enabled
    _BotLog("AutoBattleAfterRoute = " & ($enabled ? "ON" : "OFF"))
EndFunc

Func Battle_GetAutoAfterRoute()
    Return $g_bAutoBattleAfterRoute
EndFunc

Func Battle_Start()
    If $g_bBattle Then Return
    If Not AION_Activate() Then
        _BotLog("Battle_Start: не удалось активировать AION")
        Return
    EndIf

    $g_bBattle = True
    $g_tBattleStart = TimerInit()
    $g_tQ = 0
    $g_tF = 0
    $g_tE = 0
    $g_t5 = 0
    $g_t6 = 0

    _BotLog("Бой запущен")
EndFunc

Func Battle_Stop()
    If Not $g_bBattle Then
        _BotLog("Battle_Stop: бой уже остановлен")
        Return
    EndIf
    $g_bBattle = False
    _BotLog("Бой остановлен")
EndFunc

Func Battle_Process()
    If Not $g_bBattle Then Return

    Local $now = TimerDiff($g_tBattleStart) / 1000.0

    If $now - $g_tQ >= _Battle_RandInterval(0.5, 0.2) Then
        _Battle_Key(301)
        $g_tQ = $now
    EndIf

    If $now - $g_tF >= _Battle_RandInterval(5.0, 0.2) Then
        _Battle_Key(404)
        $g_tF = $now
    EndIf

    If $now - $g_tE >= _Battle_RandInterval(5.0, 0.2) Then
        _Battle_Key(303)
        $g_tE = $now
    EndIf

    If $now - $g_t5 >= _Battle_RandInterval(30.0, 0.2) Then
        _Battle_Key(205)
        $g_t5 = $now
    EndIf

    If $now - $g_t6 >= _Battle_RandInterval(50.0, 0.2) Then
        _Battle_Key(206)
        $g_t6 = $now
    EndIf
EndFunc

Func Battle_MaybeStartAfterRoute()
    If $g_bAutoBattleAfterRoute Then
        _BotLog("Маршрут завершён, авто-запуск боя")
        Battle_Start()
    Else
        _BotLog("Маршрут завершён, авто-бо́й отключён")
    EndIf
EndFunc

; INTERNAL
Func _Battle_RandInterval($base, $delta)
    Local $r = Random(-$delta, $delta)
    Return $base + $r
EndFunc

Func _Battle_Key($dd)
    Local $downTime = Random(50, 120, 1)
    DllCall($g_hDD, "int", "DD_key", "int", $dd, "int", 1)
    Sleep($downTime)
    DllCall($g_hDD, "int", "DD_key", "int", $dd, "int", 2)
    Sleep(Random(10, 40, 1))
EndFunc