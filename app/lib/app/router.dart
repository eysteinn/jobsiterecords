import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/capture/capture_hub_screen.dart';
import '../features/capture/file_capture_screen.dart';
import '../features/capture/note_capture_screen.dart';
import '../features/capture/photo_capture_screen.dart';
import '../features/capture/voice_capture_screen.dart';
import '../features/export/export_screen.dart';
import '../features/item_detail/item_detail_screen.dart';
import '../features/jobs/job_detail_screen.dart';
import '../features/jobs/job_form_screen.dart';
import '../features/jobs/jobs_list_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell.dart';

final appRouter = GoRouter(
  initialLocation: '/jobs',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/jobs',
              name: 'jobs',
              builder: (_, __) => const JobsListScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/capture',
              name: 'capture',
              builder: (_, __) => const SecondaryTabBack(child: CaptureHubScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              name: 'settings',
              builder: (_, __) => const SecondaryTabBack(child: SettingsScreen()),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/jobs/new',
      name: 'job-new',
      builder: (_, __) => const JobFormScreen(),
    ),
    GoRoute(
      path: '/jobs/:id',
      name: 'job-detail',
      builder: (_, state) => JobDetailScreen(jobId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/jobs/:id/edit',
      name: 'job-edit',
      builder: (_, state) => JobFormScreen(jobId: state.pathParameters['id']),
    ),
    GoRoute(
      path: '/jobs/:id/capture/photo',
      name: 'capture-photo',
      builder: (_, state) => PhotoCaptureScreen(jobId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/jobs/:id/capture/voice',
      name: 'capture-voice',
      builder: (_, state) => VoiceCaptureScreen(jobId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/jobs/:id/capture/note',
      name: 'capture-note',
      builder: (_, state) => NoteCaptureScreen(jobId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/jobs/:id/capture/file',
      name: 'capture-file',
      builder: (_, state) => FileCaptureScreen(jobId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/jobs/:id/export',
      name: 'job-export',
      builder: (_, state) => ExportScreen(jobId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/items/:id',
      name: 'item-detail',
      builder: (_, state) => ItemDetailScreen(itemId: state.pathParameters['id']!),
    ),
  ],
  errorBuilder: (_, state) => Scaffold(
    appBar: AppBar(title: const Text('Not found')),
    body: Center(child: Text(state.error?.toString() ?? 'Not found')),
  ),
);
