import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sse_flow/flutter_sse_flow.dart';

void main() {
  group('FlutterSseFlow', () {
    late FlutterSseFlow sseFlow;
    HttpServer? server;
    late String serverUrl;

    setUp(() async {
      sseFlow = FlutterSseFlow();
      // Start a local server for testing SSE
      server = await HttpServer.bind('localhost', 0);
      serverUrl = 'http://localhost:${server!.port}';
    });

    tearDown(() async {
      sseFlow.disconnect();
      await server?.close(force: true);
    });

    test('initial state should be disconnected', () {
      expect(sseFlow.isConnected, isFalse);
    });

    test('should connect and parse single event', () async {
      server!.listen((HttpRequest request) {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('id: 1\n');
        request.response.write('event: message\n');
        request.response.write('data: hello world\n\n');
        request.response.close();
      });

      sseFlow.connect(url: serverUrl);

      final event = await sseFlow.sseStream.first;

      expect(event.id, '1');
      expect(event.event, 'message');
      expect(event.data, 'hello world');
      expect(sseFlow.isConnected, isTrue);
    });

    test('should parse multiple lines of data', () async {
      server!.listen((HttpRequest request) {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('data: line1\n');
        request.response.write('data: line2\n\n');
        request.response.close();
      });

      sseFlow.connect(url: serverUrl);

      final event = await sseFlow.sseStream.first;

      // Note: Implementation adds newline after each data line and removes trailing newline
      // at the end of the event parsing.
      expect(event.data, 'line1\nline2');
    });

    test('should handle empty data', () async {
      server!.listen((HttpRequest request) {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('event: ping\n\n');
        request.response.close();
      });

      sseFlow.connect(url: serverUrl);

      final event = await sseFlow.sseStream.first;

      expect(event.event, 'ping');
      expect(event.data, '');
    });

    test('should not retry on 401 Unauthorized', () async {
      server!.listen((HttpRequest request) {
        request.response.statusCode = 401;
        request.response.close();
      });

      sseFlow.connect(url: serverUrl);

      // Give it a short moment to process the response
      await Future.delayed(const Duration(milliseconds: 200));

      expect(sseFlow.isConnected, isFalse);
    });

    test('disconnect should clean up resources', () async {
      server!.listen((HttpRequest request) {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('data: test\n\n');
        // Keep connection open
      });

      sseFlow.connect(url: serverUrl);
      
      // Wait for connection to establish
      await Future.delayed(const Duration(milliseconds: 100));
      expect(sseFlow.isConnected, isTrue);

      sseFlow.disconnect();
      expect(sseFlow.isConnected, isFalse);
    });
  });
}
