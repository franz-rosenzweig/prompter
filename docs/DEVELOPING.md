<sub>[Prompter docs](README.md) › Under the hood</sub>

# Developing

These are the working notes for changing Prompter itself: what each file does, how Follow matches your words, how
it scrolls, and how it's tested.

## The files

| File | What it does |
|---|---|
| `Prompter/PrompterApp.swift` | The app: the scripts window, Settings, the menu bar menu and the Prompter menu |
| `Prompter/Prompter.swift` | Runs the prompter: placing the panel, the three modes, cues, and the display link that scrolls |
| `Prompter/PrompterView.swift` | The panel (a borderless `NSPanel` above the menu bar, left out of capture) and what's in it: the notch shape, the text, the fades, the bar and the dot |
| `Prompter/Script.swift` | Reads a script (cues, notes, paragraphs) into styled text and its list of spoken words, plus the `Matcher` Follow uses |
| `Prompter/Listener.swift` | The microphone: its loudness for Voice, and its sound for the speech recognizer in Follow |
| `Prompter/Hotkeys.swift` | The ⌃⌥ shortcuts, as Carbon hot keys, which need no Accessibility permission |
| `Prompter/Library.swift`, `LibraryView.swift` | The scripts folder and the scripts window |
| `Prompter/SettingsView.swift`, `Prefs.swift` | Settings, and every setting's key and default |
| `Prompter/SelfTest.swift` | The self-test's checks, and the switches the pictures use |
| `project.yml`, `build.sh` | The XcodeGen spec, and the build that reads it |
| `selftest.sh`, `tools/pictures*` | The tests, and the scripts that make the pictures in `docs/images` |
| `tools/dmg.sh`, `tools/dmg/` | The DMG: the build, its checks, and the window's layout and background |
| `Resources/AppIcon.icon` | The icon, as Icon Composer makes them, so macOS 26 and later draw it light, dark or tinted |

## How Follow matches your words

1. The recognizer reports what it has heard so far, many times a second. Its words are normalized the same way as
   the script's: lower case, no accents, no apostrophes.
2. The `Matcher` takes the last six heard words and looks for where they end in the script, from 3 words behind the
   cursor (the next word expected) to 40 ahead. A place counts only if the last heard word, or the one before it,
   matches the script word there.
3. Each place gets a score: the longest run of heard words that appear in the same order in the script just before
   it. Words of three letters or fewer count half.
4. The further ahead a place is, the more it needs: half a word within 2 words, one and a half within 10, two and a
   half beyond. Among the places that qualify, the nearest wins (each word of distance costs 0.04).
5. The cursor only moves forward, to just past the matched word.

Two words are "the same" when they're equal, when one starts with the other and both are at least four letters (a
cut-off partial result, a plural), or when they're one letter apart (two, for words of eight letters or more).

A recognition task gets slow when it runs long, so `Listener` starts a fresh one in the first pause after 20
seconds, or after 55 seconds regardless. Script words of seven letters or more, up to a hundred, go to the
recognizer as hints.

## How it scrolls

A display link calls `tick` every frame. The text view has a screen's worth of blank space above and below the text,
so offset 0 puts the first line on the reading line, a fifth of the way down. Steady adds speed × time. Voice eases
its speed toward the set one while it heard talking in the last half second, and toward zero otherwise. Follow
eases toward the offset that puts the next word's line on the reading line. Scrolling by hand pauses all of this
for a moment, and Follow then takes the word on the reading line as its new cursor.

## Left out of capture

The panel's `sharingType` is `.none`, which tells the window server to leave it out of screenshots, recordings and
screen shares. The test copy's `PROMPTER_CAPTURABLE=1` makes it `.readOnly`, and only so the pictures can be taken.

## Building and testing

```bash
./build.sh            # build/Prompter.app
./selftest.sh         # everything below
./selftest.sh unit    # just the parser and the matcher
```

