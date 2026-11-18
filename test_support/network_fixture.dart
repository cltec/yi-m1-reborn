import 'dart:async';
import 'package:yi_m1_reborn/application/camera_pairing.dart';
import 'package:yi_m1_reborn/application/camera_network.dart';

class SampleNetwork implements CameraNetwork {
  CameraWifiCredentials? credentials;
  final session = SampleNetworkSession();
  @override
  Future<CameraNetworkSession> join(
    CameraWifiCredentials value,
    PairingAttempt attempt,
  ) async {
    credentials = value;
    return session;
  }
}

class SampleNetworkSession implements CameraNetworkSession {
  bool closed = false;
  final lostConnection = Completer<void>();
  @override
  bool get isActive => !lostConnection.isCompleted && !disconnected.isCompleted;
  @override
  Future<void> get lost => lostConnection.future;
  final disconnected = Completer<void>();
  @override
  String get localAddress => '192.168.0.20';
  @override
  Future<void> get ended => disconnected.future;
  @override
  Future<void> close() async {
    closed = true;
    if (!lostConnection.isCompleted) lostConnection.complete();
    if (!disconnected.isCompleted) disconnected.complete();
  }
}

class SampleReachability implements CameraReachability {
  String? address;
  @override
  Future<void> verify(String localAddress, PairingAttempt attempt) async {
    address = localAddress;
  }
}
