#!/bin/bash

CONFIG=${1:-debug}

if [ "$CONFIG" != "debug" ] && [ "$CONFIG" != "release" ]; then
    echo "Usage: $0 [debug|release]"
    exit 1
fi

echo "Building $CONFIG..."

mkdir -p build/Mactokio.app/Contents/{MacOS,Resources}

build_arch() {
    swiftc ${2} -o ${1} \
        Sources/MactokioApp.swift \
        Sources/Models/*.swift \
        Sources/Services/*.swift \
        Sources/Components/*.swift \
        Sources/Views/*.swift \
        Sources/Utils/*.swift \
        -framework SwiftUI -framework AppKit -framework Security \
        -framework CoreImage -framework AVFoundation -framework LocalAuthentication \
        -target ${3}-apple-macos13.0
}

if [ "$CONFIG" = "release" ]; then
    build_arch build/Mactokio_arm64 "-O" "arm64"
    build_arch build/Mactokio_x86_64 "-O" "x86_64"
    lipo -create -output build/Mactokio.app/Contents/MacOS/Mactokio build/Mactokio_{arm64,x86_64}
    rm build/Mactokio_{arm64,x86_64}
else
    build_arch build/Mactokio.app/Contents/MacOS/Mactokio "-g" $(uname -m)
fi

cp Resources/Info.plist build/Mactokio.app/Contents/
cp Resources/AppIcon.icns build/Mactokio.app/Contents/Resources/ 2>/dev/null || true

# Sign with entitlements for Touch ID / Keychain access
codesign --force --sign - --entitlements Resources/Mactokio.entitlements build/Mactokio.app

echo "Done: build/Mactokio.app"
