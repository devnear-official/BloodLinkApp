import 'user_model.dart';

/// A donation request sent directly to one specific donor, as opposed to
/// the open [BloodRequestModel] feed.
class DirectRequestModel {
  DirectRequestModel({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.bloodGroup,
    required this.hospitalName,
    required this.contactNumber,
    this.requiredDate,
    this.message,
    this.status = 'Pending',
  });

  final String id;
  final UserModel fromUser;
  final UserModel toUser;
  final String bloodGroup;
  final String hospitalName;
  final String contactNumber;
  final DateTime? requiredDate;
  final String? message;
  final String status; // Pending | Accepted | Declined | Cancelled

  static UserModel _parseUser(dynamic value) {
    if (value is Map<String, dynamic>) return UserModel.fromJson(value);
    return UserModel(id: value?.toString() ?? '', name: 'Unknown', email: '');
  }

  factory DirectRequestModel.fromJson(Map<String, dynamic> json) {
    final contactInfo = json['contactInfo']?.toString() ?? '';
    final donor = json['donor'];
    return DirectRequestModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      fromUser: _parseUser(json['requester'] ?? json['fromUser']),
      toUser: _parseUser(json['donor'] ?? json['toUser']),
      bloodGroup: (json['bloodGroup'] ??
              (donor is Map ? donor['bloodGroup'] : null) ??
              '')
          .toString(),
      hospitalName: json['hospitalName'] ?? '',
      contactNumber: json['contactNumber'] ?? contactInfo,
      requiredDate: json['requiredDate'] != null
          ? DateTime.tryParse(json['requiredDate'].toString())
          : null,
      message: json['message'],
      status: json['status'] ?? 'Pending',
    );
  }

  Map<String, dynamic> toCreateJson({required String toUserId}) {
    return {
      'donorId': toUserId,
      'bloodGroup': bloodGroup,
      'hospitalName': hospitalName,
      'contactNumber': contactNumber,
      'contactInfo': contactNumber,
      if (requiredDate != null) 'requiredDate': requiredDate!.toIso8601String(),
      if (message != null) 'message': message,
    };
  }
}
