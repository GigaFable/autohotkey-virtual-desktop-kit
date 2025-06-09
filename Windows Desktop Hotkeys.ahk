#Requires AutoHotkey v2.0

; === Load DLL and get function pointers ===
vda := DllCall("LoadLibrary", "Str", "VirtualDesktopAccessor.dll", "Ptr")
GoToDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GoToDesktopNumber", "Ptr")
GetDesktopCount := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GetDesktopCount", "Ptr")
CreateDesktop := DllCall("GetProcAddress", "Ptr", vda, "AStr", "CreateDesktop", "Ptr")
MoveWindowToDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "MoveWindowToDesktopNumber", "Ptr")

if (!GoToDesktopNumber || !GetDesktopCount || !CreateDesktop || !MoveWindowToDesktopNumber) {
    MsgBox "❌ One or more required functions not found in the DLL."
    ExitApp
}

; === Define the functions FIRST ===
DoSwitchDesktop(index, *) {
    result := DllCall(GoToDesktopNumber, "Int", index - 1, "Int")
    if (result < 0)
        MsgBox "❌ Could not switch to desktop #" index " (error " result ")"
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

; === Register hotkeys AFTER functions exist ===
keyMap := Map("1", 1, "2", 2, "3", 3, "4", 4, "5", 5, "6", 6, "7", 7, "8", 8, "9", 9, "0", 10)

for key, desktopIndex in keyMap {
    Hotkey("#" . key, DoSwitchDesktop.Bind(desktopIndex))
    Hotkey("#+" . key, DoMoveWindowToDesktop.Bind(desktopIndex))
}
