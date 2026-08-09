/**
 * Status embed via the Discord bot (VBE's discord.SendEmbed). Replaces the send-only webhook POST.
 * @param statusImage: true=capture screenshot, false=none, or a pBitmap to attach.
 * @param statusColor: RGB int, e.g. 0xe67e22
 */
PlayerStatus(statusTitle, statusColor, statusDescription := "", Mentions := True, content := "", statusImage := True, statusTimestamp := True) {
    global bottoken, MainChannelID, discordID, InstanceTag
    pBitmap := 0
    if (statusImage == True) {
        hwnd := GetRobloxHWND()
        GetRobloxClientPos(hwnd)
        pBitmap := Gdip_BitmapFromScreen((windowWidth > 0) ? (windowX "|" windowY "|" windowWidth "|" windowHeight) : 0)
    } else if (statusImage != "" && statusImage != True && statusImage != False) {
        pBitmap := statusImage
    }
    mentionStr := (Mentions && discordID != "") ? "<@" discordID ">" : ""
    fullContent := Trim(content " " mentionStr)
    ; Build prefix: [HH:MM:SS tag]
    timeStr := FormatTime(A_Now, "HH:mm:ss")
    prefix := "[" timeStr
    if (InstanceTag != "")
        prefix .= " " InstanceTag
    prefix .= "] "
    msg := (statusDescription != "") ? (statusTitle " -- " statusDescription) : statusTitle
    msg := prefix msg
    try discord.SendEmbed(msg, statusColor + 0, fullContent, pBitmap, MainChannelID)
    if (pBitmap)
        Gdip_DisposeImage(pBitmap)
}
