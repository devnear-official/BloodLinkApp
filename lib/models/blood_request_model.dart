import 'user_model.dart';

/// A single donor's response to an open [BloodRequestModel].
class DonorResponse {
  DonorResponse({
    required this.donor,
    required this.status,
    this.respondedAt,
  });

  final UserModel donor;
  final String status; // 'Pending' | 'Accepted' | 'Rejected'
  final DateTime? respondedAt;

  factory DonorResponse.fromJson(Map<String, dynamic> json) {
    final donorJson = json['donor'];
    return DonorResponse(
      donor: donorJson is Map<String, dynamic>
          ? UserModel.fromJson(donorJson)
          : UserModel(
              id: donorJson?.toString() ?? '',
              name: 'Unknown donor',
              email: '',
            ),
      status: json['status'] ?? 'Pending',
      respondedAt: json['respondedAt'] != null
          ? DateTime.tryParse(json['respondedAt'].toString())
          : null,
    );
  }
}

/// A public request for blood, broadcast to eligible donors in the feed.
class BloodRequestModel {
  BloodRequestModel({
    required this.id,
    required this.patientName,
    required this.bloodGroup,
    required this.hospitalName,
    required this.contactNumber,
    required this.division,
    required this.district,
    this.subDistrict,
    this.requiredDate,
    this.message,
    this.createdBy,
    this.acceptedBy,
    this.status = 'Pending',
    this.priority = 'Medium',
    this.responses = const [],
  });

  final String id;
  final String patientName;
  final String bloodGroup;
  final String hospitalName;
  final String contactNumber;
  final String division;
  final String district;
  final String? subDistrict; // upazila / thana
  final DateTime? requiredDate;
  final String? message;
  final UserModel? createdBy;
  final UserModel? acceptedBy;
  final String status; // Pending | Accepted | Completed | Cancelled
  final String priority; // Low | Medium | High | Critical
  final List<DonorResponse> responses;

  static UserModel? _parseUserRef(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return UserModel.fromJson(value);
    return null; // it's just an ID string; caller can fetch separately
  }

  factory BloodRequestModel.fromJson(Map<String, dynamic> json) {
    return BloodRequestModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      patientName: json['patientName'] ?? '',
      bloodGroup: json['bloodGroup'] ?? '',
      hospitalName: json['hospitalName'] ?? '',
      contactNumber: json['contactNumber'] ?? '',
      division: json['division'] ?? '',
      district: json['district'] ?? '',
      subDistrict: json['subDistrict'],
      requiredDate: json['requiredDate'] != null
          ? DateTime.tryParse(json['requiredDate'].toString())
          : null,
      message: json['message'],
      createdBy: _parseUserRef(json['createdBy']),
      acceptedBy: _parseUserRef(json['acceptedBy']),
      status: json['status'] ?? 'Pending',
      priority: json['priority'] ?? 'Medium',
      responses: (json['responses'] as List<dynamic>? ?? [])
          .map((e) => DonorResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'patientName': patientName,
      'bloodGroup': bloodGroup,
      'hospitalName': hospitalName,
      'contactNumber': contactNumber,
      'division': division,
      'district': district,
      if (subDistrict != null && subDistrict!.isNotEmpty)
        'subDistrict': subDistrict,
      if (requiredDate != null)
        'requiredDate': requiredDate!.toIso8601String(),
      if (message != null) 'message': message,
      'priority': priority,
    };
  }
}
