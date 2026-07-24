# Brainstorm: local sharing & multiplayer (no internet, no server)

Status: **idea, not implemented.** This is a thinking document, not a spec — expect it to change as we talk through it.

## Starting point

Original ask was small: "a QR code that encodes an app's exported data, so state can move device-to-device with zero internet." The more interesting version raised in conversation: a **general util for multiplayer/shared-state apps**, using a QR code as the handshake and WebRTC (or something WebRTC-like) as the transport — in the spirit of 3DS StreetPass (passive proximity exchange) or DS PictoChat (local wireless chat, no internet, no account).

Those two reference points actually point at two different problems, worth separating:

- **StreetPass-style**: passive, asynchronous, "leave a trace, pick it up later." Not really a live-connection problem — closer to the original "QR exports a data blob" idea, just automated/ambient instead of manually triggered.
- **PictoChat-style**: live, synchronous, multi-party session over local wireless, no internet, no account, no central server. This is the WebRTC-shaped problem.

**Decision: scope v1 to PictoChat-style only.** StreetPass's magic depends on background/ambient scanning — on Android that means either a persistent foreground service (unavoidable notification) or fighting Doze-mode background-execution limits, and BLE/WiFi scanning typically drags in a location permission even when location isn't the point. That's a lot of infrastructure and permission-friction for what PicoPages is (a lightweight personal tool), and it cuts against the "explicit, visible" spirit already established for Internet-as-a-tap — a QR scan *is* the explicit action; ambient background exchange is the opposite of that.

StreetPass-style passive/ambient discovery is explicitly **out of scope for now, not abandoned** — it's a fun idea for someone (possibly us, later; possibly someone else entirely) to build on top of whatever v1 turns into, once there's a working live-session primitive to extend. Worth revisiting once the PictoChat-style version exists and proves out the QR-handshake + local-transport pieces.

## Why WebRTC is the right instinct, but maybe not for the reason it first seems

WebRTC's headline feature is NAT traversal for two peers *not* on the same network. But the StreetPass/PictoChat use case is inherently proximity-based — same room, almost certainly same WiFi or at least reachable over LAN. On the same network, you don't need STUN/TURN/ICE at all; two phones can just open a plain socket to each other's local IP. We already have exactly this primitive in PicoPages — `LocalAppServer` is a real per-app HTTP server bound to a real port.

So why WebRTC anyway? Because of the *signaling* story, not the transport:

- WebRTC's DataChannel gives you encryption (DTLS) and a clean pub/sub-ish message API for free.
- More importantly: **the QR code can carry the entire handshake with no server involved at all**, which is the part that actually matters for "no accounts, no server, unable to sunset." A plain local-socket approach still needs *some* way for device A to learn device B's IP/port — which is exactly what the QR code is for either way. So the transport choice (WebRTC vs plain local WebSocket) is almost orthogonal to the QR-handshake idea; it changes what you get once connected, not whether a server is needed.

Net: **WebRTC's main value here is "connect two devices that might not be on the same network, without a signaling server."** If we can guarantee same-LAN (very likely for the StreetPass/PictoChat use case), a plain local socket is simpler and we should seriously consider it as the default, with WebRTC as an upgrade path for "different networks."

## The QR size problem, and a two-phase design that sidesteps it

A full WebRTC offer (SDP + gathered ICE candidates) is often 1-3KB — technically fits in a QR code at the lowest error-correction level, but that's a dense, easy-to-fail-to-scan code on a phone camera. Two ways around this:

1. **Two-phase handshake**: QR encodes a *small* bootstrap ticket only — local IP:port (or just a short pairing code, if we build actual peer discovery — see below) plus a random session token. The two devices then do the *real* handshake (SDP exchange, or just "hey let's talk," for the plain-socket version) over that first live connection. This keeps the QR tiny and reliable regardless of which transport we pick underneath.
2. **Chunked/animated QR** (like hardware-wallet transfer protocols — BC-UR and similar): split the payload across a short animated sequence of QR codes. More resilient to size, more friction to use (has to hold still, has to display all frames). Probably only worth it if we specifically need offline-and-not-on-the-same-network (no bootstrap connection possible at all).

**Recommendation to start:** two-phase bootstrap. Simpler, and reuses infrastructure we already have (a real per-app local HTTP/WS server).

## Scenario comparison

| | Same WiFi / LAN | Different networks (both have *some* internet, just not shared) | Neither has internet |
|---|---|---|---|
| Transport | Plain local socket (WebSocket) | WebRTC w/ STUN (no server needed, STUN is a free public utility) | Not really solvable without a relay we control — probably out of scope |
| QR carries | IP:port + token | Full SDP or bootstrap ticket to a rendezvous we don't control | — |
| Complexity | Low — we already have this | Medium — STUN dependency (a partial exception to "no external services," worth naming explicitly if we take it) | High, likely not worth it |

Suggest scoping v1 to the "same LAN" case only. It covers StreetPass/PictoChat's actual real-world condition (people in the same room) and needs zero new external dependencies.

## Getting the QR *into* the app: another native hookup, like the file-selector fix

Scanning a QR code from inside a sandboxed WebView means either:
- **In-page camera** via `getUserMedia()` + a bundled pure-JS decoder (e.g. jsQR, inlined since the sandbox forbids external CDNs). Requires wiring up WebView camera permission requests natively — same category of problem as the file-selector fix we just did for `<input type="file">` (Android WebView needs an explicit permission-request hook or it silently does nothing).
- **Native scan, bridged in** — PicoPages itself provides a "scan" capability as part of the sandbox API surface (like `/uploads`): the app's JS calls something (a fetch to a local endpoint, or a JS channel) that opens a native Flutter camera/QR scanner (e.g. `mobile_scanner`), and the decoded text comes back to the page. Reuses the same pattern as file uploads — PicoPages does the OS-level thing, the app just gets a clean result.

Leaning toward the native-bridge approach: one native camera permission to manage instead of per-app WebView camera grants, no need to bundle/maintain a JS QR decoder, and it matches how we already solved file selection.

## What this would add to the sandbox API surface

If we build this, it's a new capability class alongside `localStorage` and `/uploads` — needs its own section in the Sandbox API docs so an AI-generated app can be told about it:
- `POST /nearby/host` — start hosting a session, returns a QR-encodable ticket (and opens the local socket).
- Some way to render/scan the QR (native bridge, see above).
- `POST /nearby/join` — given a scanned ticket, connect to the host.
- A message-passing API once connected (send/receive JSON blobs, roughly WebSocket-shaped).

## Open questions to brainstorm

- **Is this per-app or a PicoPages-level concept?** e.g. could two *different* imported apps "see" each other over Nearby, or is a session strictly scoped to one app talking to the same app on another device/instance? Simplicity argues for the latter (same app on both ends) — StreetPass/PictoChat are both same-app-to-same-app.
- ~~Discovery vs. manual QR every time~~ — **resolved above**: manual QR every time for v1. Ambient mDNS/Bonjour-style discovery (closer to actual StreetPass) is the natural extension point for whoever picks up the sidelined passive-mode idea later.
- **Trust/consent model**: showing a QR code is an explicit, visible, physical action (matches the "explicit" spirit of Internet-as-a-tap) — is that consent enough, or do we want a confirm step on the host side too ("Alex's phone wants to connect — allow?")?
- ~~Does this need to survive app close/reopen~~ — **resolved above**: no, v1 is strictly a live session (both apps open at once). No persistence implications for `/nearby` to design around yet.
