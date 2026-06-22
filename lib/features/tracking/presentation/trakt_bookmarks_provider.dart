import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../data/trakt_service.dart';
import 'tracking_auth_provider.dart';

part 'trakt_bookmarks_provider.g.dart';

@riverpod
Future<List<MultimediaItem>> traktBookmarks(Ref ref) async {
  // Watch auth state so this provider refreshes when login status changes
  final authState = ref.watch(trackingAuthProvider);
  final isTraktLoggedIn = authState.maybeWhen(
    data: (data) => data['trakt'] ?? false,
    orElse: () => false,
  );

  if (!isTraktLoggedIn) {
    return [];
  }

  final traktService = ref.read(traktServiceProvider);
  final progressItems = await traktService.pullPlaybackProgress();

  // Map Trakt SyncProgressItems to your app's standard MultimediaItems
  return progressItems.map((item) {
    return MultimediaItem(
      title: item.title,
      contentType: item.type,
      // Provide a fallback or default value for URLs
      posterUrl: item.posterUrl ?? '',
      // Construct a unique identifier for navigation/keys
      url: 'trakt_sync_${item.id ?? item.tmdbId ?? item.imdbId}',
      tmdbId: item.tmdbId != null ? int.tryParse(item.tmdbId!) : null,
      imdbId: item.imdbId,
    );
  }).toList();
}