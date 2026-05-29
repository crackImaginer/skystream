import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';
import 'package:media_kit/media_kit.dart';
import 'package:video_view/video_view.dart' as vv;
import 'package:skystream/l10n/generated/app_localizations.dart';
import '../../../settings/presentation/player_settings_provider.dart';
import '../player_controller.dart';
import 'hotstar_player_style.dart';
import 'player_bottom_sheets.dart';

/// A reusable right-anchored drawer shell for the player.
///
/// Layout is a pure [Row] — an [Expanded] scrim on the left, the drawer surface
/// on the right — so there is no inner [Stack] and no magic-offset [Positioned].
/// The parent mounts it via a single `Positioned.fill` in the one overlay layer
/// that already sits over the video.
///
/// Visibility animates the drawer width (0 → [panel width]); the content is held
/// at full width by an [OverflowBox] pinned to the right edge, so it slides
/// cleanly from the right in both directions while staying mounted. Mounting
/// persists so the content can drive focus on open. While closed it ignores
/// pointers and is excluded from focus, so taps and D-pad fall through to the
/// chrome below.
class PlayerSidePanel extends StatelessWidget {
  final bool isVisible;
  final bool isTv;
  final VoidCallback onDismiss;
  final Widget child;

  const PlayerSidePanel({
    super.key,
    required this.isVisible,
    required this.onDismiss,
    required this.child,
    this.isTv = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.shortestSide < 600;
    final panelWidth = isCompact
        ? (size.width * 0.86).clamp(280.0, 460.0)
        : 420.0;

    return IgnorePointer(
      ignoring: !isVisible,
      child: ExcludeFocus(
        excluding: !isVisible,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Scrim — tap (or click) anywhere outside the drawer to dismiss.
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDismiss,
                child: AnimatedContainer(
                  duration: HotstarPlayerStyle.controlFadeDuration,
                  color: Colors.black.withValues(alpha: isVisible ? 0.45 : 0.0),
                ),
              ),
            ),
            // The drawer — width animates for a slide-from-right reveal while
            // the content is pinned to full width by the OverflowBox.
            ClipRect(
              child: AnimatedContainer(
                duration: HotstarPlayerStyle.panelMotionDuration,
                curve: Curves.fastOutSlowIn,
                width: isVisible ? panelWidth : 0,
                child: OverflowBox(
                  alignment: Alignment.centerRight,
                  minWidth: panelWidth,
                  maxWidth: panelWidth,
                  child: _PanelSurface(child: child),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dark surface for the drawer: solid scrim-coloured background + a soft shadow
/// down the left edge to lift it off the video. No blur (keeps it cheap and
/// identical across platforms).
class _PanelSurface extends StatelessWidget {
  final Widget child;

  const _PanelSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HotstarPlayerStyle.background.withValues(alpha: 0.94),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 32,
            offset: const Offset(-10, 0),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Content for the sources side panel: a [TabBar] (Sources · Audio · Subtitles)
/// over a single-tab body. D-pad is two clean axes — Left/Right switch tabs,
/// Up/Down move through the rows of the active tab. Every selection applies
/// instantly: tapping a source switches playback immediately; tapping an
/// audio/subtitle track applies it right away. No Apply button, no pause/resume.
class PlayerSourcesPanel extends ConsumerStatefulWidget {
  final Player player;
  final vv.VideoController? videoViewController;
  final bool isTv;
  final VoidCallback onClose;

  const PlayerSourcesPanel({
    super.key,
    required this.player,
    required this.onClose,
    this.videoViewController,
    this.isTv = false,
  });

  @override
  ConsumerState<PlayerSourcesPanel> createState() => _PlayerSourcesPanelState();
}

class _PlayerSourcesPanelState extends ConsumerState<PlayerSourcesPanel>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Root node holds focus only as a fallback (e.g. a tab with no rows) so
  // Left/Right tab-switching and Back still work; skipTraversal keeps it out of
  // the normal Up/Down path.
  final FocusNode _rootNode = FocusNode(
    debugLabel: 'sources_panel_root',
    skipTraversal: true,
  );
  // Attached to the active tab's current (or first) row — the open/switch focus
  // target.
  final FocusNode _anchorNode = FocusNode(debugLabel: 'sources_panel_anchor');

  // Optimistic local selection so the checkmark moves the instant a row is
  // tapped, before the engine's track stream ticks back with the real state.
  String? _audioId;
  String? _subtitleId;
  bool _subtitlesOff = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: ref.read(playerControllerProvider).sourcesPanelTab.clamp(
        0,
        2,
      ),
    );
    _tabController.addListener(_onTabChanged);
    _syncFromSnapshot();
    // If (re)mounted while already open — e.g. a blocking loading/error phase
    // tore down and rebuilt the controls subtree — restore D-pad focus.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(playerControllerProvider).showSourcesPanel) {
        _focusActiveTab();
      }
    });
  }

  void _onTabChanged() {
    if (!mounted) return;
    setState(() {}); // rebuild body to the (new) active tab
    _focusActiveTab();
  }

  void _syncFromSnapshot() {
    final snapshot = ref
        .read(playerControllerProvider.notifier)
        .getTrackSelectionSnapshot();
    _audioId = snapshot.audioTracks.firstWhereOrNull((t) => t.selected)?.id;
    _subtitlesOff = snapshot.subtitlesOffSelected;
    _subtitleId = _subtitlesOff
        ? null
        : snapshot.subtitleTracks.firstWhereOrNull((t) => t.selected)?.id;
  }

  /// Focus the active tab's anchor row; if that tab has no focusable row (e.g.
  /// empty audio list), fall back to the root so the remote isn't stranded.
  void _focusActiveTab() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(playerControllerProvider).showSourcesPanel) {
        return;
      }
      if (_anchorNode.context != null) {
        _anchorNode.requestFocus();
      } else {
        _rootNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _rootNode.dispose();
    _anchorNode.dispose();
    super.dispose();
  }

