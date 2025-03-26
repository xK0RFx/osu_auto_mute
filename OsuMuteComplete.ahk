#Requires AutoHotkey v1.1
#SingleInstance Force
#Persistent
SendMode Input
SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

global targetGameProcessName := "osu!.exe"
global isGameActive := false
global osuMuted := false
global appsMutedByScript := {}

CheckGameState()

SetTimer, CheckGameState, 1000

~LWin::
~RWin::
~Tab::
{
    SetTimer, CheckGameState, -250
    return
}

CheckGameState() 
{
    global targetGameProcessName, isGameActive, osuMuted, appsMutedByScript

    Process, Exist, %targetGameProcessName%
    targetGamePid := ErrorLevel
    if (!targetGamePid) 
    {
        if (isGameActive) 
        {
            UpdateOtherAppsMuteState(false, 0)
            isGameActive := false
        }
        osuMuted := false
        return
    }

    isCurrentlyActive := WinActive("ahk_exe " . targetGameProcessName)

    if (isCurrentlyActive) 
    {
        if (osuMuted) 
        {
            try {
                AppVol(targetGameProcessName, 100)
                osuMuted := false
            } catch {
                osuMuted := false
            }
        }
        
        if (!isGameActive) 
        {
            UpdateOtherAppsMuteState(true, targetGamePid)
            isGameActive := true
        }
    } 
    else 
    {
        if (!osuMuted) 
        {
            try {
                AppVol(targetGameProcessName, 0)
                osuMuted := true
            } catch {
                osuMuted := true
            }
        }
        
        if (isGameActive) 
        {
            UpdateOtherAppsMuteState(false, targetGamePid)
            isGameActive := false
        }
    }
}

