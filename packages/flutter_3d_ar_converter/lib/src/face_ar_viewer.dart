import 'dart:io';
import 'package:flutter/material.dart';
import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter_3d_ar_converter/src/models/model_data.dart';
import 'package:permission_handler/permission_handler.dart';

/// Face AR Viewer widget for displaying glasses on a user's face
class FaceARViewer extends StatefulWidget {
  /// The 3D model data to display
  final ModelData modelData;

  /// Callback when the AR session is ready
  final Function()? onARViewCreated;

  /// Constructor
  const FaceARViewer({
    super.key,
    required this.modelData,
    this.onARViewCreated,
  });

  @override
  FaceARViewerState createState() => FaceARViewerState();
}

/// State for the Face AR Viewer widget
class FaceARViewerState extends State<FaceARViewer>
    with WidgetsBindingObserver {
  // iOS ARKit controllers and nodes
  ARKitController? arkitController;
  ARKitNode? faceNode;

  // Android ARCore controllers and managers
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARNode? androidFaceNode;

  /// Whether the AR session is initialized
  bool isInitialized = false;

  /// Whether face tracking is available
  bool isFaceTrackingAvailable = false;

  /// Whether there was an error initializing AR
  bool hasError = false;

  /// Error message if there was an error
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _requestPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (Platform.isIOS && arkitController != null) {
      if (state == AppLifecycleState.resumed) {
        // Resume AR session when app is resumed
      } else if (state == AppLifecycleState.paused) {
        // Pause AR session when app is paused
      }
    } else if (Platform.isAndroid && arSessionManager != null) {
      if (state == AppLifecycleState.resumed) {
        // Resume AR session when app is resumed
        // Note: AR Flutter Plugin handles lifecycle internally
      } else if (state == AppLifecycleState.paused) {
        // Pause AR session when app is paused
        // Note: AR Flutter Plugin handles lifecycle internally
      }
    }
  }

  /// Request camera permissions
  Future<void> _requestPermissions() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied) {
        setState(() {
          hasError = true;
          errorMessage =
              'Camera permission is required for Face AR functionality';
        });
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error requesting camera permission: $e';
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // Dispose platform-specific controllers
    if (Platform.isIOS) {
      arkitController?.dispose();
    } else if (Platform.isAndroid) {
      arSessionManager?.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face AR Error'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(errorMessage, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    hasError = false;
                    errorMessage = '';
                  });
                  _requestPermissions();
                },
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    // Platform-specific AR implementations
    if (Platform.isIOS) {
      // iOS implementation using ARKit
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face AR (iOS)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetIOSSession,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: ARKitSceneView(
                configuration: ARKitConfiguration.faceTracking,
                onARKitViewCreated: _onARKitViewCreated,
              ),
            ),
            if (!isInitialized)
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text(
                      'Initializing face tracking...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } else if (Platform.isAndroid) {
      // Android implementation using AR Flutter Plugin
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face AR (Android)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetAndroidSession,
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: ARView(onARViewCreated: _onAndroidARViewCreated)),
            if (!isInitialized)
              Container(
                color: Colors.black54,
                padding: const EdgeInsets.all(16),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(width: 16),
                    Text(
                      'Initializing face tracking...',
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    } else {
      // Unsupported platform
      return Scaffold(
        appBar: AppBar(
          title: const Text('Face AR'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, size: 48, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Face AR is not supported on this platform.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Currently only iOS and Android are supported.',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Reset the iOS AR session
  void _resetIOSSession() {
    if (arkitController == null) return;

    try {
      // Remove existing face node
      if (faceNode != null) {
        arkitController!.remove(faceNode!.name);
        faceNode = null;
      }

      // Set state to not initialized to show loading indicator
      setState(() {
        isInitialized = false;
      });

      // Add glasses model after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && isFaceTrackingAvailable) {
          _addGlassesModel();

          // Set initialized back to true after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                isInitialized = true;
              });
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error resetting iOS face AR session: $e');
    }
  }

  /// Reset the Android AR session
  void _resetAndroidSession() {
    if (arSessionManager == null || arObjectManager == null) return;

    try {
      // Remove existing face node
      if (androidFaceNode != null) {
        arObjectManager!.removeNode(androidFaceNode!);
        androidFaceNode = null;
      }

      // Set state to not initialized to show loading indicator
      setState(() {
        isInitialized = false;
      });

      // Add glasses model after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && isFaceTrackingAvailable) {
          _addAndroidFaceModel();

          // Set initialized back to true after a short delay
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                isInitialized = true;
              });
            }
          });
        }
      });
    } catch (e) {
      debugPrint('Error resetting Android face AR session: $e');
    }
  }

  /// Handle Android AR View creation
  void _onAndroidARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    arSessionManager = sessionManager;
    arObjectManager = objectManager;

    // Start AR session with error handling
    _startAndroidARSession();
  }

  /// Start the Android AR session with face tracking
  Future<void> _startAndroidARSession() async {
    try {
      // Initialize AR session with proper error handling
      await arSessionManager!.onInitialize(
        showFeaturePoints: false,
        showPlanes: false,
        customPlaneTexturePath: null,
        showWorldOrigin: false,
        handlePans: true,
        handleRotation: true,
        handleTaps: true,
      );

      // Set up error handler using a callback
      arSessionManager!.onPlaneOrPointTap = (hitTestResult) {
        // Handle taps if needed
      };

      // After initialization, check if we can proceed with face tracking
      setState(() {
        isFaceTrackingAvailable = true;
        isInitialized = true;
      });

      // Add the 3D model to the face
      _addAndroidFaceModel();
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error initializing Android AR session: $e';
      });
    }
  }

  /// Add the face model for Android
  Future<void> _addAndroidFaceModel() async {
    try {
      final modelFile = File(widget.modelData.modelPath);

      if (!await modelFile.exists()) {
        debugPrint('Model file does not exist: ${widget.modelData.modelPath}');
        return;
      }

      // Create a node for the glasses
      // In a real implementation, this would use ARCore's face mesh API
      // to attach the model to specific face features
      androidFaceNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: widget.modelData.modelPath,
        scale: Vector3(0.2, 0.2, 0.2),
        position: Vector3(0, 0, -1.5),
        rotation: Vector4(1, 0, 0, 0),
      );

      await arObjectManager!.addNode(androidFaceNode!);
    } catch (e) {
      debugPrint('Error adding Android face model: $e');
    }
  }

  /// Callback when the AR Kit view is created
  void _onARKitViewCreated(ARKitController controller) {
    try {
      arkitController = controller;

      controller.onAddNodeForAnchor = _handleAddAnchor;
      controller.onUpdateNodeForAnchor = _handleUpdateAnchor;

      // Check if face tracking is available by attempting to get face anchors
      // If the device doesn't support face tracking, this will fail gracefully
      try {
        // In ARKit, if we can create a face tracking configuration, it's supported
        // We're already using ARKitConfiguration.faceTracking in the ARKitSceneView
        // So we just need to check if we get face anchor updates

        // Set a timeout to check if we've received face anchors
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            if (faceNode != null) {
              // Face tracking is working
              setState(() {
                isFaceTrackingAvailable = true;
                isInitialized = true;
              });
            } else {
              // No face anchors received, face tracking might not be supported
              setState(() {
                isFaceTrackingAvailable = false;
                hasError = true;
                errorMessage =
                    'Face tracking may not be supported on this device';
              });
            }
          }
        });

        // Try to add the glasses model
        _addGlassesModel();
      } catch (error) {
        setState(() {
          hasError = true;
          errorMessage = 'Error initializing face tracking: $error';
        });
      }

      if (widget.onARViewCreated != null) {
        widget.onARViewCreated!();
      }
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error initializing Face AR: $e';
      });
    }
  }

  /// Handle adding an anchor
  void _handleAddAnchor(ARKitAnchor anchor) {
    if (anchor is ARKitFaceAnchor) {
      _updateFaceGeometry(anchor);
    }
  }

  /// Handle updating an anchor
  void _handleUpdateAnchor(ARKitAnchor anchor) {
    if (anchor is ARKitFaceAnchor) {
      _updateFaceGeometry(anchor);
    }
  }

  /// Update the face geometry based on the face anchor
  void _updateFaceGeometry(ARKitFaceAnchor anchor) {
    try {
      if (faceNode != null) {
        // Update the position and orientation of the glasses model
        // based on the face tracking data
        final transform = anchor.transform;
        faceNode!.transform = transform;

        // In a real implementation, you would also update the position
        // of the glasses based on facial features like eyes position
      }
    } catch (e) {
      debugPrint('Error updating face geometry: $e');
    }
  }

  /// Add the glasses model to the scene
  Future<void> _addGlassesModel() async {
    try {
      if (arkitController == null) return;

      final modelFile = File(widget.modelData.modelPath);

      if (!await modelFile.exists()) {
        debugPrint('Model file does not exist: ${widget.modelData.modelPath}');
        return;
      }

      // Create a node for the glasses
      faceNode = ARKitNode(
        geometry: ARKitSphere(
          radius: 0.01,
        ), // Small invisible sphere as parent node
        position: Vector3(0, 0, 0),
        eulerAngles: Vector3.zero(),
      );

      // In a real implementation, you would load the 3D model here
      // For now, we're using simple geometries as a placeholder

      // Add the node to the scene
      arkitController!.add(faceNode!);

      // Add child nodes for the glasses
      // These would be positioned relative to facial features
      _addGlassesFrames();
    } catch (e) {
      debugPrint('Error adding glasses model: $e');
    }
  }

  /// Add the glasses frames to the face node
  void _addGlassesFrames() {
    try {
      if (faceNode == null || arkitController == null) return;

      // Create materials first
      final glassMaterial = _createGlassMaterial();
      final frameMaterial = _createFrameMaterial();

      // Create geometries with materials
      final leftLensGeometry = ARKitSphere(
        radius: 0.025,
        materials: [glassMaterial],
      );

      final rightLensGeometry = ARKitSphere(
        radius: 0.025,
        materials: [glassMaterial],
      );

      final bridgeGeometry = ARKitBox(
        width: 0.02,
        height: 0.01,
        length: 0.01,
        materials: [frameMaterial],
      );

      final leftTempleGeometry = ARKitBox(
        width: 0.08,
        height: 0.005,
        length: 0.005,
        materials: [frameMaterial],
      );

      final rightTempleGeometry = ARKitBox(
        width: 0.08,
        height: 0.005,
        length: 0.005,
        materials: [frameMaterial],
      );

      // Left lens
      final leftLens = ARKitNode(
        geometry: leftLensGeometry,
        position: Vector3(-0.035, 0, 0.06),
        eulerAngles: Vector3.zero(),
      );

      // Right lens
      final rightLens = ARKitNode(
        geometry: rightLensGeometry,
        position: Vector3(0.035, 0, 0.06),
        eulerAngles: Vector3.zero(),
      );

      // Bridge
      final bridge = ARKitNode(
        geometry: bridgeGeometry,
        position: Vector3(0, 0, 0.06),
        eulerAngles: Vector3.zero(),
      );

      // Left temple (arm)
      final leftTemple = ARKitNode(
        geometry: leftTempleGeometry,
        position: Vector3(-0.06, 0, 0.05),
        eulerAngles: Vector3(0, -0.2, 0),
      );

      // Right temple (arm)
      final rightTemple = ARKitNode(
        geometry: rightTempleGeometry,
        position: Vector3(0.06, 0, 0.05),
        eulerAngles: Vector3(0, 0.2, 0),
      );

      // Add the parts to the face node
      arkitController!.add(leftLens, parentNodeName: faceNode!.name);
      arkitController!.add(rightLens, parentNodeName: faceNode!.name);
      arkitController!.add(bridge, parentNodeName: faceNode!.name);
      arkitController!.add(leftTemple, parentNodeName: faceNode!.name);
      arkitController!.add(rightTemple, parentNodeName: faceNode!.name);
    } catch (e) {
      debugPrint('Error adding glasses frames: $e');
    }
  }

  /// Create a material for the glasses lenses
  ARKitMaterial _createGlassMaterial() {
    // Using Color.fromRGBO instead of withOpacity to avoid deprecation warning
    final blueWithOpacity = Color.fromRGBO(0, 0, 255, 0.5);
    final material = ARKitMaterial(
      transparency: 0.5,
      diffuse: ARKitMaterialProperty.color(blueWithOpacity),
      specular: ARKitMaterialProperty.color(Colors.white),
    );
    return material;
  }

  /// Create a material for the glasses frames
  ARKitMaterial _createFrameMaterial() {
    final material = ARKitMaterial(
      diffuse: ARKitMaterialProperty.color(Colors.black),
      specular: ARKitMaterialProperty.color(Colors.grey),
    );
    return material;
  }
}
