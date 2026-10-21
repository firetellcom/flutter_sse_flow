import 'package:http/http.dart' as http;

/// Represents an active SSE connection session.
///
/// Encapsulates the cancellation state and HTTP client for a single
/// continuous connection lifecycle, ensuring that cancelled loops cannot
/// run concurrently with newly started ones.
class SseSession {
  bool _isCancelled = false;

  /// Whether this session has been cancelled.
  bool get isCancelled => _isCancelled;

  /// The active HTTP client for this session, if any.
  http.Client? client;

  /// Cancels this session and closes the active HTTP client.
  void cancel() {
    _isCancelled = true;
    client?.close();
    client = null;
  }
}
