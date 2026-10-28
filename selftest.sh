#!/bin/zsh
# Tests Prompter from inside, as its own app (xyz.tiresia.prompter.test, with its own
# settings and a scratch scripts folder), so the real one can stay open:
#   ./selftest.sh          the parser and Follow's matcher, then a picture of the prompter
#   ./selftest.sh unit     just the first part
# The picture: the prompter shows at the top of the screen for a couple of seconds. The
# test copy alone can be captured; then it checks the ordinary build is hidden from capture.
set -euo pipefail
cd "${0:A:h}"
OUT=build/test
mkdir -p $OUT/out
PROMPTER_OUT=$OUT PROMPTER_BUNDLE_ID=xyz.tiresia.prompter.test ./build.sh >$OUT/build.log 2>&1 || { cat $OUT/build.log; exit 1; }
BIN=$PWD/$OUT/Prompter.app/Contents/MacOS/Prompter
export PROMPTER_TEST=1 PROMPTER_NO_MIC=1 PROMPTER_SCRIPTS=$PWD/$OUT/scripts

$BIN -SelfTest unit -ApplePersistenceIgnoreState YES | tee $OUT/out/unit.txt | grep -E "^(FAIL|SELFTEST)"
grep -q "SELFTEST passed" $OUT/out/unit.txt
[[ ${1:-} == unit ]] && exit 0

shot() {   # name, then settings for the demo
    local name=$1; shift
    rm -f $OUT/out/$name.log
    open -g -n -o $OUT/out/$name.log --env PROMPTER_CAPTURABLE=${CAPTURABLE:-1} $OUT/Prompter.app --args \
        -SelfTest demo -ApplePersistenceIgnoreState YES "$@"
    for _ in {1..40}; do grep -q '^WINDOW' $OUT/out/$name.log 2>/dev/null && break; sleep 0.25; done
    local line=$(grep '^WINDOW' $OUT/out/$name.log || true)
    echo "INFO $name: $line"
    local wid=$(echo $line | awk '{print $2}')
    sleep 0.6
    if [[ ${CAPTURABLE:-1} == 1 ]]; then
        screencapture -x -o -l $wid $OUT/out/$name.png
    else
        # just the prompter's own rectangle of the screen: it should show what's behind it
        local f=(${(s:,:)$(echo $line | sed -E 's/.*frame=\{\{([0-9.]+), ([0-9.]+)\}, \{([0-9.]+), ([0-9.]+)\}\}.*/\1,\2,\3,\4/')})
        local H=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSScreen.screens.objectAtIndex(0).frame.size.height')
        screencapture -x -R${f[1]},$(( H - f[2] - f[4] )),${f[3]},${f[4]} $OUT/out/$name.png
    fi
    pkill -f "$BIN" || true
    sleep 0.4
}
shot notch-steady -mode steady
shot notch-follow -mode follow -PrompterCursor 14 -PrompterShowControls YES
shot mirror -mode steady -mirror YES
shot floating -mode steady -placement floating
CAPTURABLE=0 shot hidden -mode steady
grep -q 'sharing=0' $OUT/out/hidden.log && echo "PASS the prompter is left out of capture (sharing state 0)" || echo "FAIL sharing state: $(grep WINDOW $OUT/out/hidden.log)"
ls $OUT/out/*.png