  KeyEventResult _handlePanelKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack) {
      widget.onClose();
      return KeyEventResult.handled;
    }
    // Left/Right switch tabs (and are consumed at the edges so focus can't
    // escape the panel sideways). Up/Down fall through to directional traversal
    // within the active tab's list.
    if (key == LogicalKeyboardKey.arrowLeft) {
      if (_tabController.index > 0) {
        _tabController.animateTo(_tabController.index - 1);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      if (_tabController.index < _tabController.length - 1) {
        _tabController.animateTo(_tabController.index + 1);
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    // When the panel opens, jump to the requested tab, refresh selection, and
    // hand focus to the active tab.
    ref.listen(
      playerControllerProvider.select((s) => s.showSourcesPanel),
      (prev, next) {
        if (next == true && prev != true && mounted) {
          final tab = ref.read(playerControllerProvider).sourcesPanelTab.clamp(
            0,
            2,
          );
          if (_tabController.index != tab) _tabController.index = tab;
          setState(_syncFromSnapshot);
          _focusActiveTab();
        }
      },
    );
    // A source change loads its own track set — old ids no longer apply.
    ref.listen(
      playerControllerProvider.select((s) => s.currentStreamIndex),
      (prev, next) {
        if (prev != next && mounted) setState(_syncFromSnapshot);
      },
    );

    final l10n = AppLocalizations.of(context)!;

    return Focus(
      focusNode: _rootNode,
      onKeyEvent: _handlePanelKey,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header: tabs + close. Excluded from focus so D-pad stays in the
            // body (tabs are driven by Left/Right; Back closes). Touch/mouse can
            // still tap a tab or the close button.
            ExcludeFocus(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 4, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        indicatorColor: HotstarPlayerStyle.accent,
                        indicatorWeight: 2.5,
                        dividerColor: Colors.transparent,
                        labelColor: HotstarPlayerStyle.primaryText,
                        unselectedLabelColor: HotstarPlayerStyle.mutedText,
                        labelStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        tabs: [
                          Tab(text: l10n.sources),
                          Tab(text: l10n.audioTracks),
                          Tab(text: l10n.subtitles),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      icon: const Icon(Icons.close_rounded),
                      color: HotstarPlayerStyle.secondaryText,
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: HotstarPlayerStyle.divider, height: 1),
            Expanded(child: _buildActiveTab(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab(AppLocalizations l10n) {
    switch (_tabController.index) {
      case 1:
        return _buildTrackTab(l10n, isAudio: true);
      case 2:
        return _buildTrackTab(l10n, isAudio: false);
      default:
        return _buildSourcesTab(l10n);
    }
  }

  Widget _buildSourcesTab(AppLocalizations l10n) {
    final streams = ref.watch(
      playerControllerProvider.select((s) => s.streams),
    );
    final currentStream = ref.watch(
      playerControllerProvider.select((s) => s.currentStream),
    );

    if (streams.isEmpty) {
      return _EmptyHint(text: l10n.noResultsFound);
    }

    return _OptionList(
      children: streams.mapIndexed((index, stream) {
        final selected =
            currentStream != null &&
            currentStream.url == stream.url &&
            currentStream.source == stream.source;
        final isAnchor = selected || (currentStream == null && index == 0);
        return _PanelOptionRow(
          label: stream.source,
          selected: selected,
          isTv: widget.isTv,
          focusNode: isAnchor ? _anchorNode : null,
          onTap: () {
            if (selected) return;
            ref
                .read(playerControllerProvider.notifier)
                .changeStream(stream, manualSelection: true);
          },
        );
      }).toList(),
    );
  }

  /// Audio + Subtitles share a layout; both rebuild on engine track changes so a
  /// freshly loaded source's tracks appear without reopening the panel.
  Widget _buildTrackTab(AppLocalizations l10n, {required bool isAudio}) {
    final useExoPlayer = ref.watch(
      playerControllerProvider.select((s) => s.useExoPlayer),
    );
    if (useExoPlayer && widget.videoViewController != null) {
      return ListenableBuilder(
        listenable: widget.videoViewController!.mediaInfo,
        builder: (context, _) => isAudio
            ? _buildAudioBody(l10n)
            : _buildSubtitleBody(l10n),
      );
    }
    return StreamBuilder<Tracks>(
      stream: widget.player.stream.tracks,
      builder: (context, _) =>
          isAudio ? _buildAudioBody(l10n) : _buildSubtitleBody(l10n),
    );
  }

  Widget _buildAudioBody(AppLocalizations l10n) {
    final tracks = ref
        .read(playerControllerProvider.notifier)
        .getTrackSelectionSnapshot()
        .audioTracks;
    if (tracks.isEmpty) return _EmptyHint(text: l10n.noAudioTracks);
    return _OptionList(
      children: tracks.mapIndexed((index, track) {
        final selected = _audioId == track.id;
        final isAnchor = selected || (_audioId == null && index == 0);
        return _PanelOptionRow(
          label: track.label,
          metadata: track.subtitle,
          selected: selected,
          isTv: widget.isTv,
          focusNode: isAnchor ? _anchorNode : null,
          onTap: () {
            setState(() => _audioId = track.id);
            ref
                .read(playerControllerProvider.notifier)
                .selectAudioTrack(track.id);
          },
        );
      }).toList(),
    );
  }

  Widget _buildSubtitleBody(AppLocalizations l10n) {
    final tracks = ref
        .read(playerControllerProvider.notifier)
        .getTrackSelectionSnapshot()
        .subtitleTracks;

    final rows = <Widget>[
      // "Off" is always present and is the anchor when subtitles are disabled.
      _PanelOptionRow(
        label: l10n.off,
        selected: _subtitlesOff,
        isTv: widget.isTv,
        focusNode: _subtitlesOff ? _anchorNode : null,
        onTap: () {
          setState(() {
            _subtitlesOff = true;
            _subtitleId = null;
          });
          ref.read(playerControllerProvider.notifier).selectSubtitleTrack(null);
        },
      ),
      ...tracks.map((track) {
        final selected = !_subtitlesOff && _subtitleId == track.id;
        return _PanelOptionRow(
          label: track.label,
          metadata: track.subtitle,
          selected: selected,
          isTv: widget.isTv,
          focusNode: selected ? _anchorNode : null,
          onTap: () {
            setState(() {
              _subtitlesOff = false;
              _subtitleId = track.id;
            });
            ref
                .read(playerControllerProvider.notifier)
                .selectSubtitleTrack(track.id);
          },
        );
      }),
      // Advanced subtitle tooling (sync / styles / search / load external).
      _PanelOptionRow(
        label: l10n.options,
        leadingIcon: Icons.settings_outlined,
        selected: false,
        isTv: widget.isTv,
        onTap: () => PlayerBottomSheets.showSubtitleOptions(context),
      ),
    ];

    return _OptionList(children: rows);
  }
}

/// A focus-traversal group wrapping a scrollable list of option rows. Up/Down
/// move between rows geometrically; horizontal arrows are left for the panel to
/// handle as tab switches.
class _OptionList extends StatelessWidget {
  final List<Widget> children;

  const _OptionList({required this.children});

  @override
  Widget build(BuildContext context) {
    return FocusTraversalGroup(
      policy: ReadingOrderTraversalPolicy(),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: children,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Text(
        text,
        style: const TextStyle(
          color: HotstarPlayerStyle.mutedText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One selectable row. Focus cue is a subtle accent border + soft glow (no
/// scale), matching the refreshed control style. Activates on tap and on
/// D-pad/keyboard select/enter/space; directional movement between rows is
/// handled natively by the enclosing traversal group.
class _PanelOptionRow extends StatefulWidget {
  final String label;
  final String? metadata;
  final bool selected;
  final bool isTv;
  final FocusNode? focusNode;
  final IconData? leadingIcon;
  final VoidCallback onTap;

  const _PanelOptionRow({
    required this.label,
    required this.selected,
    required this.isTv,
    required this.onTap,
    this.metadata,
    this.focusNode,
    this.leadingIcon,
  });

  @override
  State<_PanelOptionRow> createState() => _PanelOptionRowState();
}

class _PanelOptionRowState extends State<_PanelOptionRow> {
  bool _focused = false;
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final showHighlight = _focused || _hovered;
    final meta = widget.metadata?.trim();
    final hasMeta = meta != null && meta.isNotEmpty;
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Focus(
        focusNode: widget.focusNode,
        onFocusChange: (v) => setState(() => _focused = v),
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
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: HotstarPlayerStyle.fastMotionDuration,
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              decoration: BoxDecoration(
                color: widget.selected
                    ? HotstarPlayerStyle.accent.withValues(alpha: 0.14)
                    : (showHighlight
                          ? Colors.white.withValues(alpha: 0.06)
                          : Colors.transparent),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _focused && widget.isTv
                      ? HotstarPlayerStyle.accent
                      : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: _focused && widget.isTv
                    ? [
                        BoxShadow(
                          color: HotstarPlayerStyle.accent.withValues(
                            alpha: 0.2,
                          ),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 26,
                    child: widget.leadingIcon != null
                        ? Icon(
                            widget.leadingIcon,
                            color: HotstarPlayerStyle.secondaryText,
                            size: 20,
                          )
                        : (widget.selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  color: HotstarPlayerStyle.accent,
                                  size: 20,
                                )
                              : null),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: widget.label,
                        children: [
                          if (hasMeta)
                            TextSpan(
                              text: '   $meta',
                              style: const TextStyle(
                                color: HotstarPlayerStyle.mutedText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.selected
                            ? HotstarPlayerStyle.primaryText
                            : HotstarPlayerStyle.secondaryText,
                        fontSize: 15,
                        fontWeight: widget.selected
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
