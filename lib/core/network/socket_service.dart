import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/api_endpoints.dart';

/// Thin wrapper around the Socket.IO client.
///
/// Connects to the server root (not `/api`) once the user is authenticated,
/// passing the JWT via the `auth` payload as the backend expects. Because
/// the backend runs on Render's free tier and can be cold, reconnection is
/// configured to keep retrying with backoff rather than giving up quickly.
class SocketService {
  SocketService._internal();
  static final SocketService instance = SocketService._internal();

  io.Socket? _socket;

  io.Socket? get socket => _socket;

  bool get isConnected => _socket?.connected ?? false;

  /// Connects (or reconnects) using the given JWT. Safe to call again with
  /// a new token after login.
  void connect(String token) {
    disconnect();

    _socket = io.io(
      ApiEndpoints.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .enableReconnection()
          .setReconnectionAttempts(double.maxFinite.toInt())
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(15000)
          // Give a cold Render instance time to wake up before Socket.IO's
          // own connection attempt times out.
          .setTimeout(45000)
          .build(),
    );

    _socket!.connect();
  }

  /// Registers a listener for [event]. Returns nothing; callers should keep
  /// a reference to `off` manually via [off] using the same event name if
  /// they need to unregister (e.g. in a Provider's dispose).
  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }
}
