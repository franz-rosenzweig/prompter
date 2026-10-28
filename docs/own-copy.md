<sub>[Prompter docs](README.md) › Running your own copy</sub>

# Your own build

## There's nothing to host

Prompter is only a Mac app. There's no server, no database and no account behind it, so your own copy is simply the
one you build. [Install](install.md) covers that, and this page covers making it yours.

## Signing it as yourself

`build.sh` signs with the first Apple Development certificate in your keychain, which Xcode makes for you once
you've signed in with your Apple ID (Xcode › Settings › Accounts). With a certificate, macOS knows each new build is
the same app, so it keeps the microphone and speech recognition permissions.

To pick a different identity, or to sign ad hoc on purpose:

```bash
PROMPTER_SIGN="Apple Development: you@example.com (ABCDE12345)" ./build.sh
PROMPTER_SIGN=- ./build.sh     # ad hoc
```

A build signed this way runs on your own Mac. To hand a copy to someone else so that it opens without warnings, it
would need a Developer ID certificate and Apple's notarization, which `build.sh` doesn't do. The easiest way to
share it is to send them here so they can build it themselves.

## Your own name and id

The app's id is `xyz.tiresia.prompter`. Settings and permissions belong to the id, so a build under another one
starts fresh and doesn't touch an installed copy:

```bash
PROMPTER_BUNDLE_ID=com.example.prompter ./build.sh
```

To change it for good, change `PRODUCT_BUNDLE_IDENTIFIER` in `project.yml`. The scripts folder doesn't depend on the
id, so every copy sees the same scripts.

## Changing the defaults

Every setting's default is in one place, `Pref.register()` in `Prompter/Prefs.swift`: the text size, the speed, the
mode it starts in, the width and height, and the rest. Change them there and build again. A default only applies
until you change that setting yourself in Settings.

## Opening it in Xcode

```bash
xcodegen generate && open Prompter.xcodeproj
```

`project.yml` is the source of truth for both builds, so the Xcode project and `build.sh` can't drift apart. The
project file itself isn't in git.

## These docs

They're plain Markdown in `docs/`, so GitHub shows them as they are. [docs.tiresia.xyz](https://docs.tiresia.xyz/prompter/)
builds them into a site with MkDocs Material, where every `###` section in `docs/README.md` becomes a group in the
sidebar. To serve them yourself, `pip install mkdocs-material` and point an `mkdocs.yml` with `docs_dir: docs` at the
same pages.

<sub>Next: [Developing](DEVELOPING.md) →</sub>
