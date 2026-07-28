import '../../domain/entities/feature_flag.dart';

class FeatureFlagModel extends FeatureFlag {
  const FeatureFlagModel({
    required super.key,
    required super.enabled,
    super.description,
  });

  factory FeatureFlagModel.fromJson(Map<String, dynamic> json) {
    return FeatureFlagModel(
      key: json['key'] as String,
      enabled: json['enabled'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }
}
