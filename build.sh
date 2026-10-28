#!/bin/zsh
# Builds Prompter.app with the Command Line Tools and XcodeGen (brew install xcodegen):
#   ./build.sh && cp -R build/Prompter.app /Applications/
# Xcode itself is only needed for the icon (actool); without it the app builds with the plain one.
# The settings and Info.plist keys come from project.yml, the same spec the Xcode project
# is generated from, so the two builds can't drift apart.
set -euo pipefail
cd "${0:A:h}"

command -v swiftc >/dev/null || { echo "no swiftc: run xcode-select --install" >&2; exit 1; }
command -v xcodegen >/dev/null || { echo "no xcodegen: run brew install xcodegen" >&2; exit 1; }

setting() { sed -n "s/^ *$1: *\"*\([^\"]*\)\"*$/\1/p" project.yml | head -1; }
BUNDLE_ID=${PROMPTER_BUNDLE_ID:-$(setting PRODUCT_BUNDLE_IDENTIFIER)}   # selftest.sh builds as another app
VERSION=$(setting MARKETING_VERSION)
BUILD=$(setting CURRENT_PROJECT_VERSION)
MACOS=$(setting macOS)
SDK=$(xcrun --show-sdk-path)
ARCHS=(${=PROMPTER_ARCHS:-$(uname -m)})   # "arm64 x86_64" for a universal app (tools/dmg.sh)

OUT=${PROMPTER_OUT:-build}
APP=$OUT/Prompter.app

xcodegen generate --quiet              # writes the Info.plist, the entitlements and the Xcode project
rm -rf $APP && mkdir -p $APP/Contents/MacOS $APP/Contents/Resources

# An Apple Development identity if there is one, so the microphone and speech permissions
# survive a rebuild; ad hoc otherwise, and macOS asks again after each build.
IDENTITY=${PROMPTER_SIGN:-$(security find-identity -v -p codesigning | sed -n 's/^ *[0-9]*) \([0-9A-F]*\) "Apple Development.*/\1/p' | head -1)}

# one compile per architecture, joined into one binary; source paths are kept out of it
for arch in $ARCHS; do
    swiftc -O -wmo -sdk $SDK -target $arch-apple-macos$MACOS -swift-version 5 -parse-as-library \
        -file-prefix-map "$PWD=." -module-name Prompter Prompter/*.swift -o $OUT/Prompter-$arch
done
lipo -create $OUT/Prompter-${^ARCHS} -output $APP/Contents/MacOS/Prompter
rm -f $OUT/Prompter-${^ARCHS}

sed -e "s/\$(DEVELOPMENT_LANGUAGE)/en/" -e "s/\$(EXECUTABLE_NAME)/Prompter/" -e "s/\$(PRODUCT_NAME)/Prompter/" \
    -e "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/$BUNDLE_ID/" -e "s/\$(MARKETING_VERSION)/$VERSION/" \
    -e "s/\$(CURRENT_PROJECT_VERSION)/$BUILD/" -e "s/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/" \
    -e "s/\$(MACOSX_DEPLOYMENT_TARGET)/$MACOS/" Prompter/Info.plist > $APP/Contents/Info.plist
plutil -lint -s $APP/Contents/Info.plist
! grep -q '\$(' $APP/Contents/Info.plist || { echo "Info.plist still has an unfilled \$(…)" >&2; exit 1; }

# The icon, layered as Icon Composer makes them (Resources/AppIcon.icon), so macOS 26 draws it
# as it draws its own, light, dark and tinted; actool also writes an .icns for older systems.
if xcrun -f actool >/dev/null 2>&1; then
    xcrun actool Resources/AppIcon.icon --compile $APP/Contents/Resources --app-icon AppIcon \
        --platform macosx --minimum-deployment-target $MACOS --output-partial-info-plist $OUT/assets-partial.plist >/dev/null
    plutil -replace CFBundleIconFile -string AppIcon $APP/Contents/Info.plist
    plutil -replace CFBundleIconName -string AppIcon $APP/Contents/Info.plist
else
    echo "note: no actool (it comes with Xcode), so no icon"
fi

# PROMPTER_KEYCHAIN: a keychain of its own holding the identity, as tools/dmg.sh uses
codesign --force --options runtime --entitlements Prompter/Prompter.entitlements \
    ${PROMPTER_KEYCHAIN:+--keychain $PROMPTER_KEYCHAIN} --sign "${IDENTITY:--}" $APP
[[ -n $IDENTITY && $IDENTITY != - ]] || echo "note: signed ad hoc; macOS asks for the microphone again after each build"
echo "built $APP"
