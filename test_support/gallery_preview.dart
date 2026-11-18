// Running-app visual fixture. No camera or desktop-service access.
import 'package:flutter/material.dart';
import 'package:yi_m1_reborn/application/camera_discovery.dart';
import 'package:yi_m1_reborn/presentation/gallery.dart';
import 'package:yi_m1_reborn/application/pair_camera.dart';
import 'pairing_fixture.dart';

void main() => runApp(
  GalleryApp(
    discovery: PreviewDiscovery(),
    pairing: PairCamera(pairing: PreviewPairing(), store: PreviewStore()),
  ),
);

class PreviewDiscovery implements CameraDiscovery {
  @override
  Future<List<DiscoveredCamera>> discover() async => [
    const DiscoveredCamera(id: 'visual-sample', name: 'YI M1'),
  ];
}
