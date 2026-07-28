import 'package:equatable/equatable.dart';

class FeatureFlag extends Equatable {
  const FeatureFlag({
    required this.key,
    required this.enabled,
    this.description,
  });

  final String key;
  final bool enabled;
  final String? description;

  @override
  List<Object?> get props => [key, enabled, description];
}
