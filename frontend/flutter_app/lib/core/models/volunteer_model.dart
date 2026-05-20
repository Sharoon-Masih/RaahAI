// lib/core/models/volunteer_model.dart

class VolunteerModel {
  final String volunteerId;
  final String name;
  final String phone;
  final String? city;
  final String? area;
  final bool available;
  final double? latitude;
  final double? longitude;
  final List<String> skills;

  VolunteerModel({
    required this.volunteerId,
    required this.name,
    required this.phone,
    this.city,
    this.area,
    this.available = true,
    this.latitude,
    this.longitude,
    this.skills = const [],
  });

  factory VolunteerModel.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    double? parseDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '');

    return VolunteerModel(
      volunteerId: json['volunteer_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      city: json['city']?.toString(),
      area: json['area']?.toString(),
      available: json['available'] == null ? true : (json['available'] is bool ? json['available'] : json['available'] == 1),
      latitude: parseDouble(json['latitude'] ?? json['lat']),
      longitude: parseDouble(json['longitude'] ?? json['lng']),
      skills: parseList(json['skills']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'volunteer_id': volunteerId,
      'name': name,
      'phone': phone,
      'city': city,
      'area': area,
      'available': available,
      'latitude': latitude,
      'longitude': longitude,
      'skills': skills,
    };
  }
}
