# Theme layer

Colour now lives in a singleton at `Objects/Theme/Theme.qml`. `config.json` holds
only what you authored; every other value is derived at runtime and is never
written back to disk.

## Config

The `theme` block replaces the old five-colour map:

```json
"theme": {
    "mode":          "auto",        // "auto" | "dark" | "light"
    "glass":         true,          // false falls back to opaque surfaces
    "scrimStrength": 1.0,           // 0.5–1.4, scales the scrim alpha
    "accentSource":  "wallpaper",   // "wallpaper" | "fixed"
    "accent":        "#6b5d62"      // used when accentSource is "fixed",
                                    // and as the hue fallback for a greyscale wallpaper
}
```

`background`, `surface`, `primary`, `secondary` and `text` are no longer read.
Leaving them in the file is harmless — `primary` is still accepted as an alias
for `accent` if `accent` is absent.

`mode: "auto"` follows, in order: `forceDarkMode`, then `wallpapers.wallpaperMode`,
then `wallpapers.darkModeHours`. Unlike before, this runs on its own 60s timer and
no longer depends on `wallpapers.cycling` being enabled — a fixed-wallpaper setup
still switches light and dark on schedule.

## Contrast guarantee

Blur shows whatever is behind the surface, so a token is only safe if it holds
against the extreme case: a pure white wallpaper in dark mode, pure black in
light mode. `Theme.backdropWorst` composites the scrim over that extreme, and
`text`, `accentText`, `danger`, `warn` and `ok` are each walked in lightness
until they clear 4.5:1 against it. `accentIcon` targets 3.0:1, the large-glyph
threshold.

This is what stops the wallpaper from making things unreadable. The accent hue
still comes from the wallpaper; its saturation and lightness are clamped into a
band before the contrast walk, so it stays recognisably one colour.

Text is never tinted with the accent.

## Tokens

| Token | Use |
|---|---|
| `bg` | opaque base, non-glass fallback |
| `surface` | panel fill — the scrim, carries alpha when glass is on |
| `surfaceRaised` / `surfaceSunken` | inset rows, wells, list stripes |
| `border` / `borderStrong` | glass edge stroke |
| `highlight` | specular top run |
| `shadow` | drop shadow colour |
| `text` / `textDim` / `textMute` / `textInvert` | four emphasis levels |
| `accent` | fills, indicators, sliders |
| `accentText` | accent-coloured text, ≥4.5:1 |
| `accentIcon` | accent-coloured icons, ≥3.0:1 |
| `accentHover` / `accentPressed` / `accentDim` / `accentLine` | states and washes |
| `onAccent` | text drawn on top of an accent fill |
| `danger` / `warn` / `ok` | status |
| `radiusSmall` `radius` `radiusLarge` `chamfer` `softRadius` `borderWidth` | geometry |
| `durFast` `durNormal` `durSlow` | motion |

`Theme.legacy` maps the five old key names onto live tokens. Existing components
reach it through `root.theme.*`, so nothing had to be rewritten call-site by
call-site. New code should use `Theme.*` directly.

## Blur

Blur is a property of the *surface*, not of a block, so each window declares its
own region:

```qml
property Region glassBlurRegion: Region { item: background }
BackgroundEffect.blurRegion: Theme.glass ? glassBlurRegion : null
```

This uses `ext-background-effect-v1` via Quickshell's `BackgroundEffect`. The bar
unions four regions — one per block group — so the gaps between groups stay
unblurred. Gaming mode drops the region entirely.

### Why the corners needed work

A region is built from rectangles, so it cannot express a diagonal or a curve.
Left as a plain rect it covers the cut corners too, and the blurred wallpaper
showing through the cut reads as a dark wedge against the sharp wallpaper around
it.

`RoundedBlock.blurRegion` subtracts a four-step staircase from each cut corner,
so the blur stops within about a pixel of the visible edge. The same machinery
handles rounded corners, using a circular profile instead of a linear one.
`blurSteps` raises or lowers the approximation quality; each step is a rectangle
sent to the compositor, and the bar's app block re-sends its region on every
frame of its width animation, so there is a real cost to raising it.

### blurMode

```json
"theme": {
    "blurMode":   "protocol",
    "overlayDim": 1.0
}
```

```json
"theme": {
    "panelDim":   1.0,
    "overlayDim": 1.0
}
```

Three surface weights, because the same scrim does not work at every size. A bar
block is a thin strip and stays readable over a busy wallpaper at `scrim`. A tall
panel full of text does not, so popups use `panelScrim`. A fullscreen overlay
covers the whole desktop, so it uses `overlayScrim`.

