import 'dart:async';
import 'package:flutter/material.dart';
// Pulled in for LogicalKeyboardKey / KeyDownEvent in the Focus key handler;
// `material.dart` does not re-export these (despite an earlier IDE hint).
import 'package:flutter/services.dart';
import 'package:skystream/l10n/generated/app_localizations.dart';
import 'hotstar_player_style.dart';
import 'player_prompt_placement.dart';

class ResumePromptOverlay extends StatelessWidget {
  final int? positionMs;
  final double? percentage;
  final VoidCallback onResume;
  final VoidCallback onStartOver;
  final bool isTv;
  final FocusNode? focusNode;

  const ResumePromptOverlay({
    super.key,
    this.positionMs,
    this.percentage,
    required this.onResume,
    required this.onStartOver,
    this.isTv = false,
    this.focusNode,
  });

  String _formatDuration(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String subtitle = "";
    if (positionMs != null && positionMs! > 0) {
      subtitle = l10n.pausedAt(_formatDuration(positionMs!));
    } else if (percentage != null && percentage! > 0) {
      subtitle = "Synced progress: ${percentage!.toStringAsFixed(0)}%";
    }
    return PlayerPromptPlacement(
      isTv: isTv,
      child: CountdownFillButton(
        focusNode: focusNode,
        label: l10n.resumeNow,
        subtitle: subtitle,
        duration: const Duration(seconds: 8),
        onPressed: onResume,
        onTimeout: onStartOver,
        isTv: isTv,
      ),
    );
  }
}

class CountdownFillButton extends StatefulWidget {
  final String label;
  final String? subtitle;
  final Duration duration;
  final VoidCallback onPressed;
  final VoidCallback onTimeout;
  final bool showDismiss;
  final VoidCallback? onDismiss;
  final bool isTv;
  final FocusNode? focusNode;

  const CountdownFillButton({
    super.key,
    required this.label,
    this.subtitle,
    required this.duration,
    required this.onPressed,
    required this.onTimeout,
    this.showDismiss = false,
    this.onDismiss,
    this.isTv = false,
    this.focusNode,
  });

  @override
  State<CountdownFillButton> createState() => _CountdownFillButtonState();
}

class _CountdownFillButtonState extends State<CountdownFillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _completed = false;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _timer = Timer(widget.duration, _handleTimeout);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handlePressed() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    widget.onPressed();
  }

  void _handleTimeout() {
    if (_completed) return;
    _completed = true;
    widget.onTimeout();
  }

  void _handleDismiss() {
    if (_completed) return;
    _completed = true;
    _timer?.cancel();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;
    final buttonWidth = isCompact ? 190.0 : 260.0;
    final buttonHeight = widget.subtitle == null
        ? (isCompact ? 46.0 : 52.0)
        : (isCompact ? 58.0 : 64.0);
    final borderRadius = BorderRadius.circular(isCompact ? 8 : 10);

    return FocusTraversalGroup(
      child: Focus(
        focusNode: _focusNode,
        autofocus: widget.isTv,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.space) {
            _handlePressed();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.escape ||
              key == LogicalKeyboardKey.goBack) {
            if (widget.onDismiss != null) {
              _handleDismiss();
            } else {
              // No explicit dismiss — fire the timeout path early so the
              // overlay tears itself down instead of trapping focus.
              _handleTimeout();
            }
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final isFocused = Focus.of(context).hasFocus;
            return AnimatedScale(
              scale: isFocused && widget.isTv ? 1.04 : 1.0,
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: SizedBox(
                width: buttonWidth,
                height: buttonHeight,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.52),
                          borderRadius: borderRadius,
                          boxShadow: isFocused && widget.isTv
                              ? [
                                  BoxShadow(
                                    color: HotstarPlayerStyle.accent.withValues(
                                      alpha: 0.55,
                                    ),
                                    blurRadius: 16,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                          border: Border.all(
                            color: isFocused && widget.isTv
                                ? HotstarPlayerStyle.accent
                                : Colors.white.withValues(alpha: 0.22),
                            width: isFocused && widget.isTv ? 2 : 1,
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: borderRadius,
                        child: AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _controller.value,
                                heightFactor: 1,
                                child: child,
                              ),
                            );
                          },
                          child: ColoredBox(
                            color: HotstarPlayerStyle.accent.withValues(
                              alpha: 0.92,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: borderRadius,
                          onTap: _handlePressed,
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 12 : 16,
                              vertical: isCompact ? 7 : 8,
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: isCompact ? 6 : 8),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isCompact ? 13 : 15,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (widget.subtitle != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          widget.subtitle!,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.78,
                                            ),
                                            fontSize: isCompact ? 10 : 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (widget.showDismiss &&
                                    widget.onDismiss != null)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                      minWidth: 28,
                                      minHeight: 28,
                                    ),
                                    onPressed: _handleDismiss,
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
