import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../models/app_entry.dart';

/// Shows what's actually persisted per app in its Hive-backed storage box —
/// the native mirror of that app's localStorage, independent of whatever
/// the WebView engine itself is caching.
class DataViewerScreen extends StatelessWidget {
  final List<AppEntry> apps;

  const DataViewerScreen({super.key, required this.apps});

  Future<Map<String, dynamic>> _readBox(String appId) async {
    final boxName = 'storage_$appId';
    final alreadyOpen = Hive.isBoxOpen(boxName);
    final box = alreadyOpen ? Hive.box(boxName) : await Hive.openBox(boxName);
    final map = {for (final k in box.keys) k.toString(): box.get(k)};
    if (!alreadyOpen) await box.close();
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stored data')),
      body: apps.isEmpty
          ? const Center(child: Text('No apps imported yet'))
          : ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final entry = apps[index];
                return FutureBuilder<Map<String, dynamic>>(
                  future: _readBox(entry.id),
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final jsonText =
                        data == null ? '' : const JsonEncoder.withIndent('  ').convert(data);
                    return ExpansionTile(
                      title: Text(entry.title),
                      subtitle: Text(data == null
                          ? 'Loading…'
                          : '${data.length} key${data.length == 1 ? '' : 's'} stored'),
                      children: [
                        if (data != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data.isEmpty)
                                  const Text('(empty)', style: TextStyle(color: Colors.grey)),
                                if (data.isNotEmpty)
                                  SelectableText(jsonText, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                                const SizedBox(height: 8),
                                if (data.isNotEmpty)
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton.icon(
                                      icon: const Icon(Icons.copy, size: 16),
                                      label: const Text('Copy JSON'),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: jsonText));
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(content: Text('Copied')));
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
