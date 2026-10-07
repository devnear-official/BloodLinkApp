/// A district within a [DivisionModel], with its list of sub-districts
/// (upazilas/thanas) exactly as they appear in `assets/data/locations.json`.
class DistrictModel {
  DistrictModel({required this.district, required this.upazilas});

  final String district;
  final List<String> upazilas;

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      district: json['district'] as String,
      upazilas: (json['upazilas'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// A division (the top level of Bangladesh's administrative hierarchy),
/// with its list of districts.
class DivisionModel {
  DivisionModel({required this.division, required this.districts});

  final String division;
  final List<DistrictModel> districts;

  factory DivisionModel.fromJson(Map<String, dynamic> json) {
    return DivisionModel(
      division: json['division'] as String,
      districts: (json['districts'] as List<dynamic>)
          .map((e) => DistrictModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
