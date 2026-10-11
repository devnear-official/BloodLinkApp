/// Central place for every backend URL used by the app.
///
/// Set `API_BASE_URL` with `--dart-define` when the app and backend do not
/// share a localhost network namespace (for example, Android emulators use
/// `http://10.0.2.2:3000`).
class ApiEndpoints {
  ApiEndpoints._();

  /// Root of the local backend (no trailing slash).
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  /// All REST routes live under `/api`.
  static const String apiBase = '$baseUrl/api';

  /// Socket.IO connects to the server root, NOT the `/api` prefix.
  static const String socketUrl = baseUrl;

  // ---------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------
  static const String googleAuth = '$apiBase/auth/google';
  static const String register = '$apiBase/auth/register';
  static const String login = '$apiBase/auth/login';

  // ---------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------
  static const String me = '$apiBase/users/me';
  static const String users = '$apiBase/users';
  static String userStatus(String id) => '$apiBase/users/$id/status';
  static String userRole(String id) => '$apiBase/users/$id/role';
  static String userById(String id) => '$apiBase/users/$id';

  // ---------------------------------------------------------------------
  // Blood requests
  // ---------------------------------------------------------------------
  static const String requests = '$apiBase/requests';
  static String requestRespond(String id) => '$apiBase/requests/$id/respond';
  static String requestResponseStatus(String requestId, String donorId) =>
      '$apiBase/requests/$requestId/responses/$donorId/status';
  static String requestStatus(String id) => '$apiBase/requests/$id/status';
  static String requestPriority(String id) => '$apiBase/requests/$id/priority';
  static String requestById(String id) => '$apiBase/requests/$id';

  // ---------------------------------------------------------------------
  // Direct requests
  // ---------------------------------------------------------------------
  static const String directRequests = '$apiBase/direct-requests';
  static String directRequestStatus(String id) =>
      '$apiBase/direct-requests/$id/status';
  static String directRequestById(String id) => '$apiBase/direct-requests/$id';

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------
  static const String vapidPublicKey =
      '$apiBase/notifications/vapid-public-key';
  static const String testPush = '$apiBase/notifications/test-push';
  static const String subscribePush = '$apiBase/notifications/subscribe';
  static const String notifications = '$apiBase/notifications';
  static const String notificationsReadAll = '$apiBase/notifications/read-all';
  static String notificationRead(String id) =>
      '$apiBase/notifications/$id/read';

  // ---------------------------------------------------------------------
  // Socket.IO event names
  // ---------------------------------------------------------------------
  static const String eventRequestCreated = 'request:created';
  static const String eventRequestUpdated = 'request:updated';
  static const String eventRequestDeleted = 'request:deleted';
  static const String eventNotificationNew = 'notification:new';
  static const String eventDirectRequestNew = 'direct_request:new';
  static const String eventDirectRequestUpdated = 'direct_request:updated';
  static const String eventDirectRequestCancelled = 'direct_request:cancelled';
}
