/***********************************************************
* @description: Functions for automating the Roblox window  
* @author SP (modified by e1hua with RDP resilience)
***********************************************************/

; Closes any open Roblox player windows. Called before rejoining servers.
CloseRoblox() {
    try {
        ProcessClose("RobloxPlayerBeta.exe")
        Sleep 100
        WinClose("ahk_exe RobloxPlayerBeta.exe")
    }
    catch TargetError {
        ; Silently ignore if no window found
    }
}

; Activates the Roblox window and returns 1 on success, 0 if not found/fails.
; Used by various functions to ensure Roblox is focused before sending input.
ActivateRoblox() {
    try {
        local hwnd := GetRobloxHWND()
        
        ; Validate we have a valid Roblox window
        if (!hwnd || hwnd = 0)
            return 0
        
        ; Activate the window (critical for RDP: virtual displays need explicit focus)
        WinActivate("ahk_id " . hwnd)
        Sleep 150  ; Longer delay for RDP compositor to catch up
        
        ; Verify activation succeeded
        if WinActive("ahk_id " . hwnd)
            return 1
        else
            return 0
    }
    catch TargetError {
        return 0
    }
}

; Resizes Roblox window to a standard size for consistent UI behavior.
; Useful for ensuring screenshots and clicks land at expected coordinates.
ResizeRoblox(hwnd?) {
    try {
        if !IsSet(hwnd)
            hwnd := GetRobloxHWND()
        
        if (!hwnd || hwnd = 0)
            return 0
        
        ; Set Roblox to a standard windowed size (1280x720)
        local targetWidth := 1280
        local targetHeight := 720
        
        ; AHK v2: WinSetSize( Width, Height [, Win ] )
        ; Changes only W/H without moving X/Y position  
        WinSetSize(targetWidth, targetHeight, "ahk_id " . hwnd)
        
        Sleep 100  ; Let window settle after resize
        return 1
    }
    catch TargetError {
        return 0
    }
}

; Updates global variables windowX, windowY, windowWidth, windowHeight.
; Returns 1 on success, 0 if window not found or coords invalid (RDP edge case).
GetRobloxClientPos(hwnd?) {
    global windowX, windowY, windowWidth, windowHeight
    
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()

    ; RDP resilience: validate window exists before querying  
    if (!hwnd || hwnd = 0 or !WinExist("ahk_id " . hwnd)) {
        return windowX := windowY := windowWidth := windowHeight := 0
    }

    try {
        WinGetClientPos(&windowX, &windowY, &windowWidth, &windowHeight, "ahk_id " . hwnd)
        
        ; Validate dimensions (RDP sometimes returns 0 without erroring)
        if (!windowWidth or !windowHeight or windowWidth < 100 or windowHeight < 100) {
            ; RDP workaround: retry after activation  
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

; Returns hWnd on success, 0 if Roblox window not found.
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

; Returns the Y-offset for Roblox (used to adjust UI coordinates).
; Alias: GetYOffset() also works.
GetYOffset(hwnd?) {
    if !IsSet(hwnd)
        hwnd := GetRobloxHWND()
    
    try
        return WinGetPos(,,, , "ahk_id " . hwnd)[4]  ; Returns window height
    
    catch
        return 0
}

; Backward compatibility alias
GetRobloxUIYOffset(hwnd?) {
    return GetYOffset(hwnd)
}
