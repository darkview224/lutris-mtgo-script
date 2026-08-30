# MTGO for Linux (by Lutris script)

Installs Magic: The Gathering Online on computers running Linux OS — no
manual Wine setup needed.

**Status:** built with [Claude Code](https://claude.com/claude-code).
Confirmed working — clean install through a full played match — on
**Bazzite with Lutris installed natively**. **Not yet confirmed working with
Lutris installed as a Flatpak** — install completes, but a few issues are
still open there. See [docs/DESIGN-NOTES.md](docs/DESIGN-NOTES.md) for
details, troubleshooting, and known issues.

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
yourself — Lutris handles that automatically.

## 4. Play

Click **Play**.

**The first launch** shows an **"Application Install - Security Warning"**
window — click **Install** (this window sometimes renders blank; the button
is still there at the bottom, or press **Alt+I**). It then downloads and
sets up the ~640 MB client and opens the MTGO login screen. This first
launch takes a while — leave it be.

**Every later launch** opens MTGO directly.

---

Something not working as described above? See
[docs/DESIGN-NOTES.md](docs/DESIGN-NOTES.md) for troubleshooting steps and
recovery scripts.
