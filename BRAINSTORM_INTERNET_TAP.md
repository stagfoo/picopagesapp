# Brainstorm: Internet as a tap

Status: **idea, not implemented.** This is a thinking document, not a spec — expect it to change as we talk through it.

## The principle, restated for PicoPages

dumbui's version: a consistent, visible indicator for whether an app is online, and explicit "connecting…" states instead of silent background fetches. Applied to PicoPages, this becomes sharper because of what PicoPages already is: every imported app is sandboxed to `/uploads` + `localStorage`, and the Sandbox API docs already tell the AI "don't call external network APIs." So the honest question isn't "how do we show connectivity" — it's **"do we want to allow network access at all, and if so, on what terms?"**

## Proposed model

1. **Default: no network access**, per app. This matches the existing sandbox posture and the "no login, no accounts" / "unable to sunset" rules — an app that can't reach the network can't develop an undisclosed dependency on some server that later disappears.
2. **Explicit, per-app toggle lives in the WebviewScreen's title bar** — a persistent network icon right where you're actually using the app (not buried in the edit-mode banner, which you only visit occasionally). Tap to flip on/off; the icon's own state *is* the always-visible indicator dumbui asks for, so there's no separate status-pill widget needed at the chrome level — off by default, sticky until changed.
3. **Real enforcement, not just a UI convention.** The cheap version of this feature is "tell the AI to build a status pill" — but that's decorative if the app can still fetch whatever it wants underneath. The actual enforcement mechanism:

   **Content-Security-Policy headers, set by `LocalAppServer` per response.** When an app's network toggle is off, every HTML response gets:
   ```
   Content-Security-Policy: default-src 'self'; connect-src 'self'; img-src 'self' data:; frame-src 'none'
   ```
   This is enforced by the WebView engine itself, not by our JS shim — it blocks `fetch`, `XMLHttpRequest`, `<img src>`, `<iframe>`, WebSocket, everything, to any origin other than the app's own local server. No JS-level interception to get right, no way for app code to route around it via some API we forgot to shim. When the toggle is on, we just omit the CSP header (or use a more permissive one) and normal network access works as it would in any browser.

   This is a nice fit for the existing architecture: it's the same place (`LocalAppServer._handleStaticFile`) that already sets `Content-Security-Policy`-adjacent things like `Content-Type`, and it needs zero native Android platform code — unlike the file-selector fix, this doesn't require a WebView platform hook.

4. **The core win isn't the toggle — it's the pattern it enables: fetch-then-cache, not live-dependency.** The real value of "internet as a tap" for PicoPages apps is architectural, not cosmetic: an app should treat network access the way an RSS reader treats a feed — turn the tap on, pull data down, parse it into `localStorage` (already durable via the existing Hive shim), then render from that local copy from then on, tap on or off. This is basically stale-while-revalidate / offline-first, and it composes cleanly with the CSP enforcement above: while the toggle is on, the app can fetch; once it's cached what it needs, turning the toggle back off breaks nothing, because rendering never depended on a live connection in the first place.

   Concretely, once this is built, the Sandbox API docs should recommend a convention like:
   - `<app>-cache-v1` — the last successfully fetched/parsed data.
   - `<app>-cache-synced-at` — timestamp of that fetch, shown in the UI ("Last updated 2 hours ago") instead of pretending the data is always live.
   - Render from cache always; only attempt a live fetch on an explicit user action (open app, tap refresh) while the network toggle is on — never a silent background poll.

   This also answers what the "visible indicator" should actually be: not a decorative pill claiming real-time online/offline status, but the "last updated" timestamp — which is honest about the fact that these apps are fundamentally snapshot-based, not live.

## Open questions to brainstorm

- **Granularity**: one on/off toggle per app, or per-origin allowlist (e.g. "this app may reach `api.example.com` but nothing else")? An allowlist is more dumbui-esque ("explicit") but is real work to build a UI for, and most apps either need zero network or "the whole internet" (e.g. embedding a public API).
- **Should turning it on ever be temporary/session-scoped** (revert to off next launch) vs. sticky until changed? Leans toward sticky + visible, since a silent per-session reset could surprise the user ("why did it stop working").
- **Does an app get to explain itself?** e.g. a manifest-ish field an app can set (via a meta tag or a sandbox endpoint) describing *why* it wants network access, shown to the user the first time they flip the toggle on. Nice trust-building UX, extra scope.
- **Interaction with `/uploads`**: that endpoint is same-origin already (`/uploads` on the app's own local server), so it's unaffected by this — uploads keep working regardless of the network toggle. Worth confirming this explicitly in the docs once built, so it's not confused with "network access."
- **Should PicoPages itself show a global indicator** (e.g. in the home grid dock) for "any app currently has network access turned on," as a lightweight audit view — similar in spirit to Android's own per-app permission review screen?
