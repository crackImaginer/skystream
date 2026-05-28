import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_view/video_view.dart' as vv;
import '../player_controller.dart';
import '../../../../shared/widgets/custom_widgets.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import 'hotstar_player_style.dart';
import '../../../skip/data/skip_service.dart';

/// A self-contained progress bar widget that uses StreamBuilder to avoid
/// rebuilding the parent widget on every position update.
class PlayerProgressBar extends ConsumerStatefulWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final VoidCallback? onSeekStart;
  final VoidCallback? onSeekEnd;

  /// On TV the scrubber becomes a focusable element: D-pad Left/Right seek by
  /// the configured step and the thumb enlarges while focused. Off TV the
  /// slider stays pointer-only (it is reached by touch/mouse, not focus).
  final bool isTv;

  const PlayerProgressBar({
    super.key,
    required this.player,
    this.videoViewController,
    this.onSeekStart,
    this.onSeekEnd,
    this.isTv = false,
  });

  @override
  ConsumerState<PlayerProgressBar> createState() => _PlayerProgressBarState();
}

class _PlayerProgressBarState extends ConsumerState<PlayerProgressBar> {
  double? _dragValue;
  bool _scrubFocused = false;
  final FocusNode _scrubFocusNode = FocusNode(debugLabel: 'scrubber');
  static const double _sliderTrackInset = 24;

