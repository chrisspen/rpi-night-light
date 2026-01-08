# rpi-night-light

Dynamic monitor day/night color temperature control for Raspberry Pi using DDC/CI + sunwait.

## Quick install (script)

```sh
sudo ./install.sh
```

If `sunwait` isn't available via apt on your distro, the installer will build it from source.

Then edit:

```sh
sudo nano /etc/default/monitor-sun
```

You can also set RGB gains and optional brightness levels there.

Restart if needed:

```sh
sudo systemctl restart monitor-sun.service
```

## Debian package

Build a .deb on the Pi:

```sh
./build-deb.sh
```

Install it:

```sh
sudo dpkg -i build/rpi-night-light_*.deb
```

If `sunwait` isn't available via apt, the package post-install will build it from source.
The .deb pulls `build-essential`, `curl`, and `ca-certificates` so the build works without invoking apt inside the postinst.

## APT repo (GitHub Pages)

Generate a simple APT repo from your .deb:

```sh
./build-apt-repo.sh build/rpi-night-light_*.deb
```

Publish `apt/` to GitHub Pages (recommended: `gh-pages` branch) and enable Pages in the repo settings.

Update the APT repo (build .deb, regenerate `apt/`, push to `gh-pages`):

```sh
./build-and-publish-apt-repo.sh
```

Client install:

```sh
echo \"deb [trusted=yes] https://chrisspen.github.io/rpi-night-light/apt ./\" | sudo tee /etc/apt/sources.list.d/rpi-night-light.list
sudo apt update
sudo apt install rpi-night-light
```

## Manual test

```sh
sudo /usr/local/bin/monitor-day
sudo /usr/local/bin/monitor-night
```
