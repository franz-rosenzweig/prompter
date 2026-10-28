<sub>[Prompter docs](README.md) › Your privacy</sub>

# What it hears

Here's everything Prompter does with your voice and your scripts.

## The microphone

It's on only while the prompter is showing in Follow or Voice mode, and it stays on while it's paused in those
modes, so it can hear you when you resume. When the prompter is hidden, or in Steady mode, the microphone is off.
macOS's microphone light in the menu bar tells you which.

## Voice mode

Voice mode only measures how loud it is around the Mac, about twenty times a second, to tell talking from quiet.
The sound isn't kept or sent anywhere.

## Follow mode

Follow hands the sound to macOS's speech recognizer, the same one dictation uses.

- **On your Mac when it can be.** Prompter asks for recognition on the Mac whenever the language allows it, and
  then the sound never leaves your Mac. For a language that can't be recognized on the Mac, macOS sends the sound
  to Apple to recognize, as it does for dictation.
- **Nothing written down.** Prompter only keeps the words of what it's hearing right now, in memory, long enough
  to line them up with the script. Nothing is saved, logged or sent.
- **Hints from your script.** Longer words from your script (seven letters or more, up to a hundred of them) go to
  the recognizer as hints, so it gets names and jargon right.

## Your scripts and settings

They're files on your Mac: the scripts in `~/Library/Application Support/Prompter/Scripts`, and the settings in
`~/Library/Preferences/xyz.tiresia.prompter.plist`. Prompter has no server, no account and no analytics, and it
never connects to the internet itself.

<sub>Next: [Troubleshooting](troubleshooting.md) →</sub>
