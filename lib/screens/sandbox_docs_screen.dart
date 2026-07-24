import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Text meant to be copy-pasted straight into an AI prompt when asking it to
/// generate a new HTML app for this platform, so the app is written against
/// the sandbox's actual persistence surface instead of assuming a normal
/// browser/server environment.
const kSandboxApiPromptText = '''
This app will run inside a sandboxed local web server on a phone (no internet, no external APIs). Build it using only this persistence surface:

1. localStorage — works as normal (getItem/setItem/removeItem/clear/key/length). It is transparently backed by native on-device storage, so data reliably survives the app being closed and reopened.

2. Upload/save a file (photo, drawing, export, etc.):
   POST /uploads?filename=<name>
   Body: the raw file bytes — e.g.
     await fetch('/uploads?filename=' + encodeURIComponent(file.name), { method: 'POST', body: file })
   where `file` is a File/Blob (from <input type="file"> or a canvas.toBlob()).
   Response JSON: { "name": "...", "url": "/uploads/<name>", "size": <bytes> }
   Reference the saved file directly afterwards, e.g. <img src="/uploads/<name>">

3. List previously uploaded files:
   GET /uploads
   Response JSON: { "files": [ { "name": "...", "url": "/uploads/..." }, ... ] }

4. Delete an uploaded file:
   DELETE /uploads/<name>

Rules:
- Everything above is private to this one app — there is no way to read or write another app's data or files, and no auth is needed since it's already sandboxed per-app.
- Do NOT use IndexedDB, cookies, sessionStorage, or any other storage API — only localStorage and the /uploads endpoints above actually persist.
- Do NOT call any external network APIs or CDNs — the app must work fully offline. Inline everything (CSS/JS) into the HTML, or reference only files you also upload/bundle alongside it.
''';

class SandboxDocsScreen extends StatelessWidget {
  const SandboxDocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sandbox API'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy to clipboard',
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: kSandboxApiPromptText));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copied — paste into your AI prompt')));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: SelectableText(
            kSandboxApiPromptText,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
          ),
        ),
      ),
    );
  }
}