UpdateOtherAppsMuteState(muteOthers, targetGamePid) 
{
    global targetGameProcessName, appsMutedByScript

    static IID_IAudioSessionManager2 := "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}"
    static IID_IAudioSessionEnumerator := ""
    static IID_IAudioSessionControl := ""
    static IID_IAudioSessionControl2 := "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}"
    static IID_ISimpleAudioVolume := "{87CE5498-68D6-44E5-9215-6DA47EF883D8}"
    static CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    static IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"

    VarSetCapacity(GUID_IAudioSessionManager2, 16)
    DllCall("ole32\CLSIDFromString", "WStr", IID_IAudioSessionManager2, "Ptr", &GUID_IAudioSessionManager2)

    IMMDeviceEnumerator := ComObjCreate(CLSID_MMDeviceEnumerator, IID_IMMDeviceEnumerator)
    if (!IMMDeviceEnumerator) 
    {
        OutputDebug, Failed to create IMMDeviceEnumerator
        return
    }

    hr := DllCall(NumGet(NumGet(IMMDeviceEnumerator+0) + 4*A_PtrSize), "Ptr", IMMDeviceEnumerator, "Int", 0, "Int", 1, "Ptr*", pDevice := 0)
    ObjRelease(IMMDeviceEnumerator)
    if (hr != 0 || !pDevice) 
    {
        OutputDebug, Failed to get default audio device (hr=%hr%)
        return
    }

    hr := DllCall(NumGet(NumGet(pDevice+0) + 3*A_PtrSize), "Ptr", pDevice, "Ptr", &GUID_IAudioSessionManager2, "UInt", 0x17, "Ptr", 0, "Ptr*", pSessionManager := 0)
    ObjRelease(pDevice)
    if (hr != 0 || !pSessionManager) 
    {
        OutputDebug, Failed to activate IAudioSessionManager2 (hr=%hr%)
        return
    }

    hr := DllCall(NumGet(NumGet(pSessionManager+0) + 5*A_PtrSize), "Ptr", pSessionManager, "Ptr*", pSessionEnumerator := 0)
    ObjRelease(pSessionManager)
    if (hr != 0 || !pSessionEnumerator) 
    {
        OutputDebug, Failed to get session enumerator (hr=%hr%)
        return
    }

    hr := DllCall(NumGet(NumGet(pSessionEnumerator+0) + 3*A_PtrSize), "Ptr", pSessionEnumerator, "Int*", sessionCount := 0)
    if (hr != 0) 
    {
        OutputDebug, Failed to get session count (hr=%hr%)
        ObjRelease(pSessionEnumerator)
        return
    }

    Loop, %sessionCount%
    {
        hr := DllCall(NumGet(NumGet(pSessionEnumerator+0) + 4*A_PtrSize), "Ptr", pSessionEnumerator, "Int", A_Index-1, "Ptr*", pSessionControl := 0)
        if (hr != 0 || !pSessionControl) 
        {
            Continue
        }

        pSessionControl2 := ComObjQuery(pSessionControl, IID_IAudioSessionControl2)
        ObjRelease(pSessionControl)
        if (!pSessionControl2) 
        {
            Continue
        }

        hr := DllCall(NumGet(NumGet(pSessionControl2+0) + 14*A_PtrSize), "Ptr", pSessionControl2, "UInt*", pid := 0)
        if (hr != 0 || pid = 0) 
        {
            ObjRelease(pSessionControl2)
            Continue
        }

        if (pid != targetGamePid)
        {
            pSimpleAudioVolume := ComObjQuery(pSessionControl2, IID_ISimpleAudioVolume)
            if (pSimpleAudioVolume) 
            {
                if (muteOthers) 
                {
                    hr := DllCall(NumGet(NumGet(pSimpleAudioVolume+0) + 6*A_PtrSize), "Ptr", pSimpleAudioVolume, "Int*", currentMuteState := 0)
                    if (hr = 0 && currentMuteState = 0) 
                    {
                        hr_mute := DllCall(NumGet(NumGet(pSimpleAudioVolume+0) + 5*A_PtrSize), "Ptr", pSimpleAudioVolume, "Int", 1, "Ptr", 0)
                        if (hr_mute = 0) 
                        {
                            appsMutedByScript[pid] := true
                        }
                    }
                } 
                else 
                {
                    if (appsMutedByScript.HasKey(pid)) 
                    {
                        hr_unmute := DllCall(NumGet(NumGet(pSimpleAudioVolume+0) + 5*A_PtrSize), "Ptr", pSimpleAudioVolume, "Int", 0, "Ptr", 0)
                        if (hr_unmute = 0) 
                        {
                             appsMutedByScript.Delete(pid)
                        }
                    }
                }
                ObjRelease(pSimpleAudioVolume)
            }
        }
        ObjRelease(pSessionControl2)
    }

    ObjRelease(pSessionEnumerator)
}

