import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_view/video_view.dart' as vv;
import '../../../../shared/widgets/custom_widgets.dart';
import 'hotstar_player_style.dart';
import 'player_stream_widgets.dart';

/// Top zone: back button + title/subtitle. Paints its own top scrim so the
/// chrome no longer needs a separate fixed-height Positioned gradient.
class PlayerTopBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool isTv;
  final FocusNode? backFocusNode;

  const PlayerTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.isTv = false,
    this.backFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    final edge = isTv
        ? HotstarPlayerStyle.tvEdgeInset
        : HotstarPlayerStyle.edgeInset;
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: HotstarPlayerStyle.topGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(edge, 14, edge, 24),
          child: Row(
            children: [
              PlayerIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: onBack,
                isTv: isTv,
                focusNode: backFocusNode,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          color: HotstarPlayerStyle.secondaryText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Text(
                      title,
                      style: TextStyle(
                        color: HotstarPlayerStyle.primaryText,
                        fontSize: isTv ? 22 : 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom zone shell: scrubber row on top, then a single controls row laid out
/// as [leading] (playback buttons) · scrollable [actions] · [trailing]
/// (utilities). Paints its own bottom scrim. Pure layout — the orchestrator
/// supplies the content so this widget never needs a long callback list.
class PlayerBottomBar extends StatelessWidget {
  final Widget progressBar;
  final List<Widget> leading;
  final List<Widget> actions;
  final List<Widget> trailing;
  final bool isTv;

  const PlayerBottomBar({
    super.key,
    required this.progressBar,
    this.leading = const [],
    this.actions = const [],
    this.trailing = const [],
    this.isTv = false,
  });

  @override
  Widget build(BuildContext context) {
    final edge = isTv
        ? HotstarPlayerStyle.tvEdgeInset
        : HotstarPlayerStyle.edgeInset;
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: HotstarPlayerStyle.bottomGradient,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(edge, 8, edge, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              progressBar,
              const SizedBox(height: 4),
              Row(
                children: [
                  // Fixed left group: play/pause, lock, next
                  ...leading,
                  // Right group: all action + utility buttons, scrollable
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ...actions,
                            if (actions.isNotEmpty && trailing.isNotEmpty)
                              const SizedBox(width: 4),
                            ...trailing,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Center playback cluster (rewind / play-pause / forward) used on touch
/// devices where the thumb-reach center tap target is expected.
class PlayerCenterControls extends StatelessWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final bool isLoading;
  final bool isTv;
  final bool canSeek;
  final FocusNode? playFocusNode;
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final VoidCallback onPlayPause;

  const PlayerCenterControls({
    super.key,
    required this.player,
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onPlayPause,
    this.videoViewController,
    this.isLoading = false,
    this.isTv = false,
    this.canSeek = true,
    this.playFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PlayerPlayPauseButton(
        player: player,
        videoViewController: videoViewController,
        isLoading: isLoading,
        isTv: isTv,
        size: 82,
        focusNode: playFocusNode,
        onPressed: onPlayPause,
      ),
    );
  }
}

/// A circular rewind/forward button. Used at large size in the touch center
/// cluster and at compact size inline in the TV/desktop control row.
class PlayerSeekButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isTv;
  final VoidCallback onPressed;

  const PlayerSeekButton({
    super.key,
    required this.icon,
    required this.size,
    required this.isTv,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      showFocusHighlight: isTv,
      onPressed: onPressed,
      shape: const CircleBorder(),
      child: Container(
        width: size + 16,
        height: size + 16,
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

/// Compact icon-only button for utilities (resize, PiP, fullscreen) and the
/// top-bar back button. Tooltip doubles as the semantics label.
class PlayerIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isTv;
  final bool highlight;
  final FocusNode? focusNode;

  const PlayerIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isTv = false,
    this.highlight = false,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final double box = isTv ? 48 : 44;
    return Tooltip(
      message: tooltip,
      child: CustomButton(
        onPressed: onPressed,
        showFocusHighlight: isTv,
        focusNode: focusNode,
        shape: const CircleBorder(),
        child: SizedBox(
          width: box,
          height: box,
          child: Icon(
            icon,
            color: highlight
                ? Theme.of(context).colorScheme.primary
                : Colors.white,
            size: isTv ? 28 : 26,
          ),
        ),
      ),
    );
  }
}

/// Labelled icon button for the controls row (Sources, Subtitles, Speed, …).
/// Activates on tap and on D-pad/keyboard select/enter/space when focused;
/// directional navigation between buttons is handled natively by the
/// enclosing traversal group — this widget never moves focus itself.
class PlayerActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  final bool isTv;
  final FocusNode? focusNode;

  const PlayerActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
    this.isTv = false,
    this.focusNode,
  });

  @override
  State<PlayerActionButton> createState() => _PlayerActionButtonState();
}

class _PlayerActionButtonState extends State<PlayerActionButton> {
  bool _hovered = false;
  bool _focused = false;
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.highlight || _hovered || _focused || _pressed;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final showTvFocusRing = widget.isTv && _focused;

    return Semantics(
      button: true,
      selected: widget.highlight,
      label: widget.label,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (value) => setState(() => _focused = value),
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() {
            _hovered = false;
            _pressed = false;
          }),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: widget.onTap,
              onHighlightChanged: _setPressed,
              borderRadius: BorderRadius.circular(8),
              hoverColor: Colors.transparent,
              focusColor: Colors.transparent,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: AnimatedContainer(
                duration: HotstarPlayerStyle.fastMotionDuration,
                constraints: const BoxConstraints(minHeight: 44),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isActive
                      ? primaryColor.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: showTvFocusRing
                      ? Border.all(color: primaryColor, width: 2)
                      : null,
                  boxShadow: showTvFocusRing
                      ? [
                          BoxShadow(
                            color: primaryColor.withValues(alpha: 0.2),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.icon,
                      color: isActive ? primaryColor : Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: isActive
                            ? primaryColor
                            : HotstarPlayerStyle.primaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
