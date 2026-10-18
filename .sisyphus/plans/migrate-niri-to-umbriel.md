# Migrate hurunagus image from Niri + DMS to Umbriel + Noctalia

## Goal

Replace the Niri compositor and Dank Material Shell (DMS) with **Umbriel** (scrolling
Wayland compositor) and **Noctalia v5** (its companion shell), swap dms-greeter for
**noctalia-greeter**, and fully rename the image identity from `hurunagus-ublue` to
`hurunagus-umbriel` (matching the repo name).

## Decisions (confirmed with user)

| Area | Decision |
|---|---|
| Shell | Noctalia v5 (Fedora 44 default repos) replaces DMS entirely |
| Greeter | noctalia-greeter (Terra) replaces dms-greeter; greetd stays |
| Naming | Full rename `hurunagus-ublue` → `hurunagus-umbriel` everywhere |
| DMS COPR extras | Drop dms/dsearch/dms-greeter/qt6ct-kde/dankcalendar-git; keep `tuned-ppd` from Fedora repos |

## Packaging facts (verified)

- `umbriel-nightly`, `xdg-desktop-portal-umbriel-nightly`, `noctalia-greeter` → **Terra repo**
  (`dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys`)
- `noctalia`, `tuned-ppd` → **Fedora 44 default repos**
- Xwayland binary: `xorg-x11-server-Xwayland` (Fedora) — Umbriel's wlroots Xwayland needs it on PATH
- Umbriel config search order includes `$XDG_CONFIG_DIRS` → a system-wide
  `/etc/umbriel/config.toml` works (no `-c` flag needed)
- Umbriel sessions start via `start-umbriel` (installed by the package, ships a
  wayland-sessions entry that greetd greeters pick up)

## File-by-file changes

### 1. `build_files/build.sh`

- **Line 16** package install: remove `niri`; keep the rest
  (`btop fastfetch foot greetd khal adwaita-fonts-all igt-gpu-tools nautilus firefox lm_sensors cups-pk-helper fprintd kf6-kimageformats`).
- **Lines 18–22** — delete the whole DMS COPR block. Replace with a Terra block
  following the same enable/install/disable pattern so Terra doesn't stay enabled
  on the final image (weekly image builds re-fetch latest nightly anyway):

  ```bash
  # Terra repo (umbriel-nightly, xdg-desktop-portal-umbriel-nightly, noctalia-greeter),
  # then disable so it doesn't stay enabled on the final image.
  dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release terra-gpg-keys
  dnf5 -y install umbriel-nightly xdg-desktop-portal-umbriel-nightly noctalia-greeter
  sed -i 's/^enabled=1/enabled=0/' /etc/yum.repos.d/terra*.repo

  # Noctalia shell + power profiles from Fedora repos
  dnf5 install -y noctalia tuned-ppd xorg-x11-server-Xwayland
  ```

- Keep `systemctl enable greetd.service` (line 29). Noctalia-greeter's packaging
  manages its own state dir; no extra services to enable (Noctalia runs as a user
  process autostarted by Umbriel).

### 2. `system_files/etc/niri/` → `system_files/etc/umbriel/`

- **Delete** the entire `system_files/etc/niri/` directory (config.kdl + `dms/`
  fragments — all niri/DMS-specific, including both `settings.json` copies of DMS keys).
