#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn VarUnset, Off
SetWorkingDir A_ScriptDir
KeyDelay := 40

; Passive debug log: writes to A_ScriptDir\passive_debug.log so the next
; time anti-AFK stops working, we can read the log instead of guessing.
; Reset on each macro start so the log only shows the current session.
passiveDebugLog := A_ScriptDir "\passive_debug.log"
try FileDelete passiveDebugLog
dbgLine(s) {
    FileAppend A_Now " " s "`n", passiveDebugLog
}
dbgLine("macro started; pid=" DllCall("GetCurrentProcessId") " RobloxHwnd=" GetRobloxHWND() " A_ScriptDir=" A_ScriptDir)

; Default RobloxOpenTime = 20, BSSLoadTime = 5
; Incase you have a really slow pc and need more than 20 seconds to open roblox.
RobloxOpenTime := 20 

; How many seconds from roblox (Joining Server...) to blue loading screen
; Ususually good to change for unkown status or any other ingame erros.
BSSLoadTime := 15

Setkeydelay KeyDelay

GetRobloxClientPos()
pToken := Gdip_Startup()
bitmaps := Map()
bitmaps.CaseSense := 0
currentWalk := {pid:"", name:""} ; stores "pid" (script process ID) and "name" (pattern/movement name)
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SendMode "Event"

WKey := "sc011" ; w
AKey := "sc01e" ; a
SKey := "sc01f" ; s
Dkey := "sc020" ; d
RotLeft := "vkBC" ; ,
RotRight := "vkBE" ; .
RotUp := "sc149" ; PgUp
RotDown := "sc151" ; PgDn
ZoomIn := "sc017" ; i
ZoomOut := "sc018" ; o
Ekey := "sc012" ; e
Rkey := "sc013" ; r
Lkey := "sc026" ; l
EscKey := "sc001" ; Esc
EnterKey := "sc01c" ; Enter
SpaceKey := "sc039" ; Space
SlashKey := "sc035" ; /
SC_LShift:= "sc02a" ; LShift

global data := {beesmas: false, message: "", image: ""}

settingsFile := A_ScriptDir . "\settings.ini"


if (!FileExist(settingsFile)) {
    IniWrite("", settingsFile, "Settings", "discordID")
    IniWrite("", settingsFile, "Settings", "movespeed")
    IniWrite(1, settingsFile, "Settings", "Stockings")
    IniWrite(1, settingsFile, "Settings", "Feast")
    IniWrite(1, settingsFile, "Settings", "Candles")
    IniWrite(1, settingsFile, "Settings", "Samovar")
    IniWrite(1, settingsFile, "Settings", "LidArt")

    IniWrite(1, settingsFile, "Settings", "Pepper")
    IniWrite(1, settingsFile, "Settings", "Mountain")
    IniWrite(1, settingsFile, "Settings", "Cactus")
    IniWrite(1, settingsFile, "Settings", "Rose")
    IniWrite(0, settingsFile, "Settings", "Spider")
    IniWrite(0, settingsFile, "Settings", "Clover")

    ; Auto-update (Kurotsuki-Vichop) defaults
    IniWrite("imnotzephyr/Kurotsuki-Portal", settingsFile, "Settings", "GitHubRepo")
    IniWrite(1, settingsFile, "Settings", "AutoUpdate")
    IniWrite(1, settingsFile, "Settings", "MainSoloHunt")

}

NightSearchAttempts := 1


#include %A_ScriptDir%\lib\

#Include FormData.ahk
#Include Gdip_All.ahk
#include Gdip_ImageSearch.ahk
#include json.ahk
#Include roblox.ahk
#Include walk.ahk
#Include Discord.ahk
#Include Coordination.ahk

; All for gui lol
#Include ComVar.ahk
#Include Promise.ahk
#Include WebView2.ahk
#Include WebViewToo.ahk

#Include %A_ScriptDir%\images\
#include bitmaps.ahk
#include %A_ScriptDir%\scripts\

#include functions.ahk
#include gui.ahk
#include joinserver.ahk
#include paths.ahk
#include timers.ahk
#include webhook.ahk
#include updater.ahk


; Auto-update: check for a newer build on startup. If an update is applied,
; CheckForUpdate() calls Reload() and returns 1 - in that case the rest of
; this file should not execute until the reload happens.
; (webhook.ahk is included ABOVE updater.ahk because CheckForUpdate calls
;  PlayerStatus, which is defined in webhook.ahk.)
if (CheckForUpdate())
    return



