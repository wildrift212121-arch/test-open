If @ScriptName <> "main.au3" Then
    Exit
EndIf


Func _BotLog($s)
    If $g_editLog = 0 Then Return

    Local $old = GUICtrlRead($g_editLog)
    Local $time = "[" & @HOUR & ":" & @MIN & ":" & @SEC & "] "
    GUICtrlSetData($g_editLog, $old & $time & $s & @CRLF)
EndFunc

Func _RandInterval($base, $delta)
    Return $base + Random(-$delta, $delta)
EndFunc

Func _IsChecked($ctrl)
    Return BitAND(GUICtrlRead($ctrl), $GUI_CHECKED) = $GUI_CHECKED
EndFunc

Func _Delay($ms, $msg = "")
    If $msg <> "" Then _BotLog($msg & " (" & $ms & " ms)")
    Sleep($ms)
EndFunc
