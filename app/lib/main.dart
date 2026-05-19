import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/db/database.dart';
import 'data/storage/media_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  final storage = await MediaStorage.open();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        mediaStorageProvider.overrideWithValue(storage),
      ],
      child: const JobSiteRecordsApp(),
    ),
  );
}

class JobSiteRecordsApp extends StatelessWidget {
  const JobSiteRecordsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Job Site Records',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      routerConfig: appRouter,
    );
  }
}
