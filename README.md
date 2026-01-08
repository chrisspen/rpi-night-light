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

## Manual test

```sh
sudo /usr/local/bin/monitor-day
sudo /usr/local/bin/monitor-night
```
