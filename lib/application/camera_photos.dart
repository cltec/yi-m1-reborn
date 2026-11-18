import 'dart:async';
import 'camera_network.dart';

/// One camera file; identity is not its display filename.
class CameraPhoto {
  const CameraPhoto({required this.id, required this.filename, this.timestamp});
  final String id;
  final String filename;

  /// Usable camera-provided time, not a claim about capture-time semantics.
  final DateTime? timestamp;
}

class PhotoListingFailure implements Exception {
  const PhotoListingFailure(this.message);
  final String message;
}

class ListingCancelled implements Exception {
  const ListingCancelled();
}

class ListingAttempt {
  final _cancelled = Completer<void>();
  bool get cancelled => _cancelled.isCompleted;
  Future<void> get cancellation => _cancelled.future;
  void cancel() {
    if (!cancelled) _cancelled.complete();
  }

  void check() {
    if (cancelled) throw const ListingCancelled();
  }

  Future<T> wait<T>(Future<T> operation) async {
    check();
    final result = await Future.any<T>([
      operation,
      cancellation.then<T>((_) => throw const ListingCancelled()),
    ]);
    check();
    return result;
  }
}

/// Returns a complete filename catalog or a managed failure, never partial success.
/// Wire paging/format mapping belongs in the adapter. Cancellation must settle
/// owned work before returning; do not download image bytes.
abstract interface class CameraPhotos {
  Future<List<CameraPhoto>> listPhotos(
    CameraNetworkSession session,
    ListingAttempt attempt,
  );
}
