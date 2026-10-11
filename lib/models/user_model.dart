/// A registered user of the app — donor, requester, or admin (the same
/// account can act as both donor and requester).
class UserModel {
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.bloodGroup,
    this.division,
    this.district,
    this.subDistrict,
    this.lastDonation,
    this.status = 'Available',
    this.role = 'user',
    this.authProvider = 'local',
    this.photoUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? phone;
  final String? bloodGroup; // A+, A-, B+, B-, AB+, AB-, O+, O-
  final String? division;
  final String? district;
  final String? subDistrict; // upazila / thana
  final DateTime? lastDonation;
  final String status; // 'Available' | 'Unavailable'
  final String role; // 'user' | 'admin'
  final String authProvider; // 'local' | 'google'
  final String? photoUrl;

  bool get isAdmin => role == 'admin';

  /// Client-side mirror of the backend's 90-day donation eligibility rule.
  /// The backend remains the source of truth and re-validates this on
  /// `POST /requests/:id/respond` — this is only used to drive UI state
  /// (e.g. greying out a "respond" button) without an extra round trip.
  bool get isEligibleToDonate {
    if (status != 'Available') return false;
    if (lastDonation == null) return true;
    return DateTime.now().difference(lastDonation!).inDays >= 90;
  }

  int? get daysUntilEligible {
    if (lastDonation == null) return null;
    final elapsed = DateTime.now().difference(lastDonation!).inDays;
    final remaining = 90 - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final role = (json['role'] ?? 'user').toString().toLowerCase();
    return UserModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      bloodGroup: json['bloodGroup'],
      division: json['division'],
      district: json['district'],
      subDistrict: (json['upazila'] ?? json['subDistrict'])?.toString(),
      lastDonation: (json['lastDonation'] ?? json['lastDonationDate']) != null
          ? DateTime.tryParse(
              (json['lastDonation'] ?? json['lastDonationDate']).toString(),
            )
          : null,
      status: (json['status'] ?? (json['isAvailable'] == false
                  ? 'Unavailable'
                  : 'Available'))
              .toString(),
      role: role == 'admin' ? 'admin' : 'user',
      authProvider: json['authProvider'] ?? 'local',
      photoUrl: (json['photoUrl'] ?? json['picture'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'bloodGroup': bloodGroup,
      'division': division,
      'district': district,
      'subDistrict': subDistrict,
      'lastDonation': lastDonation?.toIso8601String(),
      'status': status,
      'role': role,
      'authProvider': authProvider,
      'photoUrl': photoUrl,
    };
  }

  UserModel copyWith({
    String? name,
    String? phone,
    String? bloodGroup,
    String? division,
    String? district,
    String? subDistrict,
    DateTime? lastDonation,
    String? status,
    String? role,
    String? photoUrl,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      division: division ?? this.division,
      district: district ?? this.district,
      subDistrict: subDistrict ?? this.subDistrict,
      lastDonation: lastDonation ?? this.lastDonation,
      status: status ?? this.status,
      role: role ?? this.role,
      authProvider: authProvider,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
}
