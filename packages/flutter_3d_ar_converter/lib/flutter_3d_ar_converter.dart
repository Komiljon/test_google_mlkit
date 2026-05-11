library;

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Export main components
export 'src/image_to_3d_converter.dart';
export 'src/ar_viewer.dart';
export 'src/face_ar_viewer.dart';
export 'src/models/model_data.dart';
export 'src/utils/file_utils.dart';

/// Main package class for Flutter 3D AR Converter
class Flutter3dArConverter {
  /// Singleton instance
  static final Flutter3dArConverter _instance =
      Flutter3dArConverter._internal();

  /// Method channel for native communication
  final MethodChannel _channel = const MethodChannel('flutter_3d_ar_converter');

  /// Whether the package has been initialized
  bool _isInitialized = false;

  /// Whether AR is available on this device
  bool _isARAvailable = false;

  /// Whether face tracking is available on this device
  bool _isFaceTrackingAvailable = false;

  /// Factory constructor
  factory Flutter3dArConverter() => _instance;

  /// Private constructor
  Flutter3dArConverter._internal();

  /// Whether the package has been initialized
  bool get isInitialized => _isInitialized;

  /// Whether AR is available on this device
  bool get isARAvailable => _isARAvailable;

  /// Whether face tracking is available on this device
  bool get isFaceTrackingAvailable => _isFaceTrackingAvailable;

  /// Initialize the package
  ///
  /// This method must be called before using any AR functionality.
  /// It checks if AR is available on the device and initializes the AR system.
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      // Check platform version
      final String? platformVersion = await _channel.invokeMethod(
        'getPlatformVersion',
      );
      debugPrint('Running on: $platformVersion');

      // Check AR availability
      _isARAvailable =
          await _channel.invokeMethod('checkARAvailability') ?? false;

      // Check face tracking availability (iOS and Android)
      if (Platform.isIOS) {
        _isFaceTrackingAvailable =
            await _channel.invokeMethod('checkFaceTrackingAvailability') ??
            false;
      } else if (Platform.isAndroid) {
        // For Android, we use ARCore's Face API
        _isFaceTrackingAvailable =
            await _channel.invokeMethod(
              'checkAndroidFaceTrackingAvailability',
            ) ??
            false;
      } else {
        _isFaceTrackingAvailable = false; // Not supported on other platforms
      }

      // Initialize AR if available
      if (_isARAvailable) {
        final bool initialized =
            await _channel.invokeMethod('initializeAR') ?? false;
        _isInitialized = initialized;
      } else {
        _isInitialized = false;
      }

      return _isInitialized;
    } catch (e) {
      debugPrint('Error initializing Flutter3dArConverter: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Get the platform version
  Future<String?> getPlatformVersion() async {
    return await _channel.invokeMethod('getPlatformVersion');
  }
}
