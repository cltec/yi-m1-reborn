import 'dart:async';

import 'package:flutter/material.dart';
import '../application/camera_discovery.dart';
import '../application/camera_pairing.dart';
import '../application/camera_connection.dart';
import '../application/camera_photos.dart';
import '../application/load_gallery.dart';

class GalleryApp extends StatelessWidget {
  const GalleryApp({
    super.key,
    required this.discovery,
    this.pairing,
    this.gallery,
    this.simulated = false,
  });
  final CameraDiscovery discovery;
  final CameraConnection? pairing;
  final LoadGallery? gallery;
  final bool simulated;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'YI M1 Reborn',
    home: Gallery(
      discovery: discovery,
      pairing: pairing,
      gallery: gallery,
      simulated: simulated,
    ),
  );
}

class Gallery extends StatefulWidget {
  const Gallery({
    super.key,
    required this.discovery,
    this.pairing,
    this.gallery,
    this.simulated = false,
  });
  final CameraDiscovery discovery;
  final CameraConnection? pairing;
  final LoadGallery? gallery;
  final bool simulated;

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
  List<CameraPhoto>? _photos;
  bool _listing = false;
  String? _listingError;
  int _listingGeneration = 0;
  int _connectionGeneration = 0;

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

  Future<void> _loadPhotos() async {
    final gallery = widget.gallery;
    if (gallery == null || _listing || !mounted || !_sessionReady) return;
    final generation = ++_listingGeneration;
    setState(() {
      _listing = true;
      _listingError = null;
      _photos = null;
    });
    try {
      final photos = await gallery.load();
      if (mounted && generation == _listingGeneration && _sessionReady) {
        setState(() => _photos = photos);
      }
    } on PhotoListingFailure catch (failure) {
      if (mounted && generation == _listingGeneration && _sessionReady) {
        setState(() => _listingError = failure.message);
      }
    } on ListingCancelled {
      // Disposal/link loss already selected the state; never show empty success.
    } catch (error, stack) {
      if (mounted && generation == _listingGeneration) {
        setState(() => _unexpectedError = true);
      }
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'gallery listing',
        ),
      );
    } finally {
      if (mounted && generation == _listingGeneration) {
        setState(() => _listing = false);
      }
    }
  }

  void _ready() {
    if (!mounted) return;
    if ((widget.pairing!.includesNetwork && !widget.pairing!.connected) ||
        (widget.gallery != null && widget.pairing!.verifiedSession == null)) {
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
    unawaited(_loadPhotos());
    final pairing = widget.pairing!;
    final generation = ++_connectionGeneration;
    final ended = pairing.connectionEnded;
    pairing.connectionLost?.then((_) async {
      if (!mounted || !_sessionReady || generation != _connectionGeneration)
        return;
      setState(() {
        _sessionReady = false;
        _photos = null;
        _listingError = null;
        _listingGeneration++;
        _listing = false;
        _pairingStatus = 'Releasing camera network';
        _pairingError = 'Camera network connection ended. Select Retry.';
      });
      try {
        await widget.gallery?.cancel();
        await ended;
        if (mounted && generation == _connectionGeneration) {
          setState(() => _pairingStatus = null);
        }
      } catch (error, stack) {
        _reportUnexpected(error, stack);
      }
    });
  }

  void _reportUnexpected(Object error, StackTrace stack) {
    if (mounted)
      setState(() {
        _pairingStatus = null;
        _unexpectedError = true;
      });
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'gallery lifecycle',
      ),
    );
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
    _listingGeneration++;
    _connectionGeneration++;
    unawaited(_disposeConnections());
    super.dispose();
  }

  Future<void> _disposeConnections() async {
    try {
      await widget.gallery?.cancel();
    } catch (error, stack) {
      _reportUnexpected(error, stack);
    }
    try {
      await widget.pairing?.cancel();
    } catch (error, stack) {
      _reportUnexpected(error, stack);
    }
  }

  Widget _catalog() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Connected'),
      if (_listing) ...[
        const Text('Loading photo filenames'),
        const LinearProgressIndicator(),
      ] else if (_listingError != null) ...[
        const Text('Photo listing failed'),
        Text(_listingError!),
        FilledButton(onPressed: _loadPhotos, child: const Text('Retry')),
      ] else if (_photos != null && _photos!.isEmpty)
        const Text('No photos')
      else if (_photos != null)
        Expanded(
          child: ListView.builder(
            itemCount: _photos!.length,
            itemBuilder: (context, index) => ListTile(
              key: ValueKey(_photos![index].id),
              title: Text(_photos![index].filename),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Gallery'),
      bottom: widget.simulated
          ? const PreferredSize(
              preferredSize: Size.fromHeight(28),
              child: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Simulated camera — no camera access'),
              ),
            )
          : null,
    ),
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
            if (widget.gallery != null) return _catalog();
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