| Token | Default alpha with glass | Used by |
|---|---|---|
| `scrim` | 0.68 | bar blocks |
| `panelScrim` | 0.88 | popups and settings panels |
| `overlayScrim` | 0.72 plus its own blur | the workspace overview |

`panelDim` and `overlayDim` scale their respective values and leave the bar
alone.

| Mode | How |
|---|---|
| `protocol` | `ext-background-effect-v1` with the staircase region. Self-contained, no compositor config. Corners are approximated. |
| `compositor` | No region is set. Hyprland blurs from the surface alpha, which follows the drawn shape exactly — chamfers and curves included, no approximation. Needs layer rules. |

`compositor` is the better-looking option if you are willing to edit
`hyprland.conf`, because `ignorealpha` masks the blur against what was actually
drawn rather than a list of rectangles:

```
layerrule = blur, quickshell:bar
layerrule = ignorealpha 0.1, quickshell:bar
layerrule = blurpopups, quickshell:bar
```

It is also the fallback if `BackgroundEffect` is missing from your Quickshell
build or Hyprland does not advertise the protocol.

## What to verify

1. `BackgroundEffect` exists in your Quickshell build — it ships in 0.3.x as
   `Quickshell/Wayland/_BackgroundEffect`. If the attached property errors, take
   the fallback above.
2. Hyprland supports `ext-background-effect-v1`. If not, same fallback.
3. Singleton registration. Quickshell generates `qmldir` per directory and honours
   `pragma Singleton`; if `Theme` fails to resolve, that is the thing to check
   first.
4. `Shape.CurveRenderer` — used for the block outlines. Needs Qt 6.6+. Drop the
   `preferredRendererType` line if your Qt is older.

## Removed

`--generatetheme` no longer runs from QML. Colours are derived from
`ColorQuantizer` directly in QML, so `theme.py` and `colormath` are off the hot
path — `utill.py` no longer imports either at module scope, which every poll was
previously paying for. The function and `theme.py` are still present and callable
by hand; they can be deleted once you are happy with the new pipeline.

---

# Controls

`Objects/Design/Controls/` — shared controls so every panel lines up without
each call site inventing its own metrics.

| Control | Use |
|---|---|
| `ToggleSwitch` | on/off |
| `SegmentedControl` | 2-4 exclusive options, optional per-option tint |
| `SelectBox` | a dropdown for longer option lists |
| `NumberStepper` | bounded integers, press and hold to repeat |
| `InputField` | free text, with an invalid state |
| `SettingRow` | icon, label, description and a control slot |
| `SectionLabel` | a group heading with a rule under it |
| `QuickTile` | a quick-settings tile with an active state |

Metrics live in `Theme` — `rowHeight`, `controlHeight`, `controlMinWidth`, `gap`,
`sectionGap`, `pagePadding`, `labelSize`, `descSize`, `valueSize`. Controls read
those rather than hardcoding, so changing a row height changes every panel.

`SettingRow` puts the control beside the label by default and under it when
`stacked` is set, which is what sliders and anything full-width want.

`SegmentedControl` is the pattern the wallpaper mode switch established: a track,
a sliding thumb, and invisible click zones. It is generalised to any option list
now, and an option can carry its own `color` so the thumb tints per selection.


## Icon

`Objects/Design/Icon.qml` was dead code before the control library used it — no
call site anywhere in the shell. It set `Material.foreground` on an `IconImage`,
which does nothing, because that attached property only tints icons on Material
controls. `IconButton` works because it is a `RoundButton` and Qt colours a
button's `icon.source` for it.

It is now an `Image` tinted through `MultiEffect` colorization, which works on a
bare image. `iconSize` has a default so an omitted value cannot take down the
component — a required property that is not set fails instantiation, and inside a
`Repeater` that silently drops the whole delegate rather than warning.

---

# Settings window

`Objects/Window/Settings/` — a `FloatingWindow` with a sidebar, opened from
All Settings in the quick panel.

| File | Role |
|---|---|
| `SettingsSchema.qml` | every setting, declared as data |
| `SettingControl.qml` | renders one schema item as the right control |
| `SettingsWindow.qml` | sidebar, search, page body |

## Config access

`SettingsSchema` is pure data. Reads and writes live in `SettingControl`, because
a singleton is created outside the component tree and the `ShellRoot` id does not
resolve inside one — config reads from the singleton silently fell through to
their fallbacks, so every field looked empty and every value looked default.

`config.json` is parsed into a plain object, so reading a nested value registers
no QML dependency and a binding on it never re-evaluates. `SettingControl` keeps
a `revision` counter that a write bumps, and controls depend on that to refresh.

