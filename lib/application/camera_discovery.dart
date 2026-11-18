class DiscoveredCamera {
  const DiscoveredCamera({required this.id, required this.name});

  final String id;
  final String name;
}

class DiscoveryFailure implements Exception {
  const DiscoveryFailure(this.message);

  final String message;
}

abstract interface class CameraDiscovery {
  Future<List<DiscoveredCamera>> discover();
}
