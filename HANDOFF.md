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

Install MTGO via `magic-the-gathering-online.yml`, click Play in Lutris, and have
MTGO reach a stable, usable login screen — one that stays open (doesn't crash
within, say, 2 minutes of idling on it). You do not need to actually log in
(no credentials are available to you, and none are needed to fix this — every
failure so far happens before/during login-window startup, not because of
anything account-specific).

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

5. If you exhaust all of the above without success: write up everything tried
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
