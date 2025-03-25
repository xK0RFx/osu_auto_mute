#Requires AutoHotkey v1.1

#SingleInstance Force
#Persistent

#Include AppVol.ahk

global osuProcessName := "osu!.exe"
global osuMuted := false
global otherAppsMuted := false
global savedVolumes := {}

global ignoreList := [osuProcessName, "explorer.exe", "dwm.exe", "csrss.exe", "svchost.exe", "lsass.exe", "spoolsv.exe",
    "shell32.dll", "services.exe", "wininit.exe", "winlogon.exe", "system", "smss.exe", "taskmgr.exe"]

SetTimer, CheckOsuState, 1000

~LWin:: CheckOsuState()
~RWin:: CheckOsuState()
~Tab:: CheckOsuState()

CheckOsuState:
    CheckOsuState()
    return

    CheckOsuState() {
        global osuProcessName, osuMuted, otherAppsMuted

        Process, Exist, %osuProcessName%
        if (!ErrorLevel) {
            if (otherAppsMuted) {
                RestoreAppVolumes()
                otherAppsMuted := false
            }
            return
        }

        IfWinNotExist, ahk_exe %osuProcessName%
        {
            if (otherAppsMuted) {
                RestoreAppVolumes()
                otherAppsMuted := false
            }
            return
        }

        isOsuActive := WinActive("ahk_exe " . osuProcessName)

        if (isOsuActive) {
            if (osuMuted) {
                currentVol := AppVol(osuProcessName)
                if (currentVol = 0) {
                    AppVol(osuProcessName, 100)
                    osuMuted := false
                }
            }

            if (!otherAppsMuted) {
                MuteOtherApps()
                otherAppsMuted := true
            }
        } else {
            if (!osuMuted) {
                currentVol := AppVol(osuProcessName)
                if (currentVol > 0) {
                    AppVol(osuProcessName, 0)
                    osuMuted := true
                }
            }

            if (otherAppsMuted) {
                RestoreAppVolumes()
                otherAppsMuted := false
            }
        }
    }

    MuteOtherApps() {
        global savedVolumes, ignoreList

        WinGet, processList, List, , , Program Manager
        loop, %processList%{
            WinGet, pid, PID, %"ahk_id " processList%A_Index%
            WinGet, processName, ProcessName, ahk_pid %pid%

            shouldIgnore := false
            for , ignored in ignoreList {
                if (processName = ignored) {
                    shouldIgnore := true
                    break
                }
            }

            if (!shouldIgnore) {
                currentVol := AppVol(processName)
                if (currentVol > 0) {
                    savedVolumes[processName] := currentVol
                    AppVol(processName, 0)
                }
            }
        }
    }

    RestoreAppVolumes() {
        global savedVolumes

        for processName, volume in savedVolumes {
            Process, Exist, %processName%
            if (ErrorLevel) {
                AppVol(processName, volume)
            }
        }

        savedVolumes := {}
    }

    OnExit, CleanUp
    return

CleanUp:
    if (osuMuted) {
        AppVol(osuProcessName, 100)
    }
    if (otherAppsMuted) {
        RestoreAppVolumes()
    }
    ExitApp
    return