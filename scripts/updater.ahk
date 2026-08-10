; ============================================================================
; Auto-update system for VicHopMacro (Kurotsuki-Portal)
; ============================================================================
; On startup, compares local version (version.txt) against the latest commit on
; the main branch of imnotzephyr/Kurotsuki-Portal. If newer, downloads the repo
; as a .zip, extracts to a temp directory, backs up the current install, and
; copies the new files over. The macro then restarts itself to load the new code.
;
; Required global: GitHubRepo, GitHubPAT, AutoUpdate (read from settings.ini)
; GitHubRepo defaults to "imnotzephyr/Kurotsuki-Portal" if not set.
; ============================================================================

global GitHubRepo := IniRead(settingsFile, "Settings", "GitHubRepo", "imnotzephyr/Kurotsuki-Portal")
global GitHubPAT  := IniRead(settingsFile, "Settings", "GitHubPAT", "")
global AutoUpdate := Integer(IniRead(settingsFile, "Settings", "AutoUpdate", 1))

; Path to the version file (stores the last-applied commit SHA)
global VersionFile := A_ScriptDir . "\version.txt"

; Read the local version SHA. Empty string if file doesn't exist.
ReadLocalVersion() {
    global VersionFile
    if !FileExist(VersionFile)
        return ""
    try {
        return Trim(FileRead(VersionFile))
    } catch {
        return ""
    }
}

; Write a new version SHA to version.txt
WriteLocalVersion(sha) {
    global VersionFile
    try {
        f := FileOpen(VersionFile, "w")
        f.Write(sha)
        f.Close()
        return true
    } catch {
        return false
    }
}

; Query GitHub API for the latest commit SHA on the main branch.
; Returns the SHA string on success, "" on failure.
FetchRemoteSHA() {
    global GitHubRepo, GitHubPAT
    url := "https://api.github.com/repos/" GitHubRepo "/commits/main"

    try {
        wr := ComObject("WinHttp.WinHttpRequest.5.1")
        wr.Option[9] := 2720
        wr.Open("GET", url, 1)
        wr.SetRequestHeader("User-Agent", "VicHopMacro-Updater (AHK)")
        wr.SetRequestHeader("Accept", "application/vnd.github+json")
        if (GitHubPAT != "")
            wr.SetRequestHeader("Authorization", "Bearer " Trim(GitHubPAT))
        wr.SetTimeouts(0, 10000, 15000, 10000)
        wr.Send()
        wr.WaitForResponse()

        status := wr.Status
        if (status != "200") {
            FileAppend "FetchRemoteSHA: HTTP " status " from " url "`n", A_ScriptDir "\updater.log"
            return ""
        }

        response := wr.ResponseText
        parsed := JSON.parse(response)
        sha := parsed.Has("sha") ? parsed["sha"] : ""
        FileAppend "FetchRemoteSHA: got " StrLen(sha) " char SHA`n", A_ScriptDir "\updater.log"
        return sha
    } catch as e {
        FileAppend "FetchRemoteSHA: exception " e.Message "`n", A_ScriptDir "\updater.log"
        return ""
    }
}

; Download the repo as a zip archive from GitHub.
; Returns the path to the downloaded .zip, or "" on failure.
; PowerShell does the whole download. Bypasses the AHK v2 COM SafeArray marshaling
; problems (wr.ResponseBody to ADODB.Stream.Write or FileOpen+RawWrite both failed
; silently for the user). PowerShell's Invoke-WebRequest -OutFile handles binary
; downloads cleanly. Returns the zip path on success, "" on failure.
DownloadRepoZip() {
    global GitHubRepo, GitHubPAT
    url := "https://codeload.github.com/" GitHubRepo "/zip/refs/heads/main"
    SplitPath A_Temp, &tempDir
    ; Use forward slashes for the PS path (PS -Command eats backslashes as
    ; escape chars inside double quotes). Keep a backslash variant for
    ; AHK's FileExist check which only accepts backslash separators.
    psZipPath := StrReplace(tempDir . "\Kurotsuki-Portal-update.zip", "\", "/")
    ahkZipPath := StrReplace(psZipPath, "/", "\")
    logFile := A_ScriptDir "\updater.log"

    try {
        psCmd := "try { $ProgressPreference = 'SilentlyContinue';"
            . " Invoke-WebRequest -Uri '" url "' -OutFile '" psZipPath "' -UseBasicParsing"
            . " -Headers @{'User-Agent'='VicHopMacro-Updater (AHK)'"
            . (GitHubPAT != "" ? ";'Authorization'='Bearer " Trim(GitHubPAT) "'" : "")
            . "}; exit 0 } catch { exit 1 }"
        cmd := 'powershell.exe -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "' psCmd '"'

        FileAppend "DownloadRepoZip: cmd length=" StrLen(cmd) "`n", logFile
        FileAppend "DownloadRepoZip: target=" ahkZipPath "`n", logFile

        ; Delete any leftover from a previous failed run
        if FileExist(ahkZipPath)
            FileDelete ahkZipPath

        ; AHK v2: RunWait returns the exit code. No stdout capture (v2 removed
        ; the OutputVar parameter). We rely on exit code + zip file existence.
        ; For PS error output, check A_LastError (set by PowerShell on failure).
        exitCode := RunWait(cmd, , "CreateNoWindow")
        FileAppend "DownloadRepoZip: RunWait exit code=" exitCode "`n", logFile
        FileAppend "DownloadRepoZip: ahkZipPath exists after=" FileExist(ahkZipPath) "`n", logFile
        if FileExist(ahkZipPath)
            FileAppend "DownloadRepoZip: ahkZipPath size=" FileGetSize(ahkZipPath) "`n", logFile
        return FileExist(ahkZipPath) ? ahkZipPath : ""
    } catch as e {
        FileAppend "DownloadRepoZip: exception " e.Message "`n", logFile
        return ""
    }
}

; Extract a .zip file using PowerShell (available on all Windows 10+).
; Returns the extracted root directory path, or "" on failure.
ExtractZip(zipPath, destDir) {
    try {
        ; Use PowerShell's Expand-Archive
        ; Build the inner PowerShell command with single-quoted paths
        psCmd := "Expand-Archive -Path '" zipPath "' -DestinationPath '" destDir "' -Force"
        ; -WindowStyle Hidden inside PowerShell + CreateNoWindow on RunWait to fully
        ; suppress the console window during extraction
        cmd := 'powershell.exe -WindowStyle Hidden -NoProfile -Command "' psCmd '"'
        RunWait cmd, , "CreateNoWindow"

        ; GitHub zipballs have a single top-level folder like "Kurotsuki-Portal-<sha>"
        ; Find that folder inside destDir
        Loop Files destDir . "\*", "D" {
            return A_LoopFileFullPath
        }
        return ""
    } catch {
        return ""
    }
}

; Copy a directory tree, overwriting existing files.
; Skips .git directory to avoid pulling repo metadata into the install.
CopyDirTree(srcDir, dstDir, relativePath := "") {
    currentSrc := srcDir . (relativePath != "" ? "\" relativePath : "")
    currentDst := dstDir . (relativePath != "" ? "\" relativePath : "")

    if !FileExist(currentDst)
        DirCreate(currentDst)

    ; Copy files in this directory
    Loop Files currentSrc . "\*", "F" {
        srcFile := A_LoopFileFullPath
        dstFile := currentDst . "\" . A_LoopFileName
        FileCopy srcFile, dstFile, 1  ; 1 = overwrite
    }

    ; Recurse into subdirectories
    Loop Files currentSrc . "\*", "D" {
        dirName := A_LoopFileName
        ; Skip .git directory
        if (dirName = ".git")
            continue
        newRel := relativePath != "" ? relativePath . "\" . dirName : dirName
        CopyDirTree(srcDir, dstDir, newRel)
    }
}

; Apply a downloaded update: backup current install, copy new files over,
; write new version SHA, restart the macro.
; Returns 1 on success (triggers Reload), 0 on failure.
ApplyUpdate(extractedRoot, newSHA) {
    ; Backup current install to a sibling directory (in case rollback is needed)
    backupDir := A_ScriptDir . "\..\Kurotsuki-Portal-backup-" . A_Now
    try {
        DirCreate backupDir
        CopyDirTree(A_ScriptDir, backupDir)
    } catch {
        ; Backup is best-effort; if it fails, continue with the update
    }

    ; Copy new files from extractedRoot over the current install
    try {
        ; The extracted zip has a top-level folder like "Kurotsuki-Portal-<sha>"
        ; containing all the repo files. Copy them over A_ScriptDir.
        Loop Files extractedRoot . "\*", "F" {
            FileCopy A_LoopFileFullPath, A_ScriptDir . "\" . A_LoopFileName, 1
        }
        Loop Files extractedRoot . "\*", "D" {
            dirName := A_LoopFileName
            if (dirName = ".git")
                continue
            CopyDirTree(extractedRoot, A_ScriptDir, dirName)
        }
    } catch as e {
        MsgBox "Update failed during file copy: " e.Message "`n`nThe previous version is backed up at:`n" backupDir, "Update Failed", 0x40010
        return 0
    }

    ; Write the new version
    WriteLocalVersion(newSHA)

    ; Clean up the temp zip and extracted dir
    try FileDelete A_Temp . "\Kurotsuki-Portal-update.zip"
    try DirDelete A_Temp . "\Kurotsuki-Portal-update", 1

    return 1
}

; Main entry point: check for updates, download and apply if newer.
; Returns 1 if an update was applied (caller should NOT continue - script will Reload),
;         0 if no update or update failed (caller should continue normally).
CheckForUpdate() {
    global AutoUpdate, VersionFile

    if (!AutoUpdate)
        return 0

    ; Write debug info to a log file so we can see exactly what's happening.
    logFile := A_ScriptDir "\updater.log"
    try FileDelete logFile  ; no-op if file doesn't exist
    FileAppend "=== Update check " A_Now " ===`n", logFile
    FileAppend "localSHA=" (ReadLocalVersion()) "`n", logFile

    localSHA := ReadLocalVersion()
    remoteSHA := FetchRemoteSHA()
    FileAppend "remoteSHA=" remoteSHA "`n", logFile

    if (remoteSHA = "") {
        FileAppend "FAIL: remoteSHA is empty`n", logFile
        PlayerStatus("Update check failed: could not fetch remote SHA (check network/PAT) -- see " logFile, "0xff5e00", , false, , false)
        return 0
    }

    if (localSHA = remoteSHA) {
        FileAppend "UP TO DATE`n", logFile
        return 0
    }

    if (localSHA = "") {
        ; First run / no version file - don't auto-update, just write the current SHA
        ; so the next launch knows it's current. This avoids surprise-overwriting
        ; a customized install on first run.
        WriteLocalVersion(remoteSHA)
        FileAppend "First run - wrote remote SHA as local`n", logFile
        return 0
    }

    ; We have a local SHA and a different remote SHA - update available
    FileAppend "Update available: local=" localSHA " remote=" remoteSHA "`n", logFile
    PlayerStatus("Update available: downloading latest build... (log: " logFile ")", "0x1ABC9C", , false, , false)

    zipPath := DownloadRepoZip()
    FileAppend "zipPath='" zipPath "'`n", logFile
    FileAppend "A_Temp=" A_Temp "`n", logFile
    FileAppend "Test: A_Temp\Kurotsuki-Portal-update.zip exists=" FileExist(A_Temp "\Kurotsuki-Portal-update.zip") "`n", logFile

    if (zipPath = "") {
        FileAppend "FAIL: download returned empty zipPath`n", logFile
        PlayerStatus("Update download failed (check network/PAT) -- see " logFile, "0xff5e00", , false, , false)
        return 0
    }

    extractDir := A_Temp . "\Kurotsuki-Portal-update"
    try DirDelete extractDir, 1
    DirCreate extractDir

    extractedRoot := ExtractZip(zipPath, extractDir)
    if (extractedRoot = "") {
        FileAppend "FAIL: extraction returned empty`n", logFile
        PlayerStatus("Update extraction failed -- see " logFile, "0xff5e00", , false, , false)
        return 0
    }

    if (ApplyUpdate(extractedRoot, remoteSHA)) {
        ; Update applied successfully -- but DON'T reload mid-session.
        ; The new code will take effect on the next manual restart.
        ; Reloading mid-hunt would kill the session and lose progress.
        FileAppend "Update downloaded and applied (restart to load)`n", logFile
        PlayerStatus("Update downloaded! Restart the macro to apply. (log: " logFile ")", "0x00a838", , false, , false)
        return 0  ; return 0 so the macro continues normally with the old code
    }

    FileAppend "FAIL: ApplyUpdate returned 0`n", logFile
    return 0
}