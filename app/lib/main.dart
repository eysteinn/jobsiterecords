import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/back_handler.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/theme.dart';
import 'data/db/database.dart';
import 'data/storage/media_storage.dart';

final _appBackHandler = AppBackHandler(appRouter);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(isOptional: true);
  WidgetsBinding.instance.addObserver(_appBackHandler);
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
