; ============================
;   AUTO BATTLE MODULE
;   battle.au3
; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf




; -----------------------------------------
; START AUTO-BATTLE
; -----------------------------------------
Func Battle_Start()
    If $g_bBattle Then Return

    $g_bBattle = True
    $g_tBattleStart = TimerInit()

    ; Инициализация таймеров способностей
    $g_tQ = TimerInit()
    $g_tF = TimerInit()
    $g_tE = TimerInit()
    $g_t5 = TimerInit()
    $g_t6 = TimerInit()

    _BotLog("Автобой запущен")
EndFunc


; -----------------------------------------
; STOP AUTO-BATTLE
; -----------------------------------------
Func Battle_Stop()
    If Not $g_bBattle Then Return

    $g_bBattle = False
    Key_ReleaseAll()

    _BotLog("Автобой остановлен")
EndFunc


; -----------------------------------------
; INTERNAL: PRESS KEY WITH RANDOM DELAY
; -----------------------------------------
Func _BattleKey($dd, $base, $delta)
    Local $timerName = "g_t" & $dd
    Local $t = TimerDiff(Eval($timerName))
    Local $need = _RandInterval($base, $delta)

    If $t >= $need Then
        Key_Send($dd, "DOWN")
        Sleep(Random(40, 70))
        Key_Send($dd, "UP")

        Assign($timerName, TimerInit())

        _BotLog("Бой: нажата клавиша DD=" & $dd)
    EndIf
EndFunc


; -----------------------------------------
; PROCESS AUTO-BATTLE (called from main loop)
; -----------------------------------------
Func Battle_Process()
    If Not $g_bBattle Then Return

    ; Пример ротации:
    ; Q → F → E → 5 → 6

    ; Q (DD=301)
    _BattleKey(301, 900, 200)

    ; F (DD=303)
    _BattleKey(303, 1200, 300)

    ; E (DD=304)
    _BattleKey(304, 1500, 300)

    ; 5 (DD=205)
    _BattleKey(205, 2500, 500)

    ; 6 (DD=206)
    _BattleKey(206, 3000, 600)
EndFunc
