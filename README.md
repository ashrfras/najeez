# نجيز

A small Arabic-first, offline task app built with Flutter.

## Run

```sh
flutter pub get
flutter run
```

## Design and data

- The home screen follows `assets/screens.png`. `assets/app_icon/icon-1024.png` is the opaque square source for the iOS, Android, and web app icons. iOS applies the rounded corner mask itself. `assets/logo.png` remains the launch artwork, and `assets/logo_mark.png` is the transparent header mark.
- Tasks are stored in a local SQLite database. The UI uses `TaskController` and the `TaskRepository` interface; `SqliteTaskRepository` is the current local implementation.
- Every task has a stable ID, creation and update timestamps, an optional completion timestamp, an optional scheduled calendar date, and a soft-deletion flag. Completed history is grouped from stored tasks.
- Tapping the home capture control opens a focused composer with a bucket choice and an optional tag. Tags can be reused from previous tasks or created inline. Existing databases migrate to version 3 without removing tasks.
- Tasks are grouped into **اليوم**, **غداً**, and **لاحقاً**. The **اليوم المنطقي** setting controls when tomorrow tasks become today (default 00:00); later tasks move only when changed manually. A foreground resume or day-boundary timer refreshes the sections.
- Statistics shows the latest seven logical calendar days (including today), with up to seven more loaded on demand until the oldest completion or time entry. Empty history (including after reset) keeps only the latest week. Time distribution uses each time entry’s date, including work on open tasks; completion counts use completion dates. Untagged time appears under «أخرى». The storage-independent statistics index is rebuilt on task changes, while day cards are rendered lazily without chart dependencies.
- IBM Plex Sans Arabic is bundled under its Open Font License in `assets/fonts/OFL.txt`, so typography works without a network connection.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

## Chrome web

```sh
flutter run -d chrome --web-port=8765
```

The web build uses SQLite WebAssembly with IndexedDB persistence. `web/sqlite3.wasm` and `web/sqflite_sw.js` are included so the app can initialize without downloading database code at runtime. Use the same local port when reopening the development app, because browser storage is scoped by origin.

```sh
flutter build web
```

## iPhone IPA

The iOS bundle ID is `ma.raqmain.najeez`. Xcode signs the app with the development team configured in `ios/Runner.xcodeproj`. To export an IPA for a registered iPhone:

```sh
flutter build ipa --release --export-method development
```

The signed file is written to `build/ios/ipa/نجيز.ipa`. Development IPAs install only on devices included in the provisioning profile. For App Store distribution, use the appropriate distribution method and signing profile instead.

For TestFlight, export an App Store signed IPA and upload that file through Apple's Transporter app:

```sh
flutter build ipa --release --export-method app-store
```

This also writes `build/ios/ipa/نجيز.ipa`, replacing the prior export at that path. Increment the build number in `pubspec.yaml` before uploading another build of the same version.

## Build number on commits

The repository's `.githooks/pre-commit` increments the build number in `pubspec.yaml` and stages that change with every commit. Enable it after cloning with:

```sh
git config --local core.hooksPath .githooks
```

If `pubspec.yaml` has unstaged changes, stage or discard them before committing so the hook does not stage unrelated edits.
