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

## Local daily review on iPhone

The first tap on **تنزيل النموذج** downloads 1.28 GB of Qwen3 1.7B Q4_K_M weights. The iOS bridge verifies the pinned SHA-256 before publishing the file in Application Support and excludes the directory from backup. Removing the model from the reviewer keeps the saved review. [Quantized weights](https://huggingface.co/bartowski/Qwen_Qwen3-1.7B-GGUF/tree/dcb19155b962dbb6389f4691a982043a8e651022) · [Original model and license](https://huggingface.co/Qwen/Qwen3-1.7B)

The device build resolves a pinned llama.cpp XCFramework through SwiftPM. The app loads the inference framework on demand. Current eligibility requires iOS 16.4, Metal Apple GPU family 7 or later, and at least 5 GiB of physical RAM. The app also checks current process memory headroom before download and inference. Simulator builds expose the unsupported state. [Runtime release](https://github.com/ggml-org/llama.cpp/releases/tag/b12633)

The review uses the current logical day and up to 27 preceding days. Dart computes totals, same-time comparisons and evidence-backed Arabic observations. A dedicated sample of today's completions reaches Qwen independently of recent focus sessions and notes. Qwen selects the opening and interprets the available evidence across multiple paragraphs on outcomes, focus, project progress and open work. This keeps task names, completion status and numeric claims grounded in the snapshot.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator --debug
```

## Daily tasks

The task menu offers daily repetition under “More”, alongside deletion. Enabling it uses an
unfinished task as today's occurrence; completed history keeps its original
logical date. A small repeat icon marks active recurring tasks. Titles edited
on recurring tasks apply to future copies only.

Daily templates live in the existing SQLite settings table. Schema version 7
adds nullable `repeat_id` and `repeat_day` columns without changing existing
tasks. Each generated copy is an ordinary task with fresh completion, pin and
time state. Launch, foreground resume and the existing logical-day timer create
only the current day's copy. Stored occurrence dates (including deleted or moved
copies) and deterministic daily IDs prevent regeneration. Missed days are never
backfilled. Any non-deleted unfinished copy blocks new copies of the same repeat,
even if it belongs to an older day or another bucket. After completion, the next
copy becomes eligible on the next logical day; reopening on the completion day
never creates a replacement. Existing copies and their time records stay intact.
Stopping a repeat preserves past tasks; deletion offers either the selected copy
or that copy plus stopping future repetition. Existing backup/reset mechanisms
include the templates and occurrence metadata.

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

## iCloud backup (iOS)

Settings provides optional CloudKit backup, off by default. A fixed `user-backup`
record of type `UserBackup` in the private database holds one JSON `CKAsset`
(`payload`) and a `Date/Time` field (`savedAt`). The server modification date is
used as the successful backup date. Updating this record replaces the old asset
only after a successful save. Concurrent changes from another device fail safely
rather than overwriting an unseen revision. No notifications, subscriptions,
background jobs, app accounts, or additional packages are needed.

Before testing on an iCloud device or distributing:

1. In the Apple Developer account for team `MHA5HH6YWR`, enable iCloud/CloudKit
   for `ma.raqmain.najeez`, create/associate `iCloud.ma.raqmain.najeez`, and
   regenerate provisioning profiles. `Runner.entitlements` is configured for
   this container in Debug, Profile, and Release.
2. Run on a signed iPhone using an Apple account with iCloud enabled. Make a
   backup in Development to create `UserBackup` with `payload` (Asset) and
   `savedAt` (Date/Time), or create these fields in CloudKit Console.
3. Deploy that schema to Production in CloudKit Console before TestFlight or
   App Store testing. No query indexes are needed; records are fetched by ID.
4. Verify account unavailable, offline/quota errors, manual backup, restore
   cancellation, reinstall/another device with the same account, and a return
   after 24 hours. Simulator builds and unit tests do not verify Apple account,
   provisioning, production schema, or real CloudKit uploads.

The payload includes every task (including completed and soft-deleted history),
time entries, tags, pinning, timestamps, and the complete settings table. Restore
validates the payload and replaces both tables in a single SQLite transaction;
malformed or unsupported copies leave local data intact. Cloud consent and
scheduling metadata remain specific to the current installation. A short input
barrier covers the local restore transaction and controller reload; cloud uploads
and downloads leave the app usable. Reset clears local consent/scheduling and
never deletes the cloud record. Disabling automatic backup also keeps that record;
manual backup and restore remain available.

## Focus Live Activities PoC

iOS focus sessions are mirrored locally to ActivityKit with a system-rendered
elapsed timer, Lock Screen and Dynamic Island layouts, and a small layout for
Apple Watch Smart Stack. See [the Arabic PoC notes](docs/focus-live-activities-poc.md)
for platform requirements, device checks, and the deferred watch stop action.
