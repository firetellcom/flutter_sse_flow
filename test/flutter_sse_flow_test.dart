import 'dart:async';
import 'dart:io';

import 'package:flutter_sse_flow/flutter_sse_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FlutterSseFlow', () {
    late FlutterSseFlow sseFlow;
    HttpServer? server;
    late String serverUrl;

    setUp(() async {
      sseFlow = FlutterSseFlow(
        reconnectDelay: const Duration(milliseconds: 10),
      );
      server = await HttpServer.bind('localhost', 0);
      serverUrl = 'http://localhost:${server!.port}';
    });

    tearDown(() async {
      sseFlow.disconnect();
      await server?.close(force: true);
    });

    test('initial status should be idle', () {
      expect(sseFlow.status, SseConnectionStatus.idle);
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

      final SSEModel event = await sseFlow.sseStream.first;

      expect(event.id, '1');
      expect(event.event, 'message');
      expect(event.data, 'hello world');
      expect(sseFlow.status, SseConnectionStatus.connected);
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

      final SSEModel event = await sseFlow.sseStream.first;
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

      final SSEModel event = await sseFlow.sseStream.first;

      expect(event.event, 'ping');
      expect(event.data, '');
    });

    test('should not retry on 401 Unauthorized without handler', () async {
      server!.listen((HttpRequest request) {
        request.response.statusCode = 401;
        request.response.close();
      });

      sseFlow.connect(url: serverUrl);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(sseFlow.status, SseConnectionStatus.unauthorized);
    });

    test('should send default headers and headers from provider', () async {
      final Completer<HttpHeaders> capturedHeaders = Completer<HttpHeaders>();

      server!.listen((HttpRequest request) {
        if (!capturedHeaders.isCompleted) {
          capturedHeaders.complete(request.headers);
        }
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('data: ok\n\n');
        request.response.close();
      });

      sseFlow.connect(
        url: serverUrl,
        headers: () async => <String, String>{
          'Authorization': 'Bearer test-token',
        },
      );

      final HttpHeaders headers = await capturedHeaders.future
          .timeout(const Duration(seconds: 2));

      expect(headers.value('Accept'), 'text/event-stream');
      expect(headers.value('Cache-Control'), 'no-cache');
      expect(headers.value('Authorization'), 'Bearer test-token');
    });

    test('should resolve headers again on reconnect (rotated token)', () async {
      int requestCount = 0;
      final List<String?> tokens = <String?>[];
      final Completer<void> secondRequest = Completer<void>();

      server!.listen((HttpRequest request) {
        requestCount++;
        tokens.add(request.headers.value('Authorization'));
        request.response.bufferOutput = false;
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        if (requestCount == 1) {
          request.response.write('data: first\n\n');
          request.response.close();
        } else {
          request.response.write('data: second\n\n');
          if (!secondRequest.isCompleted) {
            secondRequest.complete();
          }
        }
      });

      int tokenCounter = 1;
      sseFlow.connect(
        url: serverUrl,
        headers: () => <String, String>{
          'Authorization': 'Bearer token-$tokenCounter',
        },
      );

      await sseFlow.sseStream.first;
      tokenCounter = 2;

      await secondRequest.future.timeout(const Duration(seconds: 2));
      expect(tokens, containsAllInOrder(<String>['Bearer token-1', 'Bearer token-2']));
    });

    test('disconnect should clean up resources and set disconnected status', () async {
      server!.listen((HttpRequest request) {
        request.response.headers.contentType =
            ContentType('text', 'event-stream');
        request.response.write('data: test\n\n');
      });

      sseFlow.connect(url: serverUrl);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(sseFlow.status, SseConnectionStatus.connected);

      sseFlow.disconnect();
      expect(sseFlow.status, SseConnectionStatus.disconnected);
    });

    group('onUnauthorized', () {
      test('retry: refreshes token and reconnects with new headers', () async {
        int requestCount = 0;
        final List<String?> authHeaders = <String?>[];
        String currentToken = 'token-expired';

        server!.listen((HttpRequest request) {
          requestCount++;
          authHeaders.add(request.headers.value('Authorization'));
          if (requestCount == 1) {
            request.response.statusCode = 401;
            request.response.close();
          } else {
            request.response.bufferOutput = false;
            request.response.headers.contentType =
                ContentType('text', 'event-stream');
            request.response.write('data: ok\n\n');
          }
        });

        int unauthorizedCalls = 0;
        sseFlow.connect(
          url: serverUrl,
          headers: () => <String, String>{
            'Authorization': 'Bearer $currentToken',
          },
          onUnauthorized: () async {
            unauthorizedCalls++;
            currentToken = 'token-fresh';
            return SseAuthDecision.retry;
          },
        );

        final SSEModel event = await sseFlow.sseStream.first;
        expect(event.data, 'ok');
        expect(unauthorizedCalls, 1);
        expect(authHeaders, <String>[
          'Bearer token-expired',
          'Bearer token-fresh',
        ]);
        expect(sseFlow.status, SseConnectionStatus.connected);
      });

      test('stop: stops reconnecting and status becomes unauthorized', () async {
        int requestCount = 0;
        server!.listen((HttpRequest request) {
          requestCount++;
          request.response.statusCode = 401;
          request.response.close();
        });

        sseFlow.connect(
          url: serverUrl,
          onUnauthorized: () async => SseAuthDecision.stop,
        );

        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(requestCount, 1);
        expect(sseFlow.status, SseConnectionStatus.unauthorized);
      });

      test('throwing handler is treated as transient and retried later', () async {
        int requestCount = 0;
        int handlerCalls = 0;

        server!.listen((HttpRequest request) {
          requestCount++;
          if (requestCount <= 2) {
            request.response.statusCode = 401;
            request.response.close();
          } else {
            request.response.bufferOutput = false;
            request.response.headers.contentType =
                ContentType('text', 'event-stream');
            request.response.write('data: recovered\n\n');
          }
        });

        sseFlow.connect(
          url: serverUrl,
          onUnauthorized: () async {
            handlerCalls++;
            if (handlerCalls == 1) {
              throw Exception('Network error during refresh');
            }
            return SseAuthDecision.retry;
          },
        );

        final SSEModel event = await sseFlow.sseStream.first;
        expect(event.data, 'recovered');
        expect(handlerCalls, 2);
        expect(sseFlow.status, SseConnectionStatus.connected);
      });
    });

    group('statusStream', () {
      test('should emit connecting, connected, and disconnected in order', () async {
        final List<SseConnectionStatus> statuses = <SseConnectionStatus>[];
        sseFlow.statusStream.listen(statuses.add);

        server!.listen((HttpRequest request) {
          request.response.bufferOutput = false;
          request.response.headers.contentType =
              ContentType('text', 'event-stream');
          request.response.write('data: hi\n\n');
        });

        sseFlow.connect(url: serverUrl);
        await sseFlow.sseStream.first;
        sseFlow.disconnect();
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(statuses, <SseConnectionStatus>[
          SseConnectionStatus.connecting,
          SseConnectionStatus.connected,
          SseConnectionStatus.disconnected,
        ]);
      });

      test('should emit reconnecting and connecting on server drop', () async {
        final List<SseConnectionStatus> statuses = <SseConnectionStatus>[];
        sseFlow.statusStream.listen(statuses.add);

        int requestCount = 0;
        final Completer<void> secondRequest = Completer<void>();
        server!.listen((HttpRequest request) {
          requestCount++;
          request.response.bufferOutput = false;
          request.response.headers.contentType =
              ContentType('text', 'event-stream');
          if (requestCount == 1) {
            request.response.write('data: first\n\n');
            request.response.close();
          } else {
            request.response.write('data: second\n\n');
            if (!secondRequest.isCompleted) {
              secondRequest.complete();
            }
          }
        });

        sseFlow.connect(url: serverUrl);

        await secondRequest.future.timeout(const Duration(seconds: 2));
        expect(statuses.contains(SseConnectionStatus.reconnecting), isTrue);
      });
    });

    group('Last-Event-ID', () {
      test('should track lastEventId from received events', () async {
        server!.listen((HttpRequest request) {
          request.response.headers.contentType =
              ContentType('text', 'event-stream');
          request.response.write('id: evt-101\n');
          request.response.write('data: payload\n\n');
          request.response.close();
        });

        sseFlow.connect(url: serverUrl);

        final SSEModel event = await sseFlow.sseStream.first;
        expect(event.id, 'evt-101');
        expect(sseFlow.lastEventId, 'evt-101');
      });

      test('should send Last-Event-ID header on reconnect after stream drop', () async {
        int requestCount = 0;
        final Completer<String?> secondRequestLastEventId = Completer<String?>();

        server!.listen((HttpRequest request) {
          requestCount++;
          request.response.headers.contentType =
              ContentType('text', 'event-stream');

          if (requestCount == 1) {
            request.response.write('id: evt-42\n');
            request.response.write('data: first\n\n');
            request.response.close();
          } else {
            final String? receivedHeader = request.headers.value('Last-Event-ID');
            if (!secondRequestLastEventId.isCompleted) {
              secondRequestLastEventId.complete(receivedHeader);
            }
            request.response.write('data: second\n\n');
            request.response.close();
          }
        });

        sseFlow.connect(url: serverUrl);

        final String? lastIdOnReconnect = await secondRequestLastEventId.future
            .timeout(const Duration(seconds: 2));
        expect(lastIdOnReconnect, 'evt-42');
      });

      test('connect resets lastEventId for a fresh session', () async {
        server!.listen((HttpRequest request) {
          request.response.headers.contentType =
              ContentType('text', 'event-stream');
          request.response.write('id: evt-999\n');
          request.response.write('data: keep\n\n');
          request.response.close();
        });

        sseFlow.connect(url: serverUrl);
        await sseFlow.sseStream.first;

        expect(sseFlow.lastEventId, 'evt-999');

        sseFlow.disconnect();
        expect(sseFlow.status, SseConnectionStatus.disconnected);

        // Next connect resets lastEventId to null
        sseFlow.connect(url: serverUrl);
        expect(sseFlow.lastEventId, isNull);
      });
    });

    group('dispose', () {
      test('should close stream controllers and reject connect', () async {
        final Completer<bool> sseStreamDone = Completer<bool>();
        final Completer<bool> statusStreamDone = Completer<bool>();

        sseFlow.sseStream.listen(
          null,
          onDone: () => sseStreamDone.complete(true),
        );
        sseFlow.statusStream.listen(
          null,
          onDone: () => statusStreamDone.complete(true),
        );

        await sseFlow.dispose();

        expect(
          await sseStreamDone.future.timeout(const Duration(seconds: 1)),
          isTrue,
        );
        expect(
          await statusStreamDone.future.timeout(const Duration(seconds: 1)),
          isTrue,
        );

        expect(
          () => sseFlow.connect(url: serverUrl),
          throwsStateError,
        );
      });
    });

    group('SseSession concurrency and race prevention', () {
      test(
          'disconnect then connect back-to-back cancels old loop and does not duplicate events',
          () async {
        final List<HttpResponse> openResponses = <HttpResponse>[];
        server!.listen((HttpRequest request) {
          request.response.bufferOutput = false;
          request.response.headers.contentType =
              ContentType('text', 'event-stream');
          request.response.write(': open\n\n');
          openResponses.add(request.response);
        });

        sseFlow.connect(url: serverUrl);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        sseFlow.disconnect();
        sseFlow.connect(url: serverUrl);
        await Future<void>.delayed(const Duration(milliseconds: 100));

        int received = 0;
        final StreamSubscription<SSEModel> sub =
            sseFlow.sseStream.listen((SSEModel e) {
          if (e.data == 'MSG') received++;
        });

        for (final HttpResponse r in openResponses) {
          r.write('event: sms\ndata: MSG\n\n');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await sub.cancel();

        expect(received, 1);
      });

      test(
          'disconnect and connect while sleeping in reconnectDelay terminates old loop cleanly',
          () async {
        int requestCount = 0;
        final List<HttpResponse> openResponses = <HttpResponse>[];
        server!.listen((HttpRequest request) {
          requestCount++;
          request.response.bufferOutput = false;
          request.response.headers.contentType =
              ContentType('text', 'event-stream');
          if (requestCount == 1) {
            request.response.close();
            return;
          }
          request.response.write(': open\n\n');
          openResponses.add(request.response);
        });

        final FlutterSseFlow localSse = FlutterSseFlow(
          reconnectDelay: const Duration(milliseconds: 150),
        );
        localSse.connect(url: serverUrl);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        localSse.disconnect();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        localSse.connect(url: serverUrl);
        await Future<void>.delayed(const Duration(milliseconds: 300));

        int received = 0;
        final StreamSubscription<SSEModel> sub =
            localSse.sseStream.listen((SSEModel e) {
          if (e.data == 'MSG') received++;
        });

        for (final HttpResponse r in openResponses) {
          r.write('event: sms\ndata: MSG\n\n');
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await sub.cancel();
        localSse.disconnect();

        expect(received, 1);
      });
    });
  });
}
