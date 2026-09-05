# html_arcade

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Installing with Obtainium

[Obtainium](https://github.com/ImranR98/Obtainium) tracks the GitHub releases
and installs updates, which beats downloading an APK by hand every time.

**Add it:** [obtainium://app/…](obtainium://app/%7B%22id%22%3A%22com.picopages.app%22%2C%22url%22%3A%22https%3A%2F%2Fgithub.com%2Fstagfoo%2Fpicopagesapp%22%2C%22author%22%3A%22stagfoo%22%2C%22name%22%3A%22PicoPages%22%7D) — or paste
`https://github.com/stagfoo/picopagesapp` into Obtainium's Add App screen. No extra settings
are needed, because releases are shaped to Obtainium's defaults:

- **The tag is exactly the version** — `1.0.1`, not `v1.0.0-4fdcb7e`. Obtainium
  compares the version a release advertises against the version Android reports
  for the installed app, and can only do that when the two are the same shape.
- **Every release bumps the version and the build number**, so there is always
  something to compare and Android always has a reason to treat the APK as an
  update.
- **One APK asset per release**, so no `apkFilterRegEx` is needed.

Releases are release builds, arm64-only, signed with the committed
`debug.keystore` so they install as updates over anything built before.

Releases before `1.0.1` used the old `v1.0.0-<sha>` tag format and will not
compare cleanly; the first Obtainium-tracked version is `1.0.1`.
