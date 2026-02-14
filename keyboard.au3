
; ============================
;   KEYBOARD CONTROL MODULE
;   keyboard.au3
; ============================
If @ScriptName <> "main.au3" Then
    Exit
EndIf


; -----------------------------------------
; INITIALIZE KEY MAP (VK → DD codes)
; -----------------------------------------
Func Key_InitMap()
    ; VK → DD
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


; -----------------------------------------
; PRESS OR RELEASE KEY
; dd = DD code
; state = "DOWN" / "UP"
; -----------------------------------------
Func Key_Send($dd, $state)
    Local $mode = ($state = "DOWN") ? 1 : 2

    ; Если включено кэширование — не дублируем состояние
    If _IsChecked($g_chkKeyCache) Then
        If $KeyState[$dd] = $mode Then Return
    EndIf

    DD_Key($dd, $mode)
    $KeyState[$dd] = $mode
EndFunc


; -----------------------------------------
; RELEASE ALL KEYS (safe)
; -----------------------------------------
Func Key_ReleaseAll()
    Local $keys[] = [ _
        302,401,402,403, _ ; WASD
        301,303,304,404, _ ; Q E R F
        501,502,503,504, _ ; 1–4
        201,202,203,204, _ ; arrows
        603,500,600,602, _ ; Space, Shift, Ctrl, Alt
        205,206 _          ; 5, 6
    ]

    For $i = 0 To UBound($keys) - 1
        DD_Key($keys[$i], 2)
        $KeyState[$keys[$i]] = 0
    Next

    ; Отпустить мышь
    DD_Btn(4)
    DD_Btn(8)

    _Log("Все клавиши и мышь отпущены")
EndFunc


; -----------------------------------------
; TEST KEYS (WASD)
; -----------------------------------------
Func Key_Test()
    _Log("Тест клавиш: WASD")

    Key_Send(302, "DOWN")
    Sleep(200)
    Key_Send(302, "UP")

    Key_Send(401, "DOWN")
    Sleep(200)
    Key_Send(401, "UP")

    Key_Send(402, "DOWN")
    Sleep(200)
    Key_Send(402, "UP")

    Key_Send(403, "DOWN")
    Sleep(200)
    Key_Send(403, "UP")
EndFunc
