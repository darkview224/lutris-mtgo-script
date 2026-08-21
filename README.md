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

## 2. Download the MTGO installer

Go to **https://www.mtgo.com/en/mtgo/download** in your browser and download
`setup.exe`. Let it save to your normal Downloads folder — you'll pick the
file from inside Lutris in step 5, so its exact location doesn't matter.

## 3. Get this repo's installer script

```
git clone https://github.com/darkview224/lutris-mtgo-script.git
```

You now have `lutris-mtgo-script/magic-the-gathering-online.yml`.

## 4. Install a GE-Proton/Wine-GE runner build

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

## 5. Run the installer

1. In Lutris, click the **+** button (top left) → **Install script**.
2. Browse to `lutris-mtgo-script/magic-the-gathering-online.yml` from step 3
   and select it.
3. When prompted for the setup file, browse to the `setup.exe` you
   downloaded in step 2.
4. Click through the installer. It will:
   - create a Wine prefix,
   - install fonts and .NET Framework 4.8 (this step takes a few minutes —
     let it finish, don't cancel it),
   - disable the Wine sound driver (see "Why sound is disabled" below),
   - run `setup.exe` to install the MTGO client itself.
5. When it finishes, MTGO is listed in your Lutris library as
   **Magic The Gathering Online**.

## 6. Set the game to use the GE-Proton/Wine-GE build

The installer doesn't pin a Wine version, so point it at the one you
installed in step 4:

1. Right-click **Magic The Gathering Online** in your library → **Configure**.
2. Go to the **Runner options** tab.
3. Set **Wine version** to the GE-Proton/Wine-GE build you installed.
4. Click **Save**.

## 7. Play

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
- **Game won't launch / crashes immediately.** Double check step 6 — MTGO
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
skipping it and moving on.

Instead, use `fix-renderer.yml` from this repo the same way you installed
the main script (Lutris "+" → "Install script"), but when it asks for an
install location, browse to your **existing** MTGO folder instead of
accepting a new one. It applies exactly one winetricks verb
(`renderer=gdi`) to that folder and nothing else. Afterward, remove the
temporary "MTGO Renderer Fix" entry Lutris creates (right-click → Remove,
without deleting files) and keep using your real game entry.

The same pattern works for re-applying any single winetricks verb to an
existing install — copy `fix-renderer.yml`, change the `app:` line under
`installer:` to the verb you need (e.g. `sound=disabled`), and install it
into your existing folder the same way.
