#!/bin/sh
# 모니터 클리너.app 만들기 — Xcode 없이 swiftc 로. arm64·x86_64 둘 다 넣는다.
set -e
cd "$(dirname "$0")"
APP="build/모니터 클리너.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
for a in arm64 x86_64; do
  nice -n 15 swiftc -swift-version 5 -O -target $a-apple-macos14 Sources/*.swift -o build/mc-$a
done
lipo -create build/mc-arm64 build/mc-x86_64 -output "$APP/Contents/MacOS/MonitorCleaner"
rm build/mc-arm64 build/mc-x86_64
cp Info.plist "$APP/Contents/"
[ -f icon/AppIcon.icns ] && cp icon/AppIcon.icns "$APP/Contents/Resources/"
cp Resources/* "$APP/Contents/Resources/"
codesign --force --deep -s - "$APP"
echo "$APP"
