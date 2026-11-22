import 'package:flutter/material.dart';

import 'design.dart';
import 'status_bar_fade.dart';

/// The statistics and review routes share a viewport, scroll insets and header.
class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.content});
  final Widget Function(EdgeInsets padding) content;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    return Scaffold(
      body: StatusBarFade(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: content(
              EdgeInsets.fromLTRB(16, 18 + insets.top, 16, 28 + insets.bottom),
            ),
          ),
        ),
      ),
    );
  }
}

class ActivityPageHeader extends StatelessWidget {
  const ActivityPageHeader(this.title, {super.key});
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new, size: 18),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(title, style: AppType.pageTitle),
        ),
      ),
    ],
  );
}
