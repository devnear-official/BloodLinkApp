import 'package:flutter_test/flutter_test.dart';

import 'package:bloodlink/core/services/location_service.dart';
import 'package:bloodlink/models/blood_request_model.dart';
import 'package:bloodlink/models/direct_request_model.dart';
import 'package:bloodlink/models/notification_model.dart';
import 'package:bloodlink/models/page_result.dart';
import 'package:bloodlink/models/user_model.dart';

void main() {
  test('parses donor records returned by the live API', () {
    final donor = UserModel.fromJson({
      '_id': 'user-1',
      'name': 'Donor',
      'email': 'donor@example.com',
      'role': 'User',
      'status': 'Available',
      'upazila': 'Mirpur',
      'lastDonation': '2026-01-15',
      'picture': 'https://example.com/photo.png',
    });

    expect(donor.id, 'user-1');
    expect(donor.role, 'user');
    expect(donor.subDistrict, 'Mirpur');
    expect(donor.lastDonation, DateTime(2026, 1, 15));
    expect(donor.photoUrl, 'https://example.com/photo.png');
  });

  test('parses paginated donors and keeps contact details out of offline cache',
      () {
    final result = PageResult<UserModel>.fromJson(
      {
        'items': [
          {
            '_id': 'nearby-1',
            'name': 'Nearby donor',
            'email': 'donor@example.com',
            'phone': '01700000000',
            'distanceKm': 2.4,
          },
        ],
        'page': 2,
        'total': 21,
        'hasMore': true,
      },
      UserModel.fromJson,
    );

    expect(result.page, 2);
    expect(result.total, 21);
    expect(result.hasMore, isTrue);
    expect(result.items.single.distanceKm, 2.4);
    final cached = result.items.single.toPublicCacheJson();
    expect(cached, isNot(contains('email')));
    expect(cached, isNot(contains('phone')));
  });

  test('parses live blood requests and creates the expected upazila field', () {
    final request = BloodRequestModel.fromJson({
      '_id': 'request-1',
      'patientName': 'Patient',
      'bloodGroup': 'A+',
      'hospitalName': 'City Hospital',
      'contactNumber': '01700000000',
      'division': 'Dhaka',
      'district': 'Dhaka',
      'upazila': 'Mirpur',
      'requiredDate': '2026-10-15',
      'status': 'Active',
      'donorResponses': [],
    });

    expect(request.isOpen, isTrue);
    expect(request.subDistrict, 'Mirpur');
    expect(request.toCreateJson()['upazila'], 'Mirpur');
    expect(request.toCreateJson().containsKey('subDistrict'), isFalse);
  });

  test('maps persisted direct requests to the app field names', () {
    final request = DirectRequestModel.fromJson({
      '_id': 'direct-1',
      'requester': {
        '_id': 'requester-1',
        'name': 'Requester',
        'email': 'requester@example.com',
      },
      'donor': {
        '_id': 'donor-1',
        'name': 'Donor',
        'email': 'donor@example.com',
        'bloodGroup': 'O+',
      },
      'bloodGroup': 'O+',
      'hospitalName': 'City Hospital',
      'contactNumber': '01700000000',
      'requiredDate': '2026-10-15',
      'status': 'Pending',
    });

    expect(request.fromUser.id, 'requester-1');
    expect(request.toUser.id, 'donor-1');
    expect(request.toCreateJson(toUserId: 'donor-2')['donorId'], 'donor-2');
    expect(
      request.toCreateJson(toUserId: 'donor-2').containsKey('toUser'),
      isFalse,
    );
  });

  test('maps backend notification fields and request links', () {
    final notification = NotificationModel.fromJson({
      '_id': 'notification-1',
      'type': 'NewRequest',
      'message': 'A patient needs blood',
      'read': true,
      'link': '/request-blood?highlight=request-1',
    });

    expect(notification.title, 'New blood request');
    expect(notification.type, 'request');
    expect(notification.isRead, isTrue);
    expect(notification.relatedRequestId, 'request-1');
  });

  testWidgets('matches reverse-geocoded place names to known areas', (
    tester,
  ) async {
    final locations = LocationService.instance;
    await locations.loadDivisions();

    expect(locations.matchDivision(['Chittagong Division']), 'Chattogram');
    expect(
      locations.matchDistrict(['Dhaka'], divisionHint: 'Dhaka'),
      'Dhaka North',
    );
    expect(
      locations.matchDistrict(['Cumilla'], divisionHint: 'Chattogram'),
      'Comilla',
    );
    expect(locations.matchSubDistrict(['Mirpur'], 'Dhaka'), 'Mirpur');
    expect(
      locations.districtForSubDistrict('Mirpur', divisionHint: 'Dhaka'),
      'Dhaka North',
    );
  });
}