leaveServer(){
    if ActivateRoblox() != 1 {
        return
    }
    pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY + 30 "|" windowWidth "|" windowHeight - 30)

    if (Gdip_ImageSearch(pBMScreen, bitmaps["science"], , , , , 150, 2) = 0) {
        Gdip_DisposeImage(pBMScreen)
        return
    }
    Gdip_DisposeImage(pBMScreen)

    rn := KeyDelay
    SetKeyDelay 250 + KeyDelay
    Send "{" EscKey "}{" Lkey "}{" EnterKey "}"
    SetKeyDelay rn
    Sleep(500)
    ; Close the Roblox process entirely instead of just leaving the game
    CloseRoblox()
}


HuntServer(role, link?, coordMsgID?, targetField?) {
    global NightSearchAttempts, data, AccountMode, currentLink, MainCount, currentAlertMsgID
    AccountMode := role
    currentAlertMsgID := ""
    leaveServer()

    ; Join: explicit link (coordination: Searcher alert / Passive alert).
    ; Uses the EXACT same join flow as Passive's LoadVIPServer: single Run(deeplink),
    ; then poll the full screen for ground/nightground — no GameLoaded(), no web-URL fallback.
    if IsSet(link) && link != "" {
        currentLink := link
        normalized := NormalizeVIPLink(link)
        Run normalized
        PlayerStatus("Joining alerted server...", 0, , false, , false)
        loaded := 0
        loop 30 {
            Sleep(1000)
            pBMArea := Gdip_BitmapFromScreen()
            if (Gdip_ImageSearch(pBMArea, bitmaps["ground"], , , , , , 6) = 1
                || Gdip_ImageSearch(pBMArea, bitmaps["nightground"], , , , , , 6) = 1) {
                PlayerStatus("Loaded (ground visible)", 0x00a838, , false, , false)
                loaded := 1
                Gdip_DisposeImage(pBMArea)
                break
            }
            Gdip_DisposeImage(pBMArea)
        }
        if !loaded {
            PlayerStatus("Join timed out — Roblox " (GetRobloxHWND() ? "found (join/detection issue)" : "NOT found (deeplink did not launch Roblox)"), 0xff5e00, , false, , false)
            return
        }
    } else {
        currentLink := joinrandomserver()
        if currentLink = ""
            return
        if (GameLoaded() != true)
            return
    }

    ; Searcher: signal joined (reply to the night alert) so the Passive leaves -> free a slot for the Mains.
    if (role = "Searcher" && IsSet(coordMsgID) && coordMsgID)
        SendSearcherJoined(coordMsgID)

    ; Main: signal READY as soon as we successfully joined the server (NOT after NightDetection).
    ; The Searcher needs to know we've joined so it can leave to free a slot. We were
    ; previously signaling ready after NightDetection succeeded, which meant NightDetection
    ; failures caused the Searcher to time out at 90s (no Main joined).
    if (role = "Main" && IsSet(coordMsgID) && coordMsgID)
        SendMainReady(coordMsgID)

    ; If we have a targetField from the Searcher alert, the VB exists at that field
    ; regardless of whether night is still active. Go straight there.
    if IsSet(targetField) && targetField != "" {
        PlayerStatus("Going directly to " StrTitle(targetField) " (Searcher alert).", "0x1F8B4C", , false, , false)
        global ViciousField := targetField
        gotoField(targetField)
        HuntVB(targetField)
        return
    }

    if (NightDetection() != true) {
        NightSearchAttempts += 1
        PlayerStatus("Searching For Night Servers. " NightSearchAttempts-1 "x", "0x1ABC9C", , false, , false)
        return
    }

    NightSearchAttempts := 1
    PlayerStatus("Night Detected", "0x000000", , false)
    Send "{" Zoomout " 15}"

    global ViciousField := "none"
    if (!StartServerLoop()) {
        return
    }

    ; Main: if multi-Main, wait for MainCount ready before sweeping together.
    if (role = "Main" && MainCount > 1) {
        PlayerStatus("Waiting for " MainCount " Mains to be ready...", "0x1F8B4C", , false, , false)
        start := nowUnix()
        while (nowUnix() - start < 90) {
            if (CountMainReady(coordMsgID) >= MainCount) {
                PlayerStatus("All " MainCount " Mains ready!", "0x00a838", , false, , false)
                break
            }
            Sleep 2000
        }
    }

    PepperChecked := IniRead(settingsFile, "Settings", "Pepper", 0)
    MountainChecked := IniRead(settingsFile, "Settings", "Mountain", 0)
    CactusChecked := IniRead(settingsFile, "Settings", "Cactus", 0)
    RoseChecked := IniRead(settingsFile, "Settings", "Rose", 0)
    SpiderChecked := IniRead(settingsFile, "Settings", "Spider", 0)
    CloverChecked := IniRead(settingsFile, "Settings", "Clover", 0)


    if (!CheckFireButton()) {
        if !ResetCharacterLoop()
            return
    }
    openChat()
    if LeaveServerEarly()
        return
    if (VicSpawnedDetection("none", false)) {
        return
    }
    if (PepperChecked){
        PlayerStatus("Going to Pepper Patch.", "0x1F8B4C", , false, , false)
        PepperPatch()
        openChat()
        if LeaveServerEarly()
            return
        if (VicSpawnedDetection("pepper")) {
            return
        }
        PlayerStatus("Finished Checking Pepper Patch.", "0x57F287", , false)
        PepperToCannon()
        openChat()
        if LeaveServerEarly()
            return
        if (!CheckFireButton()) {
            if !ResetCharacterLoop()
                return
        }
        if (VicSpawnedDetection("none", false)) {
            return
        }
    }
    if (MountainChecked){
        PlayerStatus("Going to Mountain Top Field.", "0x1F8B4C", , false, , false)
        MountainTop()
        openChat()
        if LeaveServerEarly()
            return
        if (VicSpawnedDetection("mountain")) {
            return
        }
        PlayerStatus("Finished Checking Mountain Top Field.", "0x57F287", , false)
    }

    if (CactusChecked){
        PlayerStatus("Going to Cactus Field.", "0x1F8B4C", , false, , false)
        if MountainChecked
            MountainToCactus()

        if !MountainChecked {
            if (!CheckFireButton()) {
                if !ResetCharacterLoop()
                    return
            }
            if LeaveServerEarly()
                return
            if (VicSpawnedDetection("none", false)) {
                return
            }
            Cactus()
        }

        openChat()
        if LeaveServerEarly()
            return
        if VicSpawnedDetection("cactus") {
            return
        }
        PlayerStatus("Finished Checking Cactus Field.", "0x57F287", , false)
    }
    if (RoseChecked){
        PlayerStatus("Going to Rose Field.", "0x1F8B4C", , false, , false)
        if CactusChecked
            CactusToRose()

        if !CactusChecked {
            if (!CheckFireButton()) {
                if !ResetCharacterLoop()
                    return
            }
            if LeaveServerEarly()
                return
            if (VicSpawnedDetection("none", false)) {
                return
            }
            Rose()
        }

        openChat()
        if LeaveServerEarly()
            return
        if VicSpawnedDetection("rose") {
            return
        }
        PlayerStatus("Finished Checking Rose Field.", "0x57F287", , false)
    }

    if (SpiderChecked){
        PlayerStatus("Going to Spider Field.", "0x1F8B4C", , false, , false)
        if (!CheckFireButton()) {
            if !ResetCharacterLoop()
                return
        }
        if LeaveServerEarly()
            return
        if (VicSpawnedDetection("none", false)) {
            return
        }
        Spider()
        openChat()
        if LeaveServerEarly()
            return
        if VicSpawnedDetection("spider") {
            return
        }
        PlayerStatus("Finished Checking Spider Field.", "0x57F287", , false)
    }

    if (CloverChecked){
        PlayerStatus("Going to Clover Field.", "0x1F8B4C", , false, , false)
        if (!CheckFireButton()) {
            if !ResetCharacterLoop()
                return
        }
        if LeaveServerEarly()
            return
        if (VicSpawnedDetection("none", false)) {
            return
        }
        Clover()
        openChat()
        if LeaveServerEarly()
            return
        if VicSpawnedDetection("clover") {
            return
        }
        PlayerStatus("Finished Checking Clover Field.", "0x57F287", , false)
    }


    PlayerStatus("No Vicious bees found.", "0x7F8C8D", , false, , false)
    if (data.beesmas){
        BeesmasInterupt()
    }


}

; ============ ;
; Role loops   ;
; ============ ;

; Main: drain Searcher VB-alert queue (join alerted server, multi-Main ready, kill) then solo-hunt random servers.
Start_Main() {
    global MainCount, MainSoloHunt
    waitMsgTime := 0
    loop {
        ; Priority 1: Searcher VB alerts (coordMsgID = the Searcher alert, so we reply "ready" + later "left" to it)
        queue := GetSearcherQueue()
        for item in queue {
            PlayerStatus("Searcher found VB at " item.field "! Joining...", "0x1F8B4C", , false, , false)
            HuntServer("Main", item.link, item.HasProp("msgID") ? item.msgID : 0, item.field)
            leaveServer()
            if (item.HasProp("msgID") && item.msgID)
                SendMainLeft(item.msgID)
        }

        ; Priority 2: solo hunt (random public servers)
        ; Disabled if MainSoloHunt=0 -- Main will only join when a Searcher alerts it
        if (MainSoloHunt = 0) {
            ; Only post the waiting message every 5 minutes to avoid spam
            if (A_TickCount - waitMsgTime > 300000 || waitMsgTime = 0) {
                waitMsgTime := A_TickCount
                PlayerStatus("Waiting for Searcher alerts (solo hunt disabled)...", "0x7F8C8D", , false, , false)
            }
            Sleep 3000
            continue
        }
        HuntServer("Main")
        leaveServer()
    }
}

