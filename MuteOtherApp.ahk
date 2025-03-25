#Requires AutoHotkey v1.1
#SingleInstance Force
#Persistent
SetBatchLines, -1

global targetGameProcessName := "osu!.exe"
global isGamePreviouslyActive := false
global appsMutedByScript := {}

CheckGameState()

SetTimer, CheckGameState, 1000
~LWin::
~RWin::
~Tab::
    SetTimer, CheckGameState, -250
return

CheckGameState() {
    global targetGameProcessName, isGamePreviouslyActive, appsMutedByScript

    Process, Exist, % targetGameProcessName
    targetGamePid := ErrorLevel
    if (!targetGamePid) {
        if (isGamePreviouslyActive) {
            UpdateOtherAppsMuteState(false, 0)
            isGamePreviouslyActive := false
        }
        Return
    }

    isGameCurrentlyActive := WinActive("ahk_exe " . targetGameProcessName)

    if (isGameCurrentlyActive == isGamePreviouslyActive) {
        Return
    }

    UpdateOtherAppsMuteState(isGameCurrentlyActive, targetGamePid)

    isGamePreviouslyActive := isGameCurrentlyActive
}

UpdateOtherAppsMuteState(muteOthers, targetGamePid) {
    global targetGameProcessName, appsMutedByScript

    static IID_IAudioSessionManager2 := "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}"
        , IID_IAudioSessionEnumerator := ""
        , IID_IAudioSessionControl := ""
        , IID_IAudioSessionControl2 := "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}"
        , IID_ISimpleAudioVolume := "{87CE5498-68D6-44E5-9215-6DA47EF883D8}"
        , CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
        , IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"

    VarSetCapacity(GUID_IAudioSessionManager2, 16)
    DllCall("ole32\CLSIDFromString", "WStr", IID_IAudioSessionManager2, "Ptr", &GUID_IAudioSessionManager2)

    IMMDeviceEnumerator := ComObjCreate(CLSID_MMDeviceEnumerator, IID_IMMDeviceEnumerator)
    if (!IMMDeviceEnumerator) {
        OutputDebug, Failed to create IMMDeviceEnumerator
        Return
    }

    hr := DllCall(NumGet(NumGet(IMMDeviceEnumerator+0) + 4*A_PtrSize), "Ptr", IMMDeviceEnumerator, "Int", 0, "Int", 1, "Ptr*", pDevice := 0)
    ObjRelease(IMMDeviceEnumerator)
    if (hr != 0 || !pDevice) {
        OutputDebug, Failed to get default audio device (hr=" hr ")
        Return
    }

    hr := DllCall(NumGet(NumGet(pDevice+0) + 3*A_PtrSize), "Ptr", pDevice, "Ptr", &GUID_IAudioSessionManager2, "UInt", 0x17, "Ptr", 0, "Ptr*", pSessionManager := 0)
    ObjRelease(pDevice)
    if (hr != 0 || !pSessionManager) {
        OutputDebug, Failed to activate IAudioSessionManager2 (hr=" hr ")
        Return
    }

    hr := DllCall(NumGet(NumGet(pSessionManager+0) + 5*A_PtrSize), "Ptr", pSessionManager, "Ptr*", pSessionEnumerator := 0)
    ObjRelease(pSessionManager)
    if (hr != 0 || !pSessionEnumerator) {
        OutputDebug, Failed to get session enumerator (hr=" hr ")
        Return
    }

    hr := DllCall(NumGet(NumGet(pSessionEnumerator+0) + 3*A_PtrSize), "Ptr", pSessionEnumerator, "Int*", sessionCount := 0)
    if (hr != 0) {
        OutputDebug, Failed to get session count (hr=" hr ")
        ObjRelease(pSessionEnumerator)
        Return
    }

    Loop, % sessionCount
    {
        hr := DllCall(NumGet(NumGet(pSessionEnumerator+0) + 4*A_PtrSize), "Ptr", pSessionEnumerator, "Int", A_Index-1, "Ptr*", pSessionControl := 0)
        if (hr != 0 || !pSessionControl) {
            Continue
        }

        pSessionControl2 := ComObjQuery(pSessionControl, IID_IAudioSessionControl2)
        ObjRelease(pSessionControl)
        if (!pSessionControl2) {
            Continue
        }

        hr := DllCall(NumGet(NumGet(pSessionControl2+0) + 14*A_PtrSize), "Ptr", pSessionControl2, "UInt*", pid := 0)
        if (hr != 0 || pid = 0) {
            ObjRelease(pSessionControl2)
            Continue
        }

        if (pid != targetGamePid)
        {
            pSimpleAudioVolume := ComObjQuery(pSessionControl2, IID_ISimpleAudioVolume)
            if (pSimpleAudioVolume) {
                if (muteOthers) {
                    hr := DllCall(NumGet(NumGet(pSimpleAudioVolume+0) + 6*A_PtrSize), "Ptr", pSimpleAudioVolume, "Int*", currentMuteState := 0)
                    if (hr = 0 && currentMuteState = 0) {
                        hr_mute := DllCall(NumGet(NumGet(pSimpleAudioVolume+0) + 5*A_PtrSize), "Ptr", pSimpleAudioVolume, "Int", 1, "Ptr", 0)
                        if (hr_mute = 0) {
                            appsMutedByScript[pid] := true
                        }
                    }
                } else {
                    if (appsMutedByScript.HasKey(pid)) {
                        hr_unmute := DllCall(NumGet(NumGet(pSimpleAudioVolume+0) + 5*A_PtrSize), "Ptr", pSimpleAudioVolume, "Int", 0, "Ptr", 0)
                        if (hr_unmute = 0) {
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

ProcessGetName(Pid) {
    static PROCESS_QUERY_LIMITED_INFORMATION := 0x1000
    
    hProcess := DllCall("OpenProcess", "UInt", PROCESS_QUERY_LIMITED_INFORMATION, "Int", false, "UInt", Pid, "Ptr")
    if (!hProcess) {
        return ""
    }

    VarSetCapacity(processName, 1024 * (A_IsUnicode ? 2 : 1), 0)
    size := 1024
    if (DllCall("Kernel32\QueryFullProcessImageName", "Ptr", hProcess, "UInt", 0, "Ptr", &processName, "UInt*", size)) {
        DllCall("CloseHandle", "Ptr", hProcess)
        name := StrGet(&processName)
        SplitPath, name, nameOnly
        Return nameOnly
    } else {
        VarSetCapacity(moduleName, 1024 * (A_IsUnicode ? 2 : 1), 0)
        if (DllCall("psapi\GetModuleBaseName", "Ptr", hProcess, "Ptr", 0, "Ptr", &moduleName, "UInt", 1024)) {
             DllCall("CloseHandle", "Ptr", hProcess)
             Return StrGet(&moduleName)
        }
    }
    
    DllCall("CloseHandle", "Ptr", hProcess)
    Return ""
}

OnExit, UnmuteAllTrackedApps
UnmuteAllTrackedApps:
    UpdateOtherAppsMuteState(false, 0)
    ExitApp