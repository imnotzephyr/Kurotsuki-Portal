#Requires AutoHotkey v2.0

version := "v1.2.0"



TraySetIcon("images\stinger.ico")



if (A_IsCompiled) {
	WebViewCtrl.CreateFileFromResource((A_PtrSize * 8) "bit\WebView2Loader.dll", WebViewCtrl.TempDir)
    WebViewSettings := {DllPath: WebViewCtrl.TempDir "\" (A_PtrSize * 8) "bit\WebView2Loader.dll"}
} else {
    WebViewSettings := {}
    TraySetIcon("images\\stinger.ico")
}




MyWindow := WebViewGui("-Resize -Caption ",,,WebViewSettings) ; ignore error it somehow works with it.....
MyWindow.OnEvent("Close", (*) => StopMacro())
MyWindow.Navigate("scripts/Gui/index.html")
; MyWindow.Debug()
MyWindow.AddHostObjectToScript("ButtonClick", { func: WebButtonClickEvent })
MyWindow.AddHostObjectToScript("Save", { func: SaveSettings })
MyWindow.AddHostObjectToScript("ReadSettings", { func: SendSettings })
MyWindow.AddHostObjectToScript("Dragger", { func: BeginDrag })
; MyWindow.Show("w" 650 "h" 465)
winWidth := 625
winHeight := 410
MyWindow.Show("w" winWidth " h" winHeight)

Sleep(250)


BeginDrag(*) {
    DllCall("ReleaseCapture")
    DllCall("SendMessage", "Ptr", MyWindow.Hwnd, "UInt", 0xA1, "UPtr", 2, "UPtr", 0)
}





Start(*) {
    PlayerStatus("Starting " version " VicHopMacro by zephyr", "0xFFFF00", , false, , false)
    dbgLine("Start: dispatcher; AccountMode=" (AccountMode ? AccountMode : "<empty>") " movespeed=" (IniRead(settingsFile, "Settings", "movespeed", "") ? "set" : "EMPTY"))
    if (IniRead(settingsFile, "Settings", "movespeed", "") == "") {
        PlayerStatus("ERROR: Add a valid movespeed", "0xff0000", , true, , false)
        MsgBox "Please provide a valid movespeed in settings!`nYou might of forgotten to save settings.", "Error", 0x40010
    }
    CloseRoblox()
    GetServerIds(2)
    switch AccountMode {
        case "Searcher": {
            dbgLine("Start: dispatching to Start_Searcher")
            Start_Searcher()
        }
        case "Passive": {
            dbgLine("Start: dispatching to Start_Passive")
            Start_Passive()
        }
        default: {
            dbgLine("Start: dispatching to Start_Main (default)")
            Start_Main()
        }
    }
}


ResetMacro(*) { 
    SetTimer(ViciousSpawnLocation, 0)
    Send "{" WKey " up}{" AKey " up}{" SKey " up}{" Dkey " up}{F14 up}"
    try Gdip_Shutdown(pToken)
    nm_endWalk()
    try WinClose "ahk_class AutoHotkey ahk_pid " JoinSeverProcesId.pid
    try FileDelete A_ScriptDir "\serverlist.txt"
    try FileDelete A_ScriptDir "\pendingserverlist.txt"
    Reload 
}


StopMacro(*) {
    PlayerStatus("Closed VicHopMacro", "0xff5e00", , false, , false)
    SetTimer(ViciousSpawnLocation, 0)
    Send "{" WKey " up}{" AKey " up}{" SKey " up}{" Dkey " up}{F14 up}"
    try Gdip_Shutdown(pToken)
    nm_endWalk()
    try WinClose "ahk_class AutoHotkey ahk_pid " JoinSeverProcesId.pid
    try FileDelete A_ScriptDir "\serverlist.txt"
    try FileDelete A_ScriptDir "\pendingserverlist.txt"
    ExitApp()
    
}


F1:: {
    Start
}

F2:: {
    ResetMacro
}





WebButtonClickEvent(button) {
	switch button {
		case "Start":
			Send("{F1}")
        case "Stop":
			Send("{F2}")
	}
}



SaveSettings(settings) {
    settings := JSON.parse(settings)

    IniFile := A_ScriptDir . "\settings.ini"

    for key, value in settings {
        IniWrite(value, IniFile, "Settings", key)
    }
    Sleep 200
    Reload
}

SendSettings(){
	settingsFile := A_ScriptDir . "\settings.ini"

    if (!FileExist(settingsFile)) {
        IniWrite("", settingsFile, "Settings", "discordID")
        IniWrite("", settingsFile, "Settings", "movespeed")

        IniWrite(1, settingsFile, "Settings", "Pepper")
        IniWrite(1, settingsFile, "Settings", "Mountain")
        IniWrite(1, settingsFile, "Settings", "Cactus")
        IniWrite(1, settingsFile, "Settings", "Rose")
        IniWrite(0, settingsFile, "Settings", "Spider")
        IniWrite(0, settingsFile, "Settings", "Clover")

        ; Coordination (VBE) config
        IniWrite("", settingsFile, "Settings", "BotToken")
        IniWrite("", settingsFile, "Settings", "MainChannelID")
        IniWrite("", settingsFile, "Settings", "listenID")
        IniWrite("", settingsFile, "Settings", "NightChannelID")
        IniWrite("", settingsFile, "Settings", "StingerChannelID")
        IniWrite("Main", settingsFile, "Settings", "AccountMode")
        IniWrite("", settingsFile, "Settings", "VIPServerLink")
        IniWrite(10, settingsFile, "Settings", "NightTimeout")
        IniWrite(30, settingsFile, "Settings", "AntiAFKInterval")
        IniWrite("Hybrid", settingsFile, "Settings", "PassiveMode")
        IniWrite(1, settingsFile, "Settings", "MainCount")
        IniWrite(1, settingsFile, "Settings", "MainSoloHunt")
        IniWrite("", settingsFile, "Settings", "PassiveLabel")
        IniWrite("1280x720", settingsFile, "Settings", "PassiveRes")
        IniWrite("", settingsFile, "Settings", "InstanceTag")
        IniWrite("imnotzephyr/Kurotsuki-Portal", settingsFile, "Settings", "GitHubRepo")
        IniWrite(1, settingsFile, "Settings", "AutoUpdate")
    }
	
    SettingsJson := {
      discordID:            IniRead(settingsFile, "Settings", "discordID")
    , MoveSpeed:            IniRead(settingsFile, "Settings", "movespeed")
    ; Coordination (VBE) config
    , BotToken:             IniRead(settingsFile, "Settings", "BotToken", "")
    , MainChannelID:        IniRead(settingsFile, "Settings", "MainChannelID", "")
    , listenID:             IniRead(settingsFile, "Settings", "listenID", "")
    , NightChannelID:       IniRead(settingsFile, "Settings", "NightChannelID", "")
    , StingerChannelID:     IniRead(settingsFile, "Settings", "StingerChannelID", "")
    , AccountMode:          IniRead(settingsFile, "Settings", "AccountMode", "Main")
    , VIPServerLink:        IniRead(settingsFile, "Settings", "VIPServerLink", "")
    , NightTimeout:         IniRead(settingsFile, "Settings", "NightTimeout", 10)
    , AntiAFKInterval:      IniRead(settingsFile, "Settings", "AntiAFKInterval", 30)
    , PassiveMode:          IniRead(settingsFile, "Settings", "PassiveMode", "Hybrid")
    , MainCount:            IniRead(settingsFile, "Settings", "MainCount", 1)
    , MainSoloHunt:        IniRead(settingsFile, "Settings", "MainSoloHunt", 1)
    , PassiveLabel:         IniRead(settingsFile, "Settings", "PassiveLabel", "")
    , PassiveRes:           IniRead(settingsFile, "Settings", "PassiveRes", "1280x720")
    , InstanceTag:          IniRead(settingsFile, "Settings", "InstanceTag", "")
    , GitHubRepo:           IniRead(settingsFile, "Settings", "GitHubRepo", "imnotzephyr/Kurotsuki-Portal")
    , AutoUpdate:           IniRead(settingsFile, "Settings", "AutoUpdate", 1)
    , InstanceTag:          IniRead(settingsFile, "Settings", "InstanceTag", "")
    , MainSoloHunt:         IniRead(settingsFile, "Settings", "MainSoloHunt", 1)
    }
	Sleep(200)
	MyWindow.PostWebMessageAsJson(JSON.stringify(SettingsJson))
}

SendSettings()



discordID := IniRead(settingsFile, "Settings", "discordID")
MoveSpeed := IniRead(settingsFile, "Settings", "movespeed")

; Coordination (VBE) globals — read at startup so Discord.ahk (bottoken/MainChannelID) + Coordination.ahk (queues/passive) resolve.
bottoken := IniRead(settingsFile, "Settings", "BotToken", "")
MainChannelID := IniRead(settingsFile, "Settings", "MainChannelID", "")
listenID := IniRead(settingsFile, "Settings", "listenID", "")
NightChannelID := IniRead(settingsFile, "Settings", "NightChannelID", "")
StingerChannelID := IniRead(settingsFile, "Settings", "StingerChannelID", "")
StingerCropX := IniRead(settingsFile, "Settings", "StingerCropX", "")
StingerCropY := IniRead(settingsFile, "Settings", "StingerCropY", "")
StingerCropW := IniRead(settingsFile, "Settings", "StingerCropW", "")
StingerCropH := IniRead(settingsFile, "Settings", "StingerCropH", "")
AccountMode := IniRead(settingsFile, "Settings", "AccountMode", "Main")
VIPServerLink := IniRead(settingsFile, "Settings", "VIPServerLink", "")
NightTimeout := IniRead(settingsFile, "Settings", "NightTimeout", 10)
AntiAFKInterval := IniRead(settingsFile, "Settings", "AntiAFKInterval", 30)
PassiveMode := IniRead(settingsFile, "Settings", "PassiveMode", "Hybrid")
MainCount := IniRead(settingsFile, "Settings", "MainCount", 1)
MainSoloHunt := IniRead(settingsFile, "Settings", "MainSoloHunt", 1)
InstanceTag := IniRead(settingsFile, "Settings", "InstanceTag", "")
commandPrefix := "!"

; Track macro start time for uptime reporting
global MacroStartTime := nowUnix()
global LastActivity := nowUnix()

; Periodic command poller: checks MainChannelID for !status / !alive commands
CheckDiscordCommands() {
    global commandPrefix, AccountMode, MacroStartTime, LastActivity
    if !MainChannelID
        return
    cmds := discord.GetCommands()
    if !cmds.Length
        return
    for cmd in cmds {
        content := Trim(cmd.content)
        lower := StrLower(content)
        if (lower = "!alive" or lower = "!ping") {
            uptime := nowUnix() - MacroStartTime
            hours := uptime // 3600
            mins := Mod(uptime, 3600) // 60
            discord.SendEmbed("alive -- " AccountMode " -- uptime " hours "h " mins "m -- last activity " (nowUnix() - LastActivity) "s ago", 5763719, , 0, MainChannelID)
        }
        else if (lower = "!status") {
            robloxOn := GetRobloxHWND() ? "yes" : "no"
            field := (ViciousField != "none") ? ViciousField : "none"
            uptime := nowUnix() - MacroStartTime
            hours := uptime // 3600
            mins := Mod(uptime, 3600) // 60
            msg := "mode=" AccountMode " | roblox=" robloxOn " | viciousField=" field " | uptime=" hours "h " mins "m | lastActivity=" (nowUnix() - LastActivity) "s ago"
            discord.SendEmbed(msg, 3447003, , 0, MainChannelID)
        }
    }
}

SetTimer CheckDiscordCommands, 30000
PassiveLabel := IniRead(settingsFile, "Settings", "PassiveLabel", "")
PassiveRes := IniRead(settingsFile, "Settings", "PassiveRes", "1280x720")
InstanceTag := IniRead(settingsFile, "Settings", "InstanceTag", "")




PlayerStatus("Connected to discord!", "0x4D4DFF", , false, , false)





















