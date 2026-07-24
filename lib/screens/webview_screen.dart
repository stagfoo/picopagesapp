import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../models/app_entry.dart';
import '../services/app_repository.dart';
import '../services/local_server.dart';

class WebviewScreen extends StatefulWidget {
  final AppEntry entry;
  final AppRepository repository;

  const WebviewScreen({
    super.key,
    required this.entry,
    required this.repository,
  });

  @override
  State<WebviewScreen> createState() => _WebviewScreenState();
}

class _WebviewScreenState extends State<WebviewScreen> {
  LocalAppServer? _server;
  WebViewController? _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _launch();
  }

  Future<void> _launch() async {
    try {
      final folder = widget.repository.folderFor(widget.entry);
      final server = LocalAppServer(appId: widget.entry.id, rootDir: folder);
      final port = await server.start();

      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadRequest(Uri.parse('http://127.0.0.1:$port/index.html'));

      // Android WebView needs this explicitly wired up, or tapping any
      // <input type="file"> silently does nothing — no error, no dialog.
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        await platform.setOnShowFileSelector(_showFileSelector);
      }

      setState(() {
        _server = server;
        _controller = controller;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<List<String>> _showFileSelector(FileSelectorParams params) async {
    final imageOnly = params.acceptTypes.isNotEmpty &&
        params.acceptTypes.every((t) => t.startsWith('image/'));
    final result = await FilePicker.platform.pickFiles(
      type: imageOnly ? FileType.image : FileType.any,
      allowMultiple: params.mode == FileSelectorMode.openMultiple,
    );
    if (result == null) return [];
    return result.files
        .where((f) => f.path != null)
        .map((f) => Uri.file(f.path!).toString())
        .toList();
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry.title)),
      body: _error != null
          ? Center(child: Text('Failed to launch: $_error'))
          : _controller == null
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: _controller!),
    );
  }
}
