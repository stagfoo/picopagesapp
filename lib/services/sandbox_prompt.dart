/// Builds the AI-prompt text describing the sandbox's persistence surface,
/// tailored to only the capabilities a given app actually needs — no point
/// pasting the /speak docs into a prompt for an app that'll never call it.
///
/// localStorage is always included (every app can use it); everything else
/// is opt-in via [SandboxCapability.key].
class SandboxCapability {
  final String key;
  final String label;
  final String description;

  /// One or more numbered prompt sections this capability contributes,
  /// each as the body text that goes after "N. ".
  final List<String> promptSections;

  /// What to call this capability in the "only X actually persist" rule,
  /// e.g. "/uploads". Null if it doesn't add persistence (share, speak,
  /// microformats guidance).
  final String? persistenceNote;

  const SandboxCapability({
    required this.key,
    required this.label,
    required this.description,
    required this.promptSections,
    this.persistenceNote,
  });
}

const uploadsCapability = SandboxCapability(
  key: 'uploads',
  label: 'Upload files',
  description: 'Save, list, and delete a photo, drawing, or export via /uploads.',
  persistenceNote: '/uploads',
  promptSections: [
    '''Upload/save a file (photo, drawing, export, etc.):
   POST /uploads?filename=<name>
   Body: the raw file bytes — e.g.
     await fetch('/uploads?filename=' + encodeURIComponent(file.name), { method: 'POST', body: file })
   where `file` is a File/Blob (from <input type="file"> or a canvas.toBlob()).
   Response JSON: { "name": "...", "url": "/uploads/<name>", "size": <bytes> }
   Reference the saved file directly afterwards, e.g. <img src="/uploads/<name>">''',
    '''List previously uploaded files:
   GET /uploads
   Response JSON: { "files": [ { "name": "...", "url": "/uploads/..." }, ... ] }''',
    '''Delete an uploaded file:
   DELETE /uploads/<name>''',
  ],
);

const setsCapability = SandboxCapability(
  key: 'sets',
  label: 'Import folders of images',
  description: 'Pick a whole folder of images at once (e.g. a set of backgrounds) via /sets.',
  persistenceNote: '/sets',
  promptSections: [
    '''Import a whole folder of images as a named set (opens Android's real native folder browser — the user picks a folder on their device, e.g. a photo album, and every image directly inside it is imported at once):
   POST /sets/import
   POST /sets/import?name=<custom name>   (optional — otherwise the set is named after the picked folder)
   No request body. Response JSON: { "name": "...", "files": [ { "name": "...", "url": "/sets/<name>/<file>" }, ... ] }
   or { "cancelled": true } if the user backed out of the picker,
   or { "error": "..." } if the folder had no images or couldn't be read (some Android folders like Downloads are protected).''',
    '''List saved sets:
   GET /sets
   Response JSON: { "sets": [ { "name": "...", "count": <n> }, ... ] }''',
    '''List files in one set:
   GET /sets/<name>
   Response JSON: { "files": [ { "name": "...", "url": "/sets/<name>/<file>" }, ... ] }
   Reference an image directly, e.g. <img src="/sets/<name>/<file>">''',
    '''Delete a whole set:
   DELETE /sets/<name>''',
  ],
);

const shareCapability = SandboxCapability(
  key: 'share',
  label: 'Share sheet',
  description: "Push text or a file to another app via Android's native share sheet.",
  promptSections: [
    '''Share text and/or a file (opens Android's native share sheet):
   POST /share
   Body JSON: { "text": "...", "url": "/uploads/<name>" }   (both optional, at least one required; `url` must be a URL this server already gave you back from /uploads or /sets)
   Response JSON: { "status": "success" | "dismissed" | "unavailable" }''',
  ],
);

const speakCapability = SandboxCapability(
  key: 'speak',
  label: 'Text-to-speech',
  description: 'Speak text aloud on-device — no network, no external API.',
  promptSections: [
    '''Speak text aloud with on-device text-to-speech (no network, no external API):
   POST /speak
   Body JSON: { "text": "...", "language": "ja-JP" }   (language optional)
   Response JSON: { "ok": true }''',
    '''Stop any speech in progress:
   POST /speak/stop''',
    '''List available TTS language codes (so you can check one exists before offering it, e.g. as a picker):
   GET /speak/languages
   Response JSON: { "languages": [ "en-US", "ja-JP", ... ] }''',
  ],
);

const microformatsCapability = SandboxCapability(
  key: 'microformats',
  label: 'Microformats2 markup',
  description:
      "Mark up content with h-entry/p-name/e-content etc. so it's easier for an AI to edit this app later — not for any external consumer.",
  promptSections: [
    '''Where the app's content is naturally note/entry/card-shaped (journal entries, list items, saved cards — not a drawing canvas or a pure game), structure it with microformats2 class names: a root h-* class (h-entry, h-card, h-item, ...) with property classes inside it — p-name (plain text), e-content (rich/HTML content), dt-published/dt-updated (datetimes), u-photo/u-url (URLs). Example:
     <article class="h-entry">
       <h2 class="p-name">Title</h2>
       <div class="e-content">Body text...</div>
       <time class="dt-published" datetime="2026-01-01">Jan 1</time>
     </article>
   This isn't for any external tool to parse — the app is fully offline — it's so a future edit to this app (by an AI, or by you) can tell what each element means from its class name alone instead of re-deriving the structure from scratch. Full vocabulary: microformats.org/wiki/h-entry. Skip entirely if the content doesn't naturally fit this shape.''',
  ],
);

const allSandboxCapabilities = [
  uploadsCapability,
  setsCapability,
  shareCapability,
  speakCapability,
  microformatsCapability,
];

/// Builds the full prompt text for the given set of enabled capability
/// keys. localStorage is always section 1; enabled capabilities follow in
/// [allSandboxCapabilities] order; the closing rules' persistence list only
/// names the mechanisms actually included.
String buildSandboxPromptText(Set<String> enabledKeys) {
  final enabled = allSandboxCapabilities.where((c) => enabledKeys.contains(c.key));

  final sections = <String>[
    'localStorage — works as normal (getItem/setItem/removeItem/clear/key/length). '
        'It is transparently backed by native on-device storage, so data reliably '
        'survives the app being closed and reopened.',
    for (final capability in enabled) ...capability.promptSections,
  ];
  final numbered = [for (var i = 0; i < sections.length; i++) '${i + 1}. ${sections[i]}'].join('\n\n');

  final persistenceMechanisms = [
    'localStorage',
    for (final capability in enabled)
      if (capability.persistenceNote != null) capability.persistenceNote!,
  ];
  final persistenceList = persistenceMechanisms.length == 1
      ? persistenceMechanisms.first
      : '${persistenceMechanisms.sublist(0, persistenceMechanisms.length - 1).join(', ')} '
          'and ${persistenceMechanisms.last}';

  return '''This app will run inside a sandboxed local web server on a phone (no internet, no external APIs). Build it using only this persistence surface:

$numbered

Rules:
- Everything above is private to this one app — there is no way to read or write another app's data or files, and no auth is needed since it's already sandboxed per-app.
- Do NOT use IndexedDB, cookies, sessionStorage, or any other storage API — only $persistenceList actually persist.
- Do NOT call any external network APIs or CDNs — the app must work fully offline. Inline everything (CSS/JS) into the HTML, or reference only files you also upload/bundle alongside it.
''';
}
