import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/back_handler.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'app/storage_providers.dart';
import 'app/theme.dart';
import 'data/db/database.dart';
import 'data/storage/media_storage.dart';
import 'sync/sync_scheduler_host.dart';

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
      child: const SyncSchedulerHost(child: JobSiteRecordsApp()),
    ),
  );
}

class JobSiteRecordsApp extends StatefulWidget {
  const JobSiteRecordsApp({super.key});

  @override
  State<JobSiteRecordsApp> createState() => _JobSiteRecordsAppState();
}

class _JobSiteRecordsAppState extends State<JobSiteRecordsApp> {
  StreamSubscription<Uri>? _linkSub;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _linkSub = _appLinks.uriLinkStream.listen(_handleDeepLink);
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    final path = uri.path;
    final query = uri.query.isNotEmpty ? '?${uri.query}' : '';
    if (path.startsWith('/invite/accept') || path.startsWith('/auth/verify')) {
      appRouter.go('$path$query');
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Job Site Records',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
