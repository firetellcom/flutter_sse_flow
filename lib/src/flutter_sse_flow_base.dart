import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'sse_model.dart';

/// A robust client for Server-Sent Events (SSE).
/// 
/// This client automatically handles reconnections (unless encountering a 401 Unauthorized),
/// parses event streams using `utf8.decoder` and `LineSplitter`, and exposes 
/// the stream of [SSEModel] events.
class FlutterSseFlow {
  final StreamController<SSEModel> _sseStreamController = StreamController<SSEModel>.broadcast();
  bool _isConnected = false;
  http.Client? _client;

  /// Current connection status.
  bool get isConnected => _isConnected;

  /// Global broadcast stream for receiving SSE events.
  Stream<SSEModel> get sseStream => _sseStreamController.stream;

  /// Establishes an SSE connection to the specified [url].
  /// 
  /// [headers] can be used to pass Authentication tokens or other necessary headers.
  /// The connection will automatically retry upon failure, except when a 401 
  /// Unauthorized status code is returned.
  void connect({
    required String url,
    Map<String, String>? headers,
  }) {
    if (_isConnected) return;
    _isConnected = true;

    final requestHeaders = <String, String>{
      'Accept': 'text/event-stream',
      'Cache-Control': 'no-cache',
      ...?headers,
    };

    _connectInternal(url, requestHeaders);
  }

  Future<void> _connectInternal(String url, Map<String, String> headers) async {
    while (_isConnected) {
      try {
        await _connectAndListen(url, headers);
      } catch (e) {
        if (_isConnected) {
          // Retry logic on generic connection lost
          await Future.delayed(const Duration(seconds: 5));
        }
      }
    }
  }

  /// Establishes the HTTP stream and processes incoming data chunks.
  Future<void> _connectAndListen(
    String url,
    Map<String, String> headers,
  ) async {
    _client = http.Client();
    final request = http.Request('GET', Uri.parse(url));
    request.headers.addAll(headers);

    final response = await _client!.send(request);

    // Stop the connection loop permanently if the token is invalid (401).
    if (response.statusCode == 401) {
      _isConnected = false;
      return;
    }

    final Stream<String> lineStream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    var currentEvent = SSEModel();

    await for (final line in lineStream) {
      if (!_isConnected) break;

      // The SSE protocol specifies that an empty line marks the end of an event.
      if (line.isEmpty) {
        // SSE spec dictates removing exactly one trailing newline from data
        if (currentEvent.data.endsWith('\n')) {
          currentEvent.data = currentEvent.data.substring(0, currentEvent.data.length - 1);
        }

        if (!_sseStreamController.isClosed) {
          _sseStreamController.add(currentEvent);
        }
        // Reset the model to gather data for the next event.
        currentEvent = SSEModel();
        continue;
      }

      final int colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final String field = line.substring(0, colonIndex).trim();
        String value = line.substring(colonIndex + 1);
        
        // SSE spec dictates removing exactly one leading space if present
        if (value.startsWith(' ')) {
          value = value.substring(1);
        }

        switch (field) {
          case 'event':
            currentEvent.event = value;
            break;
          case 'data':
            currentEvent.data = '${currentEvent.data}$value\n';
            break;
          case 'id':
            currentEvent.id = value;
            break;
        }
      }
    }
  }

  /// Disconnects the active SSE stream and releases allocated resources.
  void disconnect() {
    _isConnected = false;
    _client?.close();
    _client = null;
  }
}
