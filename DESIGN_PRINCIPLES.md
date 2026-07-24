# PicoPages design principles

Adapted from [dumbui](https://dumbui.wtf)'s principles, applied to PicoPages specifically. Each one below is marked with its current status so this doc doesn't drift from what's actually built.

## Internet as a tap — **proposed, not yet built**

Right now the rule for imported apps is just "gracefully degrade if a network call fails" (see the Sandbox API docs screen). dumbui's version is stronger and worth adopting as a real UI pattern: a consistent, visible indicator whenever an app is or isn't connected, with explicit "connecting…" states instead of silent fetches that might hang or fail invisibly.

Proposal: a small reusable status pill component (shared JS snippet, like the localStorage shim) that any imported app can drop in to show online/offline state honestly, rather than each app inventing its own ad-hoc spinner or failing silently.

## No login, no accounts — **already true, worth stating as a hard rule**

PicoPages is single-user and every app is sandboxed to its own local folder — there's no server to log into in the first place. This should stay a hard constraint as features get added: no auth flows, no accounts, no "sign in to sync."

## Non-internet sharing — **proposed, not yet built**

There's no cloud sync in PicoPages by design (see above), which makes offline transfer between devices genuinely useful rather than a novelty. Proposal: a "generate QR code encoding this app's exported data" pattern (or a local-network transfer, similar in spirit to the existing Tailscale-based APK sharing used during development) so state can move device-to-device with zero internet involved.

## Old-ugly-is-new-cute / early-internet aesthetic — **already the default direction**

Overlaps with the dither/checkerboard/bloom-glow look already used for the home grid (pink checkerboard background, soft blurred bloom blobs, glossy rounded icons, DSi/3DS-style organize mode). Worth stating explicitly: this is PicoPages' default visual direction unless a specific app calls for something else.

## "Unable to sunset" — **already true, worth naming explicitly**

No dependency on any service that can shut down and take the app with it — no external APIs, no accounts, no cloud backend. Every imported app runs off its own local HTML/JS/CSS plus the sandbox's localStorage-via-Hive and `/uploads` endpoints, both served entirely on-device. Worth calling out explicitly so it stays true as things get added — e.g. resist the temptation to add a "cloud sync" feature that quietly reintroduces a dependency on someone else's server.

## Draggable "toy" feel — **taste note, not a hard rule**

Good general UX instinct for interactive apps (drag-to-arrange, physical-feeling manipulation) — already present in the home grid's organize mode (long-press, wiggle, drag-to-reorder, resize via the edit banner). Less of a rule to enforce on every imported app and more a taste note: when an app has draggable/arrangeable content, lean into that physicality rather than flattening it into plain buttons and forms.
