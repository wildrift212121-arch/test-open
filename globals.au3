; ============================
;   GLOBAL VARIABLES MODULE
;   globals.au3
; ============================


; --- Script info ---
Global Const $SCRIPT_NAME = "Aion 2 Route Tool v10.0 (Modular)"

; --- Paths ---
Global Const $INI = @ScriptDir & "\settings.ini"
Global Const $DD_DLL = @ScriptDir & "\dd60300.dll"
Global Const $DEATH_IMG = @ScriptDir & "\assets\death.png"

; --- AION window ---
Global $g_sAionTitle = "AION"

; --- DD handle ---
Global $g_hDD = -1

; --- Playback ---
Global $g_bPlayback = False
Global $g_iPlaybackIndex = 0
Global $g_sLog = ""
Global $g_aLines = 0
Global $g_iIndex = 0
Global $g_hTimer = 0
Global $g_bPlaying = False
Global $g_bLoop = False
Global $g_bOverlay = True

; --- Mouse settings ---
Global $K_move = IniRead($INI, "Mouse", "K_move", 3.5)
Global $K_click = IniRead($INI, "Mouse", "K_click", 1.0)
Global $g_bInvX = (IniRead($INI, "Mouse", "InvX", 0) = 1)
Global $g_bInvY = (IniRead($INI, "Mouse", "InvY", 0) = 1)
Global $g_bSmooth = (IniRead($INI, "Mouse", "Smooth", 1) = 1)
Global $g_iMinMove = IniRead($INI, "Mouse", "MinMove", 1)

; --- Key state cache ---
Global $KeyState[700]

; --- Recorder ---
Global $g_bRecording = False
Global $g_hRecTimer = 0
Global $g_hRecFile = -1
Global $g_sRecFilePath = ""
Global $g_iLastX = -1, $g_iLastY = -1
Global $g_bLastL = False, $g_bLastR = False
Global $g_aKeyMap[10][2]
Global $g_aRoute = []
Global $g_tRecord = 0

; --- Battle ---
Global $g_bBattle = False
Global $g_bAutoBattleAfterRoute = False
Global $g_tBattleStart = 0
Global $g_tQ = 0, $g_tF = 0, $g_tE = 0, $g_t5 = 0, $g_t6 = 0

; --- Death detection ---
Global $g_bDeathCheck = False
Global $g_tDeathCheck = 0

; --- GUI handles (filled in main.au3) ---
Global $g_hGUI = 0
Global $g_hTab = 0
Global $g_hStatus = 0
Global $g_hOverlay = 0

; --- GUI controls (declared here, created in main.au3) ---

Global $g_btnRecStart
Global $g_btnRecStop
Global $g_lblRecFile
Global $g_btnRecChoose
Global $g_btnLoad
Global $g_btnStart
Global $g_btnStop
Global $g_chkLoop
Global $g_chkOverlay
Global $g_inKMove
Global $g_inKClick
Global $g_chkInvX
Global $g_chkInvY
Global $g_chkSmooth
Global $g_inMinMove
Global $g_btnApplyMouse
Global $g_btnTestKeys
Global $g_btnReleaseKeys
Global $g_chkKeyCache
Global $g_editLog = 0
Global $g_btnClearLog
Global $g_btnTestMouse
Global $g_btnTestDD
Global $g_btnCheckAion
Global $g_btnSelectArea
Global $g_btnBattleStart
Global $g_btnBattleStop
Global $g_chkAutoBattle
Global $g_chkDeath
Global $g_lblInfo

; --- Additional missing variables ---
Global $g_sAionTitle = "AION2"
Global $g_aRoute = []
Global $g_tRecord = 0
Global $g_bPlayback = False
Global $g_iPlaybackIndex = 0
