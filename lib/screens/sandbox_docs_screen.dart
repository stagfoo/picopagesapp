import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sandbox_prompt.dart';

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

  @override
  Widget build(BuildContext context) {
    final promptText = buildSandboxPromptText(_enabled);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sandbox API'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_outlined),
            tooltip: 'Copy to clipboard',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: promptText));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Copied — paste into your AI prompt')));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'What does this app need? localStorage is always included.',
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
      ),
    );
  }
}
