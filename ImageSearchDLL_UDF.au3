#include-once
; #INDEX# =======================================================================================================================
; Title ............: ImageSearch_UDF
; AutoIt Version ...: 3.3.16.1+
; Language .........: English
; Description ......: Advanced image search library with cache system and SIMD optimization
; Author ...........: Dao Van Trong - TRONG.PRO
; Version ..........: 3.5
; Build Date .......: 2025-01-XX
; DLL Architecture .: C++14 (Windows XP SP3 - Windows 11)
; DLL Toolset ......: v141_xp
; ===============================================================================================================================
;
#include <Array.au3>
#include <WinAPI.au3>

;~ #RequireAdmin
;~ #AutoIt3Wrapper_UseX64=n
;~ #AutoIt3Wrapper_UseX64=y
;~ #pragma compile(x64, false)
;~ #pragma compile(x64, true)

; #CONSTANTS# ===================================================================================================================
Global Const $IMGS_UDF_VERSION = '3.5'
Global Const $IMGS_RESULTS_MAX = 64
Global Const $iSleepTime = 100
Global Const $g_IMGS_Debug = @Compiled ? False : True

; Cache System Constants
Global Const $IMGS_ENABLED_CACHE = 1   ;

; DLL Error Codes (matching C++ ErrorCode enum)
Global Const $IMGSE_INVALID_PATH = -1
Global Const $IMGSE_FAILED_TO_LOAD_IMAGE = -2
Global Const $IMGSE_FAILED_TO_GET_SCREEN_DC = -3
Global Const $IMGSE_INVALID_SEARCH_REGION = -4
Global Const $IMGSE_INVALID_PARAMETERS = -5
Global Const $IMGSE_INVALID_SOURCE_BITMAP = -6
Global Const $IMGSE_INVALID_TARGET_BITMAP = -7
Global Const $IMGSE_RESULT_TOO_LARGE = -9
Global Const $IMGSE_INVALID_MONITOR = -10

; ===============================================================================================================================

; #GLOBAL VARIABLES# ============================================================================================================
Global $g_bImageSearch_Debug = $g_IMGS_Debug

Global $g_sImgSearchDLL_Path = ""
Global $g_hImageSearchDLL = -1
Global $g_bImageSearch_Initialized = False
Global $g_sLastDllReturn = ""
Global $g_sImgSearchDLL_Dir = @ScriptDir
Global $g_sImgSearchDLL_CustomPath = ""
Global $g_bImageSearch_UseEmbeddedDLL = False
Global $g_sImgSearch_TempDLLPath = ""
Global $g_aMonitorList[1][9]

; DLL Info Cache (parsed from Get_DllInfo)
Global $g_sDllInfoCache = ""           ; Raw INI string
Global $g_mDllInfoParsed = Null         ; Parsed Map/Dictionary
; ===============================================================================================================================

; #TABLE OF CONTENTS (PUBLIC API)# =============================================================================================
;
; 📌 Startup & Configuration:
;   _ImageSearch_Startup              ; Initialize ImageSearch library by loading the DLL
;   _ImageSearch_Shutdown             ; Cleanup and unload the DLL
;   _ImageSearch_SetDllPath           ; Set custom DLL path before initialization
;
; 🔍 Core Search Functions:
;   _ImageSearch                      ; Search for image(s) on screen within specified region
;   _ImageSearch_InImage              ; Search for image(s) within another image file (offline)
;   _ImageSearch_hBitmap              ; Search for HBITMAP within another HBITMAP (advanced, uses hBitmap_Search)
;
; 📸 Screen Capture Functions:
;   _ImageSearch_CaptureScreen        ; Capture screen region to HBITMAP (DPI-aware, multi-monitor)
;   _ImageSearch_ScreenCapture_SaveImage ; Capture screen and save directly to file (BMP/PNG/JPG, 2x faster)
;   _ImageSearch_hBitmapLoad          ; Load image file to HBITMAP with background color support
;
; 🖱️ Mouse Functions:
;   _ImageSearch_MouseMove            ; Move mouse cursor with smooth movement and multi-monitor support
;   _ImageSearch_MouseClick           ; Click mouse at coordinates with configurable speed and clicks
;   _ImageSearch_MouseClickWin        ; Click at window-relative coordinates with window search
;
; ⏱️ Wait & Click Functions:
;   _ImageSearch_Wait                 ; Wait for image to appear with timeout (non-blocking)
;   _ImageSearch_WaitClick            ; Wait for image and click when found (combines Wait + Click)
;
; 🖥️ Monitor Functions:
;   _ImageSearch_Monitor_GetList      ; Get array of all monitors with position, size, DPI info
;   _ImageSearch_Monitor_ToVirtual    ; Convert monitor-relative coords to virtual desktop coords
;   _ImageSearch_Monitor_FromVirtual  ; Convert virtual desktop coords to monitor-relative coords
;   _ImageSearch_Monitor_Current      ; Auto-detect which monitor contains cursor (cursor-aware)
;   _ImageSearch_Monitor_GetAtPosition ; Get monitor info at position with auto cursor detection
;
; 🪟 Window Coordinate Functions:
;   _ImageSearch_Window_ToScreen      ; Convert window-relative coords to screen coords (client/full)
;   _ImageSearch_Window_FromScreen    ; Convert screen coords to window-relative coords (client/full)
;
; 🛠️ Cache & Info Functions:
;   _ImageSearch_ClearCache           ; Clear all cached image locations and bitmaps
;   _ImageSearch_WarmUpCache          ; Pre-load images into cache for faster searches
;   _ImageSearch_GetDllInfo           ; Get comprehensive DLL info (DLL, OS, CPU, Screen, Cache) in INI format ⭐ RECOMMENDED
;   _ImageSearch_GetLastResult        ; Get raw DLL return string from last search (debug)
;   _ImageSearch_PrimaryScale         ; Get primary monitor DPI scale (uses cached GetDllInfo)
;   _ImageSearch_GetDllValue          ; Generic accessor for any DLL info value
;
; ===============================================================================================================================


; #PUBLIC FUNCTIONS - STARTUP & CONFIG# ========================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Startup
; Description ...: Initializes the ImageSearch library by loading the appropriate DLL
; Syntax ........: _ImageSearch_Startup()
; Parameters ....: None
; Return values .: Success - 1 (DLL loaded successfully)
;                  Failure - 0 (DLL not found or load failed)
;                  Failure - 0 and sets @error:
;                  |1 - No DLL found
;                  |2 - DllOpen failed
;                  |3 - Architecture mismatch
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Must be called before using any search functions
;                  Automatically called on script start
;
;                  IMPORTANT: DLL v5+ uses thread-local DPI awareness.
;                  Loading this DLL will NOT affect your AutoIt GUI, even on high-DPI displays.
;                  Safe to load before or after GUICreate() without GUI resize issues.
; ===============================================================================================================================
Func _ImageSearch_Startup()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Startup()" & @CRLF)
	If $g_bImageSearch_Initialized Then Return 1
	If $g_bImageSearch_Debug Then ConsoleWrite(">> ImageSearch UDF Version: " & $IMGS_UDF_VERSION & @CRLF)
	; Priority 1: Custom path
	If ($g_sImgSearchDLL_CustomPath <> "") And FileExists($g_sImgSearchDLL_CustomPath) Then
		$g_sImgSearchDLL_Path = $g_sImgSearchDLL_CustomPath
		If $g_bImageSearch_Debug Then ConsoleWrite(">> Using custom DLL: " & $g_sImgSearchDLL_Path & @CRLF)
	EndIf

	; Priority 2: Auto-search
	If ($g_sImgSearchDLL_Path = "") Or (Not FileExists($g_sImgSearchDLL_Path)) Then
		Local $aDllNames[3], $sSuffix = "ImageSearchDLL"
		$aDllNames[0] = $sSuffix & "_" & (@AutoItX64 ? "x64" : "x86") & ".dll"
		$aDllNames[1] = $sSuffix & ".dll"
		$aDllNames[2] = $sSuffix & "_XP_" & (@AutoItX64 ? "x64" : "x86") & ".dll"

		Local $sPath
		For $i = 0 To UBound($aDllNames) - 1
			$sPath = $g_sImgSearchDLL_Dir & "\" & $aDllNames[$i]
			If $g_bImageSearch_Debug Then ConsoleWrite('>> Find and Check DLL Path: ' & $sPath & @CRLF)
			If FileExists($sPath) Then
				$g_sImgSearchDLL_Path = $sPath
				ExitLoop
			EndIf
		Next
	EndIf
	Local $sArch = __ImgSearch_GetFileArch($g_sImgSearchDLL_Path, True)
	If ((($sArch = "x86") And @AutoItX64) Or (($sArch = "x64") And Not @AutoItX64)) Then
		If $g_bImageSearch_Debug Then ConsoleWrite('! Wrong Dll Arch [' & $sArch & ']: ' & $g_sImgSearchDLL_Path & @CRLF)
	EndIf
	If ((($sArch = "x86") And @AutoItX64) Or (($sArch = "x64") And (Not @AutoItX64))) Or ($g_sImgSearchDLL_Path = "") Or (Not FileExists($g_sImgSearchDLL_Path)) Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> No external DLL found" & @CRLF)
		Return SetError(1, 0, 0)
	Else
		If $g_bImageSearch_Debug Then ConsoleWrite('>> DLL Architecture: ' & $sArch & @CRLF)
	EndIf
	$g_hImageSearchDLL = DllOpen($g_sImgSearchDLL_Path)
	If $g_hImageSearchDLL = -1 Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> ERROR: DllOpen failed: " & $g_sImgSearchDLL_Path & @CRLF)
		Return SetError(2, 0, 0)
	EndIf
	OnAutoItExitRegister("_ImageSearch_Shutdown")
	$g_bImageSearch_Initialized = True
	If $g_bImageSearch_Debug Then
		Local $sDllInfoAll = _ImageSearch_GetInfo()
		Local $sDllType = ($g_bImageSearch_UseEmbeddedDLL ? "[Embedded]" : "[External]")
		ConsoleWrite(">> ImageSearch DLL loaded successfully " & $sDllType & @CRLF)
		ConsoleWrite(">> Dll Path: " & $g_sImgSearchDLL_Path & @CRLF)
		ConsoleWrite($sDllInfoAll & @CRLF)
		ConsoleWrite(">> Screen Scale: " & _ImageSearch_GetScale() & @CRLF)
	EndIf
	Local $l_MonitorInfo = _ImageSearch_Monitor_GetList()
	If $g_bImageSearch_Debug Then ConsoleWrite($l_MonitorInfo)
	Return 1
EndFunc   ;==>_ImageSearch_Startup

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Shutdown
; Description ...: Closes the DLL and cleans up resources
; Syntax ........: _ImageSearch_Shutdown()
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Shutdown()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Shutdown()" & @CRLF)
	If Not $g_bImageSearch_Initialized Then Return
	If $g_hImageSearchDLL <> -1 Then
		DllClose($g_hImageSearchDLL)
		$g_hImageSearchDLL = -1
	EndIf
	; Clean up embedded DLL if used
	If $g_bImageSearch_UseEmbeddedDLL And $g_sImgSearch_TempDLLPath <> "" Then
		If FileExists($g_sImgSearch_TempDLLPath) Then
			; Retry mechanism because file might be locked
			Local $iRetries = 3
			While $iRetries > 0
				FileDelete($g_sImgSearch_TempDLLPath)
				If Not FileExists($g_sImgSearch_TempDLLPath) Then
					If $g_bImageSearch_Debug Then ConsoleWrite(">> Cleaned up embedded DLL: " & $g_sImgSearch_TempDLLPath & @CRLF)
					ExitLoop
				EndIf
				Sleep(100)
				$iRetries -= 1
			WEnd
			If FileExists($g_sImgSearch_TempDLLPath) Then
				If $g_bImageSearch_Debug Then ConsoleWrite("!> Warning: Could not delete temp DLL: " & $g_sImgSearch_TempDLLPath & @CRLF)
			EndIf
		EndIf
	EndIf
	$g_bImageSearch_Initialized = False
	If $g_bImageSearch_Debug Then ConsoleWrite(">> ImageSearch DLL closed" & @CRLF)
EndFunc   ;==>_ImageSearch_Shutdown

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_SetDllPath
; Description ...: Sets a custom DLL path (must be called before _ImageSearch_Startup)
; Syntax ........: _ImageSearch_SetDllPath($sPath)
; Parameters ....: $sPath - Full path to the DLL file
; Return values .: Success - 1
;                  Failure - 0 (file not found)
; ===============================================================================================================================
Func _ImageSearch_SetDllPath($sPath)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_SetDllPath($sPath=" & $sPath & ")" & @CRLF)
	If Not FileExists($sPath) Then Return 0
	$g_sImgSearchDLL_CustomPath = $sPath
	Return 1
EndFunc   ;==>_ImageSearch_SetDllPath

; #PUBLIC FUNCTIONS - CORE SEARCH# ============================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch
; Description ...: Searches for an image within a specified screen area
; Syntax ........: _ImageSearch($sImagePath, $iLeft=0, $iTop=0, $iRight=0, $iBottom=0[, $iScreen = -1[, $iTolerance = 10[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug]]]]]]]])
; Parameters ....: $sImagePath     - Image file path(s), multiple separated by "|"
;                  $iLeft          - [optional] Left boundary (0 = entire screen)
;                  $iTop           - [optional] Top boundary (0 = entire screen)
;                  $iRight         - [optional] Right boundary (0 = entire screen)
;                  $iBottom        - [optional] Bottom boundary (0 = entire screen)
;                  $iScreen        - [optional] Monitor index:
;                                    iScreen < 0: Virtual screen (all monitors combined)
;                                    iScreen = 0: Use provided region params only (primary screen if region=0)
;                                    iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                  $iTolerance     - [optional] Color tolerance 0-255 (default: 10)
;                  $iResults       - [optional] Max results 1-1024 (default: 1)
;                  $iCenterPOS     - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale      - [optional] Min scale 0.1-5.0 (default: 1.0)
;                  $fMaxScale      - [optional] Max scale (default: 1.0)
;                  $fScaleStep     - [optional] Scale step (default: 0.1)
;                  $iReturnDebug   - [optional] Debug mode (default: 0)
;                  $iUseCache      - [optional] Enable cache (0=off, 1=on, default: 0)
; Return values .: Success - Array of found positions:
;                    [0] = Match count (0 if not found)
;                    [1][0] = X coordinate of first match
;                    [1][1] = Y coordinate of first match
;                    [1][2] = Width of matched image
;                    [1][3] = Height of matched image
;                    [n][0..3] = Additional matches if $iResults > 1
;                  Failure - Empty array, @error set to error code
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: - Set bounds to 0 to search entire screen
;                  - Supports multiple images: "img1.png|img2.png|img3.png"
;                  - Uses SIMD (AVX512/AVX2/SSE2) for fast searching
;                  - Cache system significantly speeds up repeated searches
; Example .......: ; Search for a button image on screen
;                  Local $aResult = _ImageSearch("button.png")
;                  If $aResult[0] > 0 Then
;                      ConsoleWrite("Found at: " & $aResult[1][0] & ", " & $aResult[1][1] & @CRLF)
;                      MouseClick("left", $aResult[1][0], $aResult[1][1])
;                  EndIf
;
;                  ; Search for multiple images with scaling
;                  Local $aResult = _ImageSearch("icon1.png|icon2.png", 0, 0, 800, 600, -1, 10, 5, 1, 0.8, 1.2, 0.1)
;                  If $aResult[0] > 0 Then
;                      For $i = 1 To $aResult[0]
;                          ConsoleWrite("Match " & $i & " at: " & $aResult[$i][0] & ", " & $aResult[$i][1] & @CRLF)
;                      Next
;                  EndIf
; ===============================================================================================================================
Func _ImageSearch($sImagePath, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = -1, $iTolerance = 10, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return __ImgSearch_MakeEmptyResult()
	If $g_bImageSearch_Debug Then $iReturnDebug = $g_bImageSearch_Debug
	; Validate and normalize parameters
	$sImagePath = __ImgSearch_NormalizePaths($sImagePath)
	If $sImagePath = "" Then Return __ImgSearch_MakeEmptyResult()
	$iTolerance = __ImgSearch_Clamp($iTolerance, 0, 255)
	$iResults = __ImgSearch_Clamp($iResults, 1, $IMGS_RESULTS_MAX)
	$iCenterPOS = ($iCenterPOS = 0 ? 0 : 1)
	$fMinScale = __ImgSearch_Clamp($fMinScale, 0.1, 5.0)
	$fMaxScale = __ImgSearch_Clamp($fMaxScale, $fMinScale, 5.0)
	$fScaleStep = __ImgSearch_Clamp($fScaleStep, 0.01, 1.0)
	$iReturnDebug = ($iReturnDebug) ? 1 : 0
	$iUseCache = ($iUseCache) ? 1 : 0
	If $g_bImageSearch_Debug Then ConsoleWrite("+ _ImageSearch_Area($sImagePath=" & $sImagePath & ", $iLeft =" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ", $iTolerance=" & $iTolerance & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache = " & $iUseCache & ')' & @CRLF)

	; Call DLL - NEW SIMPLIFIED SIGNATURE
	Local $aDLL = DllCall($g_hImageSearchDLL, "wstr", "ImageSearch", _
			"wstr", $sImagePath, _
			"int", $iLeft, _
			"int", $iTop, _
			"int", $iRight, _
			"int", $iBottom, _
			"int", $iScreen, _
			"int", $iTolerance, _
			"int", $iResults, _
			"int", $iCenterPOS, _
			"float", $fMinScale, _
			"float", $fMaxScale, _
			"float", $fScaleStep, _
			"int", $iReturnDebug, _
			"int", $iUseCache)
	If @error Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DllCall error: " & @error & @CRLF)
		Return SetError(1, @error, __ImgSearch_MakeEmptyResult())
	EndIf
	; Parse result
	Local $sResult = $aDLL[0]
	$g_sLastDllReturn = $sResult
	If $g_bImageSearch_Debug Then ConsoleWrite(">> DLL returned: " & $sResult & @CRLF)
	Local $aResult = __ImgSearch_ParseResult($sResult)
	; Check if parser set error (from DLL error code)
	If @error Then
		Return SetError(@error, 0, $aResult)
	EndIf
	Return $aResult
EndFunc   ;==>_ImageSearch

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_InImage
; Description ...: Searches for a target image within a source image (file-to-file search)
; Syntax ........: _ImageSearch_InImage($sSourceImage, $sTargetImage[, $iTolerance = 10[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug]]]]]]])
; Parameters ....: $sSourceImage   - Path to source (Source) image file
;                  $sTargetImage   - Path to target (Target) image file(s), multiple separated by "|"
;                  $iTolerance     - [optional] Color tolerance (default: 10)
;                  $iResults       - [optional] Max results (default: 1)
;                  $iCenterPOS     - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale      - [optional] Min scale (default: 1.0)
;                  $fMaxScale      - [optional] Max scale (default: 1.0)
;                  $fScaleStep     - [optional] Scale step (default: 0.1)
;                  $iReturnDebug   - [optional] Debug mode (default: 0)
;                  $iUseCache      - [optional] User cache  (default: 0)
; Return values .: Same as _ImageSearch
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Useful for pre-processing images or testing without screen capture
; Example .......: $aResult = _ImageSearch_InImage("screenshot.png", "button.png", 20)
; ===============================================================================================================================
Func _ImageSearch_InImage($sSourceImage, $sTargetImage, $iTolerance = 10, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE)
	If $g_IMGS_Debug Then ConsoleWrite("+ _ImageSearch_InImage($sSourceImage=" & $sSourceImage & ", $sTargetImage=" & $sTargetImage & ", $iTolerance=" & $iTolerance & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache: " & $iUseCache & ')' & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return __ImgSearch_MakeEmptyResult()
	If $g_bImageSearch_Debug Then $iReturnDebug = $g_bImageSearch_Debug
	; Validate
	If Not FileExists($sSourceImage) Then Return __ImgSearch_MakeEmptyResult()
	$sTargetImage = __ImgSearch_NormalizePaths($sTargetImage)
	If $sTargetImage = "" Then Return __ImgSearch_MakeEmptyResult()
	$iTolerance = __ImgSearch_Clamp($iTolerance, 0, 255)
	$iResults = __ImgSearch_Clamp($iResults, 1, $IMGS_RESULTS_MAX)
	$iCenterPOS = ($iCenterPOS = 0 ? 0 : 1)
	$fMinScale = __ImgSearch_Clamp($fMinScale, 0.1, 5.0)
	$fMaxScale = __ImgSearch_Clamp($fMaxScale, $fMinScale, 5.0)
	$fScaleStep = __ImgSearch_Clamp($fScaleStep, 0.01, 1.0)
	$iReturnDebug = ($iReturnDebug) ? 1 : 0
	$iUseCache = ($iUseCache) ? 1 : 0
	; Call DLL
	Local $aDLL = DllCall($g_hImageSearchDLL, "wstr", "Search_In_Image", _
			"wstr", $sSourceImage, _
			"wstr", $sTargetImage, _
			"int", $iTolerance, _
			"int", $iResults, _
			"int", $iCenterPOS, _
			"float", $fMinScale, _
			"float", $fMaxScale, _
			"float", $fScaleStep, _
			"int", $iReturnDebug, _
			"int", $iUseCache)
	If @error Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DllCall error: " & @error & @CRLF)
		Return SetError(1, @error, __ImgSearch_MakeEmptyResult())
	EndIf
	Local $sResult = $aDLL[0]
	$g_sLastDllReturn = $sResult
	If $g_bImageSearch_Debug Then ConsoleWrite(">> DLL returned: " & $sResult & @CRLF)
	Local $aResult = __ImgSearch_ParseResult($sResult)
	If @error Then
		Return SetError(@error, 0, $aResult)
	EndIf
	Return $aResult
EndFunc   ;==>_ImageSearch_InImage

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_hBitmap
; Description ...: Searches for a target bitmap within a Source bitmap (memory-to-memory search)
; Syntax ........: _ImageSearch_hBitmap($hBitmapSource, $hBitmapTarget[, $iTolerance = 10[, $iLeft = 0[, $iTop = 0[, $iRight = 0[, $iBottom = 0[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug]]]]]]]]]]])
; Parameters ....: $hBitmapSource - Handle to Source bitmap (HBITMAP)
;                  $hBitmapTarget   - Handle to Target bitmap (HBITMAP)
;                  $iTolerance      - [optional] Color tolerance (default: 10)
;                  $iLeft/$iTop/$iRight/$iBottom - [optional] Search region in Source (0 = entire bitmap)
;                  $iResults        - [optional] Max results (default: 1)
;                  $iCenterPOS         - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale       - [optional] Min scale (default: 1.0)
;                  $fMaxScale       - [optional] Max scale (default: 1.0)
;                  $fScaleStep      - [optional] Scale step (default: 0.1)
;                  $iReturnDebug    - [optional] Debug mode (default: 0)
;                  $iUseCache       - [optional] User cache  (default: 0)
; Return values .: Same as _ImageSearch
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Fastest method for repeated searches (no disk I/O)
;                  Bitmaps must be created with GDI/GDI+ functions
; Example .......:
;   $hScreen = _ScreenCapture_Capture("", 0, 0, 800, 600)
;   $hIcon = _GDIPlus_BitmapCreateHBITMAPFromBitmap($pBitmap)
;   $aResult = _ImageSearch_hBitmap($hScreen, $hIcon, 10)
;   _WinAPI_DeleteObject($hScreen)
;   _WinAPI_DeleteObject($hIcon)
; ===============================================================================================================================
Func _ImageSearch_hBitmap($hBitmapSource, $hBitmapTarget, $iTolerance = 10, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_hBitmap($hBitmapSource, $hBitmapTarget, $iTolerance = " & $iTolerance & ", $iLeft =" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache=" & $iUseCache & ')' & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return __ImgSearch_MakeEmptyResult()
	If $g_bImageSearch_Debug Then $iReturnDebug = $g_bImageSearch_Debug
	; Validate
	$iTolerance = __ImgSearch_Clamp($iTolerance, 0, 255)
	$iResults = __ImgSearch_Clamp($iResults, 1, $IMGS_RESULTS_MAX)
	$iCenterPOS = ($iCenterPOS = 0 ? 0 : 1)
	$fMinScale = __ImgSearch_Clamp($fMinScale, 0.1, 5.0)
	$fMaxScale = __ImgSearch_Clamp($fMaxScale, $fMinScale, 5.0)
	$fScaleStep = __ImgSearch_Clamp($fScaleStep, 0.01, 1.0)
	$iReturnDebug = ($iReturnDebug) ? 1 : 0
	$iUseCache = ($iUseCache) ? 1 : 0 ; Call DLL
	Local $aDLL = DllCall($g_hImageSearchDLL, "wstr", "hBitmap_Search", _
			"handle", $hBitmapSource, _
			"handle", $hBitmapTarget, _
			"int", $iTolerance, _
			"int", $iLeft, _
			"int", $iTop, _
			"int", $iRight, _
			"int", $iBottom, _
			"int", $iResults, _
			"int", $iCenterPOS, _
			"float", $fMinScale, _
			"float", $fMaxScale, _
			"float", $fScaleStep, _
			"int", $iReturnDebug, _
			"int", $iUseCache)
	If @error Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DllCall error: " & @error & @CRLF)
		Return SetError(1, @error, __ImgSearch_MakeEmptyResult())
	EndIf
	Local $sResult = $aDLL[0]
	$g_sLastDllReturn = $sResult
	If $g_bImageSearch_Debug Then ConsoleWrite(">> DLL returned: " & $sResult & @CRLF)
	Local $aResult = __ImgSearch_ParseResult($sResult)
	If @error Then
		Return SetError(@error, 0, $aResult)
	EndIf
	Return $aResult
EndFunc   ;==>_ImageSearch_hBitmap


; #PUBLIC FUNCTIONS - UTILITIES# ==============================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_hBitmapLoad
; Description ...: Load image file and convert to HBITMAP handle
; Syntax ........: _ImageSearch_hBitmapLoad($sImageFile[, $iAlpha = 0[, $iRed = 0[, $iGreen = 0[, $iBlue = 0]]]])
; Parameters ....: $sImageFile - Path to image file
;                  $iAlpha     - Alpha channel (0-255, default=0 transparent)
;                  $iRed       - Red component (0-255, default=0)
;                  $iGreen     - Green component (0-255, default=0)
;                  $iBlue      - Blue component (0-255, default=0)
; Return values .: Success - HBITMAP handle (must DeleteObject when done)
;                  Failure - 0 and sets @error:
;                  |1 - DLL not initialized
;                  |2 - DLL call failed
;                  |3 - Invalid file path
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Remember to DeleteObject() the returned HBITMAP when finished
; Example .......: $hBitmap = _ImageSearch_hBitmapLoad("image.png", 255, 255, 255, 255) ; White background
;                  ; ... use $hBitmap ...
;                  _WinAPI_DeleteObject($hBitmap) ;#include <WinAPIHObj.au3>
; ===============================================================================================================================
Func _ImageSearch_hBitmapLoad($sImageFile, $iAlpha = 0, $iRed = 0, $iGreen = 0, $iBlue = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_hBitmapLoad($sImageFile=" & $sImageFile & ", $iAlpha=" & $iAlpha & ", $iRed=" & $iRed & ", $iGreen=" & $iGreen & ", $iBlue=" & $iBlue & ")" & @CRLF)
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, 0)
	EndIf
	If Not FileExists($sImageFile) Then Return SetError(3, 0, 0)
	Local $aResult = DllCall($g_hImageSearchDLL, "handle", "hBitmap_Load", _
			"wstr", $sImageFile, _
			"int", $iAlpha, _
			"int", $iRed, _
			"int", $iGreen, _
			"int", $iBlue)
	If @error Or Not IsArray($aResult) Or $aResult[0] = 0 Then
		Return SetError(2, @error, 0)
	EndIf
	Return $aResult[0]
EndFunc   ;==>_ImageSearch_hBitmapLoad

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_CaptureScreen
; Description ...: Capture screen region and return as HBITMAP handle
; Syntax ........: _ImageSearch_CaptureScreen([$iLeft = 0[, $iTop = 0[, $iRight = 0[, $iBottom = 0[, $iScreen = -1]]]]])
; Parameters ....: $iLeft   - Left coordinate (default=0)
;                  $iTop    - Top coordinate (default=0)
;                  $iRight  - Right coordinate (default=0, full width)
;                  $iBottom - Bottom coordinate (default=0, full height)
;                  $iScreen - Monitor index:
;                             iScreen < 0: Virtual screen (all monitors combined)
;                             iScreen = 0: User absolute coordinates (primary screen or multi-monitor)
;                                          Supports negative coords for secondary monitors (e.g., -1920, 0)
;                                          Use (0,0,0,0) for full primary screen
;                             iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                                          Coords relative to monitor origin, (0,0,0,0) = full monitor
; Return values .: Success - HBITMAP handle (must DeleteObject when done)
;                  Failure - 0 and sets @error:
;                  |1 - DLL not initialized
;                  |2 - DLL call failed
;                  |3 - Invalid screen region
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Remember to DeleteObject() the returned HBITMAP when finished
; Example .......: $hBitmap = _ImageSearch_CaptureScreen(0, 0, 800, 600)
;                  ; ... use $hBitmap ...
;                  _WinAPI_DeleteObject($hBitmap) ; #include <WinAPIHObj.au3>
; ===============================================================================================================================
Func _ImageSearch_CaptureScreen($iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = -1)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_CaptureScreen($iLeft=" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ")" & @CRLF)
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, 0)
	EndIf
	Local $aResult = DllCall($g_hImageSearchDLL, "handle", "Capture_Screen", _
			"int", $iLeft, _
			"int", $iTop, _
			"int", $iRight, _
			"int", $iBottom, _
			"int", $iScreen)
	If @error Or Not IsArray($aResult) Or $aResult[0] = 0 Then
		Return SetError(2, @error, 0)
	EndIf
	Return $aResult[0]
EndFunc   ;==>_ImageSearch_CaptureScreen

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_ScreenCapture_SaveImage
; Description ...: Captures a screen region and saves it directly to an image file in one call.
;                  Automatically detects format from file extension (BMP, PNG, JPG).
;                  Combines capture + save for maximum performance (2x faster than AutoIt GDI+).
; Syntax ........: _ImageSearch_ScreenCapture_SaveImage($sImageFile[, $iLeft = 0[, $iTop = 0[, $iRight = 0[, $iBottom = 0[, $iScreen = 0]]]]])
; Parameters ....: $sImageFile - Output file path (extension determines format: .bmp, .png, .jpg/.jpeg)
;                                Default to BMP if extension not recognized
;                  $iLeft      - [optional] Left coordinate (default: 0)
;                  $iTop       - [optional] Top coordinate (default: 0)
;                  $iRight     - [optional] Right coordinate (default: 0, full width)
;                  $iBottom    - [optional] Bottom coordinate (default: 0, full height)
;                  $iScreen    - [optional] Monitor index (default: 0):
;                                iScreen < 0: Virtual screen (all monitors combined)
;                                iScreen = 0: User absolute coordinates (primary screen or multi-monitor)
;                                             Supports negative coords for secondary monitors (e.g., -1920, 0)
;                                             Use (0,0,0,0) for full primary screen
;                                iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                                             Coords relative to monitor origin, (0,0,0,0) = full monitor
; Return values .: Success - True (1)
;                  Failure - False (0) and sets @error:
;                  |1 - DLL not initialized
;                  |2 - DLL call failed (capture or save failed)
;                  |3 - Invalid file path
; Remarks .......: * No need to manage HBITMAP - DLL handles all memory management internally
;                  * JPEG quality is fixed at 100% (highest quality)
;                  * Uses DPI-aware capture (accurate on all DPI scales)
;                  * ~2x faster than _ImageSearch_CaptureScreen + _ImageSearch_HBitmapSaveToFile
;                  * Supported formats: BMP (uncompressed), PNG (lossless), JPEG (quality 100%)
;                  * Thread-safe with proper GDI+ initialization
; Author ........: Dao Van Trong - TRONG.PRO
; Example .......: ; Capture full primary screen to PNG
;                  _ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\screenshot.png")
;
;                  ; Capture region (100, 100, 600, 400) on monitor 2 to JPEG
;                  _ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\region.jpg", 100, 100, 600, 400, 2)
;
;                  ; Capture entire virtual desktop to BMP
;                  _ImageSearch_ScreenCapture_SaveImage(@ScriptDir & "\desktop.bmp", 0, 0, 0, 0, -1)
; ===============================================================================================================================
Func _ImageSearch_ScreenCapture_SaveImage($sImageFile, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_ScreenCapture_SaveImage($sImageFile=" & $sImageFile & ", $iLeft=" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ")" & @CRLF)

	; Validate input
	If Not $sImageFile Or $sImageFile = "" Then Return SetError(3, 0, False)

	; Initialize DLL if needed
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, False)
	EndIf

	; Call DLL function (capture + save in one optimized call)
	Local $aResult = DllCall($g_hImageSearchDLL, "int", "Capture_Screen_Save", _
			"wstr", $sImageFile, _
			"int", $iLeft, _
			"int", $iTop, _
			"int", $iRight, _
			"int", $iBottom, _
			"int", $iScreen)

	If @error Or Not IsArray($aResult) Then
		If $g_IMGS_Debug Then ConsoleWrite("!> DLL call failed, @error=" & @error & @CRLF)
		Return SetError(2, @error, False)
	EndIf

	; Check result (1 = success, 0 = failure)
	If $aResult[0] = 1 Then
		If $g_IMGS_Debug Then ConsoleWrite(">> Successfully saved screenshot to: " & $sImageFile & @CRLF)
		Return SetError(0, 0, True)
	Else
		If $g_IMGS_Debug Then ConsoleWrite("!> Failed to save screenshot" & @CRLF)
		Return SetError(2, 0, False)
	EndIf
EndFunc   ;==>_ImageSearch_ScreenCapture_SaveImage


; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Wait
; Description ...: Waits for an image to appear on screen with timeout and optional max attempts limit
; Syntax ........: _ImageSearch_Wait($iTimeout, $sImagePath[, $iSleepTime = 100[, $iScreen = -1[, $iTolerance = 10[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug[, $iUseCache = $IMGS_ENABLED_CACHE[, $iMaxAttempts = 0]]]]]]]]]]]
; Parameters ....: $iTimeout       - Timeout in milliseconds (0 = wait forever)
;                  $sImagePath     - Image file path(s), multiple separated by "|"
;                  $iSleepTime     - [optional] Sleep between checks in ms (default: 100)
;                  $iScreen        - [optional] Monitor index:
;                                    iScreen < 0: Virtual screen (all monitors combined)
;                                    iScreen = 0: Use provided region params only (primary screen if region=0)
;                                    iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                  $iTolerance     - [optional] Color tolerance 0-255 (default: 10)
;                  $iResults       - [optional] Max results 1-1024 (default: 1)
;                  $iCenterPOS     - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale      - [optional] Min scale 0.1-5.0 (default: 1.0)
;                  $fMaxScale      - [optional] Max scale (default: 1.0)
;                  $fScaleStep     - [optional] Scale step (default: 0.1)
;                  $iReturnDebug   - [optional] Debug mode (default: 0)
;                  $iUseCache      - [optional] User cache  (default: 0)
;                  $iMaxAttempts   - [optional] Max number of search attempts (0 = unlimited, default: 0)
; Return values .: Success - 2D Array (same as _ImageSearch)
;                  Timeout - Empty array with [0][0] = 0
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: $iMaxAttempts provides additional control to limit search attempts
;                  Useful for preventing excessive CPU usage in tight loops
; Example .......:   ; Wait 5 seconds for button (unlimited attempts)
;                  $aResult = _ImageSearch_Wait(5000, "button.png")
;                  If $aResult[0][0] > 0 Then
;                      MouseClick("left", $aResult[1][0], $aResult[1][1])
;                  Else
;                      MsgBox(0, "Timeout", "Button not found")
;                  EndIf
;
;                  ; Wait with max 50 attempts (exits early if 50 attempts reached)
;                  $aResult = _ImageSearch_Wait(10000, "button.png", 100, -1, 10, 1, 1, 1.0, 1.0, 0.1, 0, 1, 50)
; ===============================================================================================================================
Func _ImageSearch_Wait($iTimeout, $sImagePath, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = -1, $iTolerance = 10, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE, $iMaxAttempts = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Wait($iTimeout=" & $iTimeout & ", $sImagePath=" & $sImagePath & ", $iLeft=" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ", $iTolerance=" & $iTolerance & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache=" & $iUseCache & ", $iMaxAttempts=" & $iMaxAttempts & ")" & @CRLF)
	Local $hTimer = TimerInit()
	Local $iAttempts = 0

	While True
		$iAttempts += 1
		Local $aResult = _ImageSearch($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, $iResults, $iCenterPOS, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
		If $aResult[0][0] > 0 Then Return $aResult

		; OPTIMIZED: Check max attempts limit to prevent excessive DLL calls
		If $iMaxAttempts > 0 And $iAttempts >= $iMaxAttempts Then
			If $g_IMGS_Debug Then ConsoleWrite(">> Max attempts (" & $iMaxAttempts & ") reached" & @CRLF)
			Return __ImgSearch_MakeEmptyResult()
		EndIf

		If $iTimeout > 0 And TimerDiff($hTimer) > $iTimeout Then
			If $g_IMGS_Debug Then ConsoleWrite(">> Timeout (" & $iTimeout & "ms) after " & $iAttempts & " attempts" & @CRLF)
			Return __ImgSearch_MakeEmptyResult()
		EndIf

		Sleep($iSleepTime)
	WEnd
EndFunc   ;==>_ImageSearch_Wait

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_WaitClick
; Description ...: Waits for an image and clicks it when found
; Syntax ........: _ImageSearch_WaitClick($iTimeout, $sImagePath[, $sButton = "left"[, $iClicks = 1[, $iScreen = -1[, $iTolerance = 10[, $iResults = 1[, $iCenterPOS = 1[, $fMinScale = 1.0[, $fMaxScale = 1.0[, $fScaleStep = 0.1[, $iReturnDebug = $g_bImageSearch_Debug[, $iUseCache = $IMGS_ENABLED_CACHE]]]]]]]]])
; Parameters ....: $iTimeout       - Timeout in milliseconds (0 = wait forever)
;                  $sImagePath     - Image file path(s)
;                  $sButton        - [optional] Mouse button: "left", "right", "middle" (default: "left")
;                  $iClicks        - [optional] Number of clicks (default: 1)
;                  $iScreen        - [optional] Monitor index:
;                                    iScreen < 0: Virtual screen (all monitors combined)
;                                    iScreen = 0: Use provided region params only (primary screen if region=0)
;                                    iScreen > 0: Specific monitor (1=first, 2=second, 3=third...)
;                  $iTolerance     - [optional] Color tolerance 0-255 (default: 10)
;                  $iResults       - [optional] Max results 1-1024 (default: 1)
;                  $iCenterPOS     - [optional] Return center (1) or top-left (0) (default: 1)
;                  $fMinScale      - [optional] Min scale 0.1-5.0 (default: 1.0)
;                  $fMaxScale      - [optional] Max scale (default: 1.0)
;                  $fScaleStep     - [optional] Scale step (default: 0.1)
;                  $iReturnDebug   - [optional] Debug mode (default: 0)
;                  $iUseCache      - [optional] User cache  (default: 0)
; Return values .: Success - 1 (image found and clicked)
;                  Timeout - 0 (image not found)
; Author.........: Dao Van Trong - TRONG.PRO
; Example .......:
;   ; Wait and click button
;   If _ImageSearch_WaitClick(5000, "button.png") Then
;       MsgBox(0, "Success", "Button clicked!")
;   Else
;       MsgBox(0, "Failed", "Button not found")
;   EndIf
; ===============================================================================================================================
Func _ImageSearch_WaitClick($iTimeout, $sImagePath, $sButton = "left", $iClicks = 1, $iLeft = 0, $iTop = 0, $iRight = 0, $iBottom = 0, $iScreen = -1, $iTolerance = 10, $iResults = 1, $iCenterPOS = 1, $fMinScale = 1.0, $fMaxScale = 1.0, $fScaleStep = 0.1, $iReturnDebug = $g_bImageSearch_Debug, $iUseCache = $IMGS_ENABLED_CACHE)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_WaitClick($iTimeout=" & $iTimeout & ", $sImagePath=" & $sImagePath & ", $sButton=" & $sButton & ", $iClicks=" & $iClicks & ", $iLeft=" & $iLeft & ", $iTop=" & $iTop & ", $iRight=" & $iRight & ", $iBottom=" & $iBottom & ", $iScreen=" & $iScreen & ", $iTolerance=" & $iTolerance & ", $iResults=" & $iResults & ", $iCenterPOS=" & $iCenterPOS & ", $fMinScale=" & $fMinScale & ", $fMaxScale=" & $fMaxScale & ", $fScaleStep=" & $fScaleStep & ", $iReturnDebug=" & $iReturnDebug & ", $iUseCache=" & $iUseCache & ")" & @CRLF)
	Local $aResult = _ImageSearch_Wait($iTimeout, $sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, $iResults, $iCenterPOS, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
	If $aResult[0][0] > 0 Then
		; Use DLL MouseClick with proper $iScreen parameter (supports negative coords)
		Return _ImageSearch_MouseClick($sButton, $aResult[1][0], $aResult[1][1], $iClicks, 10, $iScreen)
	EndIf
	Return 0
EndFunc   ;==>_ImageSearch_WaitClick

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_MouseClick
; Description ...: Clicks mouse at coordinates (screen or current position)
; Syntax ........: _ImageSearch_MouseClick($sButton[, $iX=-1[, $iY=-1[, $iClicks=1[, $iSpeed=0[, $iScreen=-1]]]]])
; Parameters ....: $sButton - Button: "left", "right", "middle" (default: "left")
;                  $iX, $iY - Coordinates (-1 = current position)
;                  $iClicks - Number of clicks (default: 1)
;                  $iSpeed - Speed 0-100 (0=instant, default: 0)
;                  $iScreen - Monitor index (default: -1 = all monitors/virtual screen)
; Return values .: 1 on success, 0 on failure
; ===============================================================================================================================
Func _ImageSearch_MouseClick($sButton = "left", $iX = -1, $iY = -1, $iClicks = 1, $iSpeed = 0, $iScreen = -1)
	If $g_bImageSearch_Debug Then ConsoleWrite("+  _ImageSearch_MouseClick($sButton=" & $sButton & ", $iX=" & $iX & ", $iY=" & $iY & ", $iClicks=" & $iClicks & ", $iSpeed=" & $iSpeed & ", $iScreen=" & $iScreen & ")" & @CRLF)

	; Initialize DLL if needed
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, 0)
	EndIf

	; Call DLL (handles move + click with proper timing, DPI-aware, SendInput)
	Local $aDLL = DllCall($g_hImageSearchDLL, "int", "Mouse_Click", _
			"wstr", $sButton, _
			"int", $iX, _
			"int", $iY, _
			"int", $iClicks, _
			"int", $iSpeed, _
			"int", $iScreen)

	If @error Or Not IsArray($aDLL) Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DLL call failed, @error=" & @error & @CRLF)
		Return SetError(2, @error, 0)
	EndIf

	If $aDLL[0] = 1 Then
		If $g_bImageSearch_Debug Then ConsoleWrite(">> Click performed at X=" & $iX & ", Y=" & $iY & " (via DLL)" & @CRLF)
		Return 1
	Else
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DLL Mouse_Click returned 0" & @CRLF)
		Return SetError(3, 0, 0)
	EndIf
EndFunc   ;==>_ImageSearch_MouseClick

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_MouseMove
; Description ...: Moves mouse cursor to coordinates (supports negative coordinates on multi-monitor)
; Syntax ........: _ImageSearch_MouseMove($iX, $iY[, $iSpeed=0[, $iScreen=-1]])
; Parameters ....: $iX, $iY - Target coordinates (-1 = keep current position)
;                  $iSpeed - Speed 0-100 (0=instant, default: 0)
;                  $iScreen - Monitor index:
;                             iScreen < 0: Virtual screen (coords are absolute virtual desktop coords)
;                             iScreen = 0: Absolute screen coordinates (supports negative for multi-monitor)
;                             iScreen > 0: Coordinates relative to specific monitor origin
; Return values .: 1 on success, 0 on failure
; Remarks .......: When iScreen > 0, coordinates are converted to absolute virtual desktop coords
; ===============================================================================================================================
Func _ImageSearch_MouseMove($iX, $iY, $iSpeed = 0, $iScreen = -1)
	If $g_bImageSearch_Debug Then ConsoleWrite("+  _ImageSearch_MouseMove($iX=" & $iX & ", $iY=" & $iY & ", $iSpeed=" & $iSpeed & ", $iScreen=" & $iScreen & ")" & @CRLF)

	; Initialize DLL if needed
	If Not $g_bImageSearch_Initialized Then
		If Not _ImageSearch_Startup() Then Return SetError(1, 0, 0)
	EndIf

	; Call DLL (handles all cases: multi-monitor, DPI-aware, smooth movement)
	Local $aDLL = DllCall($g_hImageSearchDLL, "int", "Mouse_Move", _
			"int", $iX, _
			"int", $iY, _
			"int", $iSpeed, _
			"int", $iScreen)

	If @error Or Not IsArray($aDLL) Then
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DLL call failed, @error=" & @error & @CRLF)
		Return SetError(2, @error, 0)
	EndIf

	If $aDLL[0] = 1 Then
		If $g_bImageSearch_Debug Then ConsoleWrite(">> Mouse moved to X=" & $iX & ", Y=" & $iY & " (via DLL)" & @CRLF)
		Return 1
	Else
		If $g_bImageSearch_Debug Then ConsoleWrite("!> DLL Mouse_Move returned 0" & @CRLF)
		Return SetError(3, 0, 0)
	EndIf
EndFunc   ;==>_ImageSearch_MouseMove

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_MouseClickWin
; Description ...: Clicks mouse in a window
; Syntax ........: _ImageSearch_MouseClickWin($sTitle, $sText, $iX, $iY[, $sButton="left"[, $iClicks=1[, $iSpeed=0]]])
; Parameters ....: $sTitle - Window title/class/handle
;                  $sText - Window text
;                  $iX, $iY - Relative coordinates in window
;                  $sButton - Button (default: "left")
;                  $iClicks - Number of clicks (default: 1)
;                  $iSpeed - Speed 0-100 (default: 0)
; Return values .: 1 on success, 0 on failure
; ===============================================================================================================================
Func _ImageSearch_MouseClickWin($sTitle, $sText, $iX, $iY, $sButton = "left", $iClicks = 1, $iSpeed = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_MouseClickWin($sTitle=" & $sTitle & ", $sText=" & $sText & ", $iX=" & $iX & ", $iY=" & $iY & ", $sButton=" & $sButton & ", $iClicks=" & $iClicks & ", $iSpeed=" & $iSpeed & ")" & @CRLF)
	If Not _ImageSearch_Startup() Then Return SetError(-1, 0, 0)
	Local $aRet = DllCall($g_hImageSearchDLL, "int:cdecl", "Mouse_ClickWin", "wstr", $sTitle, "wstr", $sText, "int", $iX, "int", $iY, "wstr", $sButton, "int", $iClicks, "int", $iSpeed)
	If @error Then Return SetError(1, 0, 0)
	Return $aRet[0]
EndFunc   ;==>_ImageSearch_MouseClickWin


; #PUBLIC FUNCTIONS - CACHE & INFO# ==========================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_WarmUpCache
; Description ...: Pre-loads images into cache for faster subsequent searches
; Syntax ........: _ImageSearch_WarmupCache($sImagePaths[, $bEnableCache = True])
; Parameters ....: $sImagePaths - Pipe-separated list of images to preload
;                  $bEnableCache - [optional] Enable persistent cache (default: True)
; Return values .: Success - Number of images cached
;                  Failure - 0
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Call this during app initialization for better performance
;                  v3.5: Now uses $iUseCache=1 for persistent caching
; Example .......:
;   _ImageSearch_WarmUpCache("btn1.png|btn2.png|icon.png")
; ===============================================================================================================================
Func _ImageSearch_WarmUpCache($sImagePaths, $bEnableCache = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_WarmUpCache($sImagePaths=" & $sImagePaths & ", $bEnableCache=" & $bEnableCache & ")" & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	Local $aFiles = StringSplit($sImagePaths, "|", 2)
	Local $iCached = 0
	Local $iUseCache = ($bEnableCache ? 1 : 0)
	For $sFile In $aFiles
		If FileExists($sFile) Then
			; FIXED: Use full screen (0,0,0,0) to properly load bitmap into cache
			; Previous bug: 1x1 region was too small and didn't load full bitmap
			; _ImageSearch($sImagePath, $iLeft, $iTop, $iRight, $iBottom, $iScreen, $iTolerance, $iResults, $iCenterPOS, $fMinScale, $fMaxScale, $fScaleStep, $iReturnDebug, $iUseCache)
			_ImageSearch($sFile, 0, 0, 0, 0, -1, 0, 1, 1, 1.0, 1.0, 0.1, 0, $iUseCache)
			$iCached += 1
		EndIf
	Next
	If $g_bImageSearch_Debug Then ConsoleWrite(">> Warmed up cache for " & $iCached & " images" & @CRLF)
	Return $iCached
EndFunc   ;==>_ImageSearch_WarmUpCache

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_ClearCache
; Description ...: Clears the internal bitmap and location cache
; Syntax ........: _ImageSearch_ClearCache()
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Useful for freeing memory or forcing re-scan after image updates
;                  v3.5: Clears both in-memory cache and persistent disk cache
; Example .......: _ImageSearch_ClearCache()  ; Clear all cached data
; ===============================================================================================================================
Func _ImageSearch_ClearCache()
	If $g_bImageSearch_Debug Then ConsoleWrite("+  _ImageSearch_ClearCache()" & @CRLF)
	If Not $g_bImageSearch_Initialized Then Return
	DllCall($g_hImageSearchDLL, "none", "Clear_Cache")
	If $g_bImageSearch_Debug Then ConsoleWrite(">> Cache cleared (memory + disk)" & @CRLF)
EndFunc   ;==>_ImageSearch_ClearCache

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetDllInfo
; Description ...: Gets comprehensive DLL information in INI format
; Syntax ........: _ImageSearch_GetDllInfo()
; Return values .: Multi-line string in INI format with sections:
;                  [DLL]     - DLL name, version, architecture, author
;                  [OS]      - OS name, version, build, platform
;                  [CPU]     - Threads, SSE2, AVX2, AVX512 support
;                  [SCREEN]  - Virtual screen, scale, monitors with individual resolutions
;                  [CACHE]   - Location cache, bitmap cache, pool size
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: This is the recommended function for getting detailed system information.
; Example .......: ConsoleWrite(_ImageSearch_GetDllInfo() & @CRLF)
; ===============================================================================================================================
Func _ImageSearch_GetDllInfo($bForceRefresh = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetDllInfo($bForceRefresh=" & $bForceRefresh & ")" & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return ""
	; Return cached version if available
	If (Not $bForceRefresh) And ($g_sDllInfoCache <> "") Then Return $g_sDllInfoCache
	; Call DLL and cache result
	Local $aDLL = DllCall($g_hImageSearchDLL, "wstr", "Get_DllInfo")
	If @error Then Return ""
	$g_sDllInfoCache = $aDLL[0]
	; Parse and cache as Map for fast access
	$g_mDllInfoParsed = __ImgSearch_ParseIniToMap($g_sDllInfoCache)
	Return $g_sDllInfoCache
EndFunc   ;==>_ImageSearch_GetDllInfo

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetInfo()
; ===============================================================================================================================
Func _ImageSearch_GetInfo()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetInfo()" & @CRLF)
	If Not $g_bImageSearch_Initialized Then _ImageSearch_Startup()
	If Not $g_bImageSearch_Initialized Then Return ""
	; Ensure cache is populated
	Local $sDllInfoRaw = _ImageSearch_GetDllInfo()
	;If $g_IMGS_Debug Then ConsoleWrite(">> DLL Info Raw (" & StringLen($sDllInfoRaw) & " chars):" & @CRLF & $sDllInfoRaw & @CRLF)
	If Not IsObj($g_mDllInfoParsed) Then
		If $g_IMGS_Debug Then ConsoleWrite("!> ERROR: Parsed map is not an object" & @CRLF)
		Return ""
	EndIf
	; Read from cached Map (FAST)
	Local $sName = __ImgSearch_IniRead($g_mDllInfoParsed, "DLL", "Name")
	Local $sVersion = __ImgSearch_IniRead($g_mDllInfoParsed, "DLL", "Version")
	Local $sArch = __ImgSearch_IniRead($g_mDllInfoParsed, "DLL", "Arch")
	Local $sOSName = __ImgSearch_IniRead($g_mDllInfoParsed, "OS", "Name")
	Local $sOSShort = StringReplace($sOSName, "Windows ", "Win")
	Local $sSSE2 = __ImgSearch_IniRead($g_mDllInfoParsed, "CPU", "SSE2")
	Local $sVirtualScreen = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "VirtualScreen")
	Local $sPrimaryScale = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "PrimaryScale")
	Local $sMonitors = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitors")
	Local $sLocationCache = __ImgSearch_IniRead($g_mDllInfoParsed, "CACHE", "LocationCache")
	Local $sBitmapCache = __ImgSearch_IniRead($g_mDllInfoParsed, "CACHE", "BitmapCache")
	Local $sPoolSize = __ImgSearch_IniRead($g_mDllInfoParsed, "CACHE", "PoolSize")
	; Build monitor list with scales (only if more than 1 monitor)
	; OPTIMIZED: Use array + _ArrayToString instead of loop concatenation
	Local $sMonitorInfo = ""
	Local $iMonitorCount = Int($sMonitors)
	If $iMonitorCount > 1 Then
		Local $aMonitorParts[$iMonitorCount]
		Local $iValidCount = 0
		For $i = 1 To $iMonitorCount
			Local $sMonRes = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitor_" & $i)
			Local $sMonScale = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitor_" & $i & "_Scale")
			If $sMonRes <> "" Then
				$aMonitorParts[$iValidCount] = "Monitor_" & $i & ":" & $sMonRes & " Scale_" & $i & ":" & $sMonScale
				$iValidCount += 1
			EndIf
		Next
		If $iValidCount > 0 Then
			ReDim $aMonitorParts[$iValidCount]
			$sMonitorInfo = _ArrayToString($aMonitorParts, ", ")
		EndIf
	EndIf
	; Build format with Scale info
	Local $sResult = ">> DLL Info: " & $sName & " v" & $sVersion & " [" & $sArch & "] " & $sOSShort & " | CPU: SSE2=" & $sSSE2 & @CRLF
	$sResult &= ">> Cache: LocationCache=" & $sLocationCache & " | BitmapCache=" & $sBitmapCache & " | PoolSize=" & $sPoolSize & @CRLF
	; Screen info: only show detailed monitor list if more than 1 monitor
	If $iMonitorCount > 1 Then
		$sResult &= ">> Screen: " & $sVirtualScreen & " PrimaryScale=" & $sPrimaryScale & " | Monitors: " & $sMonitors & " | " & $sMonitorInfo
	Else
		$sResult &= ">> Screen: " & $sVirtualScreen & " Scale=" & $sPrimaryScale & " | Monitors: " & $sMonitors
	EndIf
	Return $sResult
EndFunc   ;==>_ImageSearch_GetInfo

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetDllValue
; Description ...: Quick accessor to read any value from cached DLL Info
; Syntax ........: _ImageSearch_GetDllValue($sSection, $sKey)
; Parameters ....: $sSection - Section name (DLL, OS, CPU, SCREEN, CACHE)
;                  $sKey - Key name
; Return values .: Value string or "" if not found
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: Uses cached Map for maximum performance. Call _ImageSearch_GetDllInfo() first to populate cache.
; Example .......: $sVersion = _ImageSearch_GetDllValue("DLL", "Version")
;                  $sOSName = _ImageSearch_GetDllValue("OS", "Name")
;                  $iThreads = _ImageSearch_GetDllValue("CPU", "Threads")
; ===============================================================================================================================
Func _ImageSearch_GetDllValue($sSection, $sKey)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetDllValue($sSection=" & $sSection & ", $sKey=" & $sKey & ")" & @CRLF)
	; Ensure cache is populated
	If Not IsObj($g_mDllInfoParsed) Then
		_ImageSearch_GetDllInfo()
		If Not IsObj($g_mDllInfoParsed) Then Return ""
	EndIf
	Return __ImgSearch_IniRead($g_mDllInfoParsed, $sSection, $sKey)
EndFunc   ;==>_ImageSearch_GetDllValue

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetLastResult
; Description ...: Gets the raw DLL return string from the last search
; Syntax ........: _ImageSearch_GetLastResult()
; Return values .: Raw result string (e.g., "{2}[100|200|32|32,150|250|32|32]<debug info>")
; Remarks .......: Useful for debugging or custom parsing
; ===============================================================================================================================
Func _ImageSearch_GetLastResult()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetLastResult()" & @CRLF)
	Return $g_sLastDllReturn
EndFunc   ;==>_ImageSearch_GetLastResult

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_GetScale
; Description ...: Gets the DPI scale factor for a specific monitor as a decimal number
; Syntax ........: _ImageSearch_GetScale($iScreen = 0)
; Parameters ....: $iScreen - Monitor index (0 = Primary, 1+ = specific monitor number)
; Return values .: Scale factor as number (e.g., 1.0, 1.25, 1.5) or 0 if not found
; Author ........: Dao Van Trong - TRONG.PRO
; Remarks .......: Uses cached DLL info for fast access. Returns PrimaryScale for $iScreen=0.
;                  Converts percentage to decimal: 100% = 1.0, 125% = 1.25, 150% = 1.5
; Example .......: $fScale = _ImageSearch_GetScale(0)  ; Get primary monitor scale (e.g., 1.25)
;                  $fScale = _ImageSearch_GetScale(2)  ; Get monitor 2 scale
; ===============================================================================================================================
Func _ImageSearch_GetScale($iScreen = 0)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_GetScale($iScreen=" & $iScreen & ")" & @CRLF)
	; Ensure cache is populated
	If Not IsObj($g_mDllInfoParsed) Then
		_ImageSearch_GetDllInfo()
		If Not IsObj($g_mDllInfoParsed) Then Return 0
	EndIf
	Local $sScaleStr = ""
	; Primary monitor (0 or negative)
	If $iScreen < 1 Then
		$sScaleStr = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "PrimaryScale")
	Else
		; Specific monitor (1, 2, 3...)
		Local $sMonitorCount = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitors")
		Local $iMonitorCount = Int($sMonitorCount)
		If $iScreen > 0 And $iScreen <= $iMonitorCount Then
			$sScaleStr = __ImgSearch_IniRead($g_mDllInfoParsed, "SCREEN", "Monitor_" & $iScreen & "_Scale")
		EndIf
	EndIf
	; Convert "125%" to 1.25 or "125% (Primary)" to 1.25
	If $sScaleStr <> "" Then
		; Extract numeric part only (remove % and any text after it)
		Local $sNumeric = StringRegExpReplace($sScaleStr, "(\d+)%.*", "$1")
		Local $fScale = Number($sNumeric) / 100.0
		;If $g_IMGS_Debug Then ConsoleWrite("   Scale: " & $sScaleStr & " -> " & $fScale & @CRLF)
		Return $fScale
	EndIf
	; Not found
	Return SetError(1, 0, 0)
EndFunc   ;==>_ImageSearch_GetScale

; #PUBLIC FUNCTIONS - MONITOR INFO# ==========================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_GetList
; Description ...: Gets a list of all connected display monitors and their properties.
; Syntax ........: _ImageSearch_Monitor_GetList()
; Return values .: Success - The number of monitors found. @extended contains a detailed log.
;                  Failure - 0 and sets @error (1 = _WinAPI_EnumDisplayMonitors failed)
; Author.........: Dao Van Trong - TRONG.PRO
; Remarks .......: This function populates the global $g_aMonitorList.
;                  It is called automatically by _ImageSearch_Startup, but can be called manually to refresh the list.
; ===============================================================================================================================
Func _ImageSearch_Monitor_GetList()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_GetList()" & @CRLF)
	; --- Virtual Desktop info ---
	Local $l_vLeft = DllCall("user32.dll", "int", "GetSystemMetrics", "int", 76)[0]   ; SM_XVIRTUALSCREEN
	Local $l_vTop = DllCall("user32.dll", "int", "GetSystemMetrics", "int", 77)[0]    ; SM_YVIRTUALSCREEN
	Local $l_vWidth = DllCall("user32.dll", "int", "GetSystemMetrics", "int", 78)[0]  ; SM_CXVIRTUALSCREEN
	Local $l_vHeight = DllCall("user32.dll", "int", "GetSystemMetrics", "int", 79)[0] ; SM_CYVIRTUALSCREEN
	Local $l_vRight = $l_vLeft + $l_vWidth
	Local $l_vBottom = $l_vTop + $l_vHeight
	Local $l_aMonitors = _WinAPI_EnumDisplayMonitors()
	If @error Then Return SetError(1, 0, 0)
	Local $l_iCount = $l_aMonitors[0][0]
	ReDim $g_aMonitorList[$l_iCount + 1][9]
	; --- Virtual Desktop entry ---
	$g_aMonitorList[0][0] = $l_iCount
	$g_aMonitorList[0][1] = $l_vLeft
	$g_aMonitorList[0][2] = $l_vTop
	$g_aMonitorList[0][3] = $l_vRight
	$g_aMonitorList[0][4] = $l_vBottom
	$g_aMonitorList[0][5] = $l_vWidth
	$g_aMonitorList[0][6] = $l_vHeight
	$g_aMonitorList[0][7] = 1
	$g_aMonitorList[0][8] = "Virtual"
	Local $l_sLog = StringFormat(">> Number of screens: [%d] - Virtual Desktop: Left=%d, Top=%d, Right=%d, Bottom=%d, Width=%d, Height=%d", $l_iCount, $l_vLeft, $l_vTop, $l_vRight, $l_vBottom, $l_vWidth, $l_vHeight) & @CRLF
	; --- Individual monitors ---
	For $l_i = 1 To $l_iCount
		Local $l_hMonitor = $l_aMonitors[$l_i][0]
		Local $l_tRect = $l_aMonitors[$l_i][1]
		Local $l_aInfo = _WinAPI_GetMonitorInfo($l_hMonitor)
		Local $l_mLeft = DllStructGetData($l_tRect, "Left")
		Local $l_mTop = DllStructGetData($l_tRect, "Top")
		Local $l_mRight = DllStructGetData($l_tRect, "Right")
		Local $l_mBottom = DllStructGetData($l_tRect, "Bottom")
		Local $l_mWidth = $l_mRight - $l_mLeft
		Local $l_mHeight = $l_mBottom - $l_mTop
		Local $l_bPrimary = ($l_aInfo[2] <> 0)
		Local $l_sDevice = $l_aInfo[3]
		$g_aMonitorList[$l_i][0] = $l_hMonitor
		$g_aMonitorList[$l_i][1] = $l_mLeft
		$g_aMonitorList[$l_i][2] = $l_mTop
		$g_aMonitorList[$l_i][3] = $l_mRight
		$g_aMonitorList[$l_i][4] = $l_mBottom
		$g_aMonitorList[$l_i][5] = $l_mWidth
		$g_aMonitorList[$l_i][6] = $l_mHeight
		$g_aMonitorList[$l_i][7] = $l_bPrimary
		$g_aMonitorList[$l_i][8] = $l_sDevice
		$l_sLog &= StringFormat(">> Monitor [%d]: Handle=%s, L=%d, T=%d, R=%d, B=%d, W=%d, H=%d, IsPrimary=%d, Device=%s", $l_i, Ptr($l_hMonitor), $l_mLeft, $l_mTop, $l_mRight, $l_mBottom, $l_mWidth, $l_mHeight, $l_bPrimary, $l_sDevice) & @CRLF
	Next
	Return SetError(0, $l_iCount, $l_sLog)
EndFunc   ;==>_ImageSearch_Monitor_GetList

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_ToVirtual
; Description ...: Converts local monitor coordinates to virtual screen coordinates.
; Syntax ........: _ImageSearch_Monitor_ToVirtual($iMonitor, $iX, $iY)
; Parameters ....: $iMonitor - The 1-based index of the monitor (from $g_aMonitorList).
;                  $iX       - The X coordinate relative to the monitor's top-left corner.
;                  $iY       - The Y coordinate relative to the monitor's top-left corner.
; Return values .: Success - A 2-element array [$vX, $vY] containing virtual screen coordinates.
;                  Failure - 0 and sets @error:
;                  |1 - Invalid monitor index
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Monitor_ToVirtual($iMonitor, $iX, $iY)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_ToVirtual($iMonitor=" & $iMonitor & ", $iX=" & $iX & ", $iY=" & $iY & ")" & @CRLF)
	If $g_aMonitorList[0][0] = 0 Then _ImageSearch_Monitor_GetList()
	If $iMonitor < 1 Or $iMonitor > $g_aMonitorList[0][0] Then Return SetError(1, 0, 0)
	Local $l_Left = $g_aMonitorList[$iMonitor][1]
	Local $l_Top = $g_aMonitorList[$iMonitor][2]
	Local $aRet[2] = [$l_Left + $iX, $l_Top + $iY]
	Return $aRet
EndFunc   ;==>_ImageSearch_Monitor_ToVirtual

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_FromVirtual
; Description ...: Converts virtual screen coordinates to local monitor coordinates.
; Syntax ........: _ImageSearch_Monitor_FromVirtual($iMonitor, $iX, $iY)
; Parameters ....: $iMonitor - The 1-based index of the monitor (from $g_aMonitorList).
;                  $iX       - The virtual screen X coordinate.
;                  $iY       - The virtual screen Y coordinate.
; Return values .: Success - A 2-element array [$lX, $lY] containing local monitor coordinates.
;                  Failure - 0 and sets @error:
;                  |1 - Invalid monitor index
;                  |2 - Coordinates are not located on the specified monitor
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Monitor_FromVirtual($iMonitor, $iX, $iY)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_FromVirtual($iMonitor=" & $iMonitor & ", $iX=" & $iX & ", $iY=" & $iY & ")" & @CRLF)
	If $g_aMonitorList[0][0] = 0 Then _ImageSearch_Monitor_GetList()
	If $iMonitor < 1 Or $iMonitor > $g_aMonitorList[0][0] Then Return SetError(1, 0, 0)
	Local $l_Left = $g_aMonitorList[$iMonitor][1]
	Local $l_Top = $g_aMonitorList[$iMonitor][2]
	Local $l_Right = $g_aMonitorList[$iMonitor][3]
	Local $l_Bottom = $g_aMonitorList[$iMonitor][4]
	; FIXED: Consistent bounds check [Left,Top) to [Right,Bottom) - excludes right/bottom edge
	If $iX < $l_Left Or $iX >= $l_Right Or $iY < $l_Top Or $iY >= $l_Bottom Then
		Return SetError(2, 0, 0)
	EndIf
	Local $aRet[2] = [$iX - $l_Left, $iY - $l_Top]
	Return $aRet
EndFunc   ;==>_ImageSearch_Monitor_FromVirtual

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_Current
; Description ...: Detects which monitor contains the current mouse cursor position.
; Syntax ........: _ImageSearch_Monitor_Current()
; Parameters ....: None (automatically uses current mouse cursor position)
; Return values .: Success - Monitor index (1-based) where the cursor is located
;                  Failure - 0 and sets @error:
;                  |1 - No monitors detected
;                  |2 - Cursor position is not on any detected monitor
; Remarks .......: * This function uses MouseGetPos() to automatically get the current cursor coordinates
;                  * The returned index corresponds to $g_aMonitorList array
;                  * If cursor is between monitors (in the gap), returns 0 with @error = 2
;                  * Call _ImageSearch_Monitor_GetList() first to populate monitor list
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Monitor_Current()
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_Current() - Auto-detect using mouse cursor position" & @CRLF)

	; Auto-populate monitor list if not done yet
	If $g_aMonitorList[0][0] = 0 Then _ImageSearch_Monitor_GetList()
	If $g_aMonitorList[0][0] = 0 Then Return SetError(1, 0, 0) ; No monitors

	; Get current mouse cursor position (virtual screen coordinates)
	Local $aMousePos = MouseGetPos()
	If @error Then Return SetError(1, 0, 0)
	Local $iMouseX = $aMousePos[0]
	Local $iMouseY = $aMousePos[1]

	If $g_IMGS_Debug Then ConsoleWrite("   Mouse Position: X=" & $iMouseX & ", Y=" & $iMouseY & @CRLF)

	; Check which monitor contains the cursor
	For $i = 1 To $g_aMonitorList[0][0]
		Local $iLeft = $g_aMonitorList[$i][1]
		Local $iTop = $g_aMonitorList[$i][2]
		Local $iRight = $g_aMonitorList[$i][3]
		Local $iBottom = $g_aMonitorList[$i][4]

		; FIXED: Use < instead of <= for Right/Bottom to avoid overlap between monitors
		; Monitor bounds: [Left, Top) to [Right, Bottom) - excludes right/bottom edge
		If $iMouseX >= $iLeft And $iMouseX < $iRight And $iMouseY >= $iTop And $iMouseY < $iBottom Then
			If $g_IMGS_Debug Then ConsoleWrite("   Found on Monitor " & $i & ": " & $g_aMonitorList[$i][5] & "x" & $g_aMonitorList[$i][6] & @CRLF)
			Return $i
		EndIf
	Next

	; Cursor not on any monitor (between monitors)
	If $g_IMGS_Debug Then ConsoleWrite("!  Cursor not on any detected monitor (in gap)" & @CRLF)
	Return SetError(2, 0, 0)
EndFunc   ;==>_ImageSearch_Monitor_Current

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Monitor_GetAtPosition
; Description ...: Returns detailed information string about the monitor at specified position.
; Syntax ........: _ImageSearch_Monitor_GetAtPosition([$iX = -1[, $iY = -1]])
; Parameters ....: $iX - [optional] The X coordinate (virtual screen). Default = -1 (use mouse cursor position)
;                  $iY - [optional] The Y coordinate (virtual screen). Default = -1 (use mouse cursor position)
; Return values .: Success - String describing the monitor (e.g., "Monitor 2: 1920x1080 (Primary)")
;                  Failure - Error message string
; Remarks .......: * If $iX or $iY is -1, automatically uses current mouse cursor position (via MouseGetPos)
;                  * If both parameters omitted, uses mouse cursor position for both X and Y
;                  * Returns "Virtual Desktop" info if position is between monitors
;                  * This function is useful for tooltips and user feedback
;                  * Example outputs:
;                    - "Monitor 1: 1920x1080 (Primary)"
;                    - "Monitor 2: 2560x1440"
;                    - "Position: 2000, 500 (Virtual Desktop)" (if in gap)
;                    - "No monitors detected" (if monitor list empty)
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Monitor_GetAtPosition($iX = -1, $iY = -1)
	; Auto-detect coordinates using mouse cursor if not provided
	If $iX = -1 Or $iY = -1 Then
		Local $aMousePos = MouseGetPos()
		If @error Then Return "Unable to get mouse position"
		$iX = $aMousePos[0]
		$iY = $aMousePos[1]
		If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_GetAtPosition() - Auto-detect using cursor: X=" & $iX & ", Y=" & $iY & @CRLF)
	Else
		If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Monitor_GetAtPosition($iX=" & $iX & ", $iY=" & $iY & ")" & @CRLF)
	EndIf
	; Auto-populate monitor list if not done yet
	If $g_aMonitorList[0][0] = 0 Then _ImageSearch_Monitor_GetList()
	If $g_aMonitorList[0][0] = 0 Then Return "No monitors detected"
	; Check which monitor contains this point
	For $i = 1 To $g_aMonitorList[0][0]
		Local $iLeft = $g_aMonitorList[$i][1]
		Local $iTop = $g_aMonitorList[$i][2]
		Local $iRight = $g_aMonitorList[$i][3]
		Local $iBottom = $g_aMonitorList[$i][4]
		; FIXED: Use < instead of <= for Right/Bottom to avoid overlap between monitors
		If $iX >= $iLeft And $iX < $iRight And $iY >= $iTop And $iY < $iBottom Then
			Local $sInfo = "Monitor " & $i & ": " & $g_aMonitorList[$i][5] & "x" & $g_aMonitorList[$i][6]
			If $g_aMonitorList[$i][7] Then $sInfo &= " (Primary)"
			If $g_IMGS_Debug Then ConsoleWrite("   " & $sInfo & @CRLF)
			Return $sInfo
		EndIf
	Next
	; Not on any monitor (between monitors in virtual desktop)
	Local $sVirtualInfo = "Position: " & $iX & ", " & $iY & " (Virtual Desktop)"
	If $g_IMGS_Debug Then ConsoleWrite("   " & $sVirtualInfo & @CRLF)
	Return $sVirtualInfo
EndFunc   ;==>_ImageSearch_Monitor_GetAtPosition

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Window_ToScreen
; Description ...: Converts window-relative coordinates to screen (virtual desktop) coordinates.
; Syntax ........: _ImageSearch_Window_ToScreen($hWnd, $iX, $iY[, $bClientArea = True])
; Parameters ....: $hWnd        - Window handle or title
;                  $iX          - X coordinate relative to window
;                  $iY          - Y coordinate relative to window
;                  $bClientArea - [optional] True = relative to client area, False = relative to window (default: True)
; Return values .: Success - A 2-element array [$screenX, $screenY] containing screen coordinates
;                  Failure - 0 and sets @error:
;                  |1 - Invalid window handle
;                  |2 - Unable to get window position
;                  |3 - Unable to get client area position (when $bClientArea = True)
; Remarks .......: * Screen coordinates are in virtual desktop space (can be negative on multi-monitor)
;                  * $bClientArea = True: Coordinates relative to window's client area (excludes title bar, borders)
;                  * $bClientArea = False: Coordinates relative to entire window (includes title bar, borders)
;                  * Useful for converting click positions in a window to screen positions for automation
;                  * Example: Window at (100, 100), click at (50, 30) in window → screen (150, 130)
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Window_ToScreen($hWnd, $iX, $iY, $bClientArea = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Window_ToScreen($hWnd=" & $hWnd & ", $iX=" & $iX & ", $iY=" & $iY & ", $bClientArea=" & $bClientArea & ")" & @CRLF)

	; Validate window handle
	If Not IsHWnd($hWnd) Then
		$hWnd = WinGetHandle($hWnd)
		If @error Or Not IsHWnd($hWnd) Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Invalid window handle" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
	EndIf

	Local $iWinX, $iWinY

	If $bClientArea Then
		; Get client area position (excludes title bar and borders)
		Local $aClientPos = WinGetPos($hWnd)
		If @error Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get window position" & @CRLF)
			Return SetError(2, 0, 0)
		EndIf

		; Get client area offset using ControlGetPos
		Local $aCtrlPos = ControlGetPos($hWnd, "", "")
		If @error Then
			; Fallback: Use ClientToScreen API
			Local $tPoint = DllStructCreate("long X;long Y")
			DllStructSetData($tPoint, "X", 0)
			DllStructSetData($tPoint, "Y", 0)
			Local $aResult = DllCall("user32.dll", "bool", "ClientToScreen", "hwnd", $hWnd, "struct*", $tPoint)
			If @error Or Not $aResult[0] Then
				If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get client area position" & @CRLF)
				Return SetError(3, 0, 0)
			EndIf
			$iWinX = DllStructGetData($tPoint, "X")
			$iWinY = DllStructGetData($tPoint, "Y")
		Else
			; Use window position (client area starts at window top-left for most windows)
			$iWinX = $aClientPos[0]
			$iWinY = $aClientPos[1]

			; Adjust for title bar and borders
			Local $tPoint = DllStructCreate("long X;long Y")
			DllStructSetData($tPoint, "X", 0)
			DllStructSetData($tPoint, "Y", 0)
			Local $aResult = DllCall("user32.dll", "bool", "ClientToScreen", "hwnd", $hWnd, "struct*", $tPoint)
			If Not @error And $aResult[0] Then
				$iWinX = DllStructGetData($tPoint, "X")
				$iWinY = DllStructGetData($tPoint, "Y")
			EndIf
		EndIf
	Else
		; Get window position (includes title bar and borders)
		Local $aWinPos = WinGetPos($hWnd)
		If @error Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get window position" & @CRLF)
			Return SetError(2, 0, 0)
		EndIf
		$iWinX = $aWinPos[0]
		$iWinY = $aWinPos[1]
	EndIf

	; Calculate screen coordinates
	Local $iScreenX = $iWinX + $iX
	Local $iScreenY = $iWinY + $iY

	If $g_IMGS_Debug Then ConsoleWrite("   Window offset: (" & $iWinX & ", " & $iWinY & ") → Screen: (" & $iScreenX & ", " & $iScreenY & ")" & @CRLF)

	Local $aResult[2] = [$iScreenX, $iScreenY]
	Return $aResult
EndFunc   ;==>_ImageSearch_Window_ToScreen

; #FUNCTION# ====================================================================================================================
; Name ..........: _ImageSearch_Window_FromScreen
; Description ...: Converts screen (virtual desktop) coordinates to window-relative coordinates.
; Syntax ........: _ImageSearch_Window_FromScreen($hWnd, $iScreenX, $iScreenY[, $bClientArea = True])
; Parameters ....: $hWnd        - Window handle or title
;                  $iScreenX    - X coordinate on screen (virtual desktop)
;                  $iScreenY    - Y coordinate on screen (virtual desktop)
;                  $bClientArea - [optional] True = relative to client area, False = relative to window (default: True)
; Return values .: Success - A 2-element array [$winX, $winY] containing window-relative coordinates
;                  Failure - 0 and sets @error:
;                  |1 - Invalid window handle
;                  |2 - Unable to get window position
;                  |3 - Unable to get client area position (when $bClientArea = True)
; Remarks .......: * Inverse of _ImageSearch_Window_ToScreen()
;                  * $bClientArea = True: Returns coordinates relative to window's client area
;                  * $bClientArea = False: Returns coordinates relative to entire window
;                  * Useful for determining where on a window a screen position maps to
;                  * Example: Screen (150, 130), window at (100, 100) → window (50, 30)
; Author.........: Dao Van Trong - TRONG.PRO
; ===============================================================================================================================
Func _ImageSearch_Window_FromScreen($hWnd, $iScreenX, $iScreenY, $bClientArea = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  _ImageSearch_Window_FromScreen($hWnd=" & $hWnd & ", $iScreenX=" & $iScreenX & ", $iScreenY=" & $iScreenY & ", $bClientArea=" & $bClientArea & ")" & @CRLF)

	; Validate window handle
	If Not IsHWnd($hWnd) Then
		$hWnd = WinGetHandle($hWnd)
		If @error Or Not IsHWnd($hWnd) Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Invalid window handle" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
	EndIf

	Local $iWinX, $iWinY

	If $bClientArea Then
		; Get client area position using ClientToScreen
		Local $tPoint = DllStructCreate("long X;long Y")
		DllStructSetData($tPoint, "X", 0)
		DllStructSetData($tPoint, "Y", 0)
		Local $aResult = DllCall("user32.dll", "bool", "ClientToScreen", "hwnd", $hWnd, "struct*", $tPoint)
		If @error Or Not $aResult[0] Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get client area position" & @CRLF)
			Return SetError(3, 0, 0)
		EndIf
		$iWinX = DllStructGetData($tPoint, "X")
		$iWinY = DllStructGetData($tPoint, "Y")
	Else
		; Get window position
		Local $aWinPos = WinGetPos($hWnd)
		If @error Then
			If $g_IMGS_Debug Then ConsoleWrite("!> Error: Unable to get window position" & @CRLF)
			Return SetError(2, 0, 0)
		EndIf
		$iWinX = $aWinPos[0]
		$iWinY = $aWinPos[1]
	EndIf

	; Calculate window-relative coordinates
	Local $iWinRelX = $iScreenX - $iWinX
	Local $iWinRelY = $iScreenY - $iWinY

	If $g_IMGS_Debug Then ConsoleWrite("   Screen: (" & $iScreenX & ", " & $iScreenY & ") - Window offset: (" & $iWinX & ", " & $iWinY & ") → Relative: (" & $iWinRelX & ", " & $iWinRelY & ")" & @CRLF)

	Local $aResult[2] = [$iWinRelX, $iWinRelY]
	Return $aResult
EndFunc   ;==>_ImageSearch_Window_FromScreen

; #INTERNAL (PRIVATE) FUNCTIONS# ==============================================================================================
; ===============================================================================================================================

; Parse DLL result string
; Format: {count}[x|y|w|h,x|y|w|h,...](debug_info)          - Success
;         {error_code}[]<Error Name>(debug_info)            - Error
Func __ImgSearch_ParseResult($sResult)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_ParseResult($sResult=" & $sResult & ")" & @CRLF)
	; Extract count or error code between { }
	Local $sCountStr = __ImgSearch_ExtractBetween($sResult, "{", "}")
	Local $iCount = Number($sCountStr)
	; Check if error (negative count or has error message)
	Local $sErrorMsg = __ImgSearch_ExtractBetween($sResult, "<", ">")
	If $iCount < 0 Or $sErrorMsg <> "" Then
		; Error occurred
		If $g_bImageSearch_Debug Then
			ConsoleWrite("!> DLL Error [" & $iCount & "]: " & $sErrorMsg & @CRLF)
			; Extract debug info if exists
			Local $sDebugInfo = __ImgSearch_ExtractBetween($sResult, "(", ")")
			If $sDebugInfo <> "" Then ConsoleWrite("   Debug: " & $sDebugInfo & @CRLF)
		EndIf
		Return SetError($iCount, 0, __ImgSearch_MakeEmptyResult())
	EndIf
	; Extract matches between [ ]
	Local $sMatches = __ImgSearch_ExtractBetween($sResult, "[", "]")
	; Create result array: [row][col] where col 0=X, 1=Y, 2=W, 3=H
	Local $aResult[$iCount + 1][4]
	$aResult[0][0] = $iCount
	If $iCount = 0 Or $sMatches = "" Then Return $aResult

	; OPTIMIZED: Use single StringRegExp instead of double loop with StringSplit
	; Pattern matches: number|number|number|number (X|Y|W|H format)
	Local $aMatches = StringRegExp($sMatches, "(-?\d+)\|(-?\d+)\|(-?\d+)\|(-?\d+)", 3)

	If IsArray($aMatches) And UBound($aMatches) > 0 Then
		Local $iMatches = Int(UBound($aMatches) / 4)
		Local $iValid = ($iMatches < $iCount) ? $iMatches : $iCount

		For $i = 0 To $iValid - 1
			$aResult[$i + 1][0] = Number($aMatches[$i * 4])     ; X coordinate
			$aResult[$i + 1][1] = Number($aMatches[$i * 4 + 1]) ; Y coordinate
			$aResult[$i + 1][2] = Number($aMatches[$i * 4 + 2]) ; Width
			$aResult[$i + 1][3] = Number($aMatches[$i * 4 + 3]) ; Height
		Next

		$aResult[0][0] = $iValid
		ReDim $aResult[$iValid + 1][4]
	Else
		; Fallback to old method if regex fails
		Local $aRecords = StringSplit($sMatches, ",", 3)
		Local $iValid = 0
		For $i = 0 To UBound($aRecords) - 1
			Local $aParts = StringSplit($aRecords[$i], "|", 3)
			If UBound($aParts) >= 4 Then
				$iValid += 1
				$aResult[$iValid][0] = Number($aParts[0])
				$aResult[$iValid][1] = Number($aParts[1])
				$aResult[$iValid][2] = Number($aParts[2])
				$aResult[$iValid][3] = Number($aParts[3])
				If $iValid >= $iCount Then ExitLoop
			EndIf
		Next
		$aResult[0][0] = $iValid
		ReDim $aResult[$iValid + 1][4]
	EndIf
	; Debug output if enabled
	If $g_bImageSearch_Debug Then
		Local $sDebugInfo = __ImgSearch_ExtractBetween($sResult, "(", ")")
		If $sDebugInfo <> "" Then ConsoleWrite(">> Debug: " & $sDebugInfo & @CRLF)
	EndIf
	Return $aResult
EndFunc   ;==>__ImgSearch_ParseResult

; Extract string between delimiters
Func __ImgSearch_ExtractBetween($sString, $sStart, $sEnd)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_ExtractBetween($sString=" & $sString & ", $sStart=" & $sStart & ", $sEnd=" & $sEnd & ")" & @CRLF)
	If $sString = "" Or $sStart = "" Or $sEnd = "" Then Return ""
	Local $aRet = StringRegExp($sString, "(?si)\Q" & $sStart & "\E(.*?)" & "(?=\Q" & $sEnd & "\E)", 3)
	If @error Then
		Local $iStart = StringInStr($sString, $sStart)
		If $iStart = 0 Then Return ""
		Local $iEnd = StringInStr($sString, $sEnd, 0, 1, $iStart + StringLen($sStart))
		If $iEnd = 0 Or $iEnd <= $iStart Then Return ""
		Return StringMid($sString, $iStart + StringLen($sStart), $iEnd - $iStart - StringLen($sStart))
	EndIf
	If IsArray($aRet) And UBound($aRet) > 0 Then Return $aRet[0]
	Return ""
EndFunc   ;==>__ImgSearch_ExtractBetween

; Normalize file paths
Func __ImgSearch_NormalizePaths($sInput)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_NormalizePaths($sInput=" & $sInput & ")" & @CRLF)
	If $sInput = "" Then Return ""
	; Remove duplicate delimiters
	While StringInStr($sInput, "||")
		$sInput = StringReplace($sInput, "||", "|")
	WEnd
	; Trim delimiters
	$sInput = StringStripWS($sInput, 3)
	$sInput = StringRegExpReplace($sInput, "^\|+|\|+$", "")
	; Validate files exist
	If Not StringInStr($sInput, "|") Then
		Return (FileExists($sInput) ? $sInput : "")
	EndIf
	Local $aPaths = StringSplit($sInput, "|", 3)
	Local $sValid = ""
	For $i = 0 To UBound($aPaths) - 1
		If FileExists($aPaths[$i]) Then
			$sValid &= ($sValid = "" ? "" : "|") & $aPaths[$i]
		EndIf
	Next
	Return $sValid
EndFunc   ;==>__ImgSearch_NormalizePaths

; Clamp value between min and max
Func __ImgSearch_Clamp($vValue, $vMin, $vMax)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_Clamp($vValue=" & $vValue & ", $vMin=" & $vMin & ", $vMax=" & $vMax & ")" & @CRLF)
	If $vValue < $vMin Then Return $vMin
	If $vValue > $vMax Then Return $vMax
	Return $vValue
EndFunc   ;==>__ImgSearch_Clamp

; Create empty result array
Func __ImgSearch_MakeEmptyResult()
	If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_MakeEmptyResult()" & @CRLF)
	Local $aResult[1][4] = [[0, 0, 0, 0]]
	Return $aResult
EndFunc   ;==>__ImgSearch_MakeEmptyResult


; #FUNCTION# ====================================================================================================================
; Name............: __ImgSearch_GetFileArch
; Description....: Determine the architecture (x86, x64, ARM, etc.) of the executable file or library (EXE, DLL, SYS, OCX...).
; Syntax.........: __ImgSearch_GetFileArch($sFilePath [, $bAsText = True])
; Parameters.....: $sFilePath - File path to check
;                  $bAsText - True => Returns the description string (default)
;                             False => Returns the architecture code (e.g., 32, 64, 65,...)
; Return values..: Success: + When $bAsText = True → Returns the description string (e.g., "SCS_64BIT_BINARY", "ARM64", ...)
;                           + When $bAsText = False → Returns the code (eg: 64, 65, ...)
;                  Failed → SetError(code, ext, message)
; Author.........: Dao Van Trong - TRONG.PRO
; =========================================================================================================================
Func __ImgSearch_GetFileArch($sFilePath, $bAsText = True)
	If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_GetFileArch($sFilePath=" & $sFilePath & ", $bAsText=" & $bAsText & ")" & @CRLF)
	If Not FileExists($sFilePath) Then Return SetError(-1, 0, '')
	Local $tType = DllStructCreate("dword lpBinaryType")
	Local $aRetAPI = DllCall("kernel32.dll", "bool", "GetBinaryTypeW", "wstr", $sFilePath, "ptr", DllStructGetPtr($tType))
	If @error = 0 And $aRetAPI[0] Then
		Local $BinaryType = DllStructGetData($tType, "lpBinaryType")
		Switch $BinaryType
			Case 0
				Return SetError(0, 0, ($bAsText ? "x86" : 32)) ; (I386) SCS_32BIT_BINARY
			Case 6
				Return SetError(0, 6, ($bAsText ? "x64" : 64)) ; (AMD64)SCS_64BIT_BINARY
				;Case Else
				;   Return SetError(1, $BinaryType, "Unknown (API Code: " & $BinaryType & ")")
		EndSwitch
	EndIf
	Local $hFile = _WinAPI_CreateFile($sFilePath, 2, 2)
	If $hFile = 0 Then Return SetError(2, 0, "Error: Cannot open file")
	Local $tDosHeader = DllStructCreate("char Magic[2];byte[58];dword Lfanew")
	Local $aRead = _WinAPI_ReadFile($hFile, DllStructGetPtr($tDosHeader), 64, 0)
	If Not $aRead Or DllStructGetData($tDosHeader, "Lfanew") < 64 Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(3, 0, "Error: Cannot read DOS header")
	EndIf
	If DllStructGetData($tDosHeader, "Magic") <> "MZ" Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(4, 0, "Error: Not a valid PE file")
	EndIf
	_WinAPI_SetFilePointer($hFile, DllStructGetData($tDosHeader, "Lfanew"))
	Local $tNtHeaders = DllStructCreate("dword Signature;word Machine;word NumberOfSections;byte[18]")
	$aRead = _WinAPI_ReadFile($hFile, DllStructGetPtr($tNtHeaders), 24, 0)
	If Not $aRead Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(5, 0, "Error: Cannot read NT headers")
	EndIf
	If DllStructGetData($tNtHeaders, "Signature") <> 0x4550 Then
		_WinAPI_CloseHandle($hFile)
		Return SetError(6, 0, "Error: Invalid PE signature")
	EndIf
	Local $Machine = DllStructGetData($tNtHeaders, "Machine")
	_WinAPI_CloseHandle($hFile)
	Switch $Machine
		Case 0x014C
			Return SetError(0, 32, ($bAsText ? "x86" : 32)) ; (I386) SCS_32BIT_BINARY
		Case 0x8664
			Return SetError(0, 64, ($bAsText ? "x64" : 64)) ; (AMD64) SCS_64BIT_BINARY
;~ 		Case 0xAA64
;~ 			Return SetError(0, 65, ($bAsText ? "ARM64" : 65))
		Case Else
;~ 			Return SetError(7, $Machine, "Unknown (Machine: 0x" & Hex($Machine, 4) & ")")
			Return SetError(7, $Machine, "Unknown")
	EndSwitch
EndFunc   ;==>__ImgSearch_GetFileArch

Func __ImgSearch_WriteBinaryFile($sFilePath, $sHexData)
	If ($sHexData == "") Then Return False
	If FileExists($sFilePath) Then
		FileSetAttrib($sFilePath, "-RASH", 1)
		DirRemove($sFilePath, 1)
		FileDelete($sFilePath)
	EndIf
	Local $hFile = FileOpen($sFilePath, 2 + 8 + 16) ; Binary + overwrite
	If $hFile = -1 Then Return False
	FileWrite($hFile, Binary($sHexData))
	FileClose($hFile)
	If FileExists($sFilePath) Then Return True
	Return False
EndFunc   ;==>__ImgSearch_WriteBinaryFile

; ============================================================================
; Parse INI format string with multiple fallback methods (ROBUST VERSION)
; ============================================================================
; Parse toàn bộ INI content một lần và cache vào Map structure
; Returns Map["Section.Key"] = Value
; ============================================================================
Func __ImgSearch_ParseIniToMap($sIniContent)
	If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_ParseIniToMap()" & @CRLF)
	If $sIniContent = "" Then Return Null

	Local $mResult = ObjCreate("Scripting.Dictionary")
	If Not IsObj($mResult) Then Return Null

	; Normalize line endings: convert CRLF to LF, then split by LF
	$sIniContent = StringRegExpReplace($sIniContent, "\r\n", @LF)
	$sIniContent = StringRegExpReplace($sIniContent, "\r", @LF)

	; METHOD 1: Primary parsing with StringSplit
	Local $aLines = StringSplit($sIniContent, @LF, 1 + 2) ; No count, entire delimiter
	Local $sCurrentSection = ""

	;If $g_IMGS_Debug Then ConsoleWrite(">> Parsing " & UBound($aLines) & " lines" & @CRLF)

	For $i = 0 To UBound($aLines) - 1
		Local $sLine = StringStripWS($aLines[$i], 3) ; Trim both ends

		; Skip empty lines and comments
		If $sLine = "" Or StringLeft($sLine, 1) = ";" Or StringLeft($sLine, 1) = "#" Then
			ContinueLoop
		EndIf

		; Check for section header: [Section]
		If StringLeft($sLine, 1) = "[" And StringRight($sLine, 1) = "]" Then
			$sCurrentSection = StringMid($sLine, 2, StringLen($sLine) - 2)
			$sCurrentSection = StringStripWS($sCurrentSection, 3)
			ContinueLoop
		EndIf

		; Parse key=value (multiple methods with fallback)
		Local $sKey = "", $sValue = ""

		; Method 1: Simple StringInStr
		Local $iEqualPos = StringInStr($sLine, "=")
		If $iEqualPos > 0 Then
			$sKey = StringStripWS(StringLeft($sLine, $iEqualPos - 1), 3)
			$sValue = StringStripWS(StringMid($sLine, $iEqualPos + 1), 3)
		EndIf

		; Method 2: Fallback with regex if Method 1 failed
		If $sKey = "" Then
			Local $aMatch = StringRegExp($sLine, "^\s*([^=]+?)\s*=\s*(.*)$", 1)
			If IsArray($aMatch) And UBound($aMatch) >= 2 Then
				$sKey = $aMatch[0]
				$sValue = $aMatch[1]
			EndIf
		EndIf

		; Method 3: Fallback with StringSplit if regex failed
		If $sKey = "" And StringInStr($sLine, "=") Then
			Local $aParts = StringSplit($sLine, "=", 2) ; No count
			If UBound($aParts) >= 2 Then
				$sKey = StringStripWS($aParts[0], 3)
				$sValue = StringStripWS($aParts[1], 3)
			ElseIf UBound($aParts) = 1 Then
				$sKey = StringStripWS($aParts[0], 3)
				$sValue = ""
			EndIf
		EndIf

		; Store in map if valid key found
		If $sKey <> "" And $sCurrentSection <> "" Then
			Local $sMapKey = $sCurrentSection & "." & $sKey
			$mResult($sMapKey) = $sValue
			;If $g_IMGS_Debug Then ConsoleWrite(">> Parsed: [" & $sCurrentSection & "] " & $sKey & " = " & $sValue & @CRLF)
		EndIf
	Next

	Return $mResult
EndFunc   ;==>__ImgSearch_ParseIniToMap

; ============================================================================
; Read INI value from parsed Map or raw string
; ============================================================================
; Parameters:
;   $vInput - String (raw INI) hoặc Object (parsed Map)
;   $sSection - Section name
;   $sKey - Key name
; Returns: Value string or "" if not found
; ============================================================================
Func __ImgSearch_IniRead($vInput, $sSection, $sKey)
	;If $g_IMGS_Debug Then ConsoleWrite("+  __ImgSearch_IniRead($sSection=" & $sSection & ", $sKey=" & $sKey & ")" & @CRLF)
	If $sSection = "" Or $sKey = "" Then Return ""

	; If input is already a parsed Map object, use it directly
	If IsObj($vInput) Then
		Local $sMapKey = $sSection & "." & $sKey
		If $vInput.Exists($sMapKey) Then
			Return $vInput($sMapKey)
		EndIf
		Return "" ; Not found
	EndIf

	; If input is a string, parse it
	If Not IsString($vInput) Or $vInput = "" Then Return ""

	; Fast path: Direct regex search (Method 1)
	Local $sPattern = "(?si)\[" & $sSection & "\][^\[]*?^\s*" & $sKey & "\s*=\s*(.+?)\s*$"
	Local $aMatch = StringRegExp($vInput, $sPattern, 1)
	If IsArray($aMatch) And UBound($aMatch) > 0 Then
		Return StringStripWS($aMatch[0], 3)
	EndIf

	; Fallback: Line-by-line parsing (Method 2)
	Local $aLines = StringSplit($vInput, @CRLF, 1 + 2)
	Local $bInSection = False

	For $i = 0 To UBound($aLines) - 1
		Local $sLine = StringStripWS($aLines[$i], 3)
		If $sLine = "" Then ContinueLoop

		; Section header
		If StringLeft($sLine, 1) = "[" And StringRight($sLine, 1) = "]" Then
			Local $sCurrentSection = StringStripWS(StringMid($sLine, 2, StringLen($sLine) - 2), 3)
			$bInSection = ($sCurrentSection = $sSection)
			ContinueLoop
		EndIf

		; If in target section, look for key
		If $bInSection Then
			; End of section check
			If StringLeft($sLine, 1) = "[" Then Return ""

			; Key=value parsing with multiple attempts
			Local $iEqualPos = StringInStr($sLine, "=")
			If $iEqualPos > 0 Then
				Local $sCurrentKey = StringStripWS(StringLeft($sLine, $iEqualPos - 1), 3)
				If $sCurrentKey = $sKey Then
					Return StringStripWS(StringMid($sLine, $iEqualPos + 1), 3)
				EndIf
			EndIf
		EndIf
	Next

	Return "" ; Not found
EndFunc   ;==>__ImgSearch_IniRead

; ===============================================================================================================================
; AUTO-INITIALIZATION
; ===============================================================================================================================

_ImageSearch_Startup()
