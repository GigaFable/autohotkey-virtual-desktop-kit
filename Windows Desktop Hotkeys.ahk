#Requires AutoHotkey v2.0

global lastFocused := Map()

; === Load DLL and get function pointers ===
vda := DllCall("LoadLibrary", "Str", "VirtualDesktopAccessor.dll", "Ptr")

global GoToDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GoToDesktopNumber", "Ptr")
global GetDesktopCount := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GetDesktopCount", "Ptr")
global CreateDesktop := DllCall("GetProcAddress", "Ptr", vda, "AStr", "CreateDesktop", "Ptr")
global MoveWindowToDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "MoveWindowToDesktopNumber", "Ptr")
global GetWindowDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GetWindowDesktopNumber", "Ptr")
global GetCurrentDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GetCurrentDesktopNumber", "Ptr")

if (!GoToDesktopNumber || !GetDesktopCount || !CreateDesktop || !MoveWindowToDesktopNumber || !GetWindowDesktopNumber ||
    !GetCurrentDesktopNumber) {
    MsgBox "❌ One or more required functions not found in the DLL."
    ExitApp
}

SetTimer(TrackLastFocusedWindow, 200)

TrackLastFocusedWindow() {
    static lastSeen := 0
    hwnd := WinActive("A")
    if !hwnd || hwnd = lastSeen
        return

    desktopIndex := DllCall(GetCurrentDesktopNumber, "UInt")
    lastFocused[desktopIndex + 1] := hwnd
    lastSeen := hwnd
}

EnsureDesktopExists(index) {
    count := DllCall(GetDesktopCount, "Cdecl Int")
    while (count < index) {
        result := DllCall(CreateDesktop, "Cdecl Int")
        if (result != 0)
            count += 1
        else
            break  ; Something went wrong
    }
}

; === Define the functions FIRST ===

DoSwitchDesktop(index) {
    EnsureDesktopExists(index)
    DllCall(GoToDesktopNumber, "Int", index - 1, "Cdecl Int")
    Sleep 200  ; allow switch to complete

    hwnd := ""
    if lastFocused.Has(index) {
        hwnd := lastFocused[index]
        if WinExist("ahk_id " hwnd) {
            desktop := DllCall(GetWindowDesktopNumber, "Ptr", hwnd, "Cdecl Int")
            if (desktop = index - 1)
                try {
                    return WinActivate("ahk_id " hwnd)
                } catch {
                    return ; Occasionally caused issues.
                }
        }
    }

    ; No valid last-focused window — fallback to first visible window on this desktop
    for candidate in WinGetList() {
        try {
            if !WinExist("ahk_id " candidate)
                continue
            desktop := DllCall(GetWindowDesktopNumber, "Ptr", candidate, "Cdecl Int")
            if (desktop = index - 1) {
                WinActivate("ahk_id " candidate)
                return
            }
        } catch {
            continue  ; skip inaccessible windows (admin/UAC, etc.)
        }
    }
}

DoMoveWindowToDesktop(index, *) {
    current := DllCall(GetDesktopCount, "Int")
    while (current < index) {
        newRes := DllCall(CreateDesktop, "Int")
        if (newRes < 0) {
            MsgBox "❌ Could not create desktop #" current + 1 " (error " newRes ")"
            return
        }
        current++
    }

    hwnd := WinExist("A")
    result := DllCall(MoveWindowToDesktopNumber, "Ptr", hwnd, "Int", index - 1, "Int")
    if (result < 0)
        MsgBox "❌ Failed to move window to desktop #" index " (error " result ")"
}

MakeSwitchDesktopHandler(index) {
    return (*) => DoSwitchDesktop(index)
}

MakeMoveWindowHandler(index) {
    return (*) => DoMoveWindowToDesktop(index)
}

; === Register hotkeys AFTER functions exist ===
keyMap := Map("1", 1, "2", 2, "3", 3, "4", 4, "5", 5, "6", 6, "7", 7, "8", 8, "9", 9, "0", 10)

for key, desktopIndex in keyMap {
    Hotkey("#" . key, MakeSwitchDesktopHandler(desktopIndex))
    Hotkey("#+" . key, MakeMoveWindowHandler(desktopIndex))
}
