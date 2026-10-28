<sub>[Prompter docs](README.md) › Getting started</sub>

# Install

Prompter isn't in the App Store, and there's no download yet. You build it from the code, which takes one command
and about a minute. There's nothing to host either: it's a Mac app with nothing behind it, so building it is the
whole setup.

## What you need

- macOS 15 or later.
- The Xcode Command Line Tools, for the Swift compiler: `xcode-select --install`.
- XcodeGen, which writes the app's settings from `project.yml`: `brew install xcodegen` (that needs
  [Homebrew](https://brew.sh)).
- Xcode itself, but only for the icon. Without it the app builds and works the same, with a plain icon.

## Build it

```bash
git clone https://github.com/franz-rosenzweig/prompter.git
cd prompter
./build.sh
```

`build.sh` compiles it into `build/Prompter.app` and signs it. If you have an Apple Development certificate (Xcode
makes one from your Apple ID), it signs with that, so macOS remembers the microphone permission between builds.
Without one it signs ad hoc, which runs fine on your own Mac but means macOS asks for the microphone again after
every rebuild.

## Put it in Applications

```bash
cp -R build/Prompter.app /Applications/
open /Applications/Prompter.app
```

The scripts window opens with a sample script in it, and the quote-mark icon shows up in the menu bar.

## The first time you start it

Pick a script and press **Start** (▶ in the toolbar, or ⌘Return). In Follow mode, macOS asks two things:

1. **Microphone**, so Prompter can hear you. Follow and Voice need it. Steady doesn't.
2. **Speech recognition**, so Follow can tell which words you said. Only Follow needs it.

Say yes to both and the prompter drops down from the top of the screen. If you said no by accident, the prompter
shows an orange line saying which one is off. Turn it on in System Settings › Privacy & Security, then press Start
again.

## Starting it with your Mac

If you'd like it in the menu bar all the time, add it in System Settings › General › Login Items › Open at Login.

## Updating

Pull and build again, quit Prompter, and copy the new one over the old one:

```bash
git pull && ./build.sh
osascript -e 'quit app "Prompter"'
rm -rf /Applications/Prompter.app && cp -R build/Prompter.app /Applications/
```

Your scripts and settings aren't inside the app, so they stay.

## Removing it

Drag Prompter from Applications to the Trash. Your scripts are in `~/Library/Application Support/Prompter/Scripts`,
so move them somewhere first if you want to keep them, and the settings are in
`~/Library/Preferences/xyz.tiresia.prompter.plist`.

<sub>Next: [Writing a script](scripts.md) →</sub>
