; ============================
;   IMAGE SEARCH MODULE
;   imagesearch.au3
; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf



; Подключаем новую UDF
#include "ImageSearchDLL_UDF.au3"


; -----------------------------------------
; INIT IMAGESEARCH
; -----------------------------------------
Func IMG_Init()
    Local $ok = _ImageSearch_Startup()
    If $ok Then
        _BotLog("ImageSearch: инициализация успешна")
    Else
        _BotLog("ImageSearch: ошибка инициализации")
    EndIf
EndFunc


; -----------------------------------------
; SHUTDOWN IMAGESEARCH
; -----------------------------------------
Func IMG_Shutdown()
    _ImageSearch_Shutdown()
    _BotLog("ImageSearch: завершение работы")
EndFunc


; -----------------------------------------
; FIND DEATH BUTTON INSIDE AION WINDOW
; Returns: [x, y] or 0
; -----------------------------------------
Func IMG_FindDeathButton()
    Local $h = AION_FindWindow()
    If $h = 0 Then
        _BotLog("IMG_FindDeathButton: окно AION2 не найдено")
        Return 0
    EndIf

    Local $r = AION_GetRect()
    If Not IsArray($r) Then
        _BotLog("IMG_FindDeathButton: не удалось получить координаты окна")
        Return 0
    EndIf

    Local $left = $r[0]
    Local $top = $r[1]
    Local $right = $r[2]
    Local $bottom = $r[3]

    ; Поиск PNG внутри окна - используем 14 параметров для совместимости с UDF 3.5
    ; _ImageSearch($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, $iResults, $iCenterPOS, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
    Local $a = _ImageSearch($DEATH_IMG, $left, $top, $right, $bottom, -1, 15, 1, 1, 1.0, 1.0, 0.1, 0, 0)

    If @error Or Not IsArray($a) Or $a[0] = 0 Then
        Return 0
    EndIf

    ; Возвращаем координаты центра кнопки
    Local $pos[2]
    $pos[0] = $a[1][0]
    $pos[1] = $a[1][1]
    Return $pos
EndFunc


; -----------------------------------------
; DEBUG: F8 — CHECK IF DEATH BUTTON IS FOUND
; -----------------------------------------
Func IMG_DebugDeath()
    Local $pos = IMG_FindDeathButton()

    If IsArray($pos) Then
        _BotLog("DEBUG: Кнопка смерти найдена: X=" & $pos[0] & " Y=" & $pos[1])
    Else
        _BotLog("DEBUG: Кнопка смерти НЕ найдена")
    EndIf
EndFunc
