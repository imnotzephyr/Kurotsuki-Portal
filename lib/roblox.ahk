/***********************************************************
* @description: Functions for automating the Roblox window  
* @author SP
***********************************************************/

; Updates global variables windowX, windowY, windowWidth, windowHeight
; Optionally takes a known window handle to skip GetRobloxHWND call.
; Returns 1 on success, 0 if window not found or coords invalid (RDP edge case).
GetRobloxClientPos(hwnd?) {
    global windowX, windowY, windowWidth, windowHeight
    
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()

    ; RDP resilience: validate hwnd first  
    if (!hwnd || hwnd = 0 or !WinExist("ahk_id " . hwnd)) {
        return windowX := windowY := windowWidth := windowHeight := 0
    }

    try {
        WinGetClientPos(&windowX, &windowY, &windowWidth, &windowHeight, "ahk_id " . hwnd)
        
        ; Validate dimensions (RDP sometimes returns 0 without erroring)
        if (!windowWidth or !windowHeight or windowWidth < 100 or windowHeight < 100) {
            ; RDP workaround: try activation then retry  
            WinActivate("Roblox ahk_id " . hwnd)
            Sleep 75
            
            Try WinGetClientPos(&windowX, &windowY, &windowWidth, &windowHeight, "ahk_id " . hwnd)
            
            if (!windowWidth or !windowHeight or windowWidth < 100 or windowHeight < 100) {
                return windowX := windowY := windowWidth := windowHeight := 0
            }
        }
        
        return 1
    }
    catch TargetError {
        return windowX := windowY := windowWidth := windowHeight := 0
    }
}

; Returns: hWnd on success, 0 if window not found  
GetRobloxHWND() {
    if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
        return hwnd
    
    ; UWP app handling for Windows Store version  
    if (WinExist("Roblox ahk_exe ApplicationFrameHost.exe")) {
        try
            hwnd := ControlGetHwnd("ApplicationFrameInputSinkWindow1", "ahk_exe ApplicationFrameHost.exe")
        catch TargetError
            return 0
        
        return hwnd
    }
    
    return 0
}

; Finds the y-offset of GUI elements in current Roblox window  
; Used to adjust coordinates for different UI scales/resolutions  
GetRobloxUIYOffset(hwnd?) {
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()
    
    try
        return WinGetPos(,,, , "ahk_id " . hwnd)[4]  ; Returns window height
    
    catch
        return 0
}
