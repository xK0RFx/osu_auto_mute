#Requires AutoHotkey v1.1

#SingleInstance Force
#Persistent

#Include AppVol.ahk

global otherAppsMuted := false
global osuProcessName := "osu!.exe"
global osuPreviousState := false
global savedVolumes := {}

global ignoreList := [osuProcessName, "explorer.exe", "dwm.exe", "csrss.exe", "svchost.exe", "lsass.exe", "spoolsv.exe", "shell32.dll", "services.exe", "wininit.exe", "winlogon.exe", "system", "smss.exe", "taskmgr.exe"]

SetTimer, CheckOsuActiveState, 1000

~LWin:: CheckOsuActiveState()
~RWin:: CheckOsuActiveState()
~Tab:: CheckOsuActiveState()

CheckOsuActiveState:
    CheckOsuActiveState()
    return

CheckOsuActiveState() {
    global otherAppsMuted, osuProcessName, osuPreviousState, savedVolumes
    
    Process, Exist, %osuProcessName%
    if (!ErrorLevel) {
        if (otherAppsMuted) {
            RestoreAppVolumes()
            otherAppsMuted := false
        }
        osuPreviousState := false
        return
    }
    
    IfWinNotExist, ahk_exe %osuProcessName%
    {
        if (otherAppsMuted) {
            RestoreAppVolumes()
            otherAppsMuted := false
        }
        osuPreviousState := false
        return
    }
    
    isOsuActive := WinActive("ahk_exe " . osuProcessName)
    
    if (isOsuActive && !otherAppsMuted) {
        MuteOtherApps()
        otherAppsMuted := true
        osuPreviousState := true
    } else if (!isOsuActive && otherAppsMuted) {
        RestoreAppVolumes()
        otherAppsMuted := false
        osuPreviousState := true
    }
}

MuteOtherApps() {
    global savedVolumes, ignoreList
    
    WinGet, processList, List,,, Program Manager
    Loop, %processList%
    {
        WinGet, pid, PID, % "ahk_id " processList%A_Index%
        WinGet, processName, ProcessName, ahk_pid %pid%
        
        shouldIgnore := false
        For, ignored in ignoreList
        {
            if (processName = ignored)
            {
                shouldIgnore := true
                break
            }
        }
        
        if (!shouldIgnore)
        {
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
    
    For processName, volume in savedVolumes
    {
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
    RestoreAppVolumes()
    ExitApp
return