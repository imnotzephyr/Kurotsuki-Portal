; Coordination layer: VBE's 3-tier Discord queue coordination + Passive mode, ported onto EpicVicHop.
; Source: ViciousBeeEater lib/Searcher.ahk + lib/Passive.ahk. Uses discord.* (Discord.ahk), nowUnix (timers.ahk), roblox.ahk (identical to VBE).

; VBE color globals — queue/passive functions reference red/green/blue; SendPassiveAlert uses red by default. Top-level => global.
blue   := 3447003
green  := 5763719
red    := 15548997
purple := 10181046

; Searcher VB alert to listenID (desc=field, content=server link, no screenshot).
; Returns the alert's Discord message ID (for ready/left reply polling), or 0 on failure.
SendSearcherMessage(link, field)
{
    global listenID, red
    response := discord.SendEmbed(field, red, link, 0, listenID)
    if !response
        return 0
    try
    {
        parsed := JSON.parse(response)
        if parsed.Has("id")
            return parsed["id"]
    }
    return 0
}

; Reads the NightChannelID for Passive night alerts.
; Builds a queue of all unprocessed alerts (oldest first).
; Returns: array of {link, msgID} objects, or empty array if none
GetPassiveQueue()
{
    global NightChannelID
    static lastPassiveID := 0

    if !NightChannelID
        return []

    messages := discord.GetRecentMessages(NightChannelID)
    if !messages.Length
        return []

    queue := []
    newestID := lastPassiveID
    cutoff := nowUnix() - 300  ; 5 min freshness

    for msg in messages
    {
        msgID := Integer(msg["id"])
        if (msgID <= lastPassiveID)
            continue

        if (msgID > newestID)
            newestID := msgID

        msgTime := (msgID >> 22) + 1420070400000
        if ((msgTime / 1000) < cutoff)
            continue

        try
        {
            if !InStr(msg["embeds"][1]["description"], "night")
                continue
        }
        catch
            continue

        link := msg["content"]
        if !link
            continue

        queue.InsertAt(1, {link: link, msgID: msg["id"]})
    }

    lastPassiveID := newestID
    return queue
}

; Sends a "done" reply to a specific Passive alert message.
SendPassiveDone(passiveMsgID)
{
    global NightChannelID, green
    discord.SendEmbed("done", green, , 0, NightChannelID, passiveMsgID)
}

; Searcher signals it has joined the VIP (reply to the night alert) so the Passive leaves to free a slot.
SendSearcherJoined(passiveMsgID)
{
    global NightChannelID, blue
    discord.SendEmbed("joined", blue, , 0, NightChannelID, passiveMsgID)
}

; Polls NightChannelID for a "joined" reply to our night alert. Returns 1 if found, 0 otherwise.
CheckSearcherJoined(replyMsgID)
{
    global NightChannelID
    messages := discord.GetRecentMessages(NightChannelID)
    if !messages.Length
        return 0
    for msg in messages
    {
        ref := ""
        try ref := msg["message_reference"]["message_id"]
        catch
            continue
        if (ref != replyMsgID)
            continue
        try
        {
            if (msg["embeds"][1]["description"] = "joined")
                return 1
        }
    }
    return 0
}

; Sends a "ready" reply to a Searcher VB alert so other Mains know this instance has loaded.
SendMainReady(searcherMsgID)
{
    global listenID, blue
    discord.SendEmbed("ready", blue, , 0, listenID, searcherMsgID)
}

; Counts how many "ready" replies exist for a given Searcher VB alert.
; Returns the number of ready Mains (excluding the original Searcher alert itself).
CountMainReady(searcherMsgID)
{
    global listenID
    if !listenID
        return 0

    messages := discord.GetRecentMessages(listenID)
    if !messages.Length
        return 0

    count := 0
    for msg in messages
    {
        ref := ""
        try ref := msg["message_reference"]["message_id"]
        catch
            continue
        if (ref != searcherMsgID)
            continue
        try
        {
            if (msg["embeds"][1]["description"] = "ready")
                count++
        }
    }
    return count
}

; Main signals it has killed+left (reply to the Searcher VB alert) so the Searcher knows the server is freeing.
SendMainLeft(searcherMsgID)
{
    global listenID, purple
    discord.SendEmbed("left", purple, , 0, listenID, searcherMsgID)
}

; Counts how many "left" replies exist for a given Searcher VB alert.
CountMainLeft(searcherMsgID)
{
    global listenID
    if !listenID
        return 0
    messages := discord.GetRecentMessages(listenID)
    if !messages.Length
        return 0
    count := 0
    for msg in messages
    {
        ref := ""
        try ref := msg["message_reference"]["message_id"]
        catch
            continue
        if (ref != searcherMsgID)
            continue
        try
        {
            if (msg["embeds"][1]["description"] = "left")
                count++
        }
    }
    return count
}

; Searcher waits until >=1 Main has reported ready (joined+claimed) for the given VB alert, then returns. Timeout ~90s.
WaitForMainReady(alertMsgID)
{
    if !alertMsgID
        return
    PlayerStatus("Searcher: Waiting for a Main to join...", "0x1F8B4C", , false, , false)
    start := nowUnix()
    while (nowUnix() - start < 90)
    {
        if (CountMainReady(alertMsgID) >= 1)
        {
            PlayerStatus("Searcher: Main joined, leaving to free a slot.", "0x00a838", , false, , false)
            return
        }
        Sleep 2000
    }
    PlayerStatus("Searcher: No Main joined (timeout), leaving.", "0xff5e00", , false, , false)
}

; Searcher (off-server) waits until MainCount Mains have reported left for the given VB alert, then returns. Timeout ~5min.
WaitForMainLeft(alertMsgID)
{
    global MainCount
    need := (MainCount && MainCount > 0) ? MainCount : 1
    if !alertMsgID
        return
    PlayerStatus("Searcher: Waiting for " need " Mains to leave...", "0x1F8B4C", , false, , false)
    start := nowUnix()
    while (nowUnix() - start < 300)
    {
        if (CountMainLeft(alertMsgID) >= need)
        {
            PlayerStatus("Searcher: All Mains left, signalling Passive to rejoin.", "0x00a838", , false, , false)
            return
        }
        Sleep 3000
    }
    PlayerStatus("Searcher: Main-left timeout, continuing.", "0xff5e00", , false, , false)
}

; Reads the listenID channel for Searcher VB alerts.
; Builds a queue of all unprocessed alerts (oldest first).
; Returns: array of {link, field, msgID} objects, or empty array if none
GetSearcherQueue()
{
    global listenID
    static lastSearcherID := 0

    if !listenID
        return []

    messages := discord.GetRecentMessages(listenID)
    if !messages.Length
        return []

    queue := []
    newestID := lastSearcherID
    cutoff := nowUnix() - 600  ; 10 min freshness

    for msg in messages
    {
        msgID := Integer(msg["id"])
        if (msgID <= lastSearcherID)
            continue

        if (msgID > newestID)
            newestID := msgID

        msgTime := (msgID >> 22) + 1420070400000
        if ((msgTime / 1000) < cutoff)
            continue

        link := msg["content"]
        if !link
            continue

        field := ""
        try field := msg["embeds"][1]["description"]
        if !field
            continue

        queue.InsertAt(1, {link: link, field: field, msgID: msg["id"]})
    }

    lastSearcherID := newestID
    return queue
}

; Functions for the Passive AccountMode — stands idle in a VIP server, detects nighttime,
; alerts Searchers via Discord, then waits for completion. (ported from VBE Passive.ahk)

; Normalizes a VIP server link into a roblox:// deeplink format.
; Extracts the 32-char privateServerLinkCode and constructs:
;   roblox://placeID=1537690962&linkcode=<CODE>
; This joins directly through the Roblox client (no browser).
; Accepts: HTTPS URL, roblox:// URL, bare 32-char code.
NormalizeVIPLink(link)
{
    ; Modern share link (.../share?code=<CODE>&type=<type>) -> resolver deep link. Roblox resolves the
    ; opaque share code client-side (the exact path the browser's JS fires via DeepLinkService), so no
    ; browser tab opens. type defaults to "Server" (a VIP/private server share). Confirmed against RoSeal's
    ; reverse-engineered deeplink parser + Roblox creator docs + a live curl trace of the redirect chain.
    if RegExMatch(link, "i)[?&]code=([^&#]+)", &c) {
        type := RegExMatch(link, "i)[?&]type=([^&#]+)", &t) ? t[1] : "Server"
        return "roblox://navigation/share_links?code=" c[1] "&type=" type
    }
    ; Legacy VIP link (...?privateServerLinkCode=<CODE>) -> direct deep link.
    if RegExMatch(link, "i)privateServerLinkCode=([a-zA-Z0-9\-]{32})", &m)
        return "roblox://placeID=1537690962&linkcode=" m[1]
    if RegExMatch(link, "i)[?&]linkcode=([a-zA-Z0-9\-]{32})", &m)
        return "roblox://placeID=1537690962&linkcode=" m[1]

    ; Bare 32-char code with no URL wrapper
    if RegExMatch(link, "^[a-zA-Z0-9\-]{32}$")
        return "roblox://placeID=1537690962&linkcode=" Trim(link)

    ; Fallback: return as-is (e.g. already a valid deeplink, or HTTPS URL)
    return link
}

; Joins a VIP server via roblox:// deeplink (no browser).
; Normalizes the link first, then uses Run to open directly in the Roblox client.
; Returns: 1 on success, 0 on failure
LoadVIPServer(link)
{
    global
    if !link
    {
        PlayerStatus("Passive: VIPServerLink not configured!", 0xff0000, , false, , false)
        return 0
    }
    normalized := NormalizeVIPLink(link)
    Run normalized
    PlayerStatus("Passive: Loading VIP server...", 0, , false, , false)
    loaded := 0

    loop 30
    {
        Sleep(1000)
        pBMArea := Gdip_BitmapFromScreen()
        ; Detect "loaded" via ground (day) or nightground (night) — visible at spawn where the fresh Passive
        ; stands (it never paths to a hive, so no claimhive prompt; and it lacks the science quest UI). Same
        ; Gdip call as NightDetection so load-detection + night-detection share one signal path: if night
        ; detection works at this res/quality, load detection does too. Covers day AND night joins.
        if (Gdip_ImageSearch(pBMArea, bitmaps["ground"], , , , , , 6) = 1
            || Gdip_ImageSearch(pBMArea, bitmaps["nightground"], , , , , , 6) = 1)
            PlayerStatus("Passive: Loaded VIP (ground visible)", 0x00a838, , false, , false), loaded := 1
        Gdip_DisposeImage(pBMArea)
        if loaded
            break
    }
    ; Lock Roblox to PassiveRes (default 1280x720). Centered horizontally; vertically centered when it fits,
    ; else anchored to the screen bottom so the night-ground region stays on-screen (low-RDP testing).
    try {
        if PassiveRes && InStr(PassiveRes, "x") {
            p := StrSplit(PassiveRes, "x")
            if p.Length >= 2 {
                tw := Integer(Trim(p[1]))
                th := Integer(Trim(p[2]))
                wx := (A_ScreenWidth - tw) // 2
                wy := (A_ScreenHeight - th) // 2
                if (wy < 0)
                    wy := A_ScreenHeight - th
                WinMove wx, wy, tw, th, "Roblox"
            }
        }
    }
    if !loaded
        PlayerStatus("Passive: Load timed out — Roblox window " (GetRobloxHWND() ? "found (join/detection issue)" : "NOT found (deeplink did not launch Roblox)"), "0xff5e00", , false, , false)
    return loaded ? 1 : 0
}

; Sends a night detection alert to the NightChannelID.
; Embeds as "(label) night" if a label is configured, or just "night".
; Returns the Discord message ID string, or 0 on failure.
SendPassiveAlert(serverLink)
{
    global NightChannelID, PassiveLabel, red
    color := red
    desc := PassiveLabel ? "(" PassiveLabel ") night" : "night"
    response := discord.SendEmbed(desc, color, NormalizeVIPLink(serverLink), 0, NightChannelID)
    if !response
        return 0
    try
    {
        parsed := JSON.parse(response)
        if parsed.Has("id")
            return parsed["id"]
    }
    return 0
}

; Polls NightChannelID to check if any message is a "done" reply
; to our specific Passive alert (identified by replyMsgID).
; Returns: 1 if "done" reply found, 0 otherwise
CheckPassiveDone(replyMsgID)
{
    global NightChannelID
    messages := discord.GetRecentMessages(NightChannelID)
    if !messages.Length
        return 0

    for msg in messages
    {
        ref := ""
        try ref := msg["message_reference"]["message_id"]
        catch
            continue
        if (ref != replyMsgID)
            continue
        try
        {
            if (msg["embeds"][1]["description"] = "done")
                return 1
        }
    }
    return 0
}

; Sends a screenshot of the current screen to StingerChannelID.
; If StingerCropX/Y/W/H are configured, crops to that region.
SendStingerScreenshot()
{
    global StingerChannelID, StingerCropX, StingerCropY, StingerCropW, StingerCropH
    if !StingerChannelID
        return
    Sleep 2000  ; wait for loot to collect

    ; Default to hotbar slot 4 crop if not configured
    cropX := (StingerCropX != "") ? StingerCropX : 910
    cropY := (StingerCropY != "") ? StingerCropY : 940
    cropW := (StingerCropW != "") ? StingerCropW : 90
    cropH := (StingerCropH != "") ? StingerCropH : 60
    region := cropX . "|" . cropY . "|" . cropW . "|" . cropH

    pBitmap := Gdip_BitmapFromScreen(region)
    discord.SendImage(pBitmap, "vb_kill.png", StingerChannelID)
    Gdip_DisposeImage(pBitmap)
}

; Clicks in a safe area of the Roblox client to prevent
; the ~20-minute Roblox idle disconnect.
PerformAntiAFK()
{
    global LastActivity
    LastActivity := nowUnix()
    GetRobloxClientPos()
    if (windowX && windowY)
        Click windowX + 350, windowY + GetYOffset() + 100
}