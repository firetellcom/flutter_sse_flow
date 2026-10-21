import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sse_auth.dart';
import 'sse_connection_status.dart';
import 'sse_event_parser.dart';
import 'sse_model.dart';
import 'sse_session.dart';

/// A robust client for Server-Sent Events (SSE).
///
/// Features:
/// - Standard-compliant parsing via `utf8.decoder` and `LineSplitter`.
/// - Automatic reconnection when connection is lost.
/// - Auth-aware recovery via dynamic [headers] provider and [onUnauthorized] handler.
/// - Automatic tracking and forwarding of `Last-Event-ID` across reconnections.
/// - Connection lifecycle notifications via [statusStream].
/// - Complete resource cleanup via [dispose].
class FlutterSseFlow {
  FlutterSseFlow({
    this.reconnectDelay = const Duration(seconds: 2),
    this.maxAuthRetries = 10,
  }) : assert(maxAuthRetries >= 0, 'maxAuthRetries must not be negative');

  /// Delay between reconnection attempts.
  final Duration reconnectDelay;

  /// Maximum number of consecutive `onUnauthorized` recoveries before the
  /// client gives up and moves to [SseConnectionStatus.unauthorized].
  ///
  /// The counter resets after every successful (2xx) connection, so it only
  /// limits back-to-back rejections, e.g. a server that keeps refusing
  /// freshly refreshed credentials. The first recovery reconnects
  /// immediately; subsequent ones wait [reconnectDelay] first.
  ///
  /// Set to `0` to never call `onUnauthorized`.
  final int maxAuthRetries;

  final StreamController<SSEModel> _sseStreamController =
      StreamController<SSEModel>.broadcast();
  final StreamController<SseConnectionStatus> _statusController =
      StreamController<SseConnectionStatus>.broadcast();
  SseConnectionStatus _status = SseConnectionStatus.idle;
  SseSession? _session;
  String? _lastEventId;

  /// Current connection lifecycle status.
  SseConnectionStatus get status => _status;

  /// Stream of connection lifecycle status changes.
  Stream<SseConnectionStatus> get statusStream => _statusController.stream;

  /// Global broadcast stream for receiving SSE events.
  Stream<SSEModel> get sseStream => _sseStreamController.stream;

  /// The ID of the last received event, if any.
  ///
  /// Sent automatically in the `Last-Event-ID` header on reconnection.
  String? get lastEventId => _lastEventId;