`selftest.sh` builds a test copy as its own app, `xyz.tiresia.prompter.test`, so it never touches the installed
one's settings, and runs it with `PROMPTER_TEST=1` (an exception exits quietly instead of showing a crash report),
`PROMPTER_NO_MIC=1` (no microphone, so no permission prompt) and `PROMPTER_SCRIPTS` (a scratch scripts folder). It
checks:

- **The parser:** cues, notes, apostrophes, and that every word's range points at its word.
- **The matcher:** a simulated reader going through the sample script, with every seventh word misheard, every
  eleventh dropped, and a new utterance every fifteen words, has to reach the end without ever running ahead.
  Going off script mustn't move it more than a couple of short words, and skipping a sentence must catch up within
  five words.
- **The prompter, drawn:** pictures of Steady, Follow with the bar, mirrored and floating, in `build/test/out`.
- **Left out of capture:** the ordinary build's window reports sharing state 0, and a screenshot of its exact spot
  shows what's behind it.

## Switches for the test copy

| Switch | Does |
|---|---|
| `-SelfTest unit` | runs the parser and matcher checks and exits |
| `-SelfTest demo` | shows the sample script in the prompter and prints its window number |
| `-PrompterCursor N` | as if Follow had heard up to word N |
| `-PrompterPlay YES` | starts playing |
| `-PrompterShowControls YES` | keeps the bar showing |
| `-PrompterHearing YES` | lights the dot |
| `-PrompterNoHover YES` | ignores the pointer |
| `-PrompterFakeNotch 200x32` | pretends the screen has a notch (with `PROMPTER_TEST` only) |
| `-PrompterAppearance light` | forces light or dark (with `PROMPTER_TEST` only) |
| `-SelfTestSettings YES`, `-SelfTestSettingsTab N` | opens Settings on a tab |

Any setting can also be given at launch the same way, like `-mode steady` or `-fontSize 28`.

## The pictures

`tools/pictures.sh` takes the real pictures from a test copy into `build/pictures/raw`: the prompter in each state
(on a faked notch when the screen has none) and the windows in light and dark. `tools/pictures/compose.sh` then lays
them out into `docs/images`, shooting `tools/pictures/compose.html` with headless Chromium for the pictures of the
whole Mac. It needs Chromium, `cwebp` and ImageMagick. Everything in those pictures is drawn except the prompter,
which is the app's own capture, and the people on the call are made up.

## Releasing

1. Set the version, `MARKETING_VERSION` in `project.yml`, and raise `CURRENT_PROJECT_VERSION` by one. Commit and
   push.
2. `tools/dmg.sh` builds `build/release/Prompter-X.Y.Z.dmg` from the committed code. It refuses if the app's code
   has uncommitted changes. It checks the app before packing it: the signature and who signed it, no team, the
   hardened runtime, the microphone entitlement, both architectures, the Info.plist, no home-folder paths,
   addresses or emails, and the self-test under arm64 and under x86_64 (through Rosetta). Then it checks the DMG
   the way someone opening it would find it.
3. Publish it under the plain name `Prompter.dmg`, so the download links in the README, the docs and the about
   page always get the newest one:

```bash
cp build/release/Prompter-X.Y.Z.dmg build/release/Prompter.dmg
gh release create vX.Y.Z build/release/Prompter.dmg --title "Prompter X.Y.Z" --notes "…"
```

The Finder on macOS 26 and later shows its toolbar, path bar and status bar on a DMG's window whatever the DMG
asks, so the background keeps the words and the icons in its top 300 points. And dmgbuild's `hide_extensions` is
left out on purpose: it marks the app's folder in a way `codesign --strict` rejects.

## What a machine can't test

The self-test can't speak, so live recognition with a real voice, hovering, clicking and scrolling by hand, the
shortcuts, and each call app's screen share are checked by hand.

<sub>Next: [Prompter docs](README.md) →</sub>
