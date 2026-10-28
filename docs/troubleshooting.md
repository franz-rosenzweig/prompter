<sub>[Prompter docs](README.md) › When something's off</sub>

# Troubleshooting

## Follow doesn't move

- **Is it paused?** A small pause sign at the top right means it is. Hovering over the prompter also pauses it, so
  move the pointer away.
- **Does the dot turn green when you talk?** If it stays dim, the microphone isn't picking you up. Check which
  microphone is selected in System Settings › Sound › Input.
- **Is it the right language?** Settings › Voice › Language has to be the language you're speaking. Automatic
  means your Mac's language.
- **Are you far from where it thinks you are?** It looks about 40 words ahead of the line it's on. If you've
  jumped further than that, scroll there by hand, or jump to the cue, and it picks up from there.

## An orange line at the bottom of the prompter

| It says | What to do |
|---|---|
| Microphone off: System Settings › Privacy › Microphone | Turn Prompter on in System Settings › Privacy & Security › Microphone, then hide and show the prompter. |
| Speech recognition off: System Settings › Privacy › Speech Recognition | Turn Prompter on in System Settings › Privacy & Security › Speech Recognition, then hide and show the prompter. |
| No recognizer for … | macOS can't recognize that language. Pick another in Settings › Voice › Language, or use Voice mode. |
| No microphone | Connect one, or check System Settings › Sound › Input. |
| Speech recognition keeps stopping | It failed five times in a row. Check the language, and the internet connection if the language isn't recognized on the Mac, then hide and show the prompter to try again. |

## Voice mode moves on with nobody talking, or stops while I talk

That's **Mic sensitivity** (Settings › Voice). Turn it down if the room's noise moves it, and up if it stops when
you speak softly. The dot shows what it hears: green means talking.

## macOS asks for the microphone again after every build

Your copy is signed ad hoc, so every build looks like a new app to macOS. [Your own build](own-copy.md) explains
signing it with a certificate so macOS remembers.

## It covers something in the menu bar

It only covers the middle of the menu bar, and only while it's showing. ⌃⌥P hides it, a smaller Width covers less,
and Floating moves it off the menu bar altogether.

## It's on the wrong screen

Settings › Prompter › Display picks the screen. Automatic means the one with the notch, or the main one.

## A shortcut does something else

Another app, or macOS, may use the same keys. The likeliest is ⌃⌥Space for switching keyboard languages:
[Shortcuts and the menu bar](shortcuts.md) explains how to turn it off.

<sub>Next: [Your own build](own-copy.md) →</sub>
