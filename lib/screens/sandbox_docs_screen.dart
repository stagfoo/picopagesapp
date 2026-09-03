import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sandbox_prompt.dart';
import '../services/screen_profile.dart';

/// Lets you tick which sandbox capabilities a new app actually needs, then
/// shows (and copies) an AI-prompt tailored to just those — so the prompt
/// stays short instead of always describing every endpoint PicoPages has.
class SandboxDocsScreen extends StatefulWidget {
  const SandboxDocsScreen({super.key});

  @override
  State<SandboxDocsScreen> createState() => _SandboxDocsScreenState();
}

class _SandboxDocsScreenState extends State<SandboxDocsScreen> {
  final Set<String> _enabled = {};

  /// Kept so the copy button in the AppBar — which is built outside the body's
  /// LayoutBuilder — can put the same measured screen into the copied text as
  /// the on-screen preview shows.
  BoxConstraints? _lastConstraints;

  @override
  Widget build(BuildContext context) {
    // This screen is a Scaffold with an AppBar and a body, and so is
    // WebviewScreen — so the box this LayoutBuilder measures is the box the
    // WebView gets, insets and all. Measuring it beats deriving it from
    // MediaQuery arithmetic that has to second-guess how Scaffold treats the
    // status bar and the gesture inset.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sandbox API'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy to clipboard',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: buildSandboxPromptText(
                _enabled,
                screen: _screenOf(context, _lastConstraints),
              )));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copied — paste into your AI prompt')));
            },
          ),
        ],
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        _lastConstraints = constraints;
        final promptText = buildSandboxPromptText(
          _enabled,
          screen: _screenOf(context, constraints),
        );
        return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "What does this app need? localStorage and this phone's screen "
                "size are always included.",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ),
          ),
          for (final capability in allSandboxCapabilities)
            CheckboxListTile(
              dense: true,
              title: Text(capability.label),
              subtitle: Text(capability.description, style: const TextStyle(fontSize: 12)),
              value: _enabled.contains(capability.key),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _enabled.add(capability.key);
                } else {
                  _enabled.remove(capability.key);
                }
              }),
            ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: SelectableText(
                  promptText,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.4),
                ),
              ),
            ),
          ),
          ],
        );
      }),
    );
  }

  /// The WebView's viewport, in the CSS pixels an imported app writes in.
  ///
  /// Flutter's logical pixel and the WebView's CSS pixel are the same
  /// 1/160-inch unit on Android, so the measured constraints transfer across
  /// directly — provided the page declares `width=device-width`, which the
  /// prompt requires and the server now guarantees.
  ScreenProfile? _screenOf(BuildContext context, BoxConstraints? constraints) {
    if (constraints == null ||
        !constraints.hasBoundedWidth ||
        !constraints.hasBoundedHeight) {
      return null;
    }
    return ScreenProfile(
      widthCssPx: constraints.maxWidth.round(),
      heightCssPx: constraints.maxHeight.round(),
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
  }
}
