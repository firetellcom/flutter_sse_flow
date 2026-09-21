import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sse_flow/flutter_sse_flow.dart';

void main() {
  group('SSEModel', () {
    test('should initialize with default values', () {
      final model = SSEModel();
      expect(model.id, '');
      expect(model.event, '');
      expect(model.data, '');
    });

    test('should initialize with provided values', () {
      final model = SSEModel(
        id: '123',
        event: 'message',
        data: '{"status": "ok"}',
      );
      expect(model.id, '123');
      expect(model.event, 'message');
      expect(model.data, '{"status": "ok"}');
    });

    test('toString() should return correct format', () {
      final model = SSEModel(
        id: '1',
        event: 'ping',
        data: 'pong',
      );
      expect(model.toString(), 'SSEModel(id: 1, event: ping, data: pong)');
    });
  });
}
