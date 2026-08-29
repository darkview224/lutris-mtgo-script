# MTGO on Fedora Atomic (Bazzite / Aurora / Silverblue / Kinoite)

Installs **Magic: The Gathering Online** on Fedora Atomic distributions through
Lutris, whether Lutris is installed natively (Bazzite ships it) or as a Flatpak
(Aurora). It reaches a working, connected login screen with no manual Wine
tweaking.

## 1. Install Lutris (skip if you already have it)

**Bazzite** ships Lutris — check your app menu first. If it's missing:

```
flatpak install --user flathub net.lutris.Lutris
```

**Aurora / Silverblue / Kinoite:**

```
flatpak install --user flathub net.lutris.Lutris
```

If that fails because Flathub isn't set up, run this first, then repeat:

```
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

## 2. Get this repo's installer script

```
git clone https://github.com/darkview224/lutris-mtgo-script.git
```

You now have `lutris-mtgo-script/magic-the-gathering-online.yml`. It downloads
MTGO's `setup.exe` for you — no separate manual download needed.

## 3. Run the installer

1. In Lutris, click the **+** button (top left) → **Install script** (Flatpak
   Lutris calls this "Install game from a local file").
2. Browse to `lutris-mtgo-script/magic-the-gathering-online.yml` and select it.
3. Click **Install**, then **Continue** to accept the default install directory
   (`~/Games/magic-the-gathering-online`). **It must not already exist** — if
   you're redoing an install, delete the old folder first (re-running the
   installer over an existing folder aborts partway through; see "Redoing an
   install" below).
4. Click **Install** on the file list, then let it run. It will:
   - create a Wine prefix,
   - install fonts and .NET Framework 4.8 (**this step takes several minutes
     with no visible progress — let it finish, don't cancel it**),
   - disable the Wine sound driver and force GDI rendering (see the notes at the
     bottom).
5. When it says **Installation completed!**, click **Close**. MTGO is now in
   your Lutris library as **Magic The Gathering Online**.

Lutris 0.5.22 automatically runs this through the latest GE-Proton (via umu) —
you do **not** need to install a runner or set a Wine version by hand.

## 4. Play

Click **Play**.

**The first launch** runs MTGO's ClickOnce bootstrapper. It shows an
**"Application Install - Security Warning"** window — click **Install** (under
Wine this window sometimes paints blank; the Install button is still there at the
bottom, or press **Alt+I**). It then downloads the ~640 MB client, deploys it,
and opens the MTGO login screen. This first launch takes a while; leave it be.

**Every later launch** opens MTGO directly, with the freeze-prevention tweak
re-applied automatically first.

You don't have to log in for the install to be considered working — reaching a
stable login screen that stays open is the goal.

---

## Why sound is disabled

MTGO plays a chime as it starts up. Under Wine that code path also queries the
audio session through `ISimpleAudioVolume`, and Wine's PulseAudio driver returns
`E_NOINTERFACE` for it — MTGO doesn't handle that and dies with an unhandled
`InvalidCastException` before the login screen is usable. With **no** audio
driver at all, the same code hits a failure MTGO *does* handle, and it carries
on. The installer disables audio two ways: a runner-level DLL override
(`winepulse.drv` etc. → disabled, which is the one that actually sticks) and the
`winetricks sound=disabled` verb as a backup. MTGO is fully playable without
sound.

## Why GDI rendering is forced

MTGO's UI is WPF, which normally renders through Direct3D. Under Wine that can
fail silently: the splash and loading screens appear, the process keeps running,
but the main window never shows up. Forcing WPF onto Wine's GDI renderer
(`winetricks renderer=gdi`) avoids this. Same fix the
[pauleve/docker-mtgo](https://github.com/pauleve/docker-mtgo) project uses.

## Why ntsync is disabled (`PROTON_NO_NTSYNC=1`)

GE-Proton 11 defaults to the kernel's new `ntsync` synchronization primitive.
With it, MTGO's WPF startup crashes while tearing down one of its own windows —
an unhandled `Win32Exception` from `HwndWrapper.DestroyWindow` inside
`Dispatcher.ShutdownImpl()`. Several windows flash up and then `MTGO.exe` dies
while the rest of the Wine process tree keeps running (Lutris still shows
"Stop"). Forcing the older `fsync` path fixes it. The installer sets this as a
game environment variable; same fix used by the
[phever/mtgo-linux](https://github.com/phever/mtgo-linux) project.

## Why there's a "tuning" step on every launch

MTGO's WPF collection view can peg a CPU core and freeze the UI for seconds at a
time when scrolling or searching a large collection. Four flags in
`MTGO.exe.config` (`DisableAutomationPeer`, `PurgeAutomationEvents`,
`DisableStylusInput`, `DisableTabletDevices`) fix this, but MTGO's auto-updater
resets that file on every client update. The installer drops a small script,
`mtgo-tune.sh`, into the game folder and wires it up as a Lutris pre-launch
command, so the flags are re-applied right before every launch — no manual steps,
and nothing touched outside the game's own prefix.

## Troubleshooting

- **Installer looks frozen on the .NET Framework 4.8 step.** Normal — it can
  take 10+ minutes with no visible progress. Only worry if it's been stuck for
  more than ~20 minutes.
- **First Play: the "Application Install - Security Warning" window is blank.**
  Also normal (WPF-under-Wine paint bug). The **Install** button is still there
  at the bottom-right; click it, or press **Alt+I**.
- **Windows flash up on launch, then everything closes but Lutris still shows
  "Stop".** That's the ntsync crash. Confirm the game's configuration still has
  `PROTON_NO_NTSYNC=1` (**Configure → System options → Environment variables**).
- **Splash/loading screens appear, then nothing — no main window.** WPF failing
  to render. The installer applies `winetricks renderer=gdi`; if you're on an
  older install that predates it, see "Redoing an install" below.
- **Crashes right after the loading screen, log mentions `ISimpleAudioVolume`
  or audio.** The audio-disable didn't take. Check **Configure → Runner options
  → DLL overrides** contains `winepulse.drv=disabled` (plus winealsa / wineoss /
  winecoreaudio).
- **UI freezes when scrolling your collection.** Make sure `mtgo-tune.sh` is
  present and executable in the game folder (**Configure → System options →
  Game directory**). If MTGO just auto-updated, launch once more — the
  pre-launch hook re-applies the flags every time.

## Redoing an install

**Don't just re-run `magic-the-gathering-online.yml`** into a folder that already
has an install in it. Lutris treats an already-applied winetricks verb as a hard
error and silently aborts the rest of the install. Delete the game from your
Lutris library (with files) and confirm `~/Games/magic-the-gathering-online` is
actually gone before reinstalling.

To re-apply just one winetricks verb to an existing install without a full
reinstall, use `fix-renderer.yml` (or a copy of it with the `app:` line changed)
the same way you ran the main script, but point it at your **existing** game
folder when it asks for a location. Afterward remove the temporary entry Lutris
creates (right-click → Remove, without deleting files). If you lost only the
Lutris library entry (files still on disk), use `reconnect.yml` the same way.
