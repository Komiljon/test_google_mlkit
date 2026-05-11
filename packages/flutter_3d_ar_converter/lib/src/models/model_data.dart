/// Model data class to store 3D model information
class ModelData {
  /// The type of model (furniture, glasses, etc.)
  final ModelType type;

  /// Path to the 3D model file
  final String modelPath;

  /// Original image path that was used to create the model
  final String originalImagePath;

  /// Creation timestamp
  final DateTime createdAt;

  /// Additional metadata for the model
  final Map<String, dynamic>? metadata;

  /// Constructor
  ModelData({
    required this.type,
    required this.modelPath,
    required this.originalImagePath,
    DateTime? createdAt,
    this.metadata,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a copy of this model data with the given fields replaced
  ModelData copyWith({
    ModelType? type,
    String? modelPath,
    String? originalImagePath,
    DateTime? createdAt,
    Map<String, dynamic>? metadata,
  }) {
    return ModelData(
      type: type ?? this.type,
      modelPath: modelPath ?? this.modelPath,
      originalImagePath: originalImagePath ?? this.originalImagePath,
      createdAt: createdAt ?? this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Convert model data to JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.toString(),
      'modelPath': modelPath,
      'originalImagePath': originalImagePath,
      'createdAt': createdAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create model data from JSON
  factory ModelData.fromJson(Map<String, dynamic> json) {
    return ModelData(
      type: _modelTypeFromString(json['type'] as String),
      modelPath: json['modelPath'] as String,
      originalImagePath: json['originalImagePath'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Helper method to convert string to ModelType
  static ModelType _modelTypeFromString(String typeString) {
    return ModelType.values.firstWhere(
      (e) => e.toString() == typeString,
      orElse: () => ModelType.furniture,
    );
  }
}

/// Enum representing different types of 3D models
enum ModelType {
  /// Furniture models (chairs, tables, etc.)
  furniture,

  /// Glasses/eyewear models
  glasses,

  /// Generic object models
  object,
}