## Why a schema

Pages are data, not layout. An item names a dotted `config.json` path, a control
type, a label and a description; `SettingsSchema.get`/`set` read and write that
path and save. Adding a setting is a few lines in the schema and it inherits the
correct control, spacing and row height automatically — consistency comes from
there being one renderer rather than from remembering to match the last page.

Search filters the real schema items across every page, so it cannot drift from
what the pages actually show. A parallel search index would have been simpler and
would have gone stale the first time a label changed.

`scale` lets a stepper present a different unit than the stored value — the
wallpaper interval shows minutes over a value stored in milliseconds.

## Not yet in the schema

These lived in the old dense panel and have no page yet: theater primary display
selection, the gaming app trigger list (still managed from the app bar context
menu), the Hyprland animation and blur toggles, and the debug section.
`SettingsManagementPopup.qml` still contains them but is no longer instantiated —
it is dead code until those move, then it should be deleted.

Audio and bluetooth pages need live device lists rather than static schema items,
so they need a custom page type.

## ActionButton

`Objects/Design/Controls/ActionButton.qml` replaces the hand-rolled
`RoundButton` blocks that each popup had its own version of. Three tones —
`neutral`, `accent`, `danger` — plus a `busy` state that swaps in a spinning
sync icon, which is what the bluetooth connect button was doing with a bespoke
`contentItem`.

Colours that were hardcoded per popup now come from tokens: battery levels use
`danger`/`warn`/`ok`, disabled glyphs use `textMute`, and the connect and pair
buttons use the accent rather than a literal grey.


## Blur on popups

Layer surfaces blur; XDG popups appear not to.

Everything that blurs under `blurMode: "protocol"` is a `PanelWindow` — the bar,
the workspace overview, the power menu. Everything reported as unblurred is a
`PopupWindow` — audio, bluetooth, notification toasts, the quick panel. The
`ext-background-effect-v1` request is made identically for both, so the
difference is on the compositor side: the effect is applied to the surface, and
an XDG popup is a different surface than the layer surface it hangs off.

`blurMode: "compositor"` does not have this problem, because Hyprland's
`blurpopups` layer rule explicitly covers a layer surface's popups. Popups here
are all anchored to the bar, so one namespace covers them:

Hyprland 0.55+ uses a Lua config, where layer rules are `hl.layer_rule()` with
the same shape as `hl.window_rule()`:

```lua
hl.layer_rule({
  name = "qs-bar-blur",
  match = { namespace = "quickshell:bar" },
  blur = true,
  ignore_alpha = 0.1,
  blur_popups = true,
})

hl.layer_rule({
  name = "qs-overview-blur",
  match = { namespace = "quickshell:overview" },
  blur = true,
  ignore_alpha = 0.1,
})

hl.layer_rule({
  name = "qs-power-blur",
  match = { namespace = "quickshell:power" },
  blur = true,
  ignore_alpha = 0.1,
})
```

On the old hyprlang syntax the same rules are:

```
layerrule = blur on, ignore_alpha 0.1, match:namespace quickshell:bar
layerrule = blur on, ignore_alpha 0.1, match:namespace quickshell:overview
layerrule = blur on, ignore_alpha 0.1, match:namespace quickshell:power
```

`blur` and `ignore_alpha` are documented. `blur_popups` is inferred from the
snake_case convention the other keys follow and is **not** confirmed — if it is
wrong, the bar blurs and its popups do not, which looks identical to having no
rule at all. `hyprctl layers` lists the live namespaces.

`ignore_alpha` is a threshold: only pixels above it are blurred. Panels sit at
0.88 alpha and the gaps between bar blocks are fully transparent, so 0.1 blurs
the blocks and leaves the gaps sharp.

Set `"blurMode": "compositor"` in the theme block alongside those rules. If the
popups blur and the bar still blurs, the hypothesis above is confirmed and
`compositor` is simply the correct mode for this shell.

If you would rather stay on `protocol`, the alternative is turning those popups
into layer surfaces — a `PanelWindow` positioned by hand instead of a
`PopupWindow` anchored to the bar. That is how the power menu and the overview
already work, and it is a real change to how each popup positions and dismisses
itself rather than a setting.

---

# Clock and date

Time and date lead the right hand block, ahead of the audio and media widgets,
with a hairline after them. The left block is still the workspace summary on its
own.

## Clock

`Objects/Widgets/ClockWidget.qml`, with two styles set by
`widgets.clockStyle`:

| Value | Result |
|---|---|
| `text` | plain numerals, the default |
| `dots` | a lit 5x7 dot grid per character |

