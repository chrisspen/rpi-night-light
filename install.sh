#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

build_sunwait() {
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  echo "Building sunwait from source..."
  apt-get install -y build-essential ca-certificates curl
  curl -fsSL "https://github.com/risacher/sunwait/archive/refs/heads/master.tar.gz" -o "$tmpdir/sunwait.tar.gz"
  tar -xzf "$tmpdir/sunwait.tar.gz" -C "$tmpdir"
  make -C "$tmpdir/sunwait-master"
  install -m 0755 "$tmpdir/sunwait-master/sunwait" /usr/local/bin/sunwait
}

missing_bins=()
for bin in ddcutil sunwait i2cdetect; do
  if ! command -v "$bin" >/dev/null 2>&1; then
    missing_bins+=("$bin")
  fi
done

if [[ ${#missing_bins[@]} -gt 0 ]]; then
  if command -v apt-get >/dev/null 2>&1; then
    echo "Installing dependencies: ddcutil sunwait i2c-tools"
    apt-get update

    if ! command -v ddcutil >/dev/null 2>&1; then
      apt-get install -y ddcutil
    fi

    if ! command -v i2cdetect >/dev/null 2>&1; then
      apt-get install -y i2c-tools
    fi

    if ! command -v sunwait >/dev/null 2>&1; then
      if ! apt-get install -y sunwait; then
        build_sunwait
      fi
    fi
  else
    echo "Missing required binaries: ${missing_bins[*]}"
    echo "Please install: ddcutil sunwait i2c-tools"
    exit 1
  fi
fi

install -m 0755 "$ROOT_DIR/scripts/monitor-day" /usr/local/bin/monitor-day
install -m 0755 "$ROOT_DIR/scripts/monitor-night" /usr/local/bin/monitor-night
install -m 0755 "$ROOT_DIR/scripts/monitor-sun-loop" /usr/local/bin/monitor-sun-loop
install -m 0644 "$ROOT_DIR/systemd/monitor-sun.service" /etc/systemd/system/monitor-sun.service

if [[ ! -f /etc/default/monitor-sun ]]; then
  install -m 0644 "$ROOT_DIR/config/monitor-sun.default" /etc/default/monitor-sun
  echo "Installed /etc/default/monitor-sun (edit LAT/LON)."
else
  echo "Keeping existing /etc/default/monitor-sun."
fi

systemctl daemon-reload
systemctl enable --now monitor-sun.service

echo "Installed and started monitor-sun.service."
