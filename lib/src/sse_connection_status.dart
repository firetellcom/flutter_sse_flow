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
