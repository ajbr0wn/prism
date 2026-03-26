import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/library_service.dart';
import 'services/theme_service.dart';
import 'screens/library_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Dark status bar for the app's dark aesthetic
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const PrismApp());
}

class PrismApp extends StatelessWidget {
  const PrismApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LibraryService()..init()),
        ChangeNotifierProvider(create: (_) => ThemeService()..init()),
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