  void _updateStatus(SseConnectionStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  /// Establishes an SSE connection to the specified [url].
  ///
  /// [headers] is called before **every** connection attempt (including
  /// automatic reconnections) to build the request headers, e.g.
  /// `Authorization: Bearer <token>`. Read the latest token inside it so a
  /// reconnection never reuses an expired one:
  ///
  /// ```dart
  /// sse.connect(
  ///   url: 'https://api.example.com/stream',
  ///   headers: () async => <String, String>{
  ///     'Authorization': 'Bearer ${await tokenStorage.readAccessToken()}',
  ///   },
  ///   unauthorizedStatusCodes: const <int>{401, 403},
  ///   onUnauthorized: () async {
  ///     final bool refreshed = await authRepository.refreshToken();
  ///     return refreshed ? SseAuthDecision.retry : SseAuthDecision.stop;
  ///   },
  /// );
  /// ```
  ///
  /// [onUnauthorized] is invoked whenever the response status is in
  /// [unauthorizedStatusCodes] (defaults to `{401}`), at most
  /// [maxAuthRetries] times in a row.
  ///
  /// [unauthorizedStatusCodes] specifies which HTTP status codes represent
  /// expired or invalid credentials (defaults to `{401}`).
  ///
  /// The last received event `id` is tracked internally and sent as
  /// `Last-Event-ID` on automatic reconnections. Each call to [connect]
  /// starts a fresh session without a `Last-Event-ID`.
  void connect({
    required String url,
    SseHeadersProvider? headers,
    SseUnauthorizedHandler? onUnauthorized,
    Set<int> unauthorizedStatusCodes = const <int>{401},
  }) {
    if (_sseStreamController.isClosed) {
      throw StateError('Cannot connect a disposed FlutterSseFlow instance.');
    }
    if (_session != null && !_session!.isCancelled) return;

    _lastEventId = null;

    final SseSession session = SseSession();
    _session = session;

    _updateStatus(SseConnectionStatus.connecting);

    _connectInternal(
      session: session,
      url: url,
      headersProvider: headers,
      onUnauthorized: onUnauthorized,
      unauthorizedStatusCodes: unauthorizedStatusCodes,
    );
  }

  Future<void> _connectInternal({
    required SseSession session,
    required String url,
    required SseHeadersProvider? headersProvider,
    required SseUnauthorizedHandler? onUnauthorized,
    required Set<int> unauthorizedStatusCodes,
  }) async {
    int authRetries = 0;

    while (!session.isCancelled) {
      try {
        final Map<String, String> requestHeaders = await _resolveHeaders(
          headersProvider,
        );
        if (session.isCancelled) break;

        final int statusCode = await _connectAndListen(
          session: session,
          url: url,
          headers: requestHeaders,
          unauthorizedStatusCodes: unauthorizedStatusCodes,
        );
        if (session.isCancelled) break;

        if (unauthorizedStatusCodes.contains(statusCode)) {
          if (onUnauthorized == null || authRetries >= maxAuthRetries) {
            _updateStatus(SseConnectionStatus.unauthorized);
            session.cancel();
            break;
          }

          // The first recovery is immediate; repeated ones are spaced out so
          // a server that keeps rejecting fresh credentials is not flooded.
          if (authRetries > 0) {
            _updateStatus(SseConnectionStatus.reconnecting);
            await Future<void>.delayed(reconnectDelay);
            if (session.isCancelled) break;
          }

          _updateStatus(SseConnectionStatus.refreshingAuth);
          final SseAuthDecision decision = await onUnauthorized();
          if (session.isCancelled) break;

          if (decision == SseAuthDecision.stop) {
            _updateStatus(SseConnectionStatus.unauthorized);
            session.cancel();
            break;
          }

          // SseAuthDecision.retry: reconnect with fresh headers.
          authRetries++;
          _updateStatus(SseConnectionStatus.connecting);
          continue;
        }

        // Only a successful connection proves the credentials are valid.
        if (statusCode >= 200 && statusCode < 300) {
          authRetries = 0;
        }

        if (session.isCancelled) break;
        _updateStatus(SseConnectionStatus.reconnecting);
        await Future<void>.delayed(reconnectDelay);
        if (session.isCancelled) break;
        _updateStatus(SseConnectionStatus.connecting);
      } catch (e) {
        if (!session.isCancelled) {
          _updateStatus(SseConnectionStatus.reconnecting);
          await Future<void>.delayed(reconnectDelay);
          if (session.isCancelled) break;
          _updateStatus(SseConnectionStatus.connecting);
        }
      }
    }
  }

  /// Builds the headers for a single connection attempt by merging the SSE
  /// defaults with latest values from [headersProvider].
  Future<Map<String, String>> _resolveHeaders(
    SseHeadersProvider? headersProvider,
  ) async {
    final Map<String, String>? customHeaders = headersProvider == null
        ? null
        : await headersProvider();
    final String? currentLastEventId = _lastEventId;
    return <String, String>{
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      if (currentLastEventId != null && currentLastEventId.isNotEmpty)
        'Last-Event-ID': currentLastEventId,
      ...?customHeaders,
    };
  }

  /// Establishes the HTTP stream and forwards parsed events to [sseStream].
  ///
  /// Returns the HTTP status code of the response. For codes in
  /// [unauthorizedStatusCodes] or non-2xx codes, the body is not consumed as
  /// an SSE stream.
  Future<int> _connectAndListen({
    required SseSession session,
    required String url,
    required Map<String, String> headers,
    required Set<int> unauthorizedStatusCodes,
  }) async {
    final http.Client client = http.Client();
    session.client = client;

    try {
      final http.Request request = http.Request('GET', Uri.parse(url));
      request.headers.addAll(headers);

      final http.StreamedResponse response = await client.send(request);

      // Check for unauthorized status codes first.
      if (unauthorizedStatusCodes.contains(response.statusCode)) {
        return response.statusCode;
      }

      // If non-2xx status, do not parse body as SSE events.
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return response.statusCode;
      }

      if (session.isCancelled) return response.statusCode;
      _updateStatus(SseConnectionStatus.connected);

      final Stream<SSEModel> events = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .transform(const SseEventParser());

      await for (final SSEModel event in events) {
        if (session.isCancelled) break;
        if (event.id.isNotEmpty) {
          _lastEventId = event.id;
        }
        if (!_sseStreamController.isClosed) {
          _sseStreamController.add(event);
        }
      }
      return response.statusCode;
    } finally {
      client.close();
      if (identical(session.client, client)) {
        session.client = null;
      }
    }
  }

  /// Disconnects the active SSE stream and releases allocated resources.
  void disconnect() {
    _updateStatus(SseConnectionStatus.disconnected);
    _session?.cancel();
    _session = null;
  }

  /// Disconnects the active SSE stream and closes all stream controllers.
  ///
  /// Once disposed, this instance cannot be reused.
  Future<void> dispose() async {
    disconnect();
    await Future.wait<void>(<Future<void>>[
      _sseStreamController.close(),
      _statusController.close(),
    ]);
  }
}
