import 'dart:async';

/// Resolves request headers before every connection attempt.
///
/// Invoked on the initial connection and on every automatic reconnection,
/// so values such as access tokens are always read at request time instead
/// of being captured once when `FlutterSseFlow.connect` is called.
typedef SseHeadersProvider = FutureOr<Map<String, String>> Function();

/// The application's answer after handling a `401 Unauthorized` response.
enum SseAuthDecision {
  /// Credentials were recovered (e.g. the access token was refreshed).
  /// The client reconnects immediately, re-reading headers through
  /// [SseHeadersProvider].
  retry,

  /// Credentials cannot be recovered (e.g. the session was revoked or the
  /// user logged out). The client stops reconnecting.
  stop,
}

/// Called when the server responds with `401 Unauthorized`.
///
/// Typically refreshes the access token and returns [SseAuthDecision.retry],
/// or returns [SseAuthDecision.stop] when the session cannot be recovered.
///
/// Throwing is treated as a transient failure (e.g. the refresh endpoint is
/// unreachable): the connection is retried after the usual delay.
typedef SseUnauthorizedHandler = FutureOr<SseAuthDecision> Function();
