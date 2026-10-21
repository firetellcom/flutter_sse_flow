import 'package:flutter_sse_flow/flutter_sse_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  group('SseSession', () {
    test('initial state should not be cancelled and client should be null', () {
      final SseSession session = SseSession();
      expect(session.isCancelled, isFalse);
      expect(session.client, isNull);
    });

    test('cancel() should set isCancelled to true and close client', () {
      final SseSession session = SseSession();
      final http.Client client = http.Client();
      session.client = client;

      session.cancel();

      expect(session.isCancelled, isTrue);
      expect(session.client, isNull);
    });
  });
}