AppVol(Target := "A", Level := 0) 
{
    if (Target ~= "^[-+]?\d+$") 
    {
        Level := Target
        Target := "A"
    } 
    else if (SubStr(Target, -3) = ".exe") 
    {
        Target := "ahk_exe " Target
    }
    
    hw := A_DetectHiddenWindows
    DetectHiddenWindows, On
    WinGet, appName, ProcessName, %Target%
    DetectHiddenWindows, %hw%
    
    if (appName = "") 
    {
        throw Exception("Target not found.", -1, Target)
    }
    
    VarSetCapacity(GUID, 16, 0)
    DllCall("ole32\CLSIDFromString", "Str", "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}", "Ptr", &GUID)
    IMMDeviceEnumerator := ComObjCreate("{BCDE0395-E52F-467C-8E3D-C4579291692E}", "{A95664D2-9614-4F35-A746-DE8DB63617E6}")
    DllCall(NumGet(NumGet(IMMDeviceEnumerator + 0) + 4 * A_PtrSize), "Ptr", IMMDeviceEnumerator, "UInt", 0, "UInt", 1, "Ptr*", IMMDevice := 0)
    ObjRelease(IMMDeviceEnumerator)
    DllCall(NumGet(NumGet(IMMDevice + 0) + 3 * A_PtrSize), "Ptr", IMMDevice, "Ptr", &GUID, "UInt", 23, "Ptr", 0, "Ptr*", IAudioSessionManager2 := 0)
    ObjRelease(IMMDevice)
    DllCall(NumGet(NumGet(IAudioSessionManager2 + 0) + 5 * A_PtrSize), "Ptr", IAudioSessionManager2, "Ptr*", IAudioSessionEnumerator := 0) || DllCall("SetLastError", "UInt", 0)
    ObjRelease(IAudioSessionManager2)
    DllCall(NumGet(NumGet(IAudioSessionEnumerator + 0) + 3 * A_PtrSize), "Ptr", IAudioSessionEnumerator, "UInt*", cSessions := 0)
    
    Loop, %cSessions%
    {
        DllCall(NumGet(NumGet(IAudioSessionEnumerator + 0) + 4 * A_PtrSize), "Ptr", IAudioSessionEnumerator, "Int", A_Index - 1, "Ptr*", IAudioSessionControl := 0)
        IAudioSessionControl2 := ComObjQuery(IAudioSessionControl, "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}")
        ObjRelease(IAudioSessionControl)
        DllCall(NumGet(NumGet(IAudioSessionControl2 + 0) + 14 * A_PtrSize), "Ptr", IAudioSessionControl2, "UInt*", pid := 0)
        
        if (ProcessGetName(pid) != appName) 
        {
            Continue
        }
        
        ISimpleAudioVolume := ComObjQuery(IAudioSessionControl2, "{87CE5498-68D6-44E5-9215-6DA47EF883D8}")
        DllCall(NumGet(NumGet(ISimpleAudioVolume + 0) + 6 * A_PtrSize), "Ptr", ISimpleAudioVolume, "Int*", isMuted := 0)
        
        if (isMuted || !Level) 
        {
            DllCall(NumGet(NumGet(ISimpleAudioVolume + 0) + 5 * A_PtrSize), "Ptr", ISimpleAudioVolume, "Int", !isMuted, "Ptr", 0)
        }
        
        if (Level) 
        {
            DllCall(NumGet(NumGet(ISimpleAudioVolume + 0) + 4 * A_PtrSize), "Ptr", ISimpleAudioVolume, "Float*", levelOld := 0)
            
            if (Level ~= "^[-+]") 
            {
                levelNew := Max(0.0, Min(1.0, levelOld + (Level / 100)))
            } 
            else 
            {
                levelNew := Level / 100
            }
            
            if (levelNew != levelOld) 
            {
                DllCall(NumGet(NumGet(ISimpleAudioVolume + 0) + 3 * A_PtrSize), "Ptr", ISimpleAudioVolume, "Float", levelNew, "Ptr", 0)
            }
        }
        
        ObjRelease(ISimpleAudioVolume)
    }
    
    return (IsSet(levelOld) ? Round(levelOld * 100) : -1)
}

ProcessGetName(Pid) 
{
    static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
    
    hProcess := DllCall("OpenProcess", "UInt", PROCESS_QUERY_LIMITED_INFORMATION, "Int", false, "UInt", Pid, "Ptr")
    if (!hProcess) 
    {
        return ""
    }

    VarSetCapacity(processName, 1024 * (A_IsUnicode ? 2 : 1), 0)
    size := 1024
    if (DllCall("Kernel32\QueryFullProcessImageName", "Ptr", hProcess, "UInt", 0, "Ptr", &processName, "UInt*", size)) 
    {
        DllCall("CloseHandle", "Ptr", hProcess)
        name := StrGet(&processName)
        SplitPath, name, nameOnly
        return nameOnly
    } 
    else 
    {
        VarSetCapacity(moduleName, 1024 * (A_IsUnicode ? 2 : 1), 0)
        if (DllCall("psapi\GetModuleBaseName", "Ptr", hProcess, "Ptr", 0, "Ptr", &moduleName, "UInt", 1024)) 
        {
             DllCall("CloseHandle", "Ptr", hProcess)
             return StrGet(&moduleName)
        }
    }
    
    DllCall("CloseHandle", "Ptr", hProcess)
    return ""
}

OnExit, UnmuteAllTrackedApps
UnmuteAllTrackedApps:
    UpdateOtherAppsMuteState(false, 0)
    ExitApp