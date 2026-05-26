import 'package:flutter/material.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'player_prompt_placement.dart';
import 'resume_prompt_overlay.dart';

class NextEpisodeOverlay extends StatelessWidget {
  final String nextEpisodeTitle;
  final VoidCallback onPlayNext;
  final VoidCallback onDismiss;
  final bool isTv;

  const NextEpisodeOverlay({
    super.key,
    required this.nextEpisodeTitle,
    required this.onPlayNext,
    required this.onDismiss,
    this.isTv = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PlayerPromptPlacement(
      child: CountdownFillButton(
        label: l10n.playNow,
        subtitle: nextEpisodeTitle,
        duration: const Duration(seconds: 15),
        onPressed: onPlayNext,
        onTimeout: onDismiss,
        isTv: isTv,
      ),
    );
  }
}
