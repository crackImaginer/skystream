import '../../../../core/domain/entity/multimedia_item.dart';

sealed class LibraryState {
  const LibraryState();

  List<MultimediaItem> get items;
}

class LibraryLoading extends LibraryState {
  const LibraryLoading();
  @override
  List<MultimediaItem> get items => throw UnimplementedError();
}

class LibraryEmpty extends LibraryState {
  const LibraryEmpty();
  @override
  List<MultimediaItem> get items => throw UnimplementedError();
}

class LibrarySuccess extends LibraryState {
  @override
  final List<MultimediaItem> items;

  const LibrarySuccess(this.items);
}

class LibraryError extends LibraryState {
  final String message;
  const LibraryError(this.message);
  @override
  List<MultimediaItem> get items => throw UnimplementedError();
}