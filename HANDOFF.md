# Autonomous work order: fix the MTGO launch crash

You are a Claude Code session continuing unattended, unsupervised debugging work
on this repo. **The user is asleep and unavailable. Do not stop to ask questions
or wait for approval — make the most reasonable judgment call yourself, document
it in your commits, and keep going.** If you use `AskUserQuestion` or otherwise
pause for human input, you have failed the point of this session.

Work in small, committed, pushed increments so progress survives even if this
process gets killed (usage limit, crash, reboot) partway through. After every
meaningful change — a hypothesis tried, a fix applied, a finding confirmed or
ruled out — commit it and update this file's "Status" section below, then push.
A future run of this same loop (or the user, in the morning) needs to be able to
pick up exactly where you left off just by reading this file and `git log`.

## Target environment for this session

**Bazzite, with Lutris installed natively** (not Flatpak). This is the primary
target — Bazzite ships Lutris as a native package and is far more common than
Aurora (which needs Flatpak Lutris). Get it working here first. Once MTGO
launches reliably on native Lutris, port/verify on Aurora + Flatpak Lutris as a
secondary pass — the installer scripts themselves shouldn't need Flatpak-specific
changes (we already confirmed the main script installs and runs fine under a
native, non-Flatpak Lutris on a different test machine this session), but the
README's troubleshooting commands currently assume `flatpak run net.lutris.Lutris
...` wrappers that don't apply natively — fix those once the native path is
working, as part of finishing this out, not before.

## Goal / definition of done

The **only** thing that counts as success is: a completely clean machine state,
`magic-the-gathering-online.yml` — and nothing else — installs MTGO, and clicking
Play gets MTGO to a stable, usable login screen that stays open (doesn't crash
within, say, 2 minutes of idling on it). You do not need to actually log in (no
credentials are available to you, and none are needed — every failure so far
happens before/during login-window startup, not because of anything
account-specific).

**Any fix you find while experimenting must be folded back into
`magic-the-gathering-online.yml` itself** — as a new winetricks verb, a registry
tweak added to `mtgo-tune.sh`, a different runner default, whatever it takes —
not left as a separate repair script (`fix-renderer.yml` and friends) that has to
be run afterward. Those repair scripts exist only to patch an *existing*,
already-broken install without a full reinstall (because of the winetricks
already-applied-verb footgun) — they are debugging conveniences, not part of the
shipped solution. If a fix only exists in one of those files when you think
you're done, you are not done: port it into the main installer.

**Before declaring success, run the actual acceptance test:**
1. Fully remove MTGO — delete the Lutris library entry (with files) and confirm
   the install directory is actually gone (`ls` it, don't just trust the Lutris
   UI).
2. Install *only* by running `magic-the-gathering-online.yml` fresh — no repair
   scripts, no manual `wine reg add` commands, no manually toggling checkboxes in
   winecfg. If reaching the login screen requires any manual step beyond what the
   installer script and a normal Play click do, the work isn't finished — that
   step needs to be automated into the script (e.g. via a `write_file` +
   `wineexec`/`execute` task, the same pattern `mtgo-tune.sh` already uses).
3. Click Play. Confirm the login screen appears and survives ~2 minutes idle.
4. Only once that single-script, from-scratch run succeeds, update this file's
   Status section to say so, commit, and push.

## Repo layout

- `magic-the-gathering-online.yml` — main Lutris installer. Downloads setup.exe,
  installs corefonts/dotnet48, `sound=disabled`, `renderer=gdi`, deploys MTGO,
  writes `mtgo-tune.sh` as a pre-launch hook that patches `MTGO.exe.config`.
- `fix-renderer.yml`, `reconnect.yml`, `open-winecfg.yml` — one-off repair
  scripts. Install these *pointed at an existing game folder* (Lutris will ask
  for an install directory — browse to the existing one instead of accepting a
  new default) to apply one targeted change without re-running the whole chain.
- `README.md` — step-by-step install instructions + troubleshooting.

**Known Lutris footgun:** re-running any installer script against a folder that
already has something installed hard-aborts the whole install chain the instant
winetricks hits an already-applied verb ("winetricks verb 'X' is already
installed" → exit 256) — it does NOT just skip and continue. Never reinstall
over an existing folder. Either wipe it first, or use one of the targeted repair
scripts above.

## Status

*(Update this section as you make progress. Most recent entry at the top.)*

### [2026-08-28 ~20:00 — autonomous session on Bazzite native Lutris]

Environment confirmed: Bazzite 44 Kinoite, native Lutris/umu-run/winetricks,
GE-Proton11-4 installed (not 11-5). GUI available via KWin Wayland
(`WAYLAND_DISPLAY=wayland-0`, Xwayland `DISPLAY=:0`,
`XAUTHORITY=/run/user/1000/xauth_ZArEBO`); screenshots via ImageMagick `import`
or `spectacle`, `xdotool` present.

**Found an actively-maintained reference project that reaches the MTGO login
screen:** [phever/mtgo-linux](https://github.com/phever/mtgo-linux) (cloned to
`/tmp/mtgo-linux`). Verified working 2026-06-24 on Arch, GE-Proton11-1 + Lutris
0.5.22. Its recipe vs. ours:
- corefonts + dotnet48, sound=disabled — same as us.
- **Does NOT use `renderer=gdi`.** (We added it; may have been compensating for
  an ntsync-induced render failure rather than a real need.)
- **`PROTON_NO_NTSYNC=1`** as a game env var. Their notes: GE-Proton11's new
  in-kernel ntsync convoys MTGO's threads on locks with delayed wakeups. This is
  exactly the failure mode of our crash — an unhandled `Win32Exception` in
  `HwndWrapper.DestroyWindow` during `Dispatcher.ShutdownImpl()` is a
  thread-synchronization / wakeup failure. Our build logs are full of
  "ntsync: up and running." **Primary hypothesis: `PROTON_NO_NTSYNC=1` fixes the
  crash.**
- Same 4 WPF flags (DisableAutomationPeer etc.) via a per-launch tune script —
  same as our `mtgo-tune.sh`.

**Plan:** rebuilding a clean direct-debug prefix at `~/mtgo-test/` (corefonts
dotnet48 sound=disabled renderer=gdi via `umu-run winetricks`), then test
`setup.exe` launch with `PROTON_NO_NTSYNC=1`. Helper scripts:
`~/mtgo-test/build.sh`, `~/mtgo-test/run-setup.sh <tag> [ENV=val ...]`.
If `PROTON_NO_NTSYNC=1` reaches a stable login screen, fold it into
`magic-the-gathering-online.yml`'s `system: env:` block (the reference does
exactly this) and run the full acceptance test via the Lutris GUI.

**Progress (20:10):** clean `~/mtgo-test/prefix` built OK (corefonts, dotnet40,
dotnet48, sound=disabled, renderer=gdi). Ran `setup.exe` via umu-run directly
(`~/mtgo-test/run.sh`). Notes:
- Direct debug needs `setup.exe` copied into the prefix dir (Lutris's installer
  already does this via its `copy` step; `run.sh` handles it).
- ClickOnce shows an **"Application Install - Security Warning"** dialog that
  renders as a blank white window (WPF/GDI paint issue) but is functional:
  `xdotool key --window <id> alt+i` accepts it ("Install" mnemonic). This is the
  same click the README already tells users to do ("click through the
  installer") — no installer change needed, just be aware the dialog may not
  paint.
- After Alt+I: "(0%) Installing Magic The Gathering Online" — ~640 MB client
  download now in progress.
- GUI automation on this box: physical output not compositing to a visible
  desktop (full-screen `spectacle` returns blank), BUT `spectacle -b -n -a`
  (active window) after `xdotool windowactivate <id>` DOES capture individual
  windows. `xdotool key/windowactivate` work. `import -window` does NOT.

### [initial state — read this first]

Install completes successfully every time: corefonts, dotnet48,
`sound=disabled`, `renderer=gdi` all apply, `setup.exe` downloads and deploys
MTGO via ClickOnce fine.

**Unresolved problem:** on launch, MTGO.exe starts, several windows briefly
appear, then all windows abruptly close while the Wine process tree keeps
running in the background (Lutris shows "Stop" not "Play" — looks alive, shows
nothing).

**Root cause identified** (captured via `WINEDEBUG=+process,+module`, piped
through `tee` to a file — the raw log is 70k+ lines, terminal scrollback alone
is not enough, always redirect to a file): MTGO's own entrypoint
(`Shiny.App.Main()`) throws an unhandled `System.ComponentModel.Win32Exception`
inside `MS.Win32.HwndWrapper.DestroyWindow`, called from
`System.Windows.Threading.Dispatcher.ShutdownImpl()`. WPF is tearing down one of
its own windows (normal — MTGO opens/closes several during startup) and the
native `DestroyWindow()` call itself fails under Wine; WPF doesn't handle that
failure and the whole process dies. It's a clean/controlled CLR exit (calls
`NtTerminateProcess` itself, HRESULT `0x80131506`), not an external kill — this
matters, it means no crash dump, no dmesg entry, no OOM signature to find; you
have to catch it via `WINEDEBUG` tracing.

There was only ONE exception in the captured log — this is a first-cause crash,
not a symptom of something earlier.

**Suspicious clue, not yet followed up on:** the crash instruction address
(`kernelbase+0xd977`, disassembles to `addq $0xc8, %rsp`) is bit-for-bit
identical to an unrelated crash seen earlier in a completely different process
(`xalia.exe`, GE-Proton's bundled accessibility-bridge helper, crashing in
`Xalia.Sdl.SdlSynchronizationContext`). Two unrelated processes hitting the
identical native offset in `kernelbase.dll` suggests a shared root cause in
Proton/Wine's `kernelbase.dll` itself, not something MTGO-specific.
`UIAutomationCore.dll` was loaded in the crashing MTGO process (visible in its
module list at crash time) — plausibly the actual common culprit, since Wine's
UI Automation implementation is known to be incomplete.

**Ruled out:**
- OOM (30GB RAM, 22GB free at crash time).
- Bad filesystem (native btrfs, confirmed via `findmnt`, not NTFS/exFAT).
- External kill / segfault (dmesg/journal show nothing at all — consistent with
  the clean CLR-initiated exit above).
- "Emulate a virtual desktop" in winecfg's Graphics tab (`open-winecfg.yml`
  reaches this directly since Lutris's own Runner-options UI doesn't expose it
  for Proton-based runner entries) — enabled it, no change.

**Fixes already in the installer, confirmed needed but not sufficient alone:**
- `sound=disabled` — separate, well-documented MTGO/Wine sound-crash issue.
- `renderer=gdi` — fixes a *different*, earlier bug (MTGO's WPF UI never
  rendering any window at all). Confirmed necessary — after adding it, MTGO's
  windows started appearing for the first time. Sourced from
  [pauleve/docker-mtgo](https://github.com/pauleve/docker-mtgo)'s own Wine setup.
- `mtgo-tune.sh` pre-launch hook — patches `DisableAutomationPeer`,
  `PurgeAutomationEvents`, `DisableStylusInput`, `DisableTabletDevices` in
  `MTGO.exe.config` to stop WPF's UI-Automation peer from pinning a CPU
  core/freezing the collection view (a different, later-stage bug than the one
  we're chasing now). **Unverified whether it's ever actually had anything to
  patch yet** — `MTGO.exe.config` may not exist until MTGO has run at least once,
  and every attempt so far has crashed before that could be confirmed.

## Next steps, in rough priority order

1. **Check whether `MTGO.exe.config` exists yet and whether the patch applied:**
   ```
   find "<install dir>" -iname "MTGO.exe.config"
   grep -E "DisableAutomationPeer|PurgeAutomationEvents|DisableStylusInput|DisableTabletDevices" "<path found>"
   ```
   If it didn't exist before the last crash but does now, try Play again before
   anything else — the pre-launch hook will patch it this time and behavior may
   change.

2. **Try suppressing Wine's UI Automation bridge entirely** (not just MTGO's own
   automation peer) — `UIAutomationCore.dll` is loaded in the crashing process.
   Experiment with disabling it via `WINEDLLOVERRIDES=uiautomationcore=` (or the
   equivalent winetricks override verb if one exists) and see if the crash
   changes or goes away. This is a genuine hypothesis from the loaded-module
   evidence in the crash trace, not a guess.

3. **Try a different Wine/Proton build.** The bug may be specific to
   `GE-Proton11-5-x86_64` (wine-11.0-staging base). Install an older GE-Proton
   build, or a plain Wine-GE (non-Proton) build, via Lutris's Runner Manage
   Versions, and re-point the game at it (Configure → Runner options → Wine
   version) to test whether this is version-specific.

4. Whatever you try, **re-verify with a fresh `WINEDEBUG=+process,+module` trace**
   using the reproduction command below (piped to a file, not just terminal
   scrollback), and check whether the exception signature changed at all before
   concluding a fix worked or didn't.

5. As soon as any experiment actually gets to a stable login screen, **stop
   experimenting in the live prefix and go make the same change in
   `magic-the-gathering-online.yml` itself**, then run the full acceptance test
   from "Goal / definition of done" above before considering it fixed. A fix
   that only exists as a manual step you did by hand, or as a one-off repair
   script, is not done yet.

6. If you exhaust all of the above without success: write up everything tried
   and every finding into this Status section, commit and push, and stop. Don't
   spin on unproductive repetition — a clear, well-documented dead end is a
   useful outcome too.

## Reproduction command (bypasses Lutris, for direct terminal debugging)

Adjust `WINEPREFIX` and `PROTONPATH` to match your actual install directory and
installed GE-Proton path (find the latter under
`~/.local/share/Steam/compatibilitytools.d/` or wherever Lutris installed it).

```
WINEDEBUG=+process,+module \
WINEPREFIX=<install dir> \
GAMEID=umu-default \
PROTONPATH=<path to GE-Proton install> \
umu-run <install dir>/setup.exe 2>&1 | tee ~/mtgo-debug.log
```

Then to find the actual exception details without wading through the whole
(huge) file:
```
grep -n -B5 -A40 "err:eventlog:ReportEventW\|Unhandled exception" ~/mtgo-debug.log | less
```

**Note:** setting `WINEDEBUG` via Lutris's own "Environment variables" UI field
did NOT take effect in earlier testing (the launched process still showed
`WINEDEBUG=-all` regardless). Always use the direct terminal command above for
anything needing Wine debug flags — don't rely on Lutris's env var UI for this.

## Git workflow

Develop on `claude/mtgo-lutris-aurora-oiwfn8`, merge fast-forward into `main`
after each push (this repo has no PR review gate — both branches should always
match). Push after every meaningful commit, don't batch up a long session of
uncommitted work.
