# Native screenshot capture, 2026-10-20

The screenshots use unchanged runtime files from
`8987b235993597753053501212457fb51514e90d` (plugin 1.0.0).
The fictional data is in [demo-fixture.json](demo-fixture.json), first committed
at `4d4a867`. No plugin QML or action-script behavior changed for these images.

The capture ran on an AcePC AK2 with Omarchy 4.0.4-1 and Hyprland 0.56.2,
on one 1280×720 virtual monitor at scale 1. The installed theme was left
unchanged; no broader theme, orientation or multi-monitor pass was performed.

The portable plugin validator and the installed `omarchy plugin validate`
both passed. The runtime payload was copied with a per-file SHA-256/mode
manifest and checked on the desktop before loading.

## Scene setup

The capture backed up the existing shell configuration and used a previously
absent Scratchpad plugin/data directory. It seeded `todos.json`, `notes.md`
and `snippets.json` from the fictional fixture. Never replace your own data
without backing it up first.

The shell loaded the plugin with `omarchy-shell shell rescanPlugins` and
`omarchy plugin enable azambekdev.scratchpad --section right --index 0`.
The panel was requested through supported shell IPC. The initial hot-load
showed the bar but no panel; after `omarchy restart shell`, the panel rendered.
The following summon call reported a timeout even though the panel became
visible. The cause of that first-load behavior was not established.

Tabs were selected through the normal inline `defaultTab` setting
(`todos`, `notes`, `snippets`); `compactView: true` supplied the compact chip.
These are real rendered states. They were not reached through native key presses.
The native-input interface could not target the shell layer for clicking or
keyboard focus, so no keyboard GIF, pointer interaction, editing or clipboard
result is claimed. The footer shortcut line was clipped in this session; the
captures preserve that rendering.

`grim -g` captured each original region directly: 43×26 and 23×26 bar chips,
and 432×360, 432×425 and 432×307 panels. The PNGs were not edited or resized.

## Restoration

After capture, the exact original shell configuration bytes and mode were
restored. The task-created plugin and fixture-data directories were removed.
The normal shell answered `ping`, and the workspace and cursor were unchanged.
This is screenshot evidence, not full plugin acceptance or a security review.
