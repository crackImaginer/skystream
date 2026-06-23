import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/domain/entity/multimedia_item.dart';
import '../data/trakt_service.dart';
import 'tracking_auth_provider.dart';

// Import TMDB and Language providers to fetch the missing posters
import '../../explore/data/explore_tmdb_provider.dart';
import '../../explore/data/explore_language_provider.dart';

part 'trakt_bookmarks_provider.g.dart';

@riverpod
Future<List<MultimediaItem>> traktBookmarks(Ref ref) async {
  // 1. Check if logged in
  final authState = ref.watch(trackingAuthProvider);
  final isTraktLoggedIn = authState.maybeWhen(
    data: (data) => data['trakt'] ?? false,
    orElse: () => false,
  );

  if (!isTraktLoggedIn) {
    return [];
  }

  // 2. Fetch raw Trakt items
  final traktService = ref.read(traktServiceProvider);
  final progressItems = await traktService.pullPlaybackProgress();

  // Services needed to fetch posters
  final tmdbService = ref.read(tmdbServiceProvider);
  final language = ref.read(languageProvider);

  // 3. Map items and fetch TMDB posters concurrently
  final mappedItems = await Future.wait(progressItems.map((item) async {
    String posterUrl = item.posterUrl ?? '';
    final tmdbId = item.tmdbId != null ? int.tryParse(item.tmdbId!) : null;

    // If we have a TMDB ID but no poster, fetch it quickly from TMDB
    if (posterUrl.isEmpty && tmdbId != null) {
      try {
        final type = item.type == MultimediaContentType.movie ? 'movie' : 'tv';
        final tmdbData = await tmdbService.getDetailsForCarousel(tmdbId, type, language: language);
        
        if (tmdbData != null && tmdbData['poster_path'] != null) {
          // Construct the full TMDB image URL
          posterUrl = 'https://image.tmdb.org/t/p/w500${tmdbData['poster_path']}';
        }
      } catch (_) {
        // Silently fail and keep the empty string if TMDB fetch fails
      }
    }

    return MultimediaItem(
      title: item.title,
      contentType: item.type,
      posterUrl: posterUrl,
      // Keep the unique Trakt URL for identification
      url: 'trakt_sync_${item.id ?? item.tmdbId ?? item.imdbId}', 
      tmdbId: tmdbId,
      imdbId: item.imdbId,
    );
  }));

  return mappedItems.toList();
}