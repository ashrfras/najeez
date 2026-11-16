import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import '../../../core/design.dart';
import '../domain/task_controller.dart';

/// Paints above the page while keeping its last controls reachable.
class FocusLayout extends StatelessWidget {
  const FocusLayout({
    super.key,
    required this.controller,
    required this.child,
    required this.onError,
  });
  final TaskController controller;
  final Widget child;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final media = MediaQuery.of(context);
      final showBar =
          controller.focusedTask != null && media.viewInsets.bottom == 0;
      final text = TextPainter(
        text: const TextSpan(text: '00:00:00', style: AppType.body),
        textDirection: TextDirection.ltr,
        textScaler: media.textScaler,
      )..layout();
      // Match the bar's row, padding and border without reducing the viewport.
      final clearance = math.max(48.0, text.height) + 17.6 + 16;
      text.dispose();
      return Stack(
        fit: StackFit.expand,
        children: [
          MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom: media.padding.bottom + (showBar ? clearance : 0),
              ),
            ),
            child: child,
          ),
          if (showBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: clearance + math.max(media.padding.bottom, 8) + 36,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.background.withValues(alpha: 0),
                        AppColors.background.withValues(alpha: .35),
                        AppColors.background.withValues(alpha: .60),
                        AppColors.background.withValues(alpha: .75),
                      ],
                      stops: const [0, .45, .8, 1],
                    ),
                  ),
                ),
              ),
            ),
          if (showBar)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FocusBar(controller: controller, onError: onError),
            ),
        ],
      );
    },
  );
}

class FocusBar extends StatefulWidget {
  const FocusBar({super.key, required this.controller, required this.onError});
  final TaskController controller;
  final VoidCallback onError;

  @override
  State<FocusBar> createState() => _FocusBarState();
}

class _FocusBarState extends State<FocusBar> with WidgetsBindingObserver {
  Timer? _ticker;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    // Only refresh the visible text. Elapsed time always comes from startedAt.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ticker?.cancel();
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _startTicker();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      await widget.controller.finishFocus();
    } catch (_) {
      widget.onError();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = widget.controller.focusElapsed;
    String pad(int value) => value.toString().padLeft(2, '0');
    final time =
        '${pad(elapsed.inHours)}:${pad(elapsed.inMinutes % 60)}:${pad(elapsed.inSeconds % 60)}';
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  key: const ValueKey('focus-bar'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  decoration: panel(
                    color: AppColors.surface.withValues(alpha: .72),
                    border: AppColors.blue,
                    radius: 24,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.adjust, color: AppColors.blue, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.controller.focusedTask?.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.body.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        time,
                        textDirection: TextDirection.ltr,
                        style: AppType.body.copyWith(
                          color: AppColors.blue,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        label: 'إنهاء التركيز',
                        button: true,
                        child: IconButton.filledTonal(
                          key: const ValueKey('finish-focus'),
                          onPressed: _saving ? null : _finish,
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.blueDim,
                          ),
                          icon: const Icon(
                            Icons.stop_rounded,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
