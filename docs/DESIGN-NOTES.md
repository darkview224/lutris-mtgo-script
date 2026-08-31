# Design notes

This is the *why* behind `magic-the-gathering-online.yml`. The
[README](../README.md) intentionally doesn't explain any of this — it's just
install steps. If you're troubleshooting, curious, or maintaining this repo,
read on.

## Why sound is disabled

MTGO plays a chime as it starts up. Under Wine that code path also queries the
audio session through `ISimpleAudioVolume`, and Wine's PulseAudio driver
returns `E_NOINTERFACE` for it — MTGO doesn't handle that and dies with an
unhandled `InvalidCastException` before the login screen is usable. With
**no** audio driver at all, the same code hits a failure MTGO *does* handle,
and it carries on. The installer disables audio two ways: a runner-level DLL
override (`winepulse.drv` etc. → disabled, which is the one that actually
sticks) and the `winetricks sound=disabled` verb as a backup. This has to be
a runner-level `wine: overrides:` block, not a `system: env: WINEDLLOVERRIDES`
entry — Lutris rebuilds `WINEDLLOVERRIDES` from the runner-level list at
launch and would silently overwrite anything set via the environment. MTGO is
fully playable without sound.

## Why GDI rendering is forced

MTGO's UI is WPF, which normally renders through Direct3D. Under Wine that can
fail silently: the splash and loading screens appear, the process keeps
running, but the main window never shows up. Forcing WPF onto Wine's GDI
renderer (`winetricks renderer=gdi`) avoids this. Same fix the
[pauleve/docker-mtgo](https://github.com/pauleve/docker-mtgo) project uses.

## Why ntsync is disabled (`PROTON_NO_NTSYNC=1`)

GE-Proton 11 defaults to the kernel's new `ntsync` synchronization primitive.
With it, MTGO's WPF startup crashes while tearing down one of its own windows
— an unhandled `Win32Exception` from `HwndWrapper.DestroyWindow` inside
`Dispatcher.ShutdownImpl()`. Several windows flash up and then `MTGO.exe`
dies while the rest of the Wine process tree keeps running (Lutris still
shows "Stop"). Forcing the older `fsync` path fixes it. The installer sets
this as a game environment variable; same fix used by the
[phever/mtgo-linux](https://github.com/phever/mtgo-linux) project.

## Why the client isn't downloaded during install

`setup.exe` (MTGO's ClickOnce bootstrapper) is downloaded and copied into the
game folder during install, but the ~640 MB client itself is *not* deployed
at that point — deploying it during install used to make the installer hang
forever, because once the client reaches the login screen the Wine/umu
process tree never exits, and Lutris's installer step waits for that exit
before it can finish. Instead, the client deploys itself the first time you
click **Play** (standard ClickOnce behavior) — that's why the first launch
takes noticeably longer than every launch after it.

## Why there's a "tuning" step on every launch

MTGO's WPF collection view can peg a CPU core and freeze the UI for seconds
at a time when scrolling or searching a large collection. Four flags in
`MTGO.exe.config` (`DisableAutomationPeer`, `PurgeAutomationEvents`,
`DisableStylusInput`, `DisableTabletDevices`) fix this, but MTGO's
auto-updater resets that file on every client update. The installer drops a
small script, `mtgo-tune.sh`, into the game folder and wires it up as a
Lutris pre-launch command, so the flags are re-applied right before every
launch — no manual steps, and nothing touched outside the game's own prefix.

## Provenance

This installer script, its recovery tooling, and this documentation were
produced with [Claude Code](https://claude.com/claude-code), working from
crash traces and log analysis gathered through live, hands-on testing rather
than guesswork.

## Test status

- **Bazzite, native Lutris install**: confirmed working end-to-end — clean
  install, reaches a stable login screen, and a full match has been played
  successfully.
- **Flatpak Lutris** (Aurora, Silverblue, Kinoite): install completes, but
  not yet confirmed working end-to-end. Testing is still in progress:
  - The client hung during one test session; not yet reproduced on a
    follow-up attempt, and may have simply been resolved by a restart. Not
    confirmed as a real, repeatable issue.
  - Alt-tabbing away from the MTGO window and back seemed to leave it in a
    bad state during testing; also not yet confirmed as reproducible.
  - **Confirmed, filed:** on the verification-code (2FA) screen, the
    "remember this device for 30 days" checkbox doesn't respond to clicks —
    see [issue #1](https://github.com/darkview224/lutris-mtgo-script/issues/1).
    Not yet known whether this is Flatpak-specific or also affects native
    Lutris.

  If you hit or can confirm/deny any of these, reports and issues are
  welcome.

## Troubleshooting

- **Installer looks frozen on the .NET Framework 4.8 step.** Normal — it can
  take 10+ minutes with no visible progress. Only worry if it's been stuck
  for more than ~20 minutes.
- **First Play: the "Application Install - Security Warning" window is
  blank.** Also normal (a WPF-under-Wine paint bug). The **Install** button
  is still there at the bottom-right; click it, or press **Alt+I**.
- **Windows flash up on launch, then everything closes but Lutris still
  shows "Stop".** That's the ntsync crash. Confirm the game's configuration
  still has `PROTON_NO_NTSYNC=1` (**Configure → System options →
  Environment variables**).
- **Splash/loading screens appear, then nothing — no main window.** WPF
  failing to render. The installer applies `winetricks renderer=gdi`; if
  you're on an older install that predates it, see "Redoing an install"
  below.
- **Crashes right after the loading screen, log mentions
  `ISimpleAudioVolume` or audio.** The audio-disable didn't take. Check
  **Configure → Runner options → DLL overrides** contains
  `winepulse.drv=disabled` (plus winealsa / wineoss / winecoreaudio).
- **UI freezes when scrolling your collection.** Make sure `mtgo-tune.sh` is
  present and executable in the game folder (**Configure → System options →
  Game directory**). If MTGO just auto-updated, launch once more — the
  pre-launch hook re-applies the flags every time.

## Redoing an install

**Don't just re-run `magic-the-gathering-online.yml`** into a folder that
already has an install in it. Lutris treats an already-applied winetricks
verb as a hard error and silently aborts the rest of the install. Delete the
game from your Lutris library (with files) and confirm
`~/Games/magic-the-gathering-online` is actually gone before reinstalling.

To re-apply just one winetricks verb to an existing install without a full
reinstall, use `dev/fix-renderer.yml` (or a copy of it with the `app:` line
changed) the same way you ran the main script, but point it at your
**existing** game folder when it asks for a location. Afterward remove the
temporary entry Lutris creates (right-click → Remove, without deleting
files). If you lost only the Lutris library entry (files still on disk), use
`dev/reconnect.yml` the same way.

## What's in `dev/`

Debugging and recovery conveniences, not part of the installer proper:

- `fix-renderer.yml` — re-apply one winetricks verb to an existing install.
- `open-winecfg.yml` — open the real `winecfg` dialog against an existing
  install's prefix, for settings Lutris's own UI doesn't expose.
- `reconnect.yml` — recreate a lost Lutris library entry for an install
  that's still on disk, without touching the prefix.
- `keep-alive.sh` — supervises an unattended Claude Code session against
  `HANDOFF.md`, relaunching it whenever it exits (e.g. a usage-limit reset).
- `HANDOFF.md` — the working log from the autonomous debugging session that
  found and fixed the ntsync and audio crashes. Kept as a historical record
  of how the root causes were actually found.
