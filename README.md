# MTGO for Linux (by Lutris script)

Installs Magic: The Gathering Online on computers running Linux OS — no
manual Wine setup needed.

**Status:** Confirmed working — clean install through a full played match —
on Bazzite (with Lutris installed natively) by developer, and on Lutris
installed as a Flatpak by other users. Sound is currently not functional.
See [docs/DESIGN-NOTES.md](docs/DESIGN-NOTES.md) for details,
troubleshooting, and known issues. Built with
[Claude Code](https://claude.com/claude-code).

## 1. Install Lutris (skip if you already have it)

Some distros (e.g. Bazzite) ship Lutris already — check your app menu first.
Otherwise, install it from **[lutris.net/downloads](https://lutris.net/downloads)**,
which covers native packages for most major distros as well as Flatpak.

## 2. Get this repo's installer script

You just need the one file, `magic-the-gathering-online.yml`. The script
downloads MTGO's `setup.exe` for you — no separate manual download needed.

**Easiest way:** right-click this link and choose "Save Link As" (or
similar) to download it directly:
[magic-the-gathering-online.yml](https://raw.githubusercontent.com/darkview224/lutris-mtgo-script/main/magic-the-gathering-online.yml)

**Or, if you're comfortable with git:**

```
git clone https://github.com/darkview224/lutris-mtgo-script.git
```

which gives you `lutris-mtgo-script/magic-the-gathering-online.yml`.

## 3. Run the installer

1. In Lutris, click the **+** button (top left) → **Install script** (Flatpak
   Lutris calls this "Install game from a local file").
2. Browse to wherever you saved `magic-the-gathering-online.yml` and select
   it.
3. Click **Install**, then **Continue** to accept the default install
   directory (`~/Games/magic-the-gathering-online`). **It must not already
   exist** — if you're redoing an install, delete the old folder first.
4. Click **Install** on the file list, then let it run — including a step
   that installs .NET Framework 4.8, which **takes several minutes with no
   visible progress**. Let it finish; don't cancel it.
5. When it says **Installation completed!**, click **Close**. MTGO is now in
   your Lutris library as **Magic The Gathering Online**.

You do not need to install a Wine/Proton runner or set a Wine version
yourself — Lutris handles that automatically (see **Troubleshooting** below
if that step fails).

## 4. Play

Click **Play**.

**The first launch** shows an **"Application Install - Security Warning"**
window — click **Install** (this window sometimes renders blank; the button
is still there at the bottom, or press **Alt+I**). It then downloads and
sets up the ~640 MB client and opens the MTGO login screen. This first
launch takes a while — leave it be.

**Every later launch** opens MTGO directly.

## Troubleshooting

**Installer fails immediately with "ERROR: ... is not empty."** This means
the folder Lutris wants to install into already has something in it, either
from a previous install of this script or from files left behind after a
failed attempt. The installer refuses to run into a folder that isn't empty,
because Lutris treats a step that's already been applied (like a winetricks
verb) as a hard failure rather than something to skip, so a second run into
the same folder wouldn't get you a clean result anyway. If you're redoing an
install, remove the existing game from your Lutris library first (right-click
it, choose **Remove**, and tick the box to also delete files), and confirm
the folder — `~/Games/magic-the-gathering-online` by default — is actually
gone before running the installer again. If there's no library entry to
remove, just delete the folder's contents by hand.

**Installer fails on the Wine/GE-Proton setup step, right at the start.**
This script defaults to GE-Proton, which works well on most systems, but
some Linux distributions or versions of Lutris have trouble resolving it, and
the install fails before anything else runs. If that happens, open
`magic-the-gathering-online.yml` in a plain text editor and find the `wine:`
section near the top of the `script:` block. It has two `version:` lines: one
reading `version: ge-proton`, and below it, commented out, one reading
`version: wine-staging-x86_64`. Add a `#` to the front of the `ge-proton`
line to disable it, then remove the `#` from the front of the
`wine-staging-x86_64` line to enable it instead. Save the file and run the
installer again — this switches the runner to wine-staging, an alternative
that's compatible with a wider range of systems.

---

Something not working as described above? See
[docs/DESIGN-NOTES.md](docs/DESIGN-NOTES.md) for troubleshooting steps and
recovery scripts.