; Searcher: drain Passive night-alert queue (join VIP, sweep, alert Main, reply "done") then Hybrid solo / Listener sleep.
Start_Searcher() {
    global PassiveMode, currentAlertMsgID
    loop {
        ; Priority 1: Passive night alerts -> join VIP (signals "joined" so Passive leaves), sweep, on VB-found alert Mains + wait for >=1 ready, leave (free slot), wait for all Mains to leave, then "done" so Passive rejoins.
        queue := GetPassiveQueue()
        for item in queue {
            PlayerStatus("Passive night alert! Joining VIP...", "0x1F8B4C", , false, , false)
            HuntServer("Searcher", item.link, item.msgID)
            leaveServer()
            if currentAlertMsgID
                WaitForMainLeft(currentAlertMsgID)
            SendPassiveDone(item.msgID)
        }

        ; Priority 2: Listener sleeps; Hybrid solo-hunts random servers (alerts Mains on a public-server find, waits ready, leaves)
        if (PassiveMode = "Listener") {
            Sleep 3000
            continue
        }
        HuntServer("Searcher")
        leaveServer()
    }
}

; Passive: sit in a VIP server, watch for night, alert Searchers, wait for "joined" then leave (free a slot), wait for "done" (all Mains left, server empty, night reset) then rejoin.
Start_Passive() {
    global VIPServerLink, NightChannelID, NightTimeout, AntiAFKInterval
    dbgLine("Start_Passive: entered; VIPServerLink=" (VIPServerLink ? "<set>" : "<empty>") " NightChannelID=" (NightChannelID ? "<set>" : "<empty>") " AntiAFKInterval=" AntiAFKInterval)
    loop {
        if !VIPServerLink or !NightChannelID {
            dbgLine("Start_Passive: config missing; VIPServerLink=" (VIPServerLink ? "set" : "EMPTY") " NightChannelID=" (NightChannelID ? "set" : "EMPTY"))
            PlayerStatus("Passive: Config missing! VIPServerLink + NightChannelID required.", "0xff0000", , false, , false)
            MsgBox "VIPServerLink and NightChannelID are required for Passive mode.", "Passive Error", "0x40010 T60"
            return
        }

        PlayerStatus("Passive: Joining VIP server...", "0x1F8B4C", , false, , false)
        dbgLine("Start_Passive: calling LoadVIPServer")
        if !LoadVIPServer(VIPServerLink) {
            dbgLine("Start_Passive: LoadVIPServer returned 0; retrying in 5s")
            PlayerStatus("Passive: Load failed, retrying in 5s...", "0xff5e00", , false, , false)
            Sleep 5000
            continue
        }
        dbgLine("Start_Passive: LoadVIPServer returned success; entering inner loop")

        lastAFK := nowUnix()
        loop {
            if (nowUnix() - lastAFK >= AntiAFKInterval) {
                dbgLine("anti-afk firing; hwnd=" GetRobloxHWND())
                PerformAntiAFK()
                dbgLine("anti-afk done; hwnd=" GetRobloxHWND())
                lastAFK := nowUnix()
            }
            if !GetRobloxHWND() {
                PlayerStatus("Passive: Lost Roblox window, rejoining...", "0xff5e00", , false, , false)
                dbgLine("lost roblox window; breaking inner loop")
                break
            }
            if NightDetection() {
                PlayerStatus("Passive: Night Detected, alerting Searcher...", "0x000000", , false, , false)
                myMsgID := SendPassiveAlert(VIPServerLink)
                if !myMsgID {
                    PlayerStatus("Passive: Failed to send alert, retrying...", "0xff0000", , false, , false)
                    Sleep 10000
                    continue
                }

                timeout := NightTimeout * 60

                ; Phase 1 (on-server): wait for the Searcher to signal "joined", then leave to free a slot for the Mains.
                start := nowUnix()
                joined := 0
                dbgLine("phase 1: waiting for searcher to join; msgID=" myMsgID)
                while (nowUnix() - start < timeout) {
                    if CheckSearcherJoined(myMsgID) {
                        joined := 1
                        break
                    }
                    if (nowUnix() - lastAFK >= AntiAFKInterval) {
                        dbgLine("phase 1 anti-afk firing; hwnd=" GetRobloxHWND())
                        PerformAntiAFK()
                        lastAFK := nowUnix()
                    }
                    if !GetRobloxHWND() {
                        dbgLine("phase 1: lost roblox window; breaking both loops")
                        break 2
                    }
                    Sleep 3000
                }
                if !joined {
                    PlayerStatus("Passive: No Searcher joined in time, continuing...", "0xff5e00", , false, , false)
                    leaveServer()
                    Sleep 5000
                    break
                }
                PlayerStatus("Passive: Searcher joined, leaving to free a slot...", "0x7F8C8D", , false, , false)
                dbgLine("phase 1 ended; joined=" joined " elapsed=" (nowUnix() - start) "s")
                leaveServer()

                ; Phase 2 (off-server): wait for the Searcher "done" (all Mains left -> server empty -> night reset), then rejoin.
                start := nowUnix()
                done := 0
                dbgLine("phase 2: waiting for searcher done; msgID=" myMsgID)
                while (nowUnix() - start < timeout) {
                    if CheckPassiveDone(myMsgID) {
                        PlayerStatus("Passive: Cycle complete, rejoining...", "0x00a838", , false, , false)
                        done := 1
                        break
                    }
                    dbgLine("phase 2 iteration; elapsed=" (nowUnix() - start) "s hwnd=" GetRobloxHWND() " lastAFK_ago=" (nowUnix() - lastAFK) "s")
                    Sleep 3000
                }
                if !done
                    PlayerStatus("Passive: done timeout, rejoining anyway...", "0xff5e00", , false, , false)
                dbgLine("phase 2 ended; done=" done " elapsed=" (nowUnix() - start) "s")
                Sleep 5000
                break
            }
            Sleep 3000
        }
    }
}


