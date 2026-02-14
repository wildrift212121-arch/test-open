; ============================
;   DEATH DETECTION MODULE
;   death.au3
; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf



; -----------------------------------------
; CHECK IF CHARACTER IS DEAD
; -----------------------------------------
Func Death_Check()
    If Not $g_bDeathCheck Then Return False

    ; Ищем death.png на экране
    Local $res = Img_Find("death.png", 0, 0, 0, 0, 10)

    If $res[0] > 0 Then
        _BotLog("Смерть обнаружена")
        Return True
    EndIf

    Return False
EndFunc


; -----------------------------------------
; HANDLE DEATH (RESPAWN)
; -----------------------------------------
Func Death_Handle()
    _BotLog("Начинаю процесс возрождения")

    ; Нажимаем кнопку "Возродиться"
    Local $res = Img_Find("resurrect.png", 0, 0, 0, 0, 20)

    If $res[0] > 0 Then
        _BotLog("Кнопка возрождения найдена")
        MouseClick("left", $res[1][0], $res[1][1])
        Sleep(1500)
    Else
        _BotLog("Кнопка возрождения НЕ найдена")
    EndIf

    ; Ждём загрузку
    Sleep(3000)

    ; Нажимаем кнопку "ОК" после возрождения
    Local $ok = Img_Find("ok.png", 0, 0, 0, 0, 20)
    If $ok[0] > 0 Then
        _BotLog("ОК найден — подтверждаю возрождение")
        MouseClick("left", $ok[1][0], $ok[1][1])
        Sleep(1000)
    EndIf

    _BotLog("Возрождение завершено")
EndFunc


; -----------------------------------------
; MAIN LOOP CALL
; -----------------------------------------
Func Death_Process()
    If Not $g_bDeathCheck Then Return

    If Death_Check() Then
        Death_Handle()
    EndIf
EndFunc
