# My Linux game streaming and remote desktop solution
Run a full KDE Pasma session in polaris's Private Stream (https://github.com/papi-ux/polaris)

# Installation
### Dependencies
- [Polaris](https://github.com/papi-ux/polaris)
- labwc
- KDE Plasma Wayland
- xwayland
- dbus
- zenity

### Installation steps
1. [Install polaris](https://github.com/papi-ux/polaris) and all dependencies.
2. Enable linger for your user: `loginctl enable-linger`.
3. Setup polaris for headless acess: `sudo -H polaris --setup-host --enable-kms --enable-headless-boot`.
4. Enable polaris service `systemctl --user enable --now polaris`.
5. Reboot.
6. Go to `https://localhost:47990/` and create an account.
7. Select `Private Stream` from `Polaris Web UI > Settings > Audio/Video`.
8. Save `plasma.sh`(from the repo) and make it executable.
9. Add `plasma.sh` as an app in `Polaris Web UI > Library > Add New`.
    1. Set `Application Name` to `Plasma`.
    2. Set `Command` to the full path to `plasma.sh`.
    3. Set `Working Directory` to `$HOME`.
10. Add a Moonlight/Nova client from `Polaris Web UI > Devices`.
11. Open the `Plasma` app from your client.
<details>
<summary>Optional: run polaris with its own pipewire socket for audio isolation.</summary>
    
Run polaris using the following script:

```
#!/usr/bin/env bash
set -e
ALT="$XDG_RUNTIME_DIR/pw-polaris"
BUS="$ALT/bus"
mkdir -p "$ALT" && chmod 700 "$ALT"

# Private session bus
dbus-daemon --session --fork --nopidfile --address="unix:path=$BUS"

# Export and run services
export DBUS_SESSION_BUS_ADDRESS="unix:path=$BUS"
export XDG_RUNTIME_DIR="$ALT"
export PULSE_SERVER="unix:$ALT/pulse/native"
pipewire &
sleep 1
wireplumber &
pipewire-pulse &
sleep 1

# Run polaris
polaris
```

</details>

# Troublesooting
<details>
<summary><strong>Mouse capture.</strong></summary>

Some games that capture the mouse for in-game camera movement may not capture it correctly, preventing the camera from moving. This is a known issue that is currently being addressed.

**Temporary workaround:** When a game needs to capture the mouse, press the **Right Ctrl** key while the stream is focused.
</details>
<details>
<summary><strong>Fullscreen Video Unfullscreening on Chromium browsers.</strong></summary>

Package manager installed browsers are now managed automatically.

For Flatpak browsers, ensure the browser's `.desktop` file uses `Exec=flatpak` instead of `Exec=/usr/bin/flatpak`. If needed, apply one of these fixes:

- **Manual:** Replace all occurrences of `Exec=/usr/bin/flatpak` with `Exec=flatpak` in the browser's `.desktop` file.
- **System-wide install:** `sudo FLATPAK_BINARY="flatpak" flatpak install <appid>`
- **User install:** `FLATPAK_BINARY="flatpak" flatpak install --user <appid>`

<details>
<summary>See old fix here</summary>
When watching videos in Chromium based browser through the stream, toggling fullscreen immediately unfullscreens the video again. This does not happen when GPU acceleration is disabled entirely, and is fixed by disabling GPU compositing with `--disable-gpu-compositing`.

1. **Set the flag via config file (try first).**

    **Chromium:** `echo '--disable-gpu-compositing' >> ~/.config/chromium-flags.conf`
   
    **Google Chrome:** `echo '--disable-gpu-compositing' >> ~/.config/chrome-flags.conf`
   
    **Brave:** `echo '--disable-gpu-compositing' >> ~/.config/brave-flags.conf`

    *(Or use `~/.var/app/<AppID>/config/<browser>-flags.conf` for browsers installed trough flatpak)*

2. **Check if it worked.**

   Restart the browser fully (quit all windows/processes).
   
   Open the browser's internal GPU page and confirm the flag is active:

   Go to `chrome://gpu`

   Check "Graphics Feature Status" for GPU compositing showing as disabled/software only.

4. **If it didn't work: edit the `.desktop` file for your browser.**

    Some distro packaging doesn't source the `*-flags.conf` file automatically. In that case, edit the launcher's `Exec=` line directly.

    First, copy the relevant `.desktop` file to your local overrides directory (editing the one in `/usr/share/applications/` directly will get overwritten on package updates):

    ```
    mkdir -p ~/.local/share/applications
    cp /usr/share/applications/chromium.desktop ~/.local/share/applications/
    # or: brave-browser.desktop / google-chrome.desktop, depending on which browser
    ```

    Then edit the `Exec=` line in the copied file to include the flag before `%U`, for example:

    ```
    Exec=/usr/bin/chromium --disable-gpu-compositing %U
    ```

    Save, then re-run the check in Step 2.
</details>
</details>
