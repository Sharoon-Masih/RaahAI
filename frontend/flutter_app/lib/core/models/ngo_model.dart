// lib/core/models/ngo_model.dart

class NgoModel {
  final String ngoId;
  final String name;
  final String email;
  final List<String> crisisTypes;
  final List<String> locations;
  final String createdAt;

  NgoModel({
    required this.ngoId,
    required this.name,
    required this.email,
    required this.crisisTypes,
    required this.locations,
    required this.createdAt,
  });

  factory NgoModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return NgoModel(
      ngoId: json['ngo_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      crisisTypes: parseList(json['crisis_types']),
      locations: parseList(json['locations']),
      createdAt: json['created_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ngo_id': ngoId,
      'name': name,
      'email': email,
      'crisis_types': crisisTypes,
      'locations': locations,
      'created_at': createdAt,
    };
  }
}
