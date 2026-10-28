#!/bin/zsh
# Makes build/release/Prompter-X.Y.Z.dmg, to hand to other Macs: a universal app (Apple silicon and Intel),
# signed with the shared release identity rather than an Apple Development certificate, so no name, email or
# team is in it; checked; then laid out in a window with the Applications folder, by dmgbuild.
#
#   tools/dmg.sh            the DMG, signed with the shared identity
#   tools/dmg.sh --adhoc    signed ad hoc instead, for anyone without that identity
#
# The version is MARKETING_VERSION in project.yml. The app's code (Prompter/, Resources/, project.yml) must be
# committed, so the DMG is exactly a commit; the build tools may differ. The signing lives outside the repository,
# in ~/.config/prompter-release.env (PROMPTER_RELEASE_ENV to use another):
#   SIGN_NAME=...            the identity's name
#   SIGN_KEYCHAIN=...        the keychain file that holds it
#   SIGN_PASSWORD_FILE=...   the file that unlocks that keychain
# The keychain is locked again afterwards, and the identity's hash is never printed.
# Needs dmgbuild, which this installs into build/dmg-venv the first time.
set -euo pipefail
cd "${0:A:h}/.."
ROOT=$PWD
ADHOC=0
[[ ${1:-} == --adhoc ]] && ADHOC=1
V=$(sed -n 's/^ *MARKETING_VERSION: *"*\([^"]*\)"*$/\1/p' project.yml | head -1)
OUT=$ROOT/build/release
DMG=$OUT/Prompter-$V.dmg
say() { echo "dmg: $*"; }
fail() { echo "CHECK FAILED: $*" >&2; exit 1; }

[[ -z $(git status --porcelain -- Prompter Resources project.yml) ]] || fail "the app's code has uncommitted changes"
SHA=$(git rev-parse --short HEAD)

VENV=$ROOT/build/dmg-venv
if [[ ! -x $VENV/bin/dmgbuild ]]; then
    say "installing dmgbuild into build/dmg-venv"
    python3 -m venv $VENV && $VENV/bin/pip install -q "dmgbuild==1.6.7"
fi

KEYCHAIN=""
if (( ADHOC )); then
    SIGN=-
else
    CONF=${PROMPTER_RELEASE_ENV:-$HOME/.config/prompter-release.env}
    [[ -f $CONF ]] || fail "no $CONF (see the top of this script), or use --adhoc"
    source $CONF
    : ${SIGN_NAME:?} ${SIGN_KEYCHAIN:?} ${SIGN_PASSWORD_FILE:?}
    KEYCHAIN=${SIGN_KEYCHAIN/#\~/$HOME}; PASSFILE=${SIGN_PASSWORD_FILE/#\~/$HOME}
    SIGN=$(security find-identity -p codesigning $KEYCHAIN | sed -n "s/^ *[0-9]*) \([0-9A-F]\{40\}\) \"$SIGN_NAME\".*/\1/p" | head -1)
    [[ -n $SIGN ]] || fail "no identity named $SIGN_NAME in its keychain"
    trap 'security lock-keychain "$KEYCHAIN" >/dev/null 2>&1 || true' EXIT
    security unlock-keychain -p "$(cat $PASSFILE)" $KEYCHAIN
fi

say "building $V from $SHA, for Apple silicon and Intel"
rm -rf $OUT && mkdir -p $OUT
PROMPTER_OUT=$OUT PROMPTER_ARCHS="arm64 x86_64" PROMPTER_SIGN=$SIGN PROMPTER_KEYCHAIN=$KEYCHAIN ./build.sh >$OUT/build.log 2>&1 \
    || { grep -E "error" $OUT/build.log | head; fail "the build (see build/release/build.log)"; }
[[ -n $KEYCHAIN ]] && security lock-keychain $KEYCHAIN
APP=$OUT/Prompter.app

# --- what the app says about itself, before it's packed
say "checking the app"
codesign --verify --deep --strict $APP || fail "the signature"
sig=$(codesign -dvv $APP 2>&1)
if (( ADHOC )); then
    [[ $sig == *"Signature=adhoc"* ]] || fail "not signed ad hoc"
else
    auth=$(sed -n 's/^Authority=//p' <<<"$sig" | sort -u)
    [[ $auth == "$SIGN_NAME" ]] || fail "signed by '$auth', not only by $SIGN_NAME"
fi
[[ $sig == *$'\n'"TeamIdentifier=not set"* ]] || fail "the app carries a team"
[[ $sig == *"(runtime)"* ]] || fail "the hardened runtime isn't on"
[[ $(codesign -d --entitlements - $APP 2>/dev/null) == *"com.apple.security.device.audio-input"* ]] || fail "the microphone entitlement is missing"
[[ $(lipo -archs $APP/Contents/MacOS/Prompter) == *arm64* && $(lipo -archs $APP/Contents/MacOS/Prompter) == *x86_64* ]] || fail "it isn't universal"
pb() { /usr/libexec/PlistBuddy -c "Print :$1" $APP/Contents/Info.plist; }
[[ $(pb CFBundleShortVersionString) == $V ]] || fail "the version"
[[ $(pb CFBundleIdentifier) == xyz.tiresia.prompter ]] || fail "the bundle id"
[[ $(pb LSMinimumSystemVersion) == 15.0 ]] || fail "the minimum macOS"
pb NSMicrophoneUsageDescription >/dev/null && pb NSSpeechRecognitionUsageDescription >/dev/null || fail "a usage description is missing"
[[ -f $APP/Contents/Resources/AppIcon.icns ]] || fail "no icon (it needs Xcode's actool)"
[[ -z $(grep -r -l -a '/Users/' $APP || true) ]] || fail "a home folder's path is in the app"
[[ -z $(grep -r -l -a -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}:[0-9]{2,5}|@pm\.me|@passmail|proton' $APP || true) ]] \
    || fail "a private address or an email is in the app"

# --- it runs, on both architectures: the parser and matcher checks, with the signed binary
say "running it on both architectures"
T=$(mktemp -d)
for arch in arm64 x86_64; do
    out=$(PROMPTER_TEST=1 PROMPTER_NO_MIC=1 PROMPTER_SCRIPTS=$T arch -$arch $APP/Contents/MacOS/Prompter -SelfTest unit \
        -ApplePersistenceIgnoreState YES 2>&1 | tail -1)
    [[ $out == "SELFTEST passed" ]] || fail "the $arch build: $out"
done
rm -rf $T

# --- the DMG
BG=tools/dmg/background.tiff
if [[ ! -f $BG ]]; then   # drawn from background.html; kept in git, so this only needs Chromium when it changes
    CH=${CHROME:-/Applications/Chromium.app/Contents/MacOS/Chromium}
    for s in 1 2; do
        $CH --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=$s --window-size=660,440 \
            --screenshot=$OUT/bg@$s.png "file://$ROOT/tools/dmg/background.html" >/dev/null 2>&1
    done
    tiffutil -cathidpicheck $OUT/bg@1.png $OUT/bg@2.png -out $BG >/dev/null
fi
say "packing $DMG:t"
$VENV/bin/dmgbuild -s tools/dmg/settings.py -D app=$APP -D background=$ROOT/$BG \
    -D icon=$APP/Contents/Resources/AppIcon.icns "Prompter" $DMG >$OUT/dmgbuild.log 2>&1 \
    || { tail -5 $OUT/dmgbuild.log; fail "dmgbuild"; }

# --- what's in it, as someone opening it would find it
say "checking the DMG"
hdiutil verify -quiet $DMG || fail "the image doesn't verify"
MNT=$(mktemp -d)
hdiutil attach -quiet -nobrowse -readonly -mountpoint $MNT $DMG 2>/dev/null
problem=""   # noted, not failed on the spot: the image has to come off again first
[[ -d $MNT/Prompter.app && -L $MNT/Applications && $(readlink $MNT/Applications) == /Applications ]] || problem="the app or the Applications link"
[[ -f $MNT/.DS_Store && -f $MNT/.background.tiff && -f $MNT/.VolumeIcon.icns ]] || problem="the window's layout, background or icon"
codesign --verify --deep --strict $MNT/Prompter.app 2>/dev/null || problem="the app's signature, inside the DMG"
hdiutil detach -quiet $MNT 2>/dev/null || hdiutil detach -quiet -force $MNT 2>/dev/null
rmdir $MNT 2>/dev/null || true
[[ -z $problem ]] || fail $problem
SUM=$(shasum -a 256 $DMG | cut -d' ' -f1)
say "done: build/release/$DMG:t, $(du -h $DMG | cut -f1), from $SHA"
echo "sha256 $SUM"
