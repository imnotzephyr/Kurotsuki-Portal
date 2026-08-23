#Requires AutoHotkey v2.0
; Standalone VB Warning Detector - Test Tool
; Usage: Drag-and-drop a screenshot file onto this script, or pass path as argument

; Load GDI+ libraries
#Include ..\lib\Gdip_All.ahk  
#Include ..\images\bitmaps.ahk  ; Contains the bitmaps Map with VBWarning definition

If !(pToken := Gdip_Startup()) {
    MsgBox "ERROR: Could not initialize GDI+. Code: " pToken
    ExitApp
}

Global pVBBitmap := 0  
Global DetectX := -1, DetectY := -1

; Retrieve the loaded bitmap from bitmaps.ahk Map
try {
    if (IsObject(bitmaps) && bitmaps.HasKey("VBWarning"))
        pVBBitmap := bitmaps["VBWarning"]
} catch {
    MsgBox "Could not load VBWarning bitmap`nMake sure: lib/Gdip_All.ahk and images/bitmaps.ahk exist relative to this script."
    ExitApp  
}

if (!pVBBitmap) {
    vsLogLine("[ERROR] pVBBitmap is null")
    MsgBox "Failed to load VBWarning bitmap from bitmaps.ahk`nPath check: ../images/bitmaps.ahk"
    ExitApp
}

vsLogLine("[TEST] VBWarning bitmap loaded successfully")

; Main test routine
TestScreenshot(filePath*) {
    ; Declare function locals to avoid "unassigned variable" warnings
    Local outFile := ""  
    Local pBitmap := 0
    
    if (!filePath[1]) {
        ; No argument - use file picker  
        outFile := FileSelect("S", A_ScriptDir "\screenshots\", "*.png;*.jpg;*.bmp")
        if (outFile == "") {
            MsgBox "No file selected."
            return 0
        }
    } else {
        outFile := filePath[1]  
    }
    
    vsLogLine("[TEST] Loading: " outFile)
    
    pBitmap := Gdip_LoadImageFromFile(outFile)
    if (!pBitmap) {
        MsgBox "Error loading image: " outFile
        return 0  
    }
    
    ; Get dimensions for log
    Gdip_GetImageDimensions(pBitmap, &w, &h)  
    vsLogLine("[TEST] Image size: " w "x" h)

    ; Perform search (mimics production call in functions.ahk line 1241):
    ; warningFound := Gdip_ImageSearch(pBMScreen, bitmaps["VBWarning"], , , , , , 50, 0)
    results := ""
    found := Gdip_ImageSearch(pBitmap, pVBBitmap, results,, 0, 0, 0, 0, 50,, 1)
    
    vsLogLine("[TEST] Search return code: " found)
    
    if (found > 0 && StrLen(results) > 0) {
        ; Parse result string - typically "x,y" format  
        SplitPath(results, &firstInstance,,, ",")  ; Get first match
        
        ; results is comma-separated x,y values for each instance  
        if InStr(firstInstance, ",") { 
            parts := StrSplit(firstInstance, ",")
            DetectX := parts[1]
            DetectY := parts[2]
        } else {  ; Fallback handling  
            var := firstInstance
            vsLogLine("[WARN] Coordinate parse ambiguous")
            DetectX := found
        }
        
        msg := "VB DETECTED!`n"
            . "Matches found: " found "`n"
            . "First instance at: (" DetectX "," DetectY ")" "`n"
            . "Raw output: " results
        
        MsgBox msg
        vsLogLine("[TEST] ✓ VB FOUND at (" DetectX "," DetectY ")")  
        
    } else if (found == 0) {
        MsgBox "No VB warning icon detected in this screenshot."
        vsLogLine("[TEST] ✗ Not found")
        
    } else if (found < -1000) {
        ; Error code handling  
        switch(found) {
            case -1001: err := "Invalid bitmap"
            case -1002: err := "Variation out of range"
            case -1003: err := "Bad coordinates"
            default:     err := "Unknown error: " found
        }
        MsgBox "Detection ERROR:`n" err  
        vsLogLine("[TEST] ERROR: " err)  
    } else {
        MsgBox "No matches or invalid result."
    }
    
    ; Cleanup
    Gdip_DisposeImage(pBitmap)  
    
    return found
}

; Logging helper (outputs to Debug console - viewable in AHK console)
vsLogLine(msg) {
    OutputDebug(msg)  
}

; Handle command-line args (drag-and-drop support)  
ParamCount := ParamCount()
if (ParamCount > 0) {
    vsLogLine("[TEST] Running with arg: " P1)  
    TestScreenshot([P1])
} else {
    ; Show intro prompt in interactive mode  
    MsgBox "=== VB Warning Detector ===`n" .
           "Drag and drop a screenshot file onto this script,`n" .
           "or click Cancel to open the file browser.`n`n" .
           "The script will report if the VB warning icon is present`n" .
           "and display its coordinates."
           
    TestScreenshot()  ; Open file picker
}

; Cleanup on exit  
OnExit(OnScriptExit)

OnScriptExit(*) {
    global pToken
    if (!pToken = 0)
        Gdip_Shutdown(pToken)
}

Return

ExitApp()
