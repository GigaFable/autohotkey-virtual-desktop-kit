# AutoHotkey Virtual Desktop Kit

A two-part utility for mastering Windows virtual desktops with AutoHotkey v2.

---

## 🔧 What's Included

### 1. `Windows Desktop Hotkeys.ahk`

Provides powerful hotkeys for manual control of virtual desktops:

- `Win + 1..0`: Switch to desktop 1–10
- `Win + Shift + 1..0`: Move the active window to desktop 1–10
- Automatically creates missing desktops as needed
- Powered by `VirtualDesktopAccessor.dll`
- Unpin all items from the taskbar to stop windows using the same keys

### 2. `App to Desktop Mapper.ahk`

Automatically moves specific apps to predefined desktops:

- Detects windows based on `exe` and optional window title regex
- Configurable via `desktop-rules.json`
- Runs quietly in the background and polls every 250ms
- Includes live reload (`Ctrl + Alt + R`)
- Dynamically re-applies rules when windows reopen

---

## 📂 Folder Structure

```
auto-hotkey-virtual-desktop-kit/
│
├─ App to Desktop Mapper.ahk ; Auto-placement of apps on desktops
├─ Windows Desktop Hotkeys.ahk ; Win+number and Win+Shift+number shortcuts
├─ desktop-rules.json ; User-editable config for app mapping
└─ VirtualDesktopAccessor.dll ; Required native DLL (get from Ciantic's repo)
```

---

## 🧠 Configuration

Edit `desktop-rules.json` to control automatic window assignment:

[
{ "exe": "brave.exe", "title": "^Titan", "desktop": 4 },
{ "exe": "brave.exe", "desktop": 1 },
{ "exe": "explorer.exe", "desktop": 2 },
{ "exe": "code.exe", "desktop": 3 },
{ "exe": "discord.exe", "desktop": 5 }
]

- `exe`: Required. The process name (case-insensitive)
- `title`: Optional. A regular expression to match the window title
- `desktop`: Required. The virtual desktop number (1-based)

💡 First matching rule wins — later entries are ignored if matched earlier.

---

## 🔄 Hotkeys in `App to Desktop Mapper.ahk`

| Hotkey           | Action                                         |
| ---------------- | ---------------------------------------------- |
| Ctrl + Alt + R   | Reload `desktop-rules.json` and re-apply rules |
| Ctrl + Alt + Esc | Exit the script                                |

---

## 🧰 Requirements

- Windows 10/11 with virtual desktops
- AutoHotkey v2
- [VirtualDesktopAccessor.dll](https://github.com/Ciantic/VirtualDesktopAccessor)

> Place `VirtualDesktopAccessor.dll` in the same folder as the scripts.

---

## 📜 License & Attribution

- Created mostly by [ChatGPT](https://openai.com/chatgpt) with love and lo-fi.
- `VirtualDesktopAccessor.dll` by [Ciantic](https://github.com/Ciantic/VirtualDesktopAccessor) (MIT License)
- JSON parsing logic based on simplified public domain AHK v2 examples

This kit is licensed under the MIT License — use it freely, with attribution.
