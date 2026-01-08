# AGENTS.md

## Project: Dynamic “Night Light” via DDC/CI on Raspberry Pi 5 (Ubuntu 24.04)

### Purpose
Provide a **system-wide, dynamic warm tint at night** (and neutral color during the day) on a **Raspberry Pi 5 running Ubuntu 24.04 GNOME**, in cases where **GNOME Night Light cannot function** due to missing DRM/KMS color pipeline support (no `GAMMA_LUT`/`CTM` exposure on `vc4`).

Instead of relying on GNOME’s compositor/driver path, this project drives the **monitor’s own color controls** via **DDC/CI** using `ddcutil`, and schedules day/night transitions using `sunwait` + `systemd`.

### High-level Design
- **Color shift mechanism:** Monitor firmware settings over DDC/CI.
  - Use VCP codes:
    - `0x14` Select color preset (monitor is on “User 1” = `0x0b`)
    - `0x16` Red gain
    - `0x18` Green gain
    - `0x1A` Blue gain
- **Scheduling mechanism:** `sunwait` provides sunrise/sunset calculations using lat/lon.
- **Execution mechanism:** A persistent `systemd` service runs a loop that:
  1. Determines if it’s currently day/night (`sunwait poll`)
  2. Applies the corresponding monitor mode
  3. Blocks until the next event (`sunwait wait rise/set …`)
  4. Repeats

### Rationale / Constraints
- GNOME Night Light requires a programmable gamma/CTM path in the kernel driver stack.
- On this system, the `vc4` DRM node does **not** expose the needed properties:
  - `modetest -M vc4 -c | grep -E 'GAMMA_LUT|CTM|DEGAMMA_LUT'` returns none.
- Xorg fallback mechanisms are also ineffective:
  - `xrandr --gamma …` produces no visible change.
- However, the connected LG display supports DDC/CI, verified by:
  - `ddcutil detect` showing an active I2C bus and VCP version.

This project assumes:
- A monitor/TV that actually supports DDC/CI over the active HDMI input.
- The Pi runs 24/7 (or at least is on near the transition times).
- Latitude/longitude are correctly configured.

---

## Components

### 1) Day/Night Monitor Scripts
Two scripts live in `/usr/local/bin/`:

#### `/usr/local/bin/monitor-day`
Sets a neutral baseline:
- R = 50
- G = 50
- B = 50
- Color preset = User 1 (0x0b) when supported

#### `/usr/local/bin/monitor-night`
Applies a warm tint by reducing green/blue:
- R = 50
- G = 10
- B = 0
- Color preset = User 1 (0x0b) when supported

These values are tuned for the specific LG “LG FHD” display in use.

**Manual test:**
- `sudo /usr/local/bin/monitor-day`
- `sudo /usr/local/bin/monitor-night`

### 2) Configuration File
`/etc/default/monitor-sun`

Fields:
- `LAT` / `LON`
  - Format like `40.7128N` and `74.0060W` (N/S/E/W suffix).
- `TWILIGHT`
  - Typically `daylight` (can be changed based on preference).
- `OFFSET`
  - Offset used to bias the transition time (can be `0` / `+0:00:00`).

### 3) Scheduler Loop Script
`/usr/local/bin/monitor-sun-loop`

Responsibilities:
- Ensure it can access I2C (`modprobe i2c-dev`)
- Ensure a sane `PATH` when run under systemd
- Determine current state with `sunwait poll`
- Apply `monitor-day` or `monitor-night`
- Block until the next transition using `sunwait wait rise` or `sunwait wait set`

Key requirement:
- Must use **blocking** `sunwait wait` mode, not a non-blocking mode, otherwise it will flip rapidly.

### 4) systemd Service
`/etc/systemd/system/monitor-sun.service`

Runs the loop continuously:
- `ExecStart=/usr/local/bin/monitor-sun-loop`
- `Restart=always`

Enable/start:
- `sudo systemctl daemon-reload`
- `sudo systemctl enable --now monitor-sun.service`

Check:
- `systemctl status --no-pager monitor-sun.service`
- `journalctl -u monitor-sun.service -n 100 --no-pager`

