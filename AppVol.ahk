#Requires AutoHotkey v1.1

AppVol(Target := "A", Level := 0) {
    if (Target ~= "^[-+]?\d+$") {
        Level := Target
        Target := "A"
    } else if (SubStr(Target, -3) = ".exe") {
        Target := "ahk_exe " Target
    }
    hw := A_DetectHiddenWindows
    DetectHiddenWindows On
    WinGet appName, ProcessName, % Target
    DetectHiddenWindows % hw
    if (appName = "") {
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
    loop % cSessions {
        DllCall(NumGet(NumGet(IAudioSessionEnumerator + 0) + 4 * A_PtrSize), "Ptr", IAudioSessionEnumerator, "Int", A_Index - 1, "Ptr*", IAudioSessionControl := 0)
        IAudioSessionControl2 := ComObjQuery(IAudioSessionControl, "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}")
        ObjRelease(IAudioSessionControl)
        DllCall(NumGet(NumGet(IAudioSessionControl2 + 0) + 14 * A_PtrSize), "Ptr", IAudioSessionControl2, "UInt*", pid := 0)
        if (ProcessGetName(pid) != appName) {
            continue
        }
        ISimpleAudioVolume := ComObjQuery(IAudioSessionControl2, "{87CE5498-68D6-44E5-9215-6DA47EF883D8}")
        DllCall(NumGet(NumGet(ISimpleAudioVolume + 0) + 6 * A_PtrSize), "Ptr", ISimpleAudioVolume, "Int*", isMuted := 0)
        if (isMuted || !Level) {
            DllCall(NumGet(NumGet(ISimpleAudioVolume + 0) + 5 * A_PtrSize), "Ptr", ISimpleAudioVolume, "Int", !isMuted, "Ptr", 0)
        }
        if (Level) {
            DllCall(NumGet(NumGet(ISimpleAudioVolume + 0) + 4 * A_PtrSize), "Ptr", ISimpleAudioVolume, "Float*", levelOld := 0)
            if (Level ~= "^[-+]") {
                levelNew := Max(0.0, Min(1.0, levelOld + (Level / 100)))
            } else {
                levelNew := Level / 100
            }
            if (levelNew != levelOld) {
                DllCall(NumGet(NumGet(ISimpleAudioVolume + 0) + 3 * A_PtrSize), "Ptr", ISimpleAudioVolume, "Float", levelNew, "Ptr", 0)
            }
        }
        ObjRelease(ISimpleAudioVolume)
    }
    return (IsSet(levelOld) ? Round(levelOld * 100) : -1)
}

ProcessGetName(Pid) {
    sz := VarSetCapacity(name, 1024, 0)
    hProc := DllCall("OpenProcess", "UInt", 0x0410, "Int", false, "UInt", Pid, "Ptr")
    if (hProc != 0) {
        DllCall("psapi\GetModuleBaseName", "Ptr", hProc, "Ptr", 0, "Str", name, "UInt", sz)
        DllCall("CloseHandle", "Ptr", hProc)
    }
    VarSetCapacity(name, -1)
    return name
}