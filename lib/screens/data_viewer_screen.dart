import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../services/app_repository.dart';
import '../services/backup_service.dart';

/// Shows what's actually persisted per app in its Hive-backed storage box —
/// the native mirror of that app's localStorage, independent of whatever
/// the WebView engine itself is caching — and lets the whole thing (every
/// app, its files, and all stored data) be backed up to a zip or restored
/// from one.
class DataViewerScreen extends StatefulWidget {
  final AppRepository repository;

  const DataViewerScreen({super.key, required this.repository});

  @override
  State<DataViewerScreen> createState() => _DataViewerScreenState();
}

class _DataViewerScreenState extends State<DataViewerScreen> {
  bool _busy = false;

  Future<Map<String, dynamic>> _readBox(String appId) async {
    final boxName = 'storage_$appId';
    final alreadyOpen = Hive.isBoxOpen(boxName);
    final box = alreadyOpen ? Hive.box(boxName) : await Hive.openBox(boxName);
    final map = {for (final k in box.keys) k.toString(): box.get(k)};
    if (!alreadyOpen) await box.close();
    return map;
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final path = await BackupService(root: widget.repository.root).exportBackup();
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup saved to $path')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore from backup?'),
        content: const Text(
          'This replaces everything currently in PicoPages — every app, its files, and its '
          'stored data — with what\'s in the backup zip you pick next. This can\'t be undone. '
          'The app will close afterward; reopen it to see the restored state.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final didRestore = await BackupService(root: widget.repository.root).importBackup();
      if (!didRestore) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Restore complete'),
          content: const Text('PicoPages will now close. Reopen it to see the restored data.'),
          actions: [
            TextButton(
              onPressed: () => SystemNavigator.pop(),
              child: const Text('Close PicoPages'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = widget.repository.listApps();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stored data'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_outlined),
            tooltip: 'Export backup',
            onPressed: _busy ? null : _exportBackup,
          ),
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: 'Restore from backup',
            onPressed: _busy ? null : _importBackup,
          ),
        ],
      ),
      body: Stack(
        children: [
          apps.isEmpty
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
          if (_busy) const ColoredBox(color: Colors.black38, child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
