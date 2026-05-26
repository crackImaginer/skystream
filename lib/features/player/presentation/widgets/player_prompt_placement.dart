import 'package:flutter/material.dart';

/// Shared anchor for player prompts that should sit near the seek bar.
///
/// The right inset matches the seek bar's effective padding:
/// bottom controls horizontal padding (20) + progress bar padding (18).
class PlayerPromptPlacement extends StatelessWidget {
  const PlayerPromptPlacement({super.key, required this.child});

  final Widget child;

  static const double _rightInset = 38;
  static const double _bottomControlsPadding = 14;
  static const double _actionsRowHeight = 40;
  static const double _progressBarHeight = 58;
  static const double _bottomControlsTopPadding = 8;
  static const double _gapAboveSeekBar = 8;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewPaddingOf(context);
    const bottomInset =
        _bottomControlsPadding +
        _actionsRowHeight +
        _progressBarHeight +
        _bottomControlsTopPadding +
        _gapAboveSeekBar;

    return Positioned(
      right: _rightInset + padding.right,
      bottom: bottomInset + padding.bottom,
      child: child,
    );
  }
}
