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

    ; Используем IMG_FindDeathButton() из imagesearch.au3
    Local $pos = IMG_FindDeathButton()

    If IsArray($pos) Then
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

    ; Ищем кнопку смерти/возрождения
    Local $pos = IMG_FindDeathButton()

    If IsArray($pos) Then
        _BotLog("Кнопка возрождения найдена")
        MouseClick("left", $pos[0], $pos[1])
        Sleep(1500)
    Else
        _BotLog("Кнопка возрождения НЕ найдена")
    EndIf

    ; Ждём загрузку
    Sleep(3000)

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
