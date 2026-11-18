import 'camera_discovery.dart';

class DiscoveryApprovalRequired implements CameraDiscovery {
  @override
  Future<List<DiscoveredCamera>> discover() async {
    throw const DiscoveryFailure(
      'Bluetooth discovery has not been authorized for this run. '
      'See the connection development guide.',
    );
  }
}
