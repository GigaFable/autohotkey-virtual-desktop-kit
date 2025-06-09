#Requires AutoHotkey v2.0

global lastFocused := Map()

; === Load DLL and get function pointers ===
vda := DllCall("LoadLibrary", "Str", "VirtualDesktopAccessor.dll", "Ptr")

global GoToDesktopNumber       := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GoToDesktopNumber", "Ptr")
global GetDesktopCount         := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GetDesktopCount", "Ptr")
global CreateDesktop           := DllCall("GetProcAddress", "Ptr", vda, "AStr", "CreateDesktop", "Ptr")
global MoveWindowToDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "MoveWindowToDesktopNumber", "Ptr")
global GetWindowDesktopNumber  := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GetWindowDesktopNumber", "Ptr")
global GetCurrentDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GetCurrentDesktopNumber", "Ptr")

if (!GoToDesktopNumber || !GetDesktopCount || !CreateDesktop || !MoveWindowToDesktopNumber || !GetWindowDesktopNumber || !GetCurrentDesktopNumber) {
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
    target := index - 1
    DllCall(GoToDesktopNumber, "Int", index - 1, "Cdecl Int")

    Sleep 200

    if lastFocused.Has(index) {
        hwnd := lastFocused[index]
        if WinExist("ahk_id " hwnd)
        {
            currentDesktop := DllCall(GetWindowDesktopNumber, "Ptr", hwnd, "Cdecl Int")
            if (currentDesktop = index - 1)  ; DLL uses 0-based indexes
                WinActivate("ahk_id " hwnd)
        }
    }

    if lastFocused.Has(index) {
        hwnd := lastFocused[index]
        ; Validate it's still on that desktop and exists
        if WinExist("ahk_id " hwnd)
        {
            thisDesktop := DllCall(GetWindowDesktopNumber, "Ptr", hwnd, "Cdecl Int")
            If (thisDesktop = index - 1)
                WinActivate("ahk_id " hwnd)
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