import 'dart:io';
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import 'package:flutter_3d_ar_converter/src/models/model_data.dart';
import 'package:permission_handler/permission_handler.dart';

/// AR Viewer widget for displaying 3D models in augmented reality
class ARViewer extends StatefulWidget {
  /// The 3D model data to display
  final ModelData modelData;

  /// Callback when the AR session is ready
  final Function()? onARViewCreated;

  /// Callback when an object is placed
  final Function(ARNode node)? onObjectPlaced;

  /// Constructor
  const ARViewer({
    super.key,
    required this.modelData,
    this.onARViewCreated,
    this.onObjectPlaced,
  });

  @override
  ARViewerState createState() => ARViewerState();
}

/// State for the AR Viewer widget
class ARViewerState extends State<ARViewer> with WidgetsBindingObserver {
  /// AR session manager
  ARSessionManager? arSessionManager;

  /// AR object manager
  ARObjectManager? arObjectManager;

  /// AR anchor manager
  ARAnchorManager? arAnchorManager;

  /// List of nodes in the AR scene
  List<ARNode> nodes = [];

  /// Whether the AR session is initialized
  bool isInitialized = false;

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
    if (arSessionManager == null) return;

    if (state == AppLifecycleState.resumed) {
      // Resume AR session when app is resumed
      // Note: ar_flutter_plugin doesn't have direct onResume method
      // We need to handle this differently
      _handleSessionResume();
    } else if (state == AppLifecycleState.paused) {
      // Pause AR session when app is paused
      // Note: ar_flutter_plugin doesn't have direct onPause method
      // We need to handle this differently
      _handleSessionPause();
    }
  }

  /// Handle AR session resume
  void _handleSessionResume() {
    try {
      // For AR Flutter Plugin, we need to reinitialize the session
      if (isInitialized && arSessionManager != null) {
        arSessionManager!.onInitialize(
          showFeaturePoints: true,
          showPlanes: true,
          customPlaneTexturePath: "assets/triangle.png",
          showWorldOrigin: true,
          handlePans: true,
          handleRotation: true,
        );
      }
    } catch (e) {
      debugPrint('Error resuming AR session: $e');
    }
  }

  /// Handle AR session pause
  void _handleSessionPause() {
    try {
      // For AR Flutter Plugin, we need to dispose resources when paused
      // The actual implementation depends on the plugin's capabilities
      // This is a placeholder for proper implementation
    } catch (e) {
      debugPrint('Error pausing AR session: $e');
    }
  }

  /// Request camera permissions
  Future<void> _requestPermissions() async {
    try {
      final status = await Permission.camera.request();
      if (status.isDenied) {
        setState(() {
          hasError = true;
          errorMessage = 'Camera permission is required for AR functionality';
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
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Viewer'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetSession),
        ],
      ),
      body:
          hasError
              ? _buildErrorWidget()
              : Stack(
                children: [
                  ARView(
                    onARViewCreated: _onARViewCreated,
                    planeDetectionConfig:
                        PlaneDetectionConfig.horizontalAndVertical,
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FloatingActionButton(
                          onPressed: _addModelToScene,
                          child: const Icon(Icons.add),
                        ),
                        FloatingActionButton(
                          onPressed: _removeAllModels,
                          child: const Icon(Icons.delete),
                        ),
                      ],
                    ),
                  ),
                  if (!isInitialized)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Initializing AR...\nPlease move your device around',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
    );
  }

  /// Build widget to display error message
  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(
              'AR Initialization Error',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
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

  /// Callback when the AR view is created
  void _onARViewCreated(
    ARSessionManager sessionManager,
    ARObjectManager objectManager,
    ARAnchorManager anchorManager,
    ARLocationManager locationManager,
  ) {
    try {
      arSessionManager = sessionManager;
      arObjectManager = objectManager;
      arAnchorManager = anchorManager;

      arSessionManager!
          .onInitialize(
            showFeaturePoints: true,
            showPlanes: true,
            customPlaneTexturePath: "assets/triangle.png",
            showWorldOrigin: true,
            handlePans: true,
            handleRotation: true,
          )
          .then((_) {
            // AR session initialized successfully
            arObjectManager!.onInitialize();

            // Set up callbacks
            arSessionManager!.onPlaneOrPointTap = _onPlaneOrPointTapped;

            // Set state to initialized after a short delay to allow plane detection to start
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) {
                setState(() {
                  isInitialized = true;
                });
              }
            });

            if (widget.onARViewCreated != null) {
              widget.onARViewCreated!();
            }
          })
          .catchError((error) {
            setState(() {
              hasError = true;
              errorMessage = 'Failed to initialize AR: $error';
            });
          });
    } catch (e) {
      setState(() {
        hasError = true;
        errorMessage = 'Error setting up AR: $e';
      });
    }
  }

  /// Callback when a plane or point is tapped
  Future<void> _onPlaneOrPointTapped(List<dynamic> hitTestResults) async {
    try {
      if (hitTestResults.isEmpty) return;

      // The AR Flutter Plugin returns a list of ARKitHitTestResult or ArCoreHitTestResult
      // depending on the platform, so we need to handle it generically
      final hit = hitTestResults.first;
      await _addModelAtHit(hit);
    } catch (e) {
      debugPrint('Error handling tap: $e');
    }
  }

  /// Add a model at the hit location
  Future<void> _addModelAtHit(dynamic hit) async {
    if (arObjectManager == null) return;

    try {
      final modelFile = File(widget.modelData.modelPath);

      if (!await modelFile.exists()) {
        debugPrint('Model file does not exist: ${widget.modelData.modelPath}');
        return;
      }

      // Create position vector based on hit result
      // The hit result structure depends on the platform (iOS or Android)
      Vector3 hitPosition;

      try {
        // Try to access worldTransform (ARKit style)
        hitPosition = Vector3(
          hit.worldTransform.getColumn(3).x,
          hit.worldTransform.getColumn(3).y,
          hit.worldTransform.getColumn(3).z,
        );
      } catch (e) {
        try {
          // Try to access pose (ARCore style)
          hitPosition = Vector3(
            hit.pose.translation.x,
            hit.pose.translation.y,
            hit.pose.translation.z,
          );
        } catch (e2) {
          // Fallback to a default position if both approaches fail
          debugPrint('Could not extract position from hit result: $e2');
          hitPosition = Vector3(0, 0, -1.0);
        }
      }

      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: widget.modelData.modelPath,
        scale: Vector3(0.2, 0.2, 0.2),
        position: hitPosition,
        rotation: Vector4(0, 0, 0, 0),
      );

      final didAddNode = await arObjectManager!.addNode(node);

      if (didAddNode != null && didAddNode) {
        nodes.add(node);
        if (widget.onObjectPlaced != null) {
          widget.onObjectPlaced!(node);
        }
      }
    } catch (e) {
      debugPrint('Error adding model at hit location: $e');
    }
  }

  /// Add the model to the scene at the center of the camera view
  Future<void> _addModelToScene() async {
    if (arObjectManager == null || !isInitialized) return;

    try {
      final modelFile = File(widget.modelData.modelPath);

      if (!await modelFile.exists()) {
        debugPrint('Model file does not exist: ${widget.modelData.modelPath}');
        return;
      }

      final node = ARNode(
        type: NodeType.localGLTF2,
        uri: widget.modelData.modelPath,
        scale: Vector3(0.2, 0.2, 0.2),
        position: Vector3(0, 0, -1.0),
        rotation: Vector4(0, 0, 0, 0),
      );

      final didAddNode = await arObjectManager!.addNode(node);

      if (didAddNode != null && didAddNode) {
        nodes.add(node);
        if (widget.onObjectPlaced != null) {
          widget.onObjectPlaced!(node);
        }
      }
    } catch (e) {
      debugPrint('Error adding model to scene: $e');
    }
  }

  /// Remove all models from the scene
  Future<void> _removeAllModels() async {
    if (arObjectManager == null) return;

    try {
      for (final node in nodes) {
        await arObjectManager!.removeNode(node);
      }

      nodes.clear();
    } catch (e) {
      debugPrint('Error removing models: $e');
    }
  }

  /// Reset the AR session
  Future<void> _resetSession() async {
    if (arSessionManager == null) return;

    try {
      await _removeAllModels();

      // AR Flutter Plugin doesn't have a direct onResetARSession method
      // We need to reinitialize the session

      // Briefly set initialized to false to show loading indicator
      setState(() {
        isInitialized = false;
      });

      // Reinitialize the AR session
      await arSessionManager!.onInitialize(
        showFeaturePoints: true,
        showPlanes: true,
        customPlaneTexturePath: "assets/triangle.png",
        showWorldOrigin: true,
        handlePans: true,
        handleRotation: true,
      );

      // Set initialized back to true after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            isInitialized = true;
          });
        }
      });
    } catch (e) {
      debugPrint('Error resetting session: $e');
    }
  }
}