### 5) Packaging and APT Repo
Scripts in the repo root:
- `build-deb.sh` builds `build/rpi-night-light_<version>_all.deb`.
- `build-apt-repo.sh` generates an APT repo in `apt/`.
- `build-and-publish-apt-repo.sh` builds a fresh `.deb`, regenerates `apt/`, and pushes it to `gh-pages`.

---

## Operating Procedures

### Installation / Dependencies
Required packages:
- `ddcutil`
- `i2c-tools` (helpful for debugging)
- `sunwait`

Kernel module:
- `i2c-dev` (loaded by the loop script)

### Verify DDC/CI Works
1. Detect display:
   - `sudo ddcutil detect`
2. Confirm a change works (brightness as a safe test):
   - `sudo ddcutil setvcp 10 40`
   - `sudo ddcutil setvcp 10 70`

### Tune Night Tint
Current “night” tuning:
- Blue gain `0`
- Green gain `10`

If warmer is needed:
- Reduce green further (if possible), or increase red gain.
If too warm:
- Raise blue and/or green.

Read current gains:
- `sudo ddcutil getvcp 16 --display 1`
- `sudo ddcutil getvcp 18 --display 1`
- `sudo ddcutil getvcp 1A --display 1`

### Switch HDMI Ports
DDC/CI is per connector. Confirm detection on either port:
- `sudo ddcutil detect`
Note the connector changes (e.g., `card1-HDMI-A-1` vs `card1-HDMI-A-2`) and the I2C bus number.

If multiple displays are connected, use `--display N` accordingly and update scripts to select the correct display index.

---

## Failure Modes & Troubleshooting

### A) “GNOME Night Light enabled but no visible change”
Expected on this platform: kernel driver lacks LUT/CTM.

Confirm:
- `sudo modetest -M vc4 -c | grep -E 'GAMMA_LUT|CTM|DEGAMMA_LUT' || echo none`

### B) Service flaps/restarts (exit code 127)
Cause: missing PATH under systemd or missing binary.
Fixes:
- Ensure the loop script sets:
  - `PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin`
- Verify:
  - `command -v sunwait`
  - `command -v modprobe`

### C) Service toggles modes rapidly
Cause: `sunwait` invoked in a non-blocking way.
Fix:
- Use `sunwait wait rise ...` and `sunwait wait set ...` correctly so it blocks.

### D) DDC/CI works interactively but not in service
Common causes:
- I2C permissions / module not loaded
- Running before the display is ready after boot
Mitigations:
- Ensure `modprobe i2c-dev` runs
- Consider adding a short sleep at service start
- Confirm `ddcutil detect` works as root non-interactively

### E) Monitor ignores color VCP writes
Some displays only allow certain controls in certain modes.
Mitigation:
- Force a known preset (`0x14 = User 1`) before writing gains
- Verify capabilities:
  - `sudo ddcutil capabilities --display 1`

---

## Notes for Future Improvements
- Add multi-display support by mapping DRM connector -> display index.
- Add a “current state cache” to avoid reapplying values repeatedly.
- Add a configurable “night profile” in `/etc/default/monitor-sun` rather than hard-coded gains.
- Add optional “fade” (stepwise changes over ~30–60s) to avoid abrupt shifts.
- Add `OnBootSec=` delayed start via a timer or `ExecStartPre=/bin/sleep 10` to avoid early-boot DDC failures.

---

## Security / Safety Considerations
- This project operates via **monitor firmware controls**, not kernel gamma tables.
- It should not affect Home Assistant or other services beyond minimal I2C/DDC access.
- DDC/CI writes are generally safe, but avoid aggressive values that could make the display unusable (keep a known-good day script).
- Keep manual recovery:
  - `sudo /usr/local/bin/monitor-day` should always restore a usable picture.

---

## Quick Reference
- Day mode:
  - `sudo /usr/local/bin/monitor-day`
- Night mode:
  - `sudo /usr/local/bin/monitor-night`
- Service:
  - `sudo systemctl restart monitor-sun.service`
  - `journalctl -u monitor-sun.service -n 100 --no-pager`
- Detect display:
  - `sudo ddcutil detect`
- Verify monitor supports needed VCP features:
  - `sudo ddcutil capabilities --display 1`
