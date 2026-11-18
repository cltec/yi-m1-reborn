import 'dart:ui';
import 'package:flutter/material.dart';
import 'adapters/console_log.dart';
import 'adapters/simulated_camera.dart';
import 'application/diagnostics.dart';
import 'application/load_gallery.dart';
import 'presentation/gallery.dart';

void main() {
  const debug = bool.fromEnvironment('CAMERA_DEBUG_LOGS');
  const log = AppLog(
    sink: consoleLog,
    minimumLevel: debug ? LogLevel.debug : LogLevel.info,
  );
  FlutterError.onError = (details) => log.emit(
    LogLevel.error,
    'app.unexpected',
    code: details.exception.runtimeType.toString(),
    stackTrace: details.stack,
  );
  PlatformDispatcher.instance.onError = (error, stack) {
    log.emit(
      LogLevel.error,
      'app.unexpected',
      code: error.runtimeType.toString(),
      stackTrace: stack,
    );
    return true; // Final safe reporter, not recoverable connection handling.
  };
  const scenario = String.fromEnvironment(
    'SIMULATED_CATALOG',
    defaultValue: 'populated',
  );
  final catalog = SimulatedCatalog.values.byName(scenario);
  final camera = SimulatedCamera(log: log, catalog: catalog);
  runApp(
    GalleryApp(
      discovery: camera,
      pairing: camera,
      gallery: LoadGallery(connection: camera, photos: camera, log: log),
      simulated: true,
    ),
  );
}