; }


ElevateScript() {
	try
		file := FileOpen("scripts\functions.ahk", "a")
	catch {
		if (!A_IsAdmin || !(DllCall("GetCommandLine","Str") ~= " /restart(?!\S)"))
			Try RunWait '*RunAs "' A_AhkPath '" /script /restart "' A_ScriptFullPath '"'
		if !A_IsAdmin {
			MsgBox "You must run VichopMacro as administrator in this folder!`nIf you don't want to do this, move the macro to a different folder (e.g. Downloads, Desktop)", "Error", 0x40010
			ExitApp
		}
		; elevated but still can't write, read-only directory?
		MsgBox "You cannot run VichopMacro in this folder!`nTry moving the macro to a different folder (e.g. Downloads, Desktop)", "Error", 0x40010
    }
}
ElevateScript()

ScreenResolution(){
    if (A_ScreenDPI != 96){
        MsgBox "
        (
        Your Display Scale seems to be a value other than 100%. This means the macro will NOT work correctly!
        
        To change this:
        Right click on your Desktop -> Click 'Display Settings' -> Under 'Scale & Layout', set Scale to 100% -> Close and Restart Roblox before starting the macro.
        )", "WARNING!!", 0x1030 " T60"
    }
    
    ; if (A_ScreenHeight > 1080 || A_ScreenWidth > 1920){
    ;     MsgBox "
    ;     (
    ;         Your Resolution is too massive!! Lower it to 1920x1080 or any lower. This means the macro will NOT work correctly!
            
    ;         To change this:
    ;         Right click on your Desktop -> Click 'Display Settings' -> Under 'Scale & Layout', set Resolution to 1920x1080.
    ;         You can also use a Remote Desktop (RDP) to use this macro under or 1920x1080 resolution. For more information I would recommend looking up information on how to macro on an RDP  
    ;         )", "WARNING!!", 0x1030 " T60"
    ;     }
        
    }
    
    
ScreenResolution()
