import 'package:flutter/material.dart';
import 'hotstar_player_style.dart';

/// Shared anchor for player prompts (resume / next-episode / skip) that should
/// sit just above the bottom chrome, right-aligned. Derives its inset from the
/// single [HotstarPlayerStyle.bottomChromeHeight] token so it stays in sync
/// with the bottom bar instead of repeating its magic numbers.
class PlayerPromptPlacement extends StatelessWidget {
  const PlayerPromptPlacement({super.key, required this.child});

  final Widget child;

  static const double _gapAboveChrome = 12;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    return Positioned(
      right: HotstarPlayerStyle.edgeInset + padding.right,
      bottom:
          HotstarPlayerStyle.bottomChromeHeight +
          _gapAboveChrome +
          padding.bottom,
      child: child,
    );
  }
}
