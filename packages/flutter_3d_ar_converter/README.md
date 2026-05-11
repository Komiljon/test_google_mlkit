# Flutter 3D AR Converter

[![GitHub](https://img.shields.io/badge/GitHub-draz26648/flutter_3d_ar_converter-blue.svg)](https://github.com/draz26648/flutter_3d_ar_converter)

A Flutter package for converting 2D images to 3D models with AR visualization capabilities. This package integrates native AR technologies (ARKit for iOS and ARCore for Android) to provide immersive AR experiences. It allows you to:

1. Convert furniture images to 3D models and place them in your real-world environment using AR
2. Convert glasses/eyewear images to 3D models and try them on your face using face tracking (iOS only)
3. Convert generic objects to 3D models for AR visualization

## Features

- **Image to 3D Conversion**: Convert 2D images to 3D models using advanced image processing
- **AR Visualization**: Place 3D furniture models in your real-world environment using ARKit/ARCore
- **Face AR**: Try on glasses and eyewear in AR using face tracking on both iOS and Android
- **Native Integration**: Deep integration with platform-specific AR frameworks
- **Error Handling**: Robust error handling and fallbacks for unsupported devices
- **Easy API**: Simple Flutter API that abstracts away the complexity of AR

## Requirements

- Flutter SDK: ^3.7.2
- iOS 11.0+ for AR functionality (iOS 12.0+ recommended for face tracking)
- Android with ARCore support for AR functionality (Android 7.0+ with Google Play Services for AR)
- Camera permission
- Storage permission
- Internet permission (for downloading 3D models)

**Important**: This package requires native code implementation and cannot be used with Flutter web.

## Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_3d_ar_converter: ^0.1.0
```

### iOS Setup

Add the following to your `Info.plist` file:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access for AR functionality</string>
<key>io.flutter.embedded_views_preview</key>
<true/>
<key>UIRequiredDeviceCapabilities</key>
<array>
  <string>arm64</string>
  <string>arkit</string>
</array>
```

In your Podfile, ensure you're targeting iOS 11.0 or higher:

```ruby
platform :ios, '11.0'
```

### Android Setup

Add the following to your `AndroidManifest.xml` file:

```xml
<!-- Camera permission for AR -->
<uses-permission android:name="android.permission.CAMERA" />

<!-- Internet permission for downloading models -->
<uses-permission android:name="android.permission.INTERNET" />

<!-- AR features -->
<uses-feature android:name="android.hardware.camera.ar" android:required="true" />

<application>
  <!-- AR Core dependency -->
  <meta-data android:name="com.google.ar.core" android:value="required" />
</application>
```

Add Google Play Services for AR to your app's build.gradle:

```gradle
dependencies {
  implementation 'com.google.ar:core:1.36.0'
}
```

## Usage

### Initialize the Package

```dart
import 'package:flutter_3d_ar_converter/flutter_3d_ar_converter.dart';

// Initialize the package
final converter = Flutter3dArConverter();
await converter.initialize();

// Check if AR is available on the device
if (converter.isARAvailable) {
  print('AR is available on this device');
}

// Check if face tracking is available (iOS only)
if (converter.isFaceTrackingAvailable) {
  print('Face tracking is available on this device');
}
```

### Convert an Image to a 3D Model

```dart
// Create an instance of the converter
final imageConverter = ImageTo3DConverter();

// Pick an image from gallery
final imageFile = await imageConverter.pickImage();
// Or from camera
// final imageFile = await imageConverter.pickImage(fromCamera: true);

if (imageFile != null) {
  // Convert the image to a 3D model
  final modelData = await imageConverter.convertImageTo3D(
    imageFile,
    ModelType.furniture, // or ModelType.glasses, ModelType.object
    // Optional additional parameters
    additionalParams: {
      'quality': 'high',
      'format': 'glb',
    },
  );
  
  if (modelData != null) {
    print('Model created at: ${modelData.modelPath}');
    print('Model type: ${modelData.type}');
  }
}
```

### Display a 3D Model in AR

```dart
// Display furniture or object in AR
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => ARViewer(
      modelData: modelData,
      onARViewCreated: () {
        print('AR view created');
      },
      onObjectPlaced: (node) {
        print('Object placed at: ${node.position}');
      },
    ),
  ),
);
```

### Try on Glasses in AR (iOS and Android)

```dart
// Display glasses on face in AR
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => FaceARViewer(
      modelData: modelData,
      onARViewCreated: () {
        print('Face AR view created');
      },
    ),
  ),
);

// The FaceARViewer automatically handles platform differences
// and provides appropriate UI for iOS and Android

```

## Example App

Check out the example app in the `/example` folder for a complete implementation.

## How It Works

1. **Image Selection**: The user selects an image of furniture, glasses, or another object
2. **Image Processing**: The image is processed and converted to a 3D model using advanced algorithms
3. **Native AR Integration**: The package communicates with native AR frameworks (ARKit/ARCore) through platform channels
4. **AR Visualization**: The 3D model is displayed in AR, either placed in the environment (furniture) or on the user's face (glasses)
5. **User Interaction**: Users can manipulate the 3D model in AR space (move, rotate, scale)

### Native Code Implementation

This package uses native code implementation for AR functionality:

- **iOS**: Uses ARKit framework with Swift for AR rendering and face tracking
- **Android**: Uses ARCore through the Google Play Services for AR for environment tracking

The Flutter layer communicates with the native code through method channels, providing a seamless API while leveraging the full power of native AR capabilities.

## Limitations

- The current implementation uses placeholder 3D models for demonstration
- In a production environment, you would need to integrate with a real 3D conversion service (like Google's Objectron or custom ML models)
- Face AR is currently only available on iOS devices due to ARKit's advanced face tracking capabilities
- AR functionality requires compatible hardware and may not work on all devices
- The package size is relatively large due to AR dependencies
- Performance may vary based on device capabilities and lighting conditions

## Future Improvements

- Add support for more types of objects and 3D model formats
- Improve 3D model quality and accuracy using machine learning
- Add more customization options for AR visualization
- Enhance face tracking for better glasses placement
- Add Android face tracking support using ARCore Face Mesh
- Implement cloud-based 3D model conversion services
- Add support for multi-user AR experiences
- Optimize performance for lower-end devices
- Add support for AR scene saving and sharing

## License

This package is licensed under the MIT License - see the LICENSE file for details.
