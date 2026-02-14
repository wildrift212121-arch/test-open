; ============================
;   AION BOT — MAIN SCRIPT
;   main.au3
; ============================


#include <GUIConstantsEx.au3>
#include <WindowsConstants.au3>
#include <Array.au3>

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
$g_btnStartBattle   = GUICtrlCreateButton("Старт бой", 10, 240, 120, 30)
$g_btnStopBattle    = GUICtrlCreateButton("Стоп бой", 140, 240, 120, 30)

$g_btnStartRecord   = GUICtrlCreateButton("Запись маршрута", 10, 280, 120, 30)
$g_btnStopRecord    = GUICtrlCreateButton("Стоп запись", 140, 280, 120, 30)

$g_btnStartPlay     = GUICtrlCreateButton("Воспроизведение", 10, 320, 120, 30)
$g_btnStopPlay      = GUICtrlCreateButton("Стоп воспроизв.", 140, 320, 120, 30)

$g_chkDeath         = GUICtrlCreateCheckbox("Отслеживать смерть", 280, 240, 150, 20)

GUISetState(@SW_SHOW)

; -----------------------------------------
; INITIALIZATION
; -----------------------------------------
_BotLog("Initializing bot systems...")

If Not DD_Init() Then
    MsgBox(16, "Error", "Failed to initialize DD driver!")
    Exit
EndIf

IMG_Init()
Key_InitMap()

_BotLog("Bot initialized successfully")


; -----------------------------------------
; MAIN LOOP
; -----------------------------------------
While 1
    Local $msg = GUIGetMsg()

    Switch $msg

        Case $GUI_EVENT_CLOSE
            _BotLog("Shutting down...")
            Key_ReleaseAll()
            DD_Shutdown()
            IMG_Shutdown()
            Exit

        Case $g_btnStartBattle
            _BotLog("Нажата кнопка: старт боя")
            Battle_Start()

        Case $g_btnStopBattle
            _BotLog("Нажата кнопка: стоп боя")
            Battle_Stop()

        Case $g_btnStartRecord
            _BotLog("Нажата кнопка: запись маршрута")
            Recorder_Start()

        Case $g_btnStopRecord
            _BotLog("Нажата кнопка: стоп записи")
            Recorder_Stop()

        Case $g_btnStartPlay
            _BotLog("Нажата кнопка: воспроизведение")
            Playback_Start()

        Case $g_btnStopPlay
            _BotLog("Нажата кнопка: стоп воспроизведения")
            Playback_Stop()

        Case $g_chkDeath
            $g_bDeathCheck = _IsChecked($g_chkDeath)
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
