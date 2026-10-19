import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'core/design.dart';
import 'features/backup/backup_controller.dart';
import 'features/backup/backup_scope.dart';
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
  final backup = BackupController(repository, controller);
  await backup.loadSettings();
  runApp(BaqiApp(controller: controller, backup: backup));
}

class BaqiApp extends StatefulWidget {
  const BaqiApp({
    super.key,
    required this.controller,
    this.backup,
    this.splashDuration = const Duration(milliseconds: 2800),
  });

  final TaskController controller;
  final BackupController? backup;
  final Duration splashDuration;

  @override
  State<BaqiApp> createState() => _BaqiAppState();
}

class _BaqiAppState extends State<BaqiApp> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  String? _lastBackupMessage;

  void _backupChanged() {
    final message = widget.backup?.message;
    if (message == null) {
      _lastBackupMessage = null;
      return;
    }
    if (message == _lastBackupMessage) return;
    _lastBackupMessage = message;
    _messengerKey.currentState?.hideCurrentSnackBar();
    _messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: message.startsWith('جارٍ')
            ? const Duration(days: 1)
            : const Duration(seconds: 4),
      ),
    );
  }

  void _checkBackup() {
    final context = _navigatorKey.currentState?.overlay?.context;
    if (!mounted || _showSplash || context == null) return;
    unawaited(
      widget.backup?.foreground((date) => confirmBackupRestore(context, date)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkBackup();
  }

  Timer? _splashTimer;
  late bool _showSplash;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.backup?.addListener(_backupChanged);
    _showSplash = widget.splashDuration > Duration.zero;
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkBackup());
    if (_showSplash) {
      _splashTimer = Timer(widget.splashDuration, () {
        if (mounted) {
          setState(() => _showSplash = false);
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkBackup());
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.backup?.removeListener(_backupChanged);
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: _navigatorKey,
    scaffoldMessengerKey: _messengerKey,
    builder: (context, child) {
      final backup = widget.backup;
      if (backup == null) return child!;
      return BackupScope(
        controller: backup,
        child: AnimatedBuilder(
          animation: backup,
          builder: (context, _) => Stack(
            children: [
              child!,
              if (backup.applyingRestore)
                const Positioned.fill(
                  child: AbsorbPointer(
                    child: ColoredBox(
                      color: Color(0x88000000),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    },
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