`widgets.clock24` switches to 24 hour and drops the meridiem.

`Objects/Widgets/Internal/DotMatrix.qml` draws the grid. Glyphs are declared as
seven row strings of ones and zeros per character, covering digits, colon and
space — enough for a clock and nothing more. Unlit dots are drawn faintly so the
grid reads as a display rather than as floating numerals; `showUnlit` turns that
off.

The old `DatetimeWidget` spawned a Python process **every second** purely to
format a date string. Both widgets now read the clock from Qt.

## Date

`Objects/Widgets/DateWidget.qml` shows the week as seven marks with today's
filled and widened, above the month in small caps, beside the day number. The
position in the week is legible without reading anything. Hovering gives the
full date.

## Removed

The colour picker is off the bar. `ColorPickerWidget.qml` and
`ColorHistoryPopup.qml` are unused as a result — the picker itself is still
reachable from Quick Access in the quick panel, which runs the same
`colorpicker` command. `DatetimeWidget.qml` is also unused now.

## Network

`Objects/Widgets/NetworkWidget.qml` replaces `InterfaceWidget`, with
`widgets.networkStyle` choosing `dots` or `text`.

The dots form is a rolling throughput meter in the same language as the clock:
twelve columns of history, newest on the right, download filling upward in the
top band and upload mirrored downward below it. Levels are logarithmic — 8KB/s,
128KB/s and 1MB/s — so ordinary browsing still moves the display instead of
sitting flat until something saturates the link.

## Why it stopped calling python

`--getnetworkinfo` samples `/proc/net/dev` twice half a second apart to compute a
rate, so every call spawned an interpreter **and blocked for 500ms** — and the
widget did that every 1.5 seconds.

Throughput is now read from `/proc/net/dev` through a `FileView` and differenced
in QML once a second, with no subprocess at all. `lo`, `veth*` and `br-*` are
skipped. The Python call still runs, but only every 15 seconds and only for the
interface name and VPN state, which rarely change.

---

# Icons

Icons come from the Material Symbols font when it is installed, and from the
bundled folder otherwise.

```
sudo pacman -S ttf-material-symbols-variable
```

It is in Extra, not the AUR, and ships Outlined, Rounded and Sharp as variable
fonts. `theme.iconFamily` picks the style, `theme.icons` picks the source
(`auto`, `font`, `images`), and Settings → Appearance → Icons exposes both.

## Why a font

The font draws an icon from a **ligature of its own name**, so `folder_open`
renders as the folder icon with nothing to resolve on disk. That removes the
whole per-name file lookup and its cache, scales to any size, and tints by
setting a text colour rather than running a colorization pass.

Most of our names are already Material's. `IconMap.aliases` translates the ones
we invented — `media_output` to `speaker`, `wired` to `lan`, `backlight_high` to
`brightness_high`, and so on.

## What still uses files

Application icons. Those come from `.desktop` entries and are real artwork, so
they resolve through `DesktopEntries` and `Quickshell.iconPath` as before.
`IconButton.setIconSource()` is the escape hatch the app bar uses for them.

If the font is missing, `Icon` falls back to the bundled folder and tints through
`MultiEffect`, so nothing breaks — it just looks as it did before.


---

# Bar layout

`bar` in `config.json` describes the whole bar.

```json
"bar": {
    "position": "top",
    "style":    "blocks",
    "left":     ["workspaces"],
    "center":   ["appbar"],
    "right":    ["clock", "date", "separator", "volume",
                 "network", "bluetooth", "tray", "notifications"]
}
```

Settings → Bar edits all of it: position, style, per-zone ordering, moving a
widget between zones, and a catalogue showing where each widget currently sits.

## Widgets as data

`Objects/Widgets/BarWidget.qml` maps an id to a component, so the zones in
`MainWindow` are `Repeater`s over those arrays rather than hardcoded markup.
Adding a widget to the shell means one entry in that map and one in the
catalogue.

The settings button is deliberately not in the list. The quick panel, power menu
and settings window are all parented to it, so it stays pinned at the end of the
right zone.

## Full versus blocks

Full mode does not rebuild the layout. A single `RoundedBlock` is drawn behind
everything at `z: -1`, and the per-zone blocks drop their fill, border and
highlight — so widgets keep their exact positions and only the surface beneath
them changes. Duplicating the zones into a second layout would have meant two
copies of every widget, including the one that owns the popups.

The blur region follows whichever surface is actually painted: one region in
full mode, the union of four in blocks mode.

## Bottom placement

Swaps the layer shell anchor and flips every chamfer, and popups position
through `mainWindow.popupOffset()` so they open upward instead of off screen.
