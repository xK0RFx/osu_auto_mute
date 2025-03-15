#Requires AutoHotkey v1.1

#Include AppVol.ahk

osuMuted := false
osuProcessName := "osu!.exe"
osuPreviousState := false

SetTimer, CheckOsuActive, 1000

~LWin:: CheckOsuActive()
~RWin:: CheckOsuActive()
~Tab:: CheckOsuActive()

CheckOsuActive:
    CheckOsuActive()
    return

    CheckOsuActive() {
        global osuMuted, osuProcessName, osuPreviousState

        Process, Exist, %osuProcessName%
        if (!ErrorLevel) {
            osuPreviousState := false
            return
        }

        IfWinNotExist, ahk_exe %osuProcessName%
        {
            osuPreviousState := false
            return
        }

        isOsuActive := WinActive("ahk_exe " . osuProcessName)

        if (!isOsuActive && !osuMuted) {
            AppVol(osuProcessName, 0)
            osuMuted := true
            osuPreviousState := true
        } else if (isOsuActive && osuMuted) {
            AppVol(osuProcessName, 100)
            osuMuted := false
            osuPreviousState := true
        }
    }

    #SingleInstance, Force
    SendMode, Input
    SetBatchLines, -1
    SetWorkingDir, %A_ScriptDir%