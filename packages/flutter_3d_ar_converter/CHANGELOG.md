## 0.1.1 

## Bug Fixes
* Fixed duplicate class definitions in FaceARViewer
* Resolved UI layout issues on Android devices
* Fixed permission handling for camera access
* Corrected model positioning in Face AR mode
* Follow dart formatting

## 0.1.0 - Cross-Platform Face AR Support (April 2025)

### New Features
* Added Android support for Face AR using ARCore face tracking
* Implemented platform-specific AR session management
* Added reset functionality for both iOS and Android AR sessions

### Improvements
* Fixed Face AR viewer implementation for iOS
* Improved platform detection and compatibility checks
* Removed redundant code and dependencies
* Enhanced error handling and user feedback
* Cleaner UI for all platforms
* Updated documentation with platform-specific instructions
* Improved lifecycle management for AR sessions

### Bug Fixes
* Fixed duplicate class definitions in FaceARViewer
* Resolved UI layout issues on Android devices
* Fixed permission handling for camera access
* Corrected model positioning in Face AR mode

### Known Limitations
* Face tracking quality may vary between iOS and Android devices
* Android implementation uses simplified face tracking compared to iOS

## 0.0.1 - Initial Release (April 2025)

### Features
* Initial implementation of image to 3D model conversion
* AR visualization for 3D models using ARKit (iOS) and ARCore (Android)
* Face AR for glasses try-on (iOS only)
* Comprehensive error handling and platform compatibility checks
* Example app demonstrating all features

### Components
* `ImageTo3DConverter` - Convert 2D images to 3D models
* `ARViewer` - Display 3D models in AR environment
* `FaceARViewer` - Try on glasses in AR using face tracking (iOS only)
* `ModelData` - Data model for 3D models
* `FileUtils` - Utility functions for file operations
* `Flutter3dArConverter` - Main package class with initialization and platform checks

### Platform Support
* iOS 11.0+ (iOS 12.0+ recommended for face tracking)
* Android with ARCore support (Android 7.0+ with Google Play Services for AR)

### Known Limitations
* Face tracking is only available on iOS devices
* Current implementation uses placeholder 3D models
* Integration with real 3D conversion services required for production use
