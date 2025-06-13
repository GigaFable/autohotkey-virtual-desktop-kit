#Requires AutoHotkey v2.0

global appsToDesktops := []

; --- JSON loader (AHK v2 compatible) ---
jxon_load(&src) {
    static NULL := "", WS := A_Space A_Tab "`r`n"
    i := 1
    return parse_value()

    parse_value() {
        ch := substr(src, i, 1)
        while instr(WS, ch) {
            i++
            ch := substr(src, i, 1)
        }
        if ch = "{" {
            i++
            obj := Map()
            while true {
                ch := substr(src, i, 1)
                while instr(WS, ch) {
                    i++
                    ch := substr(src, i, 1)
                }
                if ch = "}" {
                    i++
                    return obj
                }
                key := parse_value()
                ch := substr(src, i, 1)
                while instr(WS, ch) {
                    i++
                    ch := substr(src, i, 1)
                }
                if ch != ":" {
                    throw Error("Expected ':' at position " i)
                }
                i++
                val := parse_value()
                obj[key] := val
                ch := substr(src, i, 1)
                while instr(WS, ch) {
                    i++
                    ch := substr(src, i, 1)
                }
                if ch = "}" {
                    i++
                    return obj
                } else if ch != "," {
                    throw Error("Expected ',' at position " i)
                }
                i++
            }
        } else if ch = "[" {
            i++
            arr := []
            while true {
                ch := substr(src, i, 1)
                while instr(WS, ch) {
                    i++
                    ch := substr(src, i, 1)
                }
                if ch = "]" {
                    i++
                    return arr
                }
                arr.Push(parse_value())
                ch := substr(src, i, 1)
                while instr(WS, ch) {
                    i++
                    ch := substr(src, i, 1)
                }
                if ch = "]" {
                    i++
                    return arr
                } else if ch != "," {
                    throw Error("Expected ',' at position " i)
                }
                i++
            }
        } else if ch = Chr(34) {
            return parse_string()
        } else if RegExMatch(ch, "^[0-9]") or ch = "-" {
            return parse_number()
        } else if substr(src, i, 4) = "true" {
            i += 4
            return true
        } else if substr(src, i, 5) = "false" {
            i += 5
            return false
        } else if substr(src, i, 4) = "null" {
            i += 4
            return NULL
        } else {
            throw Error("Unexpected character at position " i)
        }
    }

    parse_string() {
        i++  ; skip opening "
        out := ""
        while i <= StrLen(src) {
            ch := substr(src, i, 1)
            if ch = Chr(34) {
                i++
                return out
            } else if ch = "\" {
                i++
                ch2 := substr(src, i, 1)
                if ch2 = "n"
                    out .= "`n"
                else if ch2 = "r"
                    out .= "`r"
                else if ch2 = "t"
                    out .= "`t"
                else if ch2 = Chr(34)
                    out .= Chr(34)
                else if ch2 = "\"
                    out .= "\"
                else
                    out .= ch2
            } else {
                out .= ch
            }
            i++
        }
        throw Error("Unterminated string at position " i)
    }

    parse_number() {
        start := i
        while i <= StrLen(src) && RegExMatch(substr(src, i, 1), "[0-9eE+-.]") {
            i++
        }
        num := substr(src, start, i - start)
        return InStr(num, ".") || InStr(num, "e") || InStr(num, "E") ? num + 0.0 : num + 0
    }
}

; === Load DLL and function pointers ===
vda := DllCall("LoadLibrary", "Str", "VirtualDesktopAccessor.dll", "Ptr")
GoToDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GoToDesktopNumber", "Ptr")
GetDesktopCount := DllCall("GetProcAddress", "Ptr", vda, "AStr", "GetDesktopCount", "Ptr")
CreateDesktop := DllCall("GetProcAddress", "Ptr", vda, "AStr", "CreateDesktop", "Ptr")
MoveWindowToDesktopNumber := DllCall("GetProcAddress", "Ptr", vda, "AStr", "MoveWindowToDesktopNumber", "Ptr")

if (!GoToDesktopNumber || !GetDesktopCount || !CreateDesktop || !MoveWindowToDesktopNumber) {
    MsgBox "❌ One or more required functions could not be loaded from the DLL."
    ExitApp
}

; === App → Desktop rules ===
rulesPath := A_ScriptDir "\desktop-rules.json"
if !FileExist(rulesPath) {
    MsgBox "❌ desktop-rules.json not found."
    ExitApp
}

jsonText := FileRead(rulesPath)
appsToDesktops := jxon_load(&jsonText)

; === Track which windows have already been moved ===
seen := Map()

; === Main monitoring loop ===
SetTimer(WatchWindows, 250)

WatchWindows() {
    global appsToDesktops, seen
    seenHwnds := Map()

    for hwnd in WinGetList() {
        try exe := WinGetProcessName(hwnd)
        catch {
            continue  ; Skip inaccessible window (e.g., admin prompt)
        }

        if !exe
            continue

        exe := StrLower(exe)
        seenHwnds[hwnd] := true

        if !seen.Has(hwnd) {
            title := WinGetTitle(hwnd)

            ; Get window class name
            class := WinGetClass(hwnd)
            if (class = "#32770") { ; Ignore dialog boxes
                seen[hwnd] := true
                continue
            }

            for rule in appsToDesktops {
                if (StrLower(exe) = StrLower(rule["exe"])) {
                    if rule.Has("title") && !RegExMatch(title, rule["title"])
                        continue

                    index := rule["desktop"]
                    EnsureDesktopExists(index)
                    moved := DllCall(MoveWindowToDesktopNumber, "Ptr", hwnd, "Int", index - 1, "Cdecl Int")
                    if (moved) {
                        seen[hwnd] := true  ; ✅ only mark as seen if successful
                    }
                    break
                }
            }
        }
    }

    ; Remove any stale hwnds from the seen map
    for hwnd in seen {
        if !seenHwnds.Has(hwnd)
            seen.Delete(hwnd)
    }
}

EnsureDesktopExists(index) {
    current := DllCall(GetDesktopCount, "Int")
    while (current < index) {
        DllCall(CreateDesktop, "Int")
        current++
    }
}

; Optional tray tip for testing (can be removed)
TrayTip "Auto desktop assigner is running...", "Press Ctrl+Alt+Esc to exit", 1

; Exit hotkey
^!Esc:: ExitApp

^!r:: { ; Ctrl + Alt + R
    global appsToDesktops
    jsonText := FileRead(rulesPath)
    appsToDesktops := jxon_load(&jsonText)
    seen := Map()
    TrayTip "Reloaded desktop rules", rulesPath, 1
}
