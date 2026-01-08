#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUT_DIR="${OUT_DIR:-$ROOT_DIR/apt}"

if ! command -v dpkg-scanpackages >/dev/null 2>&1; then
  echo "dpkg-scanpackages not found. Install dpkg-dev." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"

if [[ $# -gt 0 ]]; then
  DEBS=("$@")
else
  mapfile -t DEBS < <(ls -1 "$ROOT_DIR"/build/*.deb 2>/dev/null || true)
fi

if [[ ${#DEBS[@]} -eq 0 ]]; then
  echo "No .deb files found. Build one with ./build-deb.sh." >&2
  exit 1
fi

for deb in "${DEBS[@]}"; do
  if [[ ! -f "$deb" ]]; then
    echo "Missing .deb: $deb" >&2
    exit 1
  fi
  cp -f "$deb" "$OUT_DIR/"
done

pushd "$OUT_DIR" >/dev/null

dpkg-scanpackages -m . /dev/null > Packages

gzip -9 -c Packages > Packages.gz

if command -v apt-ftparchive >/dev/null 2>&1; then
  apt-ftparchive release . > Release
fi

popd >/dev/null

echo "APT repo generated at $OUT_DIR"
