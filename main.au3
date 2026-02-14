; ============================
;   AION BOT — MAIN SCRIPT
;   main.au3
; ============================


#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>

#include "globals.au3"
#include "utils.au3"
#include "dd.au3"
#include "aion.au3"
#include "battle.au3"
#include "death.au3"
#include "recorder.au3"
#include "playback.au3"
#include "imagesearch.au3"
#include "keyboard.au3"
#include "mouse.au3"

; дальше — создание GUI, логика, цикл

; -----------------------------------------
; CREATE GUI
; -----------------------------------------
$g_hGUI = GUICreate("AION BOT", 420, 420)

GUICtrlCreateLabel("Лог:", 10, 10, 100, 20)
$g_editLog = GUICtrlCreateEdit("", 10, 30, 400, 200, BitOR($ES_AUTOVSCROLL, $WS_VSCROLL))

; Кнопки
$btnStartBattle   = GUICtrlCreateButton("Старт бой", 10, 240, 120, 30)
$btnStopBattle    = GUICtrlCreateButton("Стоп бой", 140, 240, 120, 30)

$btnStartRecord   = GUICtrlCreateButton("Запись маршрута", 10, 280, 120, 30)
$btnStopRecord    = GUICtrlCreateButton("Стоп запись", 140, 280, 120, 30)

$btnStartPlay     = GUICtrlCreateButton("Воспроизведение", 10, 320, 120, 30)
$btnStopPlay      = GUICtrlCreateButton("Стоп воспроизв.", 140, 320, 120, 30)

$chkDeath         = GUICtrlCreateCheckbox("Отслеживать смерть", 280, 240, 150, 20)

GUISetState(@SW_SHOW)


; -----------------------------------------
; MAIN LOOP
; -----------------------------------------
While 1
    Local $msg = GUIGetMsg()

    Switch $msg

        Case $GUI_EVENT_CLOSE
            Exit

        Case $btnStartBattle
            _BotLog("Нажата кнопка: старт боя")
            Battle_Start()

        Case $btnStopBattle
            _BotLog("Нажата кнопка: стоп боя")
            Battle_Stop()

        Case $btnStartRecord
            _BotLog("Нажата кнопка: запись маршрута")
            Recorder_Start()

        Case $btnStopRecord
            _BotLog("Нажата кнопка: стоп записи")
            Recorder_Stop()

        Case $btnStartPlay
            _BotLog("Нажата кнопка: воспроизведение")
            Playback_Start()

        Case $btnStopPlay
            _BotLog("Нажата кнопка: стоп воспроизведения")
            Playback_Stop()

        Case $chkDeath
            $g_bDeathCheck = _IsChecked($chkDeath)
            _BotLog("Отслеживание смерти: " & ($g_bDeathCheck ? "включено" : "выключено"))

    EndSwitch


    ; -----------------------------------------
    ; BACKGROUND PROCESSING
    ; -----------------------------------------

    ; Автобой
    Battle_Process()

    ; Смерть
    Death_Process()

    ; Запись маршрута
    Recorder_Process()

    ; Воспроизведение маршрута
    Playback_Process()

    Sleep(20)
WEnd
