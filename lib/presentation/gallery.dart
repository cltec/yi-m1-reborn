import 'dart:async';

import 'package:flutter/material.dart';
import '../application/camera_discovery.dart';
import '../application/camera_pairing.dart';
import '../application/pair_camera.dart';

class GalleryApp extends StatelessWidget {
  const GalleryApp({super.key, required this.discovery, this.pairing});
  final CameraDiscovery discovery;
  final PairCamera? pairing;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'YI M1 Reborn',
    home: Gallery(discovery: discovery, pairing: pairing),
  );
}

class Gallery extends StatefulWidget {
  const Gallery({super.key, required this.discovery, this.pairing});
  final CameraDiscovery discovery;
  final PairCamera? pairing;

  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  late Future<List<DiscoveredCamera>> _discovery;
  String? _selectedCamera;
  String? _pairingStatus;
  String? _pairingError;
  bool _sessionReady = false;
  bool _unexpectedError = false;

  @override
  void initState() {
    super.initState();
    _discovery = _open();
  }

  Future<List<DiscoveredCamera>> _open() async {
    try {
      final pairing = widget.pairing;
      if (pairing != null &&
          await pairing.resumeRemembered(onProgress: _progress)) {
        _ready();
        return [];
      }
      if (mounted) setState(() => _pairingStatus = null);
      return await widget.discovery.discover();
    } on PairingFailure catch (failure) {
      if (mounted)
        setState(() {
          _pairingError = failure.message;
          _pairingStatus = null;
        });
      return [];
    } on DiscoveryFailure {
      rethrow;
    } catch (error, stack) {
      if (mounted)
        setState(() {
          _pairingStatus = null;
          _unexpectedError = true;
        });
      // FutureBuilder consumes future errors; report unexpected faults explicitly.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'camera connection',
        ),
      );
      rethrow;
    }
  }

  void _progress(PairingStage stage) {
    if (!mounted) return;
    setState(
      () => _pairingStatus = switch (stage) {
        PairingStage.storage => 'Reading remembered pairing',
        PairingStage.cameraApproval => 'Approve pairing on the camera',
        PairingStage.saving => 'Saving pairing in the keyring',
        PairingStage.session => 'Establishing camera session',
        PairingStage.wifi => 'Joining camera Wi-Fi',
        PairingStage.verification => 'Checking camera response',
      },
    );
  }

  Future<void> _pair(DiscoveredCamera camera) async {
    if (_pairingStatus != null) return;
    setState(() => _pairingStatus = 'Preparing camera pairing');
    try {
      await widget.pairing!.pair(camera, onProgress: _progress);
      _ready();
    } on PairingFailure catch (failure) {
      if (mounted)
        setState(() {
          _pairingError = failure.message;
          _pairingStatus = null;
        });
    } catch (error, stack) {
      if (mounted)
        setState(() {
          _pairingStatus = null;
          _unexpectedError = true;
        });
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'camera connection',
        ),
      );
    }
  }

  void _ready() {
    if (!mounted) return;
    if (widget.pairing!.includesNetwork && !widget.pairing!.connected) {
      setState(() {
        _pairingStatus = null;
        _pairingError = 'Camera network connection ended. Select Retry.';
      });
      return;
    }
    setState(() {
      _sessionReady = true;
      _pairingStatus = null;
    });
    final pairing = widget.pairing!;
    final ended = pairing.connectionEnded;
    pairing.connectionLost?.then((_) async {
      if (!mounted || !_sessionReady) return;
      setState(() {
        _sessionReady = false;
        _pairingStatus = 'Releasing camera network';
        _pairingError = 'Camera network connection ended. Select Retry.';
      });
      await ended;
      if (mounted) setState(() => _pairingStatus = null);
    });
  }

  void _retry() {
    if (_pairingStatus != null) return;
    setState(() {
      _pairingError = null;
      _pairingStatus = null;
      _sessionReady = false;
      _selectedCamera = null;
      _discovery = _open();
    });
  }

  @override
  void dispose() {
    final pairing = widget.pairing;
    if (pairing != null) unawaited(pairing.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gallery')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: FutureBuilder<List<DiscoveredCamera>>(
        future: _discovery,
        builder: (context, snapshot) {
          if (_unexpectedError) {
            return const Text(
              'Unexpected application error. See diagnostic logs.',
            );
          }
          if (_sessionReady) {
            return widget.pairing?.includesNetwork == true
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Connected'),
                      Text(
                        'Camera is reachable. Photo filenames are not loaded yet.',
                      ),
                    ],
                  )
                : const Text(
                    'Pairing saved and BLE session verified. Wi-Fi connection is not enabled in this run.',
                  );
          }
          if (_pairingError != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Camera connection failed'),
                Text(_pairingError!),
                if (_pairingStatus != null) ...[
                  Text(_pairingStatus!),
                  const LinearProgressIndicator(),
                ] else
                  FilledButton(onPressed: _retry, child: const Text('Retry')),
              ],
            );
          }
          if (_pairingStatus != null) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pairingStatus!),
                const LinearProgressIndicator(),
              ],
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Searching for camera'),
                LinearProgressIndicator(),
              ],
            );
          }
          if (snapshot.hasError && snapshot.error is! DiscoveryFailure) {
            return const Text(
              'Unexpected application error. See diagnostic logs.',
            );
          }
          final cameras = snapshot.data ?? <DiscoveredCamera>[];
          if (snapshot.hasError || cameras.isEmpty) {
            final error = snapshot.error;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  snapshot.hasError
                      ? 'Camera discovery failed'
                      : 'No camera found',
                ),
                const SizedBox(height: 12),
                Text(
                  snapshot.hasError
                      ? (error is DiscoveryFailure
                            ? error.message
                            : 'Unable to search for the camera.')
                      : 'Check that the camera is on and Bluetooth is available.',
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _retry, child: const Text('Retry')),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select a camera'),
              Expanded(
                child: RadioGroup<String>(
                  groupValue: _selectedCamera,
                  onChanged: (value) => setState(() => _selectedCamera = value),
                  child: ListView(
                    children: [
                      for (final camera in cameras)
                        RadioListTile<String>(
                          value: camera.id,
                          title: Text(camera.name),
                        ),
                    ],
                  ),
                ),
              ),
              if (_selectedCamera != null) ...[
                Text(
                  'Selected: ${snapshot.data!.firstWhere((camera) => camera.id == _selectedCamera).name}',
                ),
                Text(
                  widget.pairing == null
                      ? 'Pairing is not available in this run.'
                      : 'Pair may replace an existing camera pairing. Confirm on the camera.',
                ),
              ],
              FilledButton(
                onPressed: _selectedCamera == null || widget.pairing == null
                    ? null
                    : () => _pair(
                        cameras.firstWhere(
                          (camera) => camera.id == _selectedCamera,
                        ),
                      ),
                child: const Text('Pair'),
              ),
            ],
          );
        },
      ),
    ),
  );
}
