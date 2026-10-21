/// Connection lifecycle status emitted by `FlutterSseFlow.statusStream`.
enum SseConnectionStatus {
  /// The client has not connected yet.
  idle,

  /// Establishing an HTTP connection to the SSE server.
  connecting,

  /// Actively connected and receiving events from the SSE stream.
  connected,

  /// Connection lost or closed, waiting before reconnection attempt.
  reconnecting,

  /// Handling an unauthorized response, awaiting token refresh.
  refreshingAuth,

  /// Authentication failed or refresh was rejected; client has stopped.
  unauthorized,

  /// Manually disconnected via `FlutterSseFlow.disconnect`.
  disconnected,
}

/// Internal helpers for [SseConnectionStatus].
///
/// Hidden from the public API by the package barrel file.
extension SseConnectionStatusActivity on SseConnectionStatus {
  /// Whether the connection loop should keep running in this status.
  ///
  /// The switch is exhaustive, so adding a new [SseConnectionStatus] value
  /// fails to compile until it is classified here.
  bool get isActive => switch (this) {
        SseConnectionStatus.connecting ||
        SseConnectionStatus.connected ||
        SseConnectionStatus.reconnecting ||
        SseConnectionStatus.refreshingAuth =>
          true,
        SseConnectionStatus.idle ||
        SseConnectionStatus.unauthorized ||
        SseConnectionStatus.disconnected =>
          false,
      };
}
