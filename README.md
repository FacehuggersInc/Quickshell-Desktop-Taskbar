# Quickshell — Arch Linux / Hyprland

![Preview](Assets/Previews/preview_A.png)

A Hyprland desktop shell built with Quickshell.

> ⚠️ **Work in Progress**
>
> This config is functional but not finished. Known issues and limitations:
>
> - **Tooltips** don't always align correctly, particularly inside popups and menus
> - **System Tray** icons are rendered as-is — coloured icons won't always match the shell's theme
> - **Workspace switching and window hiding** are imperfect — behaviour can be inconsistent depending on the app
> - **Widgets are static** — the bar layout is hardcoded in `MainWindow.qml`. There is currently no way to add, remove, or reorder widgets from `config.json` alone
> - **Missing edge cases** — there are interactions and menu states that have not been fully accounted for. Some flows may behave unexpectedly or not work at all in certain situations
> - **QoL settings are incomplete** — many things that would be useful to configure from the settings panel are not yet exposed there and require editing the config or source directly

---

 Requires a **Wayland session** — does not work under X11.

---

## 1. Dependencies

**All of the following are required to use this config as-is.** If you want to skip any group you will need to remove or replace the relevant commands in `config.json` under `commands`, or edit the QML source directly for anything hardcoded.

**Core — required to run the shell:**
```bash
sudo pacman -S quickshell python \
    qt6-base qt6-declarative qt6-wayland qt6-tools
```

**Wallpaper — only needed if `wallpapers.cycling` is `true` in your config. `awww` is the default but any wallpaper tool can be used by changing `commands.wallpaper_set`:**
```bash
sudo pacman -S awww
```

**Audio — required for volume, media controls, and the audio popup:**
```bash
sudo pacman -S pipewire wireplumber alsa-utils playerctl
```

**Bluetooth — required for the bluetooth popup:**
```bash
sudo pacman -S bluez bluez-utils bluez-plugins
```

**Display brightness — required for DDC brightness sliders:**
```bash
sudo pacman -S ddcutil
```

**USB automounting — required for USB quick access:**
```bash
sudo pacman -S udisks2
```

**Network — required for the network widget:**
```bash
sudo pacman -S networkmanager
```

**Notifications — required for toast popups:**
```bash
sudo pacman -S libnotify
```

**Apps used by default commands** — these match the defaults in `config.json` but can be swapped for alternatives:
```bash
sudo pacman -S nautilus ghostty hyprpicker
sudo pacman -S grim slurp wl-clipboard jq libnotify
yay -S hyprshot
```

**Wayland/Hyprland integration:**
```bash
sudo pacman -S hyprland xdg-desktop-portal-hyprland
```

**Python packages — required for background operations:**
```bash
pip install rapidfuzz colormath pillow numpy --break-system-packages
```

> **Install order matters:**
> 1. Install system packages via `pacman` first
> 2. Enable services before adding user to groups
> 3. Add user to groups and **log out/in** before running anything that needs them (DDC, bluetooth, USB)
> 4. Install Python packages after Python is installed
> 5. `awww` daemon must be running before Quickshell starts — add `exec-once = awww-daemon` to your Hyprland config. Without this wallpapers will silently do nothing
> 6. Reboot after adding `i2c-dev` to modules — `modprobe` is a temporary fix until reboot

---

## 2. Services

```bash
sudo systemctl enable --now bluetooth NetworkManager udisks2
```

**Bluetooth battery** — add to `/etc/bluetooth/main.conf` under `[General]`:
```ini
Experimental=true
```

**DDC brightness** — create `/etc/modules-load.d/i2c.conf`:
```
i2c-dev
```
Then reboot or `sudo modprobe i2c-dev`.

---

## 3. User Groups

```bash
sudo usermod -aG video storage i2c bluetooth $USER
```

Log out and back in after.

---

## 4. Installation

**Clone the config** — this places the shell config directly where Quickshell expects it:

```bash
git clone https://github.com/FacehuggersInc/Quickshell-Desktop-Taskbar.git ~/.config/quickshell
```

