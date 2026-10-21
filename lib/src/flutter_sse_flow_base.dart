import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'sse_auth.dart';
import 'sse_connection_status.dart';
import 'sse_event_parser.dart';
import 'sse_model.dart';

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
  });

  /// Delay between reconnection attempts.
  final Duration reconnectDelay;

  final StreamController<SSEModel> _sseStreamController =
      StreamController<SSEModel>.broadcast();
  final StreamController<SseConnectionStatus> _statusController =
      StreamController<SseConnectionStatus>.broadcast();
  SseConnectionStatus _status = SseConnectionStatus.idle;
  http.Client? _client;
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
  /// [unauthorizedStatusCodes] (defaults to `{401}`).
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
    if (_status.isActive) return;

    _lastEventId = null;

    _updateStatus(SseConnectionStatus.connecting);

    _connectInternal(
      url: url,
      headersProvider: headers,
      onUnauthorized: onUnauthorized,
      unauthorizedStatusCodes: unauthorizedStatusCodes,
    );
  }

  Future<void> _connectInternal({
    required String url,
    required SseHeadersProvider? headersProvider,
    required SseUnauthorizedHandler? onUnauthorized,
    required Set<int> unauthorizedStatusCodes,
  }) async {
    while (_status.isActive) {
      try {
        final Map<String, String> requestHeaders = await _resolveHeaders(
          headersProvider,
        );
        if (!_status.isActive) break;

        final int statusCode = await _connectAndListen(
          url: url,
          headers: requestHeaders,
          unauthorizedStatusCodes: unauthorizedStatusCodes,
        );
        if (!_status.isActive) break;

        if (unauthorizedStatusCodes.contains(statusCode)) {
          if (onUnauthorized == null) {
            _updateStatus(SseConnectionStatus.unauthorized);
            break;
          }

          _updateStatus(SseConnectionStatus.refreshingAuth);
          final SseAuthDecision decision = await onUnauthorized();
          if (!_status.isActive) break;

          if (decision == SseAuthDecision.stop) {
            _updateStatus(SseConnectionStatus.unauthorized);
            break;
          }

          // SseAuthDecision.retry: reconnect immediately with fresh headers.
          _updateStatus(SseConnectionStatus.connecting);
          continue;
        }

        if (!_status.isActive) break;
        _updateStatus(SseConnectionStatus.reconnecting);
        await Future<void>.delayed(reconnectDelay);
        if (_status.isActive) {
          _updateStatus(SseConnectionStatus.connecting);
        }
      } catch (e) {
        if (_status.isActive) {
          _updateStatus(SseConnectionStatus.reconnecting);
          await Future<void>.delayed(reconnectDelay);
          if (_status.isActive) {
            _updateStatus(SseConnectionStatus.connecting);
          }
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
    required String url,
    required Map<String, String> headers,
    required Set<int> unauthorizedStatusCodes,
  }) async {
    final http.Client client = http.Client();
    _client = client;

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

      _updateStatus(SseConnectionStatus.connected);

      final Stream<SSEModel> events = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .transform(const SseEventParser());

      await for (final SSEModel event in events) {
        if (!_status.isActive) break;
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
      if (identical(_client, client)) {
        _client = null;
      }
    }
  }

  /// Disconnects the active SSE stream and releases allocated resources.
  void disconnect() {
    _updateStatus(SseConnectionStatus.disconnected);
    _client?.close();
    _client = null;
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
