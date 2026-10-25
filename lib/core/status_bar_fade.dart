import 'package:flutter/material.dart';

/// Lets a scroll view paint behind the status bar while fading into its backdrop.
/// The child must include the top safe inset in its scrollable content padding.
class StatusBarFade extends StatelessWidget {
  const StatusBarFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final background = Theme.of(context).scaffoldBackgroundColor;
    return SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (topInset > 0)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        background,
                        background,
                        background.withValues(alpha: 0),
                      ],
                      stops: const [0, .35, 1],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
