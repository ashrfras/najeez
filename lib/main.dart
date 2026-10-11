import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'core/design.dart';
import 'features/tasks/data/sqlite_task_repository.dart';
import 'features/tasks/domain/task_controller.dart';
import 'features/tasks/presentation/home_screen.dart';
import 'features/tasks/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }
  final repository = await SqliteTaskRepository.open();
  final controller = TaskController(repository);
  await controller.load();
  runApp(BaqiApp(controller: controller));
}

class BaqiApp extends StatefulWidget {
  const BaqiApp({
    super.key,
    required this.controller,
    this.splashDuration = const Duration(milliseconds: 2800),
  });

  final TaskController controller;
  final Duration splashDuration;

  @override
  State<BaqiApp> createState() => _BaqiAppState();
}

class _BaqiAppState extends State<BaqiApp> {
  Timer? _splashTimer;
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    _showSplash = widget.splashDuration > Duration.zero;
    if (_showSplash) {
      _splashTimer = Timer(widget.splashDuration, () {
        if (mounted) setState(() => _showSplash = false);
      });
    }
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'نجيز',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Plex Arabic',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.blue,
        surface: AppColors.surface,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.blue,
      ),
    ),
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: _showSplash
            ? const SplashScreen(key: ValueKey('splash'))
            : HomeScreen(
                key: const ValueKey('home'),
                controller: widget.controller,
              ),
      ),
    ),
  );
}
