#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
VERSION=$(cat "$ROOT_DIR/VERSION")
BUILD_DIR="$ROOT_DIR/build"
PKG_DIR="$BUILD_DIR/pkgroot"
OUT_DEB="$BUILD_DIR/rpi-night-light_${VERSION}_all.deb"

rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN" \
  "$PKG_DIR/usr/local/bin" \
  "$PKG_DIR/etc/default" \
  "$PKG_DIR/etc/systemd/system"

sed "s/@VERSION@/$VERSION/" "$ROOT_DIR/packaging/deb-control" > "$PKG_DIR/DEBIAN/control"
install -m 0644 "$ROOT_DIR/packaging/DEBIAN/conffiles" "$PKG_DIR/DEBIAN/conffiles"
install -m 0755 "$ROOT_DIR/packaging/DEBIAN/postinst" "$PKG_DIR/DEBIAN/postinst"
install -m 0755 "$ROOT_DIR/packaging/DEBIAN/prerm" "$PKG_DIR/DEBIAN/prerm"

install -m 0755 "$ROOT_DIR/scripts/monitor-day" "$PKG_DIR/usr/local/bin/monitor-day"
install -m 0755 "$ROOT_DIR/scripts/monitor-night" "$PKG_DIR/usr/local/bin/monitor-night"
install -m 0755 "$ROOT_DIR/scripts/monitor-sun-loop" "$PKG_DIR/usr/local/bin/monitor-sun-loop"
install -m 0644 "$ROOT_DIR/systemd/monitor-sun.service" "$PKG_DIR/etc/systemd/system/monitor-sun.service"
install -m 0644 "$ROOT_DIR/config/monitor-sun.default" "$PKG_DIR/etc/default/monitor-sun"

dpkg-deb --build "$PKG_DIR" "$OUT_DEB" >/dev/null

echo "Built $OUT_DEB"
