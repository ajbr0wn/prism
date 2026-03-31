import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/highlight_service.dart';
import 'services/library_service.dart';
import 'services/reading_settings_service.dart';
import 'services/sync_service.dart';
import 'services/theme_service.dart';
import 'screens/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0e0e16),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Try to initialize Firebase — gracefully skip if not configured
  SyncService? syncService;
  try {
    await Firebase.initializeApp();
    syncService = SyncService();
    await syncService.init();
  } catch (e) {
    debugPrint('Firebase not configured — running in local-only mode');
    syncService = null;
  }

  final libraryService = LibraryService();
  if (syncService != null) {
    libraryService.setSyncService(syncService);
  }

  runApp(PrismApp(
    libraryService: libraryService,
    syncService: syncService,
  ));
}

class PrismApp extends StatelessWidget {
  final LibraryService libraryService;
  final SyncService? syncService;

  const PrismApp({
    super.key,
    required this.libraryService,
    required this.syncService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: libraryService..init()),
        ChangeNotifierProvider(create: (_) => ThemeService()..init()),
        ChangeNotifierProvider(create: (_) => ReadingSettingsService()..init()),
        ChangeNotifierProvider(create: (_) => HighlightService()..init()),
        if (syncService != null)
          ChangeNotifierProvider.value(value: syncService!),
      ],
      child: MaterialApp(
        title: 'Prism',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0e0e16),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7c6fef),
            brightness: Brightness.dark,
          ),
        ),
        home: const LibraryScreen(),
      ),
    );
  }
}
