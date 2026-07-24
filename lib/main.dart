import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'screens/home_screen.dart';
import 'services/app_repository.dart';
import 'services/storage_root.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final root = await resolvePicoPagesRoot();
  Hive.init(root.path);
  final repository = AppRepository(root: root);
  await repository.init();
  runApp(PicoPagesApp(repository: repository));
}

class PicoPagesApp extends StatelessWidget {
  final AppRepository repository;

  const PicoPagesApp({super.key, required this.repository});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PicoPages',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A5AE0)),
        useMaterial3: true,
      ),
      home: HomeScreen(repository: repository),
    );
  }
}