  // ValueNotifiers so position/duration updates don't setState the whole widget.
  final _vvPositionNotifier = ValueNotifier<int>(0);
  final _vvDurationNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    widget.videoViewController?.position.addListener(_onVvPosition);
    widget.videoViewController?.mediaInfo.addListener(_onVvMediaInfo);
    _syncVideoViewProgress();
    // Drop any stale scrub-drag value when the active stream changes
    // (source switch, episode change, quality change). Otherwise the
    // thumb stays pinned to the previous drag position until the user
    // touches it again — confusing in particular when switching to a
    // shorter source where the drag value is now beyond duration.
    _watchStreamChanges();
  }

  void _watchStreamChanges() {
    // `currentStreamIndex` ticks every time the active source changes
    // (source picker, quality switch, episode autoplay). Cheap int
    // comparison; no allocations.
    ref.listenManual<int>(
      playerControllerProvider.select((s) => s.currentStreamIndex),
      (prev, next) {
        if (prev != null && prev != next && _dragValue != null && mounted) {
          setState(() => _dragValue = null);
        }
      },
    );
  }

  @override
  void didUpdateWidget(PlayerProgressBar old) {
    super.didUpdateWidget(old);
    if (old.videoViewController != widget.videoViewController) {
      old.videoViewController?.position.removeListener(_onVvPosition);
      old.videoViewController?.mediaInfo.removeListener(_onVvMediaInfo);
      widget.videoViewController?.position.addListener(_onVvPosition);
      widget.videoViewController?.mediaInfo.addListener(_onVvMediaInfo);
      _syncVideoViewProgress();
    }
  }

  void _syncVideoViewProgress() {
    _onVvPosition();
    _onVvMediaInfo();
  }

  void _onVvPosition() {
    _vvPositionNotifier.value = widget.videoViewController?.position.value ?? 0;
  }

  void _onVvMediaInfo() {
    _vvDurationNotifier.value =
        widget.videoViewController?.mediaInfo.value?.duration ?? 0;
  }

  @override
  void dispose() {
    widget.videoViewController?.position.removeListener(_onVvPosition);
    widget.videoViewController?.mediaInfo.removeListener(_onVvMediaInfo);
    _vvPositionNotifier.dispose();
    _vvDurationNotifier.dispose();
    _scrubFocusNode.dispose();
    super.dispose();
  }

  /// D-pad Left/Right seek while the scrubber holds focus on TV. Uses the
  /// user's configured seek step, matching the center seek buttons.
  KeyEventResult _handleScrubKey(KeyEvent event, bool canSeek) {
    if (!canSeek) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final step =
        ref.read(playerSettingsProvider).asData?.value.seekDuration ?? 10;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      ref
          .read(playerControllerProvider.notifier)
          .seekRelative(Duration(seconds: -step));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      ref
          .read(playerControllerProvider.notifier)
          .seekRelative(Duration(seconds: step));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  String _formatDuration(Duration duration) {
    final absDuration = duration.abs();
    final hours = absDuration.inHours;
    final minutes = absDuration.inMinutes.remainder(60);
    final seconds = absDuration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatRemaining(Duration duration, Duration position) {
    final remaining = duration - position;
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    return '-${_formatDuration(clamped)}';
  }

  Widget _buildTimeHeader({
    required bool isLive,
    required Duration duration,
    required Duration displayDuration,
  }) {
    if (isLive) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: _sliderTrackInset),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, color: Colors.red, size: 7),
                SizedBox(width: 5),
                Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final currentText = _formatDuration(displayDuration);
    final remainingText = _formatRemaining(duration, displayDuration);
    final durationText = _formatDuration(duration);
    // Persisted across sessions — once a user toggles to remaining-time
    // they almost always want it always. Stored in PlayerSettings so it
    // survives episode change, source change, and app restart.
    final showRemaining =
        ref.watch(
          playerSettingsProvider.select(
            (s) => s.asData?.value.showRemainingTime,
          ),
        ) ??
        false;
    final label = showRemaining
        ? '$remainingText / $durationText'
        : '$currentText / $durationText';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sliderTrackInset),
      child: Align(
        alignment: Alignment.centerLeft,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              ref
                  .read(playerSettingsProvider.notifier)
                  .setShowRemainingTime(!showRemaining);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: HotstarPlayerStyle.primaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useExoPlayer = ref.watch(
      playerControllerProvider.select((s) => s.useExoPlayer),
    );
    final canSeek = ref.watch(
      playerControllerProvider.select((s) => s.canSeek),
    );

    final skipSegments = ref.watch(
      playerControllerProvider.select((s) => s.skipSegments),
    );

    if (useExoPlayer && widget.videoViewController != null) {
      return _buildVideoViewBar(canSeek: canSeek, skipSegments: skipSegments);
    }
    return _buildMediaKitBar(canSeek: canSeek, skipSegments: skipSegments);
  }

  Widget _buildVideoViewBar({
    required bool canSeek,
    required List<SkipSegment> skipSegments,
  }) {
    final isLive = ref.watch(playerControllerProvider.select((s) => s.isLive));

    return ValueListenableBuilder<int>(
      valueListenable: _vvDurationNotifier,
      builder: (context, durationMs, _) {
        return ValueListenableBuilder<int>(
          valueListenable: _vvPositionNotifier,
          builder: (context, positionMs, _) {
            final durationMsD = durationMs.toDouble();
            final positionMsD = positionMs.toDouble();
            final displayValue = _dragValue ?? positionMsD;
            final displayDuration = Duration(
              milliseconds: (_dragValue ?? positionMsD).toInt(),
            );
            final duration = Duration(milliseconds: durationMs);

            return _buildRow(
              duration: duration,
              durationMs: durationMsD,
              displayValue: displayValue,
              displayDuration: displayDuration,
              bufferWidget: null,
              canSeek: canSeek,
              onSeekEnd: (val) => ref
                  .read(playerControllerProvider.notifier)
                  .seekTo(Duration(milliseconds: val.toInt())),
              isLive: isLive,
              skipSegments: skipSegments,
            );
          },
        );
      },
    );
  }

  Widget _buildMediaKitBar({
    required bool canSeek,
    required List<SkipSegment> skipSegments,
  }) {
    final isLive = ref.watch(playerControllerProvider.select((s) => s.isLive));

    return StreamBuilder<Duration>(
      stream: widget.player.stream.duration,
      initialData: widget.player.state.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;
        final durationMs = duration.inMilliseconds.toDouble();

        return StreamBuilder<Duration>(
          stream: widget.player.stream.position,
          initialData: widget.player.state.position,
          builder: (context, positionSnapshot) {
            final position = positionSnapshot.data ?? Duration.zero;
            final positionMs = position.inMilliseconds.toDouble();
            final displayValue = _dragValue ?? positionMs;
            final displayDuration = _dragValue != null
                ? Duration(milliseconds: _dragValue!.toInt())
                : position;

            final bufferWidget = durationMs > 0
                ? StreamBuilder<Duration>(
                    stream: widget.player.stream.buffer,
                    initialData: widget.player.state.buffer,
                    builder: (context, bufferSnapshot) {
                      final bufferMs = (bufferSnapshot.data ?? Duration.zero)
                          .inMilliseconds
                          .toDouble();
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: LinearProgressIndicator(
                          value: (bufferMs / durationMs).clamp(0, 1),
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withValues(alpha: 0.25),
                          ),
                          minHeight: 2,
                        ),
                      );
                    },
                  )
                : null;

            return _buildRow(
              duration: duration,
              durationMs: durationMs,
              displayValue: displayValue,
              displayDuration: displayDuration,
              bufferWidget: bufferWidget,
              canSeek: canSeek,
              onSeekEnd: (val) => ref
                  .read(playerControllerProvider.notifier)
                  .seekTo(Duration(milliseconds: val.toInt())),
              isLive: isLive,
              skipSegments: skipSegments,
            );
          },
        );
      },
    );
  }

  Widget _buildRow({
    required Duration duration,
    required double durationMs,
    required double displayValue,
    required Duration displayDuration,
    required Widget? bufferWidget,
    required bool canSeek,
    required void Function(double val) onSeekEnd,
    required List<SkipSegment> skipSegments,
    bool isLive = false,
  }) {
    final isDragging = _dragValue != null;
    return SizedBox(
      height: 58,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTimeHeader(
              isLive: isLive,
              duration: duration,
              displayDuration: displayDuration,
            ),
            Focus(
              focusNode: _scrubFocusNode,
              canRequestFocus: widget.isTv && canSeek,
              skipTraversal: !(widget.isTv && canSeek),
              onFocusChange: (f) {
                if (mounted) setState(() => _scrubFocused = f);
              },
              onKeyEvent: (node, event) => _handleScrubKey(event, canSeek),
              child: SizedBox(
                height: 34,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const tooltipWidth = 76.0;
                    final scrubPercent = durationMs > 0
                        ? (displayValue / durationMs).clamp(0.0, 1.0).toDouble()
                        : 0.0;
                    final maxTooltipLeft = constraints.maxWidth > tooltipWidth
                        ? constraints.maxWidth - tooltipWidth
                        : 0.0;
                    final tooltipLeft =
                        (constraints.maxWidth * scrubPercent - tooltipWidth / 2)
                            .clamp(0.0, maxTooltipLeft)
                            .toDouble();

                    return Stack(
                      alignment: Alignment.center,
                      clipBehavior: Clip.none,
                      children: [
                        ?bufferWidget,
                        if (durationMs > 0 && skipSegments.isNotEmpty)
                          ...skipSegments.map((seg) {
                            final leftPercent =
                                (seg.startTime * 1000 / durationMs).clamp(
                                  0.0,
                                  1.0,
                                );
                            final rightPercent =
                                (seg.endTime * 1000 / durationMs).clamp(
                                  0.0,
                                  1.0,
                                );
                            if (leftPercent >= rightPercent) {
                              return const SizedBox.shrink();
                            }

                            return Positioned(
                              left: constraints.maxWidth * leftPercent,
                              width:
                                  constraints.maxWidth *
                                  (rightPercent - leftPercent),
                              height: 2.5,
                              child: ColoredBox(
                                color: HotstarPlayerStyle.accent.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                            );
                          }),
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: _scrubFocused ? 4 : 2.5,
                            thumbShape: RoundSliderThumbShape(
                              enabledThumbRadius: canSeek
                                  ? (isDragging ? 8 : (_scrubFocused ? 9 : 6))
                                  // Hide the thumb entirely when the stream
                                  // isn't seekable (live) — a visible thumb
                                  // that doesn't respond to drag is the worst
                                  // UX, users tap it and assume the player is
                                  // broken.
                                  : 0,
                            ),
                            overlayShape: RoundSliderOverlayShape(
                              overlayRadius: canSeek
                                  ? (isDragging || _scrubFocused ? 16 : 10)
                                  : 0,
                            ),
                            activeTrackColor: canSeek
                                ? HotstarPlayerStyle.accent
                                : HotstarPlayerStyle.accent.withValues(
                                    alpha: 0.5,
                                  ),
                            inactiveTrackColor:
                                HotstarPlayerStyle.trackInactive,
                            disabledActiveTrackColor: HotstarPlayerStyle.accent
                                .withValues(alpha: 0.5),
                            disabledInactiveTrackColor:
                                HotstarPlayerStyle.trackInactive,
                            disabledThumbColor: Colors.transparent,
                            trackShape: const RoundedRectSliderTrackShape(),
                            thumbColor: Colors.white,
                            overlayColor: HotstarPlayerStyle.accent.withValues(
                              alpha: 0.18,
                            ),
                          ),
                          child: CustomSlider(
                            value: displayValue.clamp(
                              0,
                              durationMs > 0 ? durationMs : 1.0,
                            ),
                            min: 0.0,
                            max: durationMs > 0 ? durationMs : 1.0,
                            step: 5000,
                            onChanged: canSeek
                                ? (val) => setState(() => _dragValue = val)
                                : null,
                            onChangeStart: canSeek
                                ? (val) {
                                    widget.onSeekStart?.call();
                                    setState(() => _dragValue = val);
                                  }
                                : null,
                            onChangeEnd: canSeek
                                ? (val) {
                                    onSeekEnd(val);
                                    widget.onSeekEnd?.call();
                                    setState(() => _dragValue = null);
                                  }
                                : null,
                          ),
                        ),
                        if (isDragging)
                          Positioned(
                            left: tooltipLeft,
                            bottom: 34,
                            child: IgnorePointer(
                              child: SizedBox(
                                width: tooltipWidth,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.82,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _formatDuration(displayDuration),
                                      maxLines: 1,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlayerPlayPauseButton extends StatelessWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final bool isLoading;
  final bool isTv;
  final double size;
  final FocusNode? focusNode;
  final VoidCallback? onPressed;

  const PlayerPlayPauseButton({
    super.key,
    required this.player,
    this.videoViewController,
    this.isLoading = false,
    this.isTv = false,
    this.size = 82,
    this.focusNode,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isBuffering = ref.watch(
          playerControllerProvider.select((s) => s.isBuffering),
        );
        final useExoPlayer = ref.watch(
          playerControllerProvider.select((s) => s.useExoPlayer),
        );

        if (useExoPlayer && videoViewController != null) {
          return ListenableBuilder(
            listenable: videoViewController!.playbackState,
            builder: (context, _) {
              final isPlaying =
                  videoViewController!.playbackState.value ==
                  vv.VideoControllerPlaybackState.playing;
              return _buildButton(
                isPlaying: isPlaying,
                isSpinning: isBuffering,
              );
            },
          );
        }

        return StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (context, snapshot) {
            return _buildButton(
              isPlaying: snapshot.data ?? false,
              isSpinning: isBuffering,
            );
          },
        );
      },
    );
  }

  Widget _buildButton({required bool isPlaying, required bool isSpinning}) {
    return CustomButton(
      // No `autofocus: true` here. The parent (SkyStreamPlayerControlsState)
      // owns the focus story — on TV it calls `_playFocusNode.requestFocus()`
      // explicitly from initState / showControls. Setting autofocus here
      // additionally stole focus on phone + desktop every time the player
      // opened, even when the user was interacting with something else.
      focusNode: focusNode,
      onPressed: onPressed ?? () => player.playOrPause(),
      shape: const CircleBorder(),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        child: isSpinning
            ? SizedBox(
                width: size * 0.78,
                height: size * 0.78,
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3.5,
                  ),
                ),
              )
            : Icon(
                isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: size * 0.88,
              ),
      ),
    );
  }
}

class PlayerBufferingIndicator extends StatelessWidget {
  final bool isVisible;

  const PlayerBufferingIndicator({super.key, this.isVisible = false});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isBuffering = ref.watch(
          playerControllerProvider.select((s) => s.isBuffering),
        );
        final isLoading = ref.watch(
          playerControllerProvider.select((s) => s.isLoading),
        );
        final userSkippedOverlay = ref.watch(
          playerControllerProvider.select((s) => s.userSkippedOverlay),
        );

        // If controls are visible, the play button already shows a spinner; skip.
        // If the user hasn't skipped and we are loading, the primary loading overlay is visible; skip.
        if ((!isBuffering && !isLoading) || isVisible) {
          return const SizedBox.shrink();
        }
        if (isLoading && !userSkippedOverlay) return const SizedBox.shrink();

        return Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Container(
                width: 80,
                height: 80,
                padding: const EdgeInsets.all(8),
                child: const Center(
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
