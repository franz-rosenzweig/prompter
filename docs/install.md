<sub>[Prompter docs](README.md) › Getting started</sub>

# Install

There are two ways to get Prompter: download it, or build it from the code. Either way there's nothing to host.
It's a Mac app with no server behind it.

## Download it

1. Download **[Prompter.dmg](https://github.com/franz-rosenzweig/prompter/releases/latest/download/Prompter.dmg)**, the latest release. It runs on macOS 15 or later, on Apple silicon and
   Intel Macs.
2. Open it, and drag Prompter onto Applications.
3. Open Prompter from Applications.

The first time, macOS says it can't check Prompter. That's because it's signed with my own identity, not one Apple
has checked, which needs a paid developer account. Click **Done**, open System Settings › Privacy & Security, scroll
down to where it says Prompter was blocked, and click **Open Anyway**. macOS asks for your password, and from then
on Prompter opens like any other app. If you'd rather use Terminal, this does the same:

```bash
xattr -dr com.apple.quarantine /Applications/Prompter.app
```

## Or build it yourself

### What you need

- macOS 15 or later.
- The Xcode Command Line Tools, for the Swift compiler: `xcode-select --install`.
- XcodeGen, which writes the app's settings from `project.yml`: `brew install xcodegen` (that needs
  [Homebrew](https://brew.sh)).
- Xcode itself, but only for the icon. Without it the app builds and works the same, with a plain icon.

### Build it

```bash
git clone https://github.com/franz-rosenzweig/prompter.git
cd prompter
./build.sh
```

`build.sh` compiles it into `build/Prompter.app` and signs it. If you have an Apple Development certificate (Xcode
makes one from your Apple ID), it signs with that, so macOS remembers the microphone permission between builds.
Without one it signs ad hoc, which runs fine on your own Mac but means macOS asks for the microphone again after
every rebuild.

### Put it in Applications

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

If you downloaded it, quit Prompter, download the new [Prompter.dmg](https://github.com/franz-rosenzweig/prompter/releases/latest/download/Prompter.dmg), and drag Prompter onto Applications
again, choosing **Replace**.

If you built it, pull and build again, quit Prompter, and copy the new one over the old one:

```bash
git pull && ./build.sh
osascript -e 'quit app "Prompter"'
rm -rf /Applications/Prompter.app && cp -R build/Prompter.app /Applications/
```

Your scripts and settings aren't inside the app, so they stay. A downloaded copy and one you built are signed
differently, so if you switch from one to the other, macOS asks for the microphone and speech recognition once more.

## Removing it

Drag Prompter from Applications to the Trash. Your scripts are in `~/Library/Application Support/Prompter/Scripts`,
so move them somewhere first if you want to keep them, and the settings are in
`~/Library/Preferences/xyz.tiresia.prompter.plist`.

<sub>Next: [Writing a script](scripts.md) →</sub>
