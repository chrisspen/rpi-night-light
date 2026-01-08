#!/usr/bin/env bash
set -euo pipefail

if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  echo "Please run as root (use sudo)."
  exit 1
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl disable --now monitor-sun.service >/dev/null 2>&1 || true
fi

rm -f /usr/local/bin/monitor-day \
  /usr/local/bin/monitor-night \
  /usr/local/bin/monitor-sun-loop \
  /etc/systemd/system/monitor-sun.service

if [[ "${KEEP_CONFIG:-0}" != "1" ]]; then
  rm -f /etc/default/monitor-sun
else
  echo "Keeping /etc/default/monitor-sun (KEEP_CONFIG=1)"
fi

if command -v systemctl >/dev/null 2>&1; then
  systemctl daemon-reload >/dev/null 2>&1 || true
fi

echo "Uninstalled rpi-night-light."
