# MTGO on Aurora (Fedora Atomic) via Flatpak Lutris

Installs Magic: The Gathering Online on Aurora — or any Fedora Atomic distro
(Bazzite, Silverblue, Kinoite) where Lutris is only available as a Flatpak.
Follow the steps below in order. Every command is meant to be copy-pasted
as-is into a terminal.

## 1. Install Lutris

```
flatpak install --user flathub net.lutris.Lutris
```

If that fails because Flathub isn't set up, run this first, then repeat the
command above:

```
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
```

## 2. Get this repo's installer script

```
git clone https://github.com/darkview224/lutris-mtgo-script.git
```

You now have `lutris-mtgo-script/magic-the-gathering-online.yml`. It
downloads MTGO's `setup.exe` for you — no separate manual download needed.

## 3. Install a GE-Proton/Wine-GE runner build

MTGO needs a newer Wine build than Lutris ships by default. Do this once,
before installing the game:

1. Open Lutris.
2. Click the hamburger menu (top right) → **Preferences**.
3. Go to the **Runners** tab, find **Wine** in the list, and click the
   settings/gear icon next to it.
4. Click **Manage Versions**.
5. In the list that opens, install the newest build whose name starts with
   `GE-Proton` (or `wine-ge` if no GE-Proton build is listed). This
   downloads it into Lutris's own Flatpak data directory — nothing is
   written to your host system.
6. Close the version manager and Preferences.

## 4. Run the installer

1. In Lutris, click the **+** button (top left) → **Install script**.
2. Browse to `lutris-mtgo-script/magic-the-gathering-online.yml` from step 2
   and select it.
3. **Make sure the install directory it offers doesn't already exist** (or
   is completely empty). Re-running this installer into a folder that
   already has an MTGO install in it will fail partway through — Lutris
   aborts the whole install if any winetricks step finds something already
   applied, instead of just skipping it. If you're redoing an install,
   delete the old folder first.
4. Click through the installer. It will:
   - download `setup.exe` from MTGO's patch server,
   - create a Wine prefix,
   - install fonts and .NET Framework 4.8 (this step takes a few minutes —
     let it finish, don't cancel it),
   - disable the Wine sound driver (see "Why sound is disabled" below),
   - force GDI rendering so MTGO's main window actually appears (see
     "Why GDI rendering is forced" below),
   - run `setup.exe` to install the MTGO client itself.
5. When it finishes, MTGO is listed in your Lutris library as
   **Magic The Gathering Online**.

## 5. Set the game to use the GE-Proton/Wine-GE build

The installer doesn't pin a Wine version, so point it at the one you
installed in step 3:

1. Right-click **Magic The Gathering Online** in your library → **Configure**.
2. Go to the **Runner options** tab.
3. Set **Wine version** to the GE-Proton/Wine-GE build you installed.
4. Click **Save**.

## 6. Play

Click **Play** on the game in Lutris. The first launch runs the MTGO
bootstrapper, which finishes downloading and activating the client, then
opens MTGO's login screen. Every subsequent click of **Play** launches MTGO
directly, with the freeze-prevention tweak (step below) re-applied
automatically first.

---

## Why sound is disabled

MTGO reliably crashes under Wine the instant it tries to play a sound
effect (the EULA-accept chime, a match starting, etc.) — this is a known
Wine/.NET WPF audio issue, not something specific to this script or to
Aurora. Disabling Wine's audio driver sidesteps the crash entirely. MTGO is
fully playable without sound; you aren't losing anything you'd otherwise
have working.

## Why GDI rendering is forced

MTGO's UI is built on WPF, which normally renders through Direct3D. Under
Wine, that can fail silently: MTGO's splash and loading screens appear, the
process stays running, but the main window never actually shows up. Forcing
WPF onto Wine's GDI renderer (`winetricks renderer=gdi`) avoids this. This
is the same fix used by the actively-maintained
[pauleve/docker-mtgo](https://github.com/pauleve/docker-mtgo) project's own
Wine setup.

## Why there's a "tuning" step on every launch

MTGO's WPF-based collection view can peg a CPU core and freeze the UI for
seconds at a time when scrolling or searching a large card collection. Four
flags in `MTGO.exe.config` (`DisableAutomationPeer`, `PurgeAutomationEvents`,
`DisableStylusInput`, `DisableTabletDevices`) fix this. The problem is that
MTGO's own auto-updater overwrites that config file and resets the flags
back to `false` on every client update. The installer writes a small script,
`mtgo-tune.sh`, into the game's own install folder and wires it up as a
Lutris pre-launch command, so it re-applies those four flags right before
MTGO starts, every time — no manual steps needed after the initial install,
and no editing of files outside the game's own prefix.

## Troubleshooting

- **Installer hangs on the .NET Framework 4.8 step.** This is normal — it
  can take several minutes with no visible progress. Only cancel it if it's
  been stuck for more than ~15 minutes.
- **Game won't launch / crashes immediately.** Double check step 5 — MTGO
  needs the GE-Proton/Wine-GE build, not Lutris's older bundled Wine.
- **Splash/loading screens appear, then nothing — no main window, but the
  process is still running.** This is MTGO's WPF UI failing to render
  under Wine's default hardware-accelerated renderer. The installer
  already applies the fix (`winetricks renderer=gdi`) for new installs. If
  you installed with an older copy of this script, see "Applying a fix to
  an existing install" below.
- **Still crashes when a sound would play.** The installer already applies
  `winetricks sound=disabled`. If it's still happening, see "Applying a fix
  to an existing install" below to re-apply that verb.
- **UI still freezes when scrolling your collection.** Confirm
  `mtgo-tune.sh` actually ran: check the Lutris install folder for the game
  (visible under **Configure** → **System options** → **Game directory**)
  and make sure `mtgo-tune.sh` is present and executable. If MTGO was just
  updated by its own auto-updater, launch the game once more — the
  pre-launch hook re-applies the flags before every session.

### Applying a fix to an existing install

**Do not just re-run `magic-the-gathering-online.yml`** against a folder
you already installed to. Lutris's winetricks step treats a verb that's
already applied as a hard error and aborts the *rest* of the install
silently — including any later steps you actually needed — rather than
skipping it and moving on. This applies even on a second machine if you're
installing into a shared/external drive that already has a previous
attempt's files on it — check the target folder is actually empty first.

If you just need to re-apply one winetricks fix (e.g. you're on an older
install that predates `renderer=gdi` being added), use `fix-renderer.yml`
from this repo the same way you installed the main script (Lutris "+" →
"Install script"), but when it asks for an install location, browse to
your **existing** MTGO folder instead of accepting a new one. It applies
exactly one winetricks verb (`renderer=gdi`) to that folder and nothing
else. Afterward, remove the temporary "MTGO Renderer Fix" entry Lutris
creates (right-click → Remove, without deleting files) and keep using your
real game entry. The same pattern works for any other single verb — copy
`fix-renderer.yml`, change the `app:` line under `installer:` to the verb
you need (e.g. `sound=disabled`), and install it into your existing folder
the same way.

If your game's Lutris library entry itself gets removed (its files are
still on disk, you just lost the entry), use `reconnect.yml` the same
way — point it at the existing folder — to recreate the entry with no
winetricks steps at all.
