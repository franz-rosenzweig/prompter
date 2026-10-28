#!/bin/zsh
# Takes the real pictures for the README and the docs from a test copy of the app
# (xyz.tiresia.prompter.test, its own settings, the made-up scripts in tools/pictures/scripts), into
# build/pictures/raw. tools/pictures/compose.sh then lays them out into docs/images.
#   ./tools/pictures.sh
# The prompter shows at the top of the screen, and the windows open behind whatever is in front,
# for about a minute. A notch is faked with -PrompterFakeNotch, so a screen without one still
# shows the MacBook's shape.
set -euo pipefail
cd "${0:A:h}/.."
OUT=build/pictures
RAW=$OUT/raw
rm -rf $RAW $OUT/scripts && mkdir -p $RAW $OUT/scripts
cp tools/pictures/scripts/*.md $OUT/scripts/
PROMPTER_OUT=build/test PROMPTER_BUNDLE_ID=xyz.tiresia.prompter.test ./build.sh >$OUT/build.log 2>&1 || { cat $OUT/build.log; exit 1; }
APP=build/test/Prompter.app
BIN=$PWD/$APP/Contents/MacOS/Prompter
# the sample the app writes, newest, so the scripts window opens on it
touch -t 202610240900 $OUT/scripts/*.md
pkill -f "$BIN" 2>/dev/null || true

env_args=(--env PROMPTER_TEST=1 --env PROMPTER_NO_MIC=1 --env PROMPTER_SCRIPTS=$PWD/$OUT/scripts)
common=(-ApplePersistenceIgnoreState YES -PrompterNoHover YES -width 560 -height 150 -fontSize 24 -speed 12)

prompter() {   # name, then settings
    local name=$1; shift
    open -g -n -o $RAW/$name.log ${env_args[@]} --env PROMPTER_CAPTURABLE=1 $APP --args -SelfTest demo ${common[@]} "$@"
    for _ in {1..40}; do grep -q '^WINDOW' $RAW/$name.log 2>/dev/null && break; sleep 0.25; done
    sleep 0.8
    screencapture -x -o -l $(awk '/^WINDOW/ {print $2}' $RAW/$name.log) $RAW/$name.png
    pkill -f "$BIN" || true
    sleep 0.5
    echo "  $name"
}

window() {   # name, then settings: the largest window the app opens
    local name=$1; shift
    open -g -n -o $RAW/$name.log ${env_args[@]} $APP --args ${common[@]} "$@"
    sleep 3
    local pid=$(pgrep -f "$BIN" | head -1)
    local id=$(swift tools/windows.swift $pid | awk '$4 == 0 {print $2 * $3, $1}' | sort -n | tail -1 | awk '{print $2}')
    screencapture -x -o -l $id $RAW/$name.png
    pkill -f "$BIN" || true
    sleep 0.5
    echo "  $name"
}

settings() {   # name, tab, then settings: the Settings window
    local name=$1 tab=$2; shift 2
    open -g -n -o $RAW/$name.log ${env_args[@]} $APP --args ${common[@]} -SelfTestSettings YES -SelfTestSettingsTab $tab "$@"
    sleep 3
    local pid=$(pgrep -f "$BIN" | head -1)
    local id=$(swift tools/windows.swift $pid | awk '$4 == 0 && $2 == 480 {print $1}' | head -1)
    screencapture -x -o -l $id $RAW/$name.png
    pkill -f "$BIN" || true
    sleep 0.5
    echo "  $name"
}

echo "the prompter:"
prompter follow -mode follow -PrompterFakeNotch 200x32 -PrompterCursor 20 -PrompterHearing YES
prompter follow-start -mode follow -PrompterFakeNotch 200x32 -PrompterHearing YES
prompter controls -mode steady -PrompterFakeNotch 200x32 -PrompterShowControls YES -PrompterCursor 9
prompter steady -mode steady -PrompterFakeNotch 200x32
prompter warm -mode steady -PrompterFakeNotch 200x32 -textColor '#FFD98A' -alignment center -fontSize 28 -PrompterCursor 9
prompter mirror -mode steady -PrompterFakeNotch 200x32 -mirror YES
prompter floating -mode voice -placement floating -PrompterHearing YES -PrompterCursor 9
prompter top-of-screen -mode follow -PrompterCursor 20 -PrompterHearing YES
echo "the windows:"
for look in light dark; do
    window scripts-$look -PrompterAppearance $look
    settings settings-prompter-$look 0 -PrompterAppearance $look
    settings settings-voice-$look 1 -PrompterAppearance $look
    settings settings-shortcuts-$look 2 -PrompterAppearance $look
done
ls $RAW/*.png | wc -l