**Create your `config.json`** — the shell will not start without it. Create it manually at `~/.config/quickshell/config.json` using the [Configuration](#7-configuration) section as a reference. At minimum you need `iconsPath`, `fontFamily`, `theme`, and `commands.terminal`. `displays` and wallpaper keys are only needed if `wallpapers.cycling` is `true` — see the [Configuration](#7-configuration) section for what is truly required.


**Start your wallpaper daemon before Quickshell** — only needed if `wallpapers.cycling` is `true`. If using `awww` add this to your `~/.config/hypr/hyprland.conf`. Swap `awww-daemon` for whatever daemon your chosen tool requires, or skip this entirely if you are not using wallpaper cycling:

```
exec-once = awww-daemon
exec-once = quickshell
```

> **`theme.py` must be present** in `~/.config/quickshell/Scripts/` alongside `utill.py`. It is included in the repo — if it is missing every `utill.py` call will crash and the shell will not function.

---

## 5. Icons

Icons are hand-picked from [Google Material Icons](https://fonts.google.com/icons) and saved as PNG. They are not always named to match their Material name — some are renamed to fit the context they're used in based on personal preference.

Place all icons in the directory set as `iconsPath`. The path must end with a trailing `/`. Required names:

```
add                 alarm               apps
audio_adjust        backlight_high      backlight_low
backlight_off       bluetooth           bluetooth_connected
bluetooth_disabled  bluetooth_searching brightness
calendar_add        calendar_edit       calendar_event
calendar_month      calendar_today      check
close               copy_content        dark_mode
delete              download            ethernet
filter              filter_off          hide
history             home                light_mode
lock                masked              masked_add
media_input         media_output        microphone
microphone_alert    microphone_mute     music_add
music_album         music_artist        music_note
music_note_single   music_off           music_pause
music_play          music_prev          music_queue
music_resume        music_skip          notify
notify_unread       open_app            open_folder
pin                 refresh             restart
screenshot          search              settings
show                stop                sync
terminal            unpin               upload
volume_max          volume_med          volume_min
volume_mute         vpn                 wallpaper
wifi_max            wifi_med            wifi_min
wifi_off            wired
```

All icons are `.png`.

---

## 6. Python Utility (`utill.py`)

The shell depends heavily on `Scripts/utill.py`. Almost every background operation — from fetching active windows to setting brightness to picking wallpapers — calls this file via a subprocess. It is **not optional**.

The file is called by Quickshell like this:

```bash
python3 ~/.config/quickshell/Scripts/utill.py --functionname arg1 arg2
```

The table below documents what the shell is actually doing in the background. These are not user-facing commands — they run automatically and the results are parsed by the QML layer:

| Function | What the shell uses it for |
|---|---|
| `--getcurrentplaying` | Polls MPRIS every 300ms when the audio popup is open — returns title, artist, album, art URL, source app and playback status |
| `--getactiveapplications` | Polls every 650ms to build the app bar — returns all open windows with their class, PID, command, workspace and title |
| `--getappicons` | Called when an app class name has no cached icon — fuzzy-matches the class name against icon files on disk and caches the result (class name → icon path) in `.icon-path-cache` |
| `--getdesktopapps` | Called once when the "Add App" window opens — parses all `.desktop` files including Flatpak |
| `--getnetworkinfo` | Polls every 1.5s when the network popup is open — samples `/proc/net/dev` twice 0.5s apart to calculate live speeds |
| `--getaudiodevices` | Called when the audio popup opens — lists input and output devices via `wpctl status` |
| `--getcommandhistory` | Called when the Command History popup opens — reads `~/.bash_history`, `~/.zsh_history` and `~/.local/share/fish/fish_history`. **Filters heavily** — strips sudo, package managers, git, file ops, shell builtins and any single-word command. The intent is app launches and custom scripts only. If a command you expect to see is missing it is almost certainly being filtered. Edit `FILTER_PREFIXES` in `utill.py` to loosen this. |
| `--randomfile` | Called on each wallpaper cycle — picks one random file per display from the configured folder |
| `--smartcrop` | Called before setting a wallpaper on a vertical monitor — analyses column variance to find the most visually interesting horizontal region and crops to it. Returns the original path unchanged if the image ratio is already close enough or if variance is too uniform |
| `--getmonitorres` | Called once on startup — reads monitor dimensions and transform from `hyprctl monitors -j` to determine which displays are vertical |
| `--ddcdetect` | Called when the settings panel opens — lists DDC-capable displays via `ddcutil detect` |
| `--ddcgetbrightness` | Called when the settings panel opens — reads current brightness for each detected display |
| `--ddcsetbrightness` | Called on slider release — sets brightness on a specific display number via `ddcutil setvcp 10` |
| `--btstate` | Polls every 2s in the bluetooth widget — returns adapter power, scanning and discoverable state |
| `--btdevices` | Polls when the bluetooth popup is open — lists paired devices with alias, connection status and battery percentage |
| `--btscan` | Called when the scan button is pressed — starts a 10s `bluetoothctl` scan in the background |
| `--btscanresults` | Polls while scanning — returns discovered devices not already paired |
| `--btconnect` | Called on connect button press — connects by MAC and sends a `notify-send` notification |
| `--btdisconnect` | Called on disconnect — disconnects by MAC |
| `--btpair` | Called on pair button press — trusts, pairs and connects a new device |
| `--btforget` | Called on forget — removes a device from paired list |
| `--btpower` | Called on the power toggle — toggles or sets adapter power state |
| `--addcolor` | Called after `hyprpicker` exits — saves the picked hex color to `colorHistory` in `config.json`, keeps last 10 |
| `--getcolors` | Called when the color history popup opens |
| `--clearcolors` | Called on the clear button in the color history popup |
| `--usbmountcheck` | Called when a USB hotplug event fires — checks if the partition is mounted and mounts it via `udisksctl` if not |
| `--generatetheme` | Called when `autoTheme` is enabled — builds a full color theme from seed colors extracted from the current wallpaper |
| `--getdisplays` | Called once on startup — reads all monitors from `hyprctl monitors -j`, sorts left-to-right by x position, and auto-updates `settings.displays` if the connected monitors have changed |
| `--ddcmapping` | Called once on startup — maps DDC display numbers to connector names so brightness commands target the correct physical monitor |

**Python packages required** by this file:

- `rapidfuzz` — fuzzy icon matching
- `pillow` + `numpy` — smart crop saliency detection
- `colormath` — theme generation

If any package is missing the affected features will silently fail or return empty results.

---

## 7. Configuration

If you have not yet created `config.json` see [Installation](#4-installation) above. All available keys and what they do:

```json
{
    "displays":            ["DP-1", "HDMI-A-1"], // auto-populated from Hyprland on startup
    "primaryDisplayIndex": 0,                    // auto-set to focused monitor on first run — change in Display settings
    "wallpapers": {
        "cycling":            true,              // set false to skip all wallpaper handling
        "day":        "/path/to/day/",           // required if cycling — trailing slash needed
        "night":      "/path/to/night/",         // required if cycling — trailing slash needed
        "interval":   600000,                    // ms between wallpaper changes
        "randomWallpaperPerDisplay": true,       // different wallpaper per display
        "smartCrop":      false,                 // auto-crop for vertical monitors
        "portraitFolder": "",                    // optional — portrait wallpapers preferred on vertical monitors
        "wallpaperMode":  0,                     // 0=auto, 1=force day, 2=force night
        "autoTheme":      false,                 // generate theme from current wallpaper
        "darkModeHours": {
            "at":     21,                        // hour to switch to night (24h)
            "before": 6                          // hour to switch to day (24h)
        }
    },
    "variables": {
        "home":    "/home/USER",                 // reference as {v-home} in commands below
        "editor":  "code"                        // reference as {v-editor} — swap to change editor everywhere
    },
    "commands": {
        "terminal":          "ghostty",          // required
        "terminal_run":      "ghostty -e bash -c", // required
        "wallpaper_set":     "awww img -o {display} {wallpaper}", // required if cycling
        "screenshot":        "hyprshot -m region --clipboard-only -z",
        "files":             "nautilus",
        "files_open":        "nautilus {path}",
        "colorpicker":       "hyprpicker",
        "editor":            "{v-editor}",
        "config_json":       "{v-editor} {v-home}/.config/quickshell/config.json",
        "config_main":       "{v-editor} {v-home}/.config/",
        "config_hypr":       "{v-editor} {v-home}/.config/hypr/",
        "config_quickshell": "{v-editor} {v-home}/.config/quickshell/",
        "lock":              "loginctl lock-session",
        "suspend":           "systemctl suspend",
        "reboot":            "systemctl reboot",
        "poweroff":          "systemctl poweroff",
        "logout":            "bash -c command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit",
        "restart_shell":     "{v-home}/.config/quickshell/Scripts/restart.sh",
        "hypr_reload":       "hyprctl reload"
    },
    "iconsPath":       "/path/to/icons/",        // required — trailing slash needed
    "fontFamily":      "JetBrainsMono",          // required
    "dateTimeFormat":  "%I:%M%p %a, %b %d",      // strftime format for the clock widget
    "theme": {
        "background": "#19090e",                 // required
        "surface":    "#2b1e22",                 // required
        "primary":    "#6b5d62",                 // required
        "secondary":  "#55474c",
        "text":       "#e7d9df"                  // required
    },

    "colorHistory": [],
    "forceDarkMode":   false,
    "theater": {
        "enabled":        false,         // reset to false on startup automatically
        "primaryDisplay": null,          // index into displays — defaults to primaryDisplayIndex if null
        "dimBrightness":  10,            // brightness % for non-primary displays in theater mode (0-50)
        "wallpaper":      ""             // path to wallpaper set on non-primary displays when active
    },
    "launcherflags": {
        "maxOptions":    3,
        "filters":       {},   // class: [args to strip]
        "setOptions":    {},
        "lockOptions":   [],   // class names — never auto-update options
        "ignoreOptions": []    // class names — never show options
    },
    "launchers": []
}
```

Replace `USER` with your username and all paths with your actual locations.

**`variables`** — optional key/value pairs you can reference in any command using `{v-varname}`:

```json
"variables": {
    "user":        "fach",
    "config":      "/home/fach/.config",
    "scripts":     "/home/fach/.config/quickshell/Scripts",
    "wallpapers":  "/home/fach/Pictures/Wallpapers"
}
```

Then in `commands`:
```json
"config_hypr":       "code {v-config}/hypr/",
"config_quickshell": "code {v-config}/quickshell/",
"restart_shell":     "{v-scripts}/restart.sh"
```

Any `{v-key}` that doesn't match a key in `variables` is left as-is.

> **`{placeholder}` substitution** — any command containing `{placeholder}` has that token replaced at runtime before the command is executed:
> - `{display}` — replaced with the connector name e.g. `DP-1`
> - `{wallpaper}` — replaced with the full path to the wallpaper file
> - `{path}` — replaced with a file or folder path (used by `files_open`)
>
> You can use these in any command value. Custom placeholders are also supported — add `{anything}` to a command string and pass the value when calling `root.cmd("key", {"anything": "value"})` from QML.

> **Other commands used internally** — the following are called directly in QML without going through the `commands` map and cannot be overridden from config:
> - `hyprctl dispatch workspace {n}` — workspace switching
> - `hyprctl dispatch movetoworkspacesilent` — sending windows between workspaces
> - `hyprctl keyword` — toggling animations and blur
> - `wpctl set-volume` / `wpctl set-default` — audio control
> - `playerctl previous/play-pause/next` — media controls
> - `bluetoothctl` — all bluetooth operations (via `utill.py`)
> - `ddcutil` — all brightness operations (via `utill.py`)
> - `udisksctl mount` — USB mounting (via `utill.py`)
> - `notify-send` — desktop notifications
> - `kill {pid}` — force-closing apps
> - `rm -f` — cleaning up smart crop temp files

---

## 8. Theme

Theme colors are set manually in `config.json` under the `theme` key. If you want to generate a theme from seed colors, `utill.py` includes a `--generatetheme` function that builds a full theme from a set of hex colors:

```bash
python3 ~/.config/quickshell/Scripts/utill.py --generatetheme dark #19090e #6b5d62
```

**Auto theming** — setting `"autoTheme": true` in `wallpapers` enables automatic theme generation. Every time the wallpaper changes, colors are sampled from it and the theme is updated and saved to `config.json` automatically.

> **`autoTheme` requires `wallpapers.cycling` to also be `true`.** The theme is generated as a side effect of a wallpaper being set — if cycling is disabled, no wallpaper is ever applied by the shell and `autoTheme` will never fire. The initial theme on startup also depends on cycling running at least once to sample colors. If you want a fixed theme, set `autoTheme: false` and define your colors manually in `config.json` — this works regardless of whether cycling is on or off.

---

## 9. Launchers & Options

Launchers are pinned apps in the app bar. Each launcher maps a window class name to a launch command. All launcher management — window matching, active state, instance tracking, options, masques — is handled entirely by `AppBarWidget`.

> **`name` is the app or package class name** — this is the class name the application registers with the window system (e.g. `code`, `brave-browser`, `org.gnome.Nautilus`). Without a `nickname`, `name` is also what gets displayed in the bar.

```json
"launchers": [
    {
        "name":     "code",
        "nickname": "VS Code",
        "icon":     "/usr/share/icons/Papirus/64x64/apps/code.svg",
        "command":  "/opt/visual-studio-code/code",
        "options":  [
            ["/home/user/project-a"],
            ["/home/user/project-b"],
            ["--new-window"]
        ]
    }
]
```

**Options** are like a Windows Jump List — right-clicking a pinned app shows a menu of launch variants. Each entry in `options` is a list of arguments appended to the launch command when that variant is chosen.

In the example above, right-clicking VS Code shows three entries:
- `code /home/user/project-a`
- `code /home/user/project-b`
- `code --new-window`

**Launcher fields:**

| Field | Required | Description |
|---|---|---|
| `name` | ✔ | App or package class name. `AppBarWidget` uses this to match running windows, track instances, and manage state. Doubles as display name if no `nickname` is set |
| `command` | ✔ | Launch command |
| `icon` | ✔ | Path to icon file |
| `nickname` | — | Display name shown in the bar. Defaults to `name` if omitted |
| `options` | — | List of argument sets for the right-click jump list |
| `masque` | — | Makes another app's windows appear under this pin — `{ "classIncludes": "Electron" }` or `{ "cmdIncludes": "some-process" }` |

**`launcherflags` controls per-launcher behaviour:**

| Flag | Description |
|---|---|
| `lockOptions` | Class names whose options are never auto-updated from running process args |
| `ignoreOptions` | Class names that never show or save options at all |
| `filters` | Args to strip when capturing options — e.g. `{ "org.gnome.Nautilus": ["--gapplication-service"] }` |
| `maxOptions` | Max number of options stored per launcher |

> **Finding the class name** — most native apps use their binary name (e.g. `code`, `ghostty`). Flatpak apps use their full app ID (e.g. `com.discordapp.Discord`). You can confirm it by running `hyprctl clients` while the app is open and checking the `class:` field, or by checking the app's `.desktop` file for `StartupWMClass`.

---

## 10. Pinning Apps

The easiest way to pin an app is to simply open it, then **right-click its icon in the app bar** and select **Pin**. The shell will capture the app's class name, command, and any launch arguments automatically.

> **This is not always accurate.** Some apps launch under a different class name than their executable, spawn child processes with different names, or use wrapper scripts. If a pinned app doesn't launch anything when clicked, or opens under the wrong icon, you may need to manually set the correct `command` in `config.json` or use the **Custom App** form in the Add App menu.

For full control, use the **Add App** button (apps icon, far right of the app bar) which gives you two options:
- **From Installed Apps** — picks from all `.desktop` files on your system
- **Custom App** — manually set the class name, command, icon, and options

---

## 11. Masquing

Masquing lets you make one app's windows appear under a different pinned app's icon. This is useful when an app spawns windows under a class name that doesn't match its launcher — for example a game launcher that opens the actual game under a completely different class, or an Electron app that reports a generic class name.

**How to set a masque:**
1. The app you want to masque **under** must already be pinned
2. Open the app you want to masque
3. Right-click its icon in the app bar
4. Select **Add as Masque...** and choose the pinned app to masque under

From that point on, any window matching that class name will appear under the chosen pin as if it were that app.

To remove a masque, right-click the pinned app and select **Manage Masques** — this lists all masques assigned to that pin and lets you remove them individually.

You can also set a masque upfront when adding a custom app via the **Custom App** form using the **Masque Under** field.

---

## 12. Timers & Reactivity

Most polling uses `Timer` components with fixed intervals. These control how quickly the UI reacts to changes — lower means faster updates but more subprocess calls. **If the default intervals feel too slow or too aggressive for your system, change them directly in the file listed.**

| Feature | Default | File | What it polls |
|---|---|---|---|
| Wallpaper switching | set via config (`interval` key in ms) | `shell.qml` | Cycles to the next wallpaper — controlled by `setWallpaperInterval()` |
| USB hotplug retry | 1500ms | `shell.qml` | Delay before retrying a USB mount check after a hotplug event |
| Active applications (initial) | 10ms | `Objects/Widgets/AppBarWidget.qml` | Fires immediately on startup to build the static app list, then slows down |
| Active applications (polling) | 650ms | `Objects/Widgets/AppBarWidget.qml` | Running windows, active state, instance counts |
| Media metadata | 1000ms | `Objects/Systems/MediaSystem.qml` | Currently playing track, artist, album, status — always polling |
| Media display refresh | 300ms | `Objects/Window/AudioManagementPopup.qml` | Updates the now-playing display in the audio popup (only while popup is open) |
| Notification popup auto-dismiss | 6000ms | `Objects/Window/NotificationPopup.qml` | Auto-closes toast after this time |
| Notifications badge | 500ms | `Objects/Widgets/NotificationsWidget.qml` | Unread count fallback |
| Workspace list | 2000ms | `Objects/Widgets/WorkspaceSwitcherWidget.qml` | All workspaces and window counts |
| Active workspace | 200ms | `Objects/Widgets/WorkspaceSwitcherWidget.qml` | Current workspace highlight |
| Network info | 1500ms | `Objects/Window/NetworkPopup.qml` | Interface, VPN, upload/download (only while popup is open) |
| Bluetooth device list | 3000ms | `Objects/Window/BluetoothPopup.qml` | Paired devices and connection state |
| Bluetooth scan timeout | 12000ms | `Objects/Window/BluetoothPopup.qml` | Stops scanning after this duration |
| USB drives in settings | 3000ms | `Objects/Window/SettingsManagementPopup.qml` | Mounted USB devices (only while popup is open) |
| Brightness debounce | 350ms | `Objects/Window/SettingsManagementPopup.qml` | Delay before sending DDC command after slider release |

---

## 13. First Run

On the first launch `.icon-path-cache` does not exist yet. `AppBarWidget` will call `--getappicons` which walks your icon theme directory and records each icon's name and path — this is a one-time operation and may take a few seconds. Subsequent launches read from the cache and are fast. The cache stores only class name → icon path mappings, not icon image data.

The cache is stored at `~/.config/quickshell/.icon-path-cache`.

---

## 14. Run

```bash
quickshell
```

Add to `~/.config/hypr/hyprland.conf` to start automatically:
```
exec-once = awww-daemon
exec-once = quickshell
```

> `awww-daemon` must be listed **before** `quickshell` so the wallpaper daemon is ready when the shell starts.