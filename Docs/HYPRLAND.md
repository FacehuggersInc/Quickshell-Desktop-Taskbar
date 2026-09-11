# Hyprland state layer

`Objects/Systems/HyprlandSystem.qml` is a singleton that mirrors Hyprland's
state from the event socket. Nothing in it polls.

Before this, every consumer shelled out to `hyprctl` through `utill.py` on a
timer — the app bar at 650ms, the active workspace at 200ms, the workspace list
at 2s. Each of those spawned a Python interpreter, and the app bar's call also
walked the full process table with `ps -eo pid,args`.

## Where the data comes from

Quickshell's `Quickshell.Hyprland` module keeps `monitors`, `workspaces` and
`toplevels` models fed from socket2, plus `focusedMonitor`, `focusedWorkspace`
and a `rawEvent` signal.

`lastIpcObject` — which is where geometry, class and pid live — does not update
on its own. It only refreshes when the object is fetched again. So the layer
does this on every event:

1. coalesce for 60ms, because one workspace switch emits several events
2. call `refreshMonitors()`, `refreshWorkspaces()`, `refreshToplevels()`
3. wait 90ms for those to land
4. rebuild the snapshots and emit `changed()`

## Properties

| Property | Contents |
|---|---|
| `monitors` | `{name, x, y, w, h, scale, transform, vertical, focused, activeWorkspaceId, activeWorkspaceName}`, sorted left to right, rotation already applied to w/h |
| `workspaces` | `{id, name, special, monitor, windowCount, focused}` |
| `windows` | `{address, pid, appClass, title, monitor, workspaceId, workspaceName, special, x, y, w, h, floating, fullscreen, hidden, activated}` |
| `windowsByAddress` | the same entries keyed by address |
| `focusedMonitor` `focusedWorkspaceId` `activeAddress` | current focus |

`x/y/w/h` on a window are real Hyprland geometry, which is what makes a
true-scale minimap possible rather than an abstract grid.

Lookups: `monitorByName`, `monitorNames`, `windowsOnWorkspace`,
`windowsOnMonitor`, `windowsInClass`, `specialWorkspaces`.

## Dispatch

Every function targets a window by **address**, not pid. A pid cannot
distinguish between two windows of the same application, which is the cause of
the README's long-standing note that window hiding and workspace moves behave
inconsistently depending on the app.

`focusWindow` `closeWindow` `moveWindowToWorkspace` `moveWindowToMonitor`
`switchWorkspace` `swapActiveWorkspaces` `moveWorkspaceToMonitor`
`toggleSpecial` `stashWindow` `setFullscreen`

`swapActiveWorkspaces` and `moveWorkspaceToMonitor` are Hyprland's own
dispatchers — one call, layout preserved. `stashWindow` moves a window to
`special:<bucket>`.

Every dispatch schedules a refresh, since several of them change state without
emitting an event.

### Addresses

Quickshell reports `HyprlandToplevel.address` without the `0x` prefix, but every
Hyprland selector expects it. `normalizeAddress` adds it back, and the snapshot
stores the prefixed form so anything comparing addresses sees one representation.

### Lua config mode

Since 0.55 Hyprland's config can be Lua, and in that mode `hl.dispatch` takes a
dispatcher table from the `hl.dsp` namespace rather than a legacy command
string — `hyprctl dispatch 'movetoworkspacesilent 2,address:0x...'` is rejected
outright. `Hyprland.usingLua` reports which mode is live, and every function
builds both forms.

| Operation | Legacy | Lua |
|---|---|---|
| focus window | `focuswindow <sel>` | `hl.dsp.focus({window="<sel>"})` |
| close window | `closewindow <sel>` | `hl.dsp.window.close({window="<sel>"})` |
| move to workspace | `movetoworkspace[silent] <ws>,<sel>` | `hl.dsp.window.move({workspace="<ws>", follow=<bool>, window="<sel>"})` |
| switch workspace | `workspace <id>` | `hl.dsp.focus({workspace="<id>"})` |
| toggle special | `togglespecialworkspace <name>` | `hl.dsp.workspace.toggle_special("<name>")` |

**Unconfirmed.** `swapActiveWorkspaces` and `moveWorkspaceToMonitor` follow the
same namespace pattern but their Lua forms have not been checked against a
running 0.55. Neither is reached yet — both exist for the workspace overlay.

**Still legacy.** `hypr_set_animations`, `hypr_set_blur` and `hypr_reload` in the
settings panel go through `hyprctl keyword`, not `dispatch`. They may or may not
need updating under a Lua config; they were not touched.

## Migrated

- `WorkspaceSwitcherWidget` — both timers and both `Process` objects removed
- `shell.qml` monitor detection — `getmonitorres` and `getdisplays` no longer run
- `AppBarWidget` — the 650ms poll is gone
- `WorkspaceSendPopup` — reads workspaces from the layer, moves by address

`ddcmapping` still shells out, since ddcutil is not a Hyprland concern.

## The app bar

`getActiveApps` still consumes the same pipe-delimited string the Python helper
used to produce, so only the producer changed. Rewriting 240 lines of masque,
instance and options state as a side effect of this migration was not worth the
risk.

The old producer ran `ps -eo pid,args` over the whole process table, `hyprctl
clients -j`, and an icon resolution pass — every 650ms. The new one reads
windows from the event socket and caches the two things Hyprland does not
expose:

| Cache | Filled by | When |
|---|---|---|
| `iconCache` | `--getappicons` | a class is seen for the first time |
| `commandCache` | `--getcommands` | a pid is seen for the first time |

`--getcommands` reads `/proc/<pid>/cmdline` for the pids asked for. A sync that
finds an unknown pid fetches first and rebuilds on completion, otherwise an app
would be added to the bar with an empty launch command and never pick one up.

Window titles and command lines are stripped of commas before being joined,
since the format is comma-delimited and titles routinely contain them. That was
a latent bug in the old producer too — a comma in a title shifted every field
after it, including the window address.

## Hiding and restoring

`hideInstance` and `showInstance` act on an address. The old `hypr_hide_window`
and `hypr_move_window` commands matched on `pid:`, which cannot pick between two
windows of the same application — the cause of the inconsistent hide and restore
behaviour on browsers and other multi-window apps. `hideInWorkspace(pid)` and
`showInDefault(pid)` are kept as thin wrappers so existing call sites still work.

The `hypr_hide_window`, `hypr_move_window` and `hypr_close_window` command
entries in `config.json` are now unused by the app bar.

---

# Workspace overview

`Objects/Window/WorkspaceOverview/` — a fullscreen layer-shell overlay, not a bar
popup. It takes exclusive keyboard focus while open, dismisses on Escape or a
click outside, and renders on whichever monitor is focused.

| File | Role |
|---|---|
| `WorkspaceOverview.qml` | the overlay window, drag state, hit testing |
| `MonitorTile.qml` | one monitor at its real aspect ratio |
| `WindowTile.qml` | one window, positioned from real geometry |

Each monitor tile shows only its **active** workspace, scaled by
`width / monitor.w`, with every window drawn at its true position and size. So
the tile is a picture of the monitor rather than an abstract arrangement.

## Drag

Window tiles are positioned by binding to Hyprland geometry, so dragging a tile
directly would overwrite `x`/`y` and destroy those bindings permanently. Instead
a ghost rectangle follows the cursor and the drop target is resolved by mapping
the cursor into each monitor tile and testing containment. Nothing about the
real tiles is mutated, and the layout re-derives from the event socket after the
move lands.

A drag starts after 6px of movement, so a click still reads as a click.

## Interactions

| Action | Result |
|---|---|
| click a window | focus it and close the overlay |
| middle click a window | close that window |
| drag a window onto another monitor | move it to that monitor's active workspace |
| click a monitor's background | switch to that workspace |
| Escape, or click outside | dismiss |

## Buckets

Hidden holding areas backed by Hyprland special workspaces, shown as a strip
above the monitors.

A special workspace only exists while it holds a window, so an emptied bucket
would disappear from the strip. The names are therefore kept in `config.json`
under `buckets`, and the strip renders the union of those and any live special
workspace found on the event socket — so a bucket someone created outside the
shell still shows up.

| Action | Result |
|---|---|
| `+` | create the next `stash-N` |
| drag a window onto a bucket | `movetoworkspacesilent special:<name>` |
| drag a window out of a bucket | move to that monitor's active workspace |
| double click a bucket | peek — overlay it onto the focused monitor |
| middle click a bucket | empty it permanently onto the focused monitor |
| right click an empty bucket | remove it |
| hover a bucket | show its contents panel |

Hovering a bucket opens a panel showing it as a monitor: a minimap of the stashed
windows at their real geometry, plus a list of their classes and titles. The
panel renders in the overlay's layer rather than inside the tile, so the strip
does not reflow, and it is suppressed during a drag so it can never sit over a
drop target.

The minimap uses letters, not captures. A stashed window is on an inactive
workspace, so the compositor is not rendering it and `ScreencopyView` has nothing
to read. Getting real thumbnails would mean peeking the bucket to force a render
and capturing during it, which is far too invasive for a hover.

A special workspace lives on one monitor at a time, so its windows share that
monitor's coordinate frame and the panel adopts that monitor's aspect. If the
monitor is gone, it falls back to the bounding box of the windows.

Peek is `hl.dsp.workspace.toggle_special`: one dispatch, reversible, and the
arrangement inside the bucket survives. Toggling again sends the windows back.

A peeked bucket sits **on top of** the real workspace rather than replacing it,
and Hyprland reports it as `specialWorkspace` on the monitor. The tile shows
which monitor it is on and stays accented, the overview no longer closes after a
peek — doing so left nothing to toggle it back off with — and a "hide bucket
showing on screen" button appears while any special is up, so recovery never
depends on finding the right tile.

Empty is a permanent relocation and moves windows one at a time. A single
dispatch that promotes a whole workspace would be better, but on Hyprland 0.56.2
`hl.dsp.workspace.move_to_monitor` is nil and no `swap_active` exists. Hyprland's
source documentation lists `move_to_monitor` under `hl.dsp.workspace`, so that
describes a different commit than 0.56 ships — worth rechecking after an update.

Verified against 0.56.2: `hl.dsp.workspace.toggle_special` is a function,
`hl.dsp.workspace.move_to_monitor` is nil.

## Monitor coordinate spaces

`hyprctl monitors` reports the **physical** mode, while `hyprctl clients`
reports **logical** coordinates. On a scaled display the two differ, and drawing
windows into the physical space makes them occupy only `1/scale` of the tile —
two tiled windows never reach the edges even though they fill the real monitor.
The snapshot divides monitor width and height by `scale` so both live in the
logical space.

## Previews

Window tiles capture through `ScreencopyView` against the toplevel's Wayland
handle, which the snapshot carries as `wayland`. The handle is null until the
address is reported and goes stale when the toplevel dies, so it is null checked
before use.

```json
"theme": { "previews": "still" }
```

| Mode | Behaviour |
|---|---|
| `still` | one `captureFrame()` per layout change — the default |
| `live` | a video feed per window |
| `off` | letters everywhere |

`live` runs a separate stream for every visible window, so it costs real GPU on a
busy desktop. `still` re-captures on a 120ms timer after the overlay maps and
again whenever the event socket reports a change, which covers everything except
a window repainting its own contents while the overlay sits open.

The letter shows until a frame actually arrives, so there is no empty tile during
capture, and it stays permanently for stashed windows — Hyprland does not render
inactive workspaces, so a special workspace has nothing to capture. Tiles below
26x20 skip previews entirely and stay on letters.

Corners are square inside the tile's rounded border. Clipping in QtQuick is
rectangular, so rounding the capture would need a mask pass per tile.

## Bar widget

Each cell is a miniature of one monitor's layout at that monitor's aspect ratio,
with the window count over it and an outline behind the digits so they stay
readable against the miniature. A bucket cell appears at the end only when
something is stashed.

Screen capture is deliberately not used here. Three live output feeds behind a
20px cell is a lot of GPU for something that small, and a capture of an output
would include the bar itself.

## Opening the overview from a keybind

Two entry points are registered in `shell.qml`, because the bind syntax for the
`global` dispatcher under a Lua config has not been confirmed.

**Global shortcut** — `hyprland_global_shortcuts_v1`, no process spawn, lowest
latency. Registered as `quickshell:overview`; check it appears in
`hyprctl globalshortcuts`. The hyprlang bind is
`bind = ALT, Tab, global, quickshell:overview`, and the Lua equivalent depends on
whether a `global` dispatcher exists in your version.

**IPC** — works regardless, since `hl.dsp.exec_cmd` is verified:

```lua
hl.bind("ALT + Tab", hl.dsp.exec_cmd("qs ipc call overview toggle"))
```

No `-c`. That flag names a config under `~/.config/quickshell/<name>/shell.qml`;
a shell living directly at `~/.config/quickshell/shell.qml` is the default config
and `-c quickshell` will not resolve to it. Check what is actually reachable with
`qs ipc show`.

`open`, `close` and `toggle` are all exposed. The IPC route spawns a process per
press, so it costs perhaps 50-100ms more than the global shortcut.

Note that neither gives true alt-tab semantics — hold to browse, release to
commit. `GlobalShortcut` does expose `pressed` and `released` separately, so that
is buildable, but it needs selection state and Tab cycling inside the overlay.

---

# Brightness

`Objects/Systems/BrightnessSystem.qml` — one control for every DDC display.

## Why the old one felt slow

Opening the settings panel ran `ddcutil detect` and then a `getvcp 10` per
display, serially. `detect` alone is seconds over I2C and each `getvcp` is
hundreds of milliseconds, so with three monitors the panel showed placeholder
values for several seconds before snapping to the real ones. Writing was one
`ddcutil` process per display per change.

Three things changed:

- **The display list is cached** to `.ddc-cache`. `detect` only runs on first use
  or on an explicit re-detect.
- **Per-display calls run in parallel** through a thread pool, so reading or
  writing N displays costs one round trip rather than N.
- **Brightness is read once at startup**, not on every panel open. The slider has
  a real value before you open anything.

## Why per-display control is gone

N sliders meant N serial round trips and N stale values. A single control writes
every display in one call. `--ddcsetbrightness` still exists for one-off use.

## Writes

Throttled rather than debounced — the first move writes immediately, then at most
one write every 220ms while dragging, so the monitors track the slider instead of
jumping once at the end. `holding` blocks reads from overwriting the value until
600ms after the last change.

| Function | Purpose |
|---|---|
| `--ddcstatus` | `average#num:pct:name\|…` from the cached list, read in parallel |
| `--ddcsetall <v>` | set every cached display in parallel |
| `--ddcrefresh` | force a re-detect and rewrite the cache |

## Send to workspace

`WorkspaceSendPopup` is now a centred overlay like the power menu rather than a
bar-anchored popup, and it shows the same monitor tiles as the overview with
live previews instead of a list reading "Workspace 1 (2)".

`MonitorTile` gained `selectMode`: window tiles stop reacting and the background
reports a pick instead of switching workspaces, so the same component serves both
the overview and the picker. `WindowTile` gained `interactive` for the same
reason.

The popup implements the minimal owner contract those tiles expect —
`previewTick`, `dragAddress`, `dropTarget`. Nothing here drags, so the drag half
is inert.

An application can have several windows, so the popup lists every window of the
class as a selectable preview and defaults to the active one. An "All windows"
tile sends the whole set at once. The row is hidden when there is only one
window, so the common case stays a single click.

The context menu no longer preselects an address. It used to pass
`instances[0].address`, which silently picked whichever window happened to be
first with no way to choose another.

Buckets appear underneath, so stashing is one click from the same place and
follows the same selection.

---

# Displays

`Objects/Systems/DisplaySystem.qml` and `Objects/Window/Settings/DisplaysPage.qml`.

Connected monitors come from the event socket — make, model, serial, current
mode, scale, transform and `availableModes`. Nothing about which displays exist
is stored in config any more.

## The config migration

`settings.displays` was an array of connector names and `primaryDisplayIndex`
pointed into it, so unplugging a monitor or changing the order silently moved
which display was primary. Both are gone.

`primaryDisplay` is a monitor name now, and `migrateDisplayConfig()` converts the
old pair once on startup, resolving the old index against the old array before
deleting both keys. Wallpaper cycling, theater mode and the ddc mapping all read
from live monitor names.

## Why the shell stores the layout

`keyword` is **not** a dispatcher. `Hyprland.dispatch()` wraps whatever it is
given in `hl.dispatch(...)`, so routing a keyword through it is a syntax error
under a lua config. `HyprlandSystem.keyword()` runs a real `hyprctl keyword`
process instead, queued so overlapping changes do not race.

`hyprctl keyword monitor …` applies instantly but does **not** survive a
compositor reload, because Hyprland reads monitors from its own config. Writing
into your Lua config would mean generating code into a file you hand edit, so
instead the layout lives under `displays.layout` keyed by monitor name and is
re-applied 1.5s after startup, once the socket has reported what is connected.

If it ever misbehaves, delete that key — nothing else depends on it, and the
monitor falls back to whatever Hyprland's own config says. Forget Saved Layout
does the same for one monitor.

## Arrangement

Monitors are drawn at their real relative positions scaled to fit, and dragging
one writes its position straight back — the canvas coordinates *are* Hyprland's
coordinates, just scaled.

## Modes

`availableModes` arrives as `1920x1080@144.00Hz` strings. Resolutions are the
deduplicated sizes; refresh rates are filtered to the chosen resolution, and
changing resolution keeps the current rate only if the new mode supports it.

## Reading your Hyprland config

`--hyprmonitorconfig` scans `~/.config/hypr` for monitor lines in both the lua
(`hl.monitor(...)`) and hyprlang (`monitor=`) forms, pulls the connector name out
of each, and reports file, line, text and target. The page lists them and warns
when a line targets a monitor the shell also has a stored layout for.

That matters because whichever applies last wins. Without it, the only symptom of
a conflict is a display setting quietly reverting on reload, with nothing to
point at.

## HDR

Not exposed. Hyprland's colour management options have moved between versions
and the 0.56 syntax has not been checked against your compositor.
