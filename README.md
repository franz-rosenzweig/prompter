# Prompter

A teleprompter for this Mac that hangs from the top of the screen, right under the camera
(or floats anywhere), and is left out of screen shares, recordings and screenshots.

- **Follow** moves line by line as it hears the script's words (on-device speech recognition).
- **Voice** scrolls at the set speed while you talk and stops when you stop.
- **Steady** scrolls at the set speed until paused.

Scripts are plain text in `~/Library/Application Support/Prompter/Scripts`.
`# Heading` lines are cues you can jump between; `[like this]` is a note to yourself. Neither is read aloud.

| Shortcut | |
|---|---|
| ⌃⌥P | Show / hide |
| ⌃⌥Space | Play / pause |
| ⌃⌥= / ⌃⌥− | Faster / slower |
| ⌃⌥] / ⌃⌥[ | Next / previous cue |
| ⌃⌥R | Back to start |
| ⌃⌥M | Next mode |

Hover over the prompter to pause and show its controls; click it to play or pause; scroll to move.

## Build

    ./build.sh && cp -R build/Prompter.app /Applications/
    ./selftest.sh     # the parser and matcher, plus pictures of the prompter in build/test/out

`project.yml` generates an Xcode project too: `xcodegen generate && open Prompter.xcodeproj`.
