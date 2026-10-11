/// An in-app notification for the authenticated user (new requests, donor
/// responses, direct-request updates, etc.).
class NotificationModel {
  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    this.relatedRequestId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final String? relatedRequestId;
  final DateTime? createdAt;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawType = (json['type'] ?? '').toString();
    final type = switch (rawType.toLowerCase()) {
      'newrequest' || 'requestcancelled' => 'request',
      'donorresponse' || 'responsereviewed' => 'response',
      'directrequest' || 'statusupdate' => 'direct_request',
      _ => rawType.toLowerCase(),
    };
    final link = json['link']?.toString() ?? '';
    final requestId = json['relatedRequestId'] ?? json['requestId'];
    final highlightedRequest =
        RegExp(r'[?&]highlight=([^&]+)').firstMatch(link)?.group(1);

    return NotificationModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      title: (json['title'] ?? _titleFor(rawType)).toString(),
      message: json['message'] ?? '',
      type: type,
      isRead: (json['isRead'] ?? json['read']) == true,
      relatedRequestId: (requestId ?? highlightedRequest)?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }

  static String _titleFor(String type) {
    switch (type.toLowerCase()) {
      case 'newrequest':
        return 'New blood request';
      case 'donorresponse':
        return 'A donor responded';
      case 'responsereviewed':
        return 'Your offer was reviewed';
      case 'directrequest':
        return 'New direct request';
      case 'statusupdate':
        return 'Direct request updated';
      case 'requestcancelled':
        return 'Blood request cancelled';
      default:
        return 'BloodLink notification';
    }
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      title: title,
      message: message,
      type: type,
      isRead: isRead ?? this.isRead,
      relatedRequestId: relatedRequestId,
      createdAt: createdAt,
    );
  }
}
