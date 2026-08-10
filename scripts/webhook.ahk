/**
 * Status embed via the Discord bot (VBE's discord.SendEmbed). Replaces the send-only webhook POST.
 * @param statusImage: true=capture screenshot, false=none, or a pBitmap to attach.
 * @param statusColor: RGB int, e.g. 0xe67e22
 * @param statusTitle: bold clickable title (becomes a link if linkUrl is set)
 * @param linkUrl: optional URL to make the statusTitle clickable in Discord
 */
PlayerStatus(statusTitle, statusColor, statusDescription := "", Mentions := True, content := "", statusImage := True, statusTimestamp := True, linkUrl := "") {
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
    ; Pass statusTitle as embed title (clickable if linkUrl is set); msg becomes the description.
    try discord.SendEmbed(msg, statusColor + 0, fullContent, pBitmap, MainChannelID, 0, statusTitle, linkUrl)
    if (pBitmap)
        Gdip_DisposeImage(pBitmap)
}