- **Create** `system_files/etc/umbriel/config.toml` porting the *active* settings
  from the old `config.kdl`, following Umbriel's example config and the official
  Noctalia↔Umbriel integration guide
  (https://docs.noctalia.dev/umbriel + /noctalia/compositor-settings/umbriel/):

  ```toml
  [general]
  autostart = ["noctalia"]

  [environment]
  GTK_THEME = "Adwaita:dark"

  [input.keyboard]
  numlock_toggle = true

  [input.touchpad]
  # port: tap, natural-scroll (verify exact key names against
  # https://docs.noctalia.dev/umbriel/input/ during implementation)

  [input.focus]
  follows_mouse = true

  [appearance]
  prefer_no_csd = true
  border_width = 2
  corner_radius = 10

  [appearance.blur]
  enabled = true
  optimized = true
  passes = 3
  radius = 3

  [layout]
  gap = 16
  extent_presets = [0.333, 0.5, 0.75]

  [layout.scrolling]
  default_extent_fraction = 0.75

  [hot_corners.top_left]
  enabled = true
  delay_ms = 500
  action = "overview-open"

  [keybinds]
  # Terminal (foot is the installed terminal; niri config's alacritty bind was stale)
  "Mod+T" = { action = "spawn:foot", repeat = false }
  "Mod+Return" = { action = "spawn:foot", repeat = false }

  # Noctalia shell
  "Mod" = "spawn:noctalia msg panel-toggle launcher"
  "Mod+D" = "spawn:noctalia msg panel-toggle launcher"
  "Mod+Q" = { action = "window-close", repeat = false }
  "Mod+Escape" = "session-quit"
  "Mod+O" = { action = "overview-toggle", repeat = false }
  "Alt+Tab" = "spawn:noctalia msg window-switcher hold"

  # Media / volume / brightness via Noctalia (shows OSDs), safe while locked
  "XF86AudioRaiseVolume" = { action = "spawn:noctalia msg volume-up", allow_when_locked = true }
  "XF86AudioLowerVolume" = { action = "spawn:noctalia msg volume-down", allow_when_locked = true }
  "XF86AudioMute" = { action = "spawn:noctalia msg volume-mute", allow_when_locked = true, repeat = false }
  "XF86AudioPlay" = { action = "spawn:noctalia msg media toggle", allow_when_locked = true, repeat = false }
  "XF86AudioNext" = { action = "spawn:noctalia msg media next", allow_when_locked = true }
  "XF86AudioPrev" = { action = "spawn:noctalia msg media previous", allow_when_locked = true }
  "XF86MonBrightnessUp" = { action = "spawn:noctalia msg brightness-up", allow_when_locked = true }
  "XF86MonBrightnessDown" = { action = "spawn:noctalia msg brightness-down", allow_when_locked = true }

  # Focus / move (same vim-style muscle memory as the old niri config)
  "Mod+H" = "window-focus-left"
  "Mod+J" = "window-focus-down"
  "Mod+K" = "window-focus-up"
  "Mod+L" = "window-focus-right"
  "Mod+Left" = "window-focus-left"
  "Mod+Down" = "window-focus-down"
  "Mod+Up" = "window-focus-up"
  "Mod+Right" = "window-focus-right"
  "Mod+Shift+H" = "column-move-left"
  "Mod+Shift+L" = "column-move-right"
  "Mod+Shift+J" = "window-move-down"
  "Mod+Shift+K" = "window-move-up"

  # Window state (matches old niri binds: V=floating, F=maximize, W=tabs)
  "Mod+V" = { action = "window-toggle-floating", repeat = false }
  "Mod+F" = { action = "window-toggle-maximize", repeat = false }
  "Mod+Shift+F" = { action = "window-toggle-fullscreen", repeat = false }
  "Mod+W" = { action = "column-toggle-tabbed", repeat = false }
  "Mod+R" = "window-cycle-primary-extent"
  "Mod+Shift+R" = "window-cycle-primary-extent-back"
  "Mod+Comma" = "window-consume-left"
  "Mod+Period" = "window-consume-right"
  "Mod+BracketLeft" = "window-consume-or-expel-left"
  "Mod+BracketRight" = "window-consume-or-expel-right"
  "Mod+Minus" = "window-modify-primary-extent:-0.1"
  "Mod+Equal" = "window-modify-primary-extent:0.1"

  # Workspaces
  "Mod+1" = "workspace-switch:1"
  # ... Mod+2..9 same pattern
  "Mod+Shift+1" = "window-move-to-workspace:1"
  # ... Mod+Shift+2..9 same pattern

  # Scratchpad (new, from umbriel defaults)
  "Mod+Shift+Space" = { action = "window-move-to-scratchpad", repeat = false }
  "Mod+Space" = "scratchpad-toggle"

  # Screenshots: Noctalia owns these now (umbriel has no screenshot action;
  # portal screenshot goes through xdg-desktop-portal-umbriel)
  "Print" = "spawn:noctalia msg screenshot"
  # (verify exact noctalia screenshot IPC name against
  #  https://docs.noctalia.dev/noctalia/ipc/ during implementation)

  # Lock: Noctalia's lock screen (verify exact IPC, e.g. noctalia msg lock)
  "Super+Alt+L" = "spawn:noctalia msg lock"

  # Shortcuts inhibit + power
  "Mod+Shift+Escape" = { action = "shortcuts-inhibit-toggle", allow_when_inhibited = true, repeat = false }
  "Mod+Shift+P" = "dpms-off"

  # Noctalia extras
  "Mod+S" = "spawn:noctalia msg panel-toggle control-center"
  "Mod+Shift+A" = "spawn:noctalia msg screenshot-annotate"

  # Window rules
  [[window_rule]]
  blur = true

  [[window_rule]]
  match.title = "^(Picture-in-Picture|Picture in picture)$"
  default_floating = true
  default_maximize = false
  default_position = { x = 20, y = 20, anchor = "bottom_right" }

  [[window_rule]]
  match.app_id = "^dev.noctalia.Noctalia$"
  default_floating = true
  default_floating_size_px = { width = 1020, height = 900 }

  # Layer rules: Noctalia surfaces get blur
  [[layer_rule]]
  match.namespace = "^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd|desktop-widget-[^\"]*)$"
  blur = true
  blur_ignore_alpha = 0.5
  blur_popups = true

  [[layer_rule]]
  match.namespace = "^noctalia-(notification|dock|panel|attached-panel|osd)$"
  blur_optimized = false
  ```

  Notes:
  - The disabled `/-output "eDP-1"` block from the niri config stays out (it was
    already commented out; outputs are machine-specific).
  - `Mod+Shift+E { quit; }` from niri is dropped — umbriel's quit is
    `session-quit` on `Mod+Escape` with confirmation.
  - DMS-generated `dms/*.kdl` includes disappear with the directory; Noctalia needs
    no compositor-side fragments beyond the layer rules above.

### 3. greetd wiring — new `system_files/etc/greetd/config.toml`

The repo currently ships **no** greetd config (default greeter was never explicitly
wired). Ship one pointing at the noctalia-greeter session wrapper:

```toml
[terminal]
vt = 1

[default_session]
command = "noctalia-greeter-session"
user = "greeter"
```

(Confirm exact command path/packaging expectations against
https://docs.noctalia.dev/greeter/installation/ during implementation — the Terra
package may already drop config; if it does, skip this file.)

- **Delete** `system_files/usr/lib/tmpfiles.d/greetd-portal.conf` — it exists only to
  recreate a dms-greeter-specific portal symlink; noctalia-greeter ships its own
  tmpfiles drop-in.

### 4. Full rename `hurunagus-ublue` → `hurunagus-umbriel`

| File | Change |
|---|---|
| `image-template.env` | `IMAGE_NAME`, `ID`, `PRETTY_NAME` → `hurunagus-umbriel`; `IMAGE_DESC="Umbriel + Noctalia"` |
| `Containerfile` | sed targets lines 43–45: `NAME`, `PRETTY_NAME`, `VERSION_CODENAME` → `hurunagus-umbriel` (keep `DEFAULT_HOSTNAME="hurunagas33"`) |
| `README.md` | Badge URL (line 1), rebase URLs (lines 22, 30), intro text (line 5), section title (line 37) → Umbriel + Noctalia wording; **remove** the niri logo `<img>` (line 42); mark the screenshot as outdated (still shows Niri) or drop it until replaced |
| `disk_config/iso-gnome.toml`, `disk_config/iso-kde.toml` | `bootc switch` URLs → `ghcr.io/wegweg7979/hurunagus-umbriel:latest` |

Not renamed (unrelated personal branding): `DEFAULT_HOSTNAME`, wallpaper/branding
dirs (`usr/share/backgrounds/hurunagus`, `hurunagus-treasure`, background XMLs).

### 5. Leave alone

- `system_files/usr/share/hurunagus-treasure/dank/` — DMS-era archive, not
  installed by any build script; keep as historical (optional follow-up: prune).
- `Justfile`, `.github/workflows/*` — zero niri references; build-disk workflow
  derives image name from the GitHub repo name (already `hurunagus-umbriel`, so it
  aligns automatically after rename).
- `system-flatpaks.list`, backgrounds, logos, plymouth, sysctl, other services.

## Implementation order

1. `build_files/build.sh` — package + repo changes
2. Delete `system_files/etc/niri/`, write `system_files/etc/umbriel/config.toml`
3. greetd config + remove `greetd-portal.conf`
4. Rename in `image-template.env`, `Containerfile`, `README.md`, `disk_config/*.toml`
5. Verify (below)

## Verification

- `bash -n build_files/build.sh` (syntax)
- `grep -rni niri .` → expect hits only in `.sisyphus/`, `.git/`, and the
  untouched `hurunagus-treasure/dank/` archive
- `grep -rni hurunagus-ublue .` → expect zero hits outside `.git/`
- If podman is available: `just build` (full image build; catches Terra package
  name mistakes, bootc lint failures from removed tmpfiles, greetd config issues).
  Otherwise flag build verification for the user's next weekly build.
- Optionally validate `config.toml` with `umbriel config validate` inside a
  container with umbriel-nightly installed.

## Risks / follow-ups

- Umbriel is young ("configuration may change between releases"); nightly package
  means the image's WM can shift weekly — acceptable for this personal image.
- Exact Noctalia IPC names (`screenshot`, `lock`) and Umbriel touchpad key names
  must be confirmed against live docs during implementation.
- Existing installs rebasing must switch to the new
  `ghcr.io/wegweg7979/hurunagus-umbriel:latest` URL (README will document it);
  old `hurunagus-ublue` images stop updating once the repo publishes the new name.
- The README screenshot still shows the Niri desktop until the user replaces it.
