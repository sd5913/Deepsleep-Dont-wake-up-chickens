#!/usr/bin/env bash
set -euo pipefail

for package in build/packages/night-coop-{linux-x86_64,macos-universal,windows-x86_64}.zip; do
  test -s "$package"
done
test -s build/web/index.html

mkdir -p build/release
cp build/packages/night-coop-linux-x86_64.zip build/release/linux.zip
cp build/packages/night-coop-macos-universal.zip build/release/macos.zip
cp build/packages/night-coop-windows-x86_64.zip build/release/windows.zip
(cd build/web && zip -qr ../release/web.zip .)

cd build/release
sha256sum linux.zip macos.zip web.zip windows.zip > SHA256SUMS
