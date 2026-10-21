import 'package:flutter_sse_flow/flutter_sse_flow.dart';
import 'package:flutter_sse_flow/src/sse_event_parser.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<SSEModel>> parse(List<String> lines) {
  return Stream<String>.fromIterable(lines)
      .transform(const SseEventParser())
      .toList();
}

void main() {
  group('SseEventParser', () {
    test('parses id, event and data fields', () async {
      final List<SSEModel> events = await parse(<String>[
        'id: 1',
        'event: message',
        'data: hello',
        '',
      ]);

      expect(events, hasLength(1));
      expect(events.first.id, '1');
      expect(events.first.event, 'message');
      expect(events.first.data, 'hello');
    });

    test('joins multiple data lines with a newline', () async {
      final List<SSEModel> events = await parse(<String>[
        'data: line1',
        'data: line2',
        '',
      ]);

      expect(events.single.data, 'line1\nline2');
    });

    test('ignores comment lines', () async {
      final List<SSEModel> events = await parse(<String>[
        ':keep-alive',
        'data: real',
        '',
      ]);

      expect(events.single.data, 'real');
    });

    test('removes only one leading space from the value', () async {
      final List<SSEModel> events = await parse(<String>[
        'data:  two spaces',
        '',
      ]);

      expect(events.single.data, ' two spaces');
    });

    test('does not emit an event without a terminating empty line', () async {
      final List<SSEModel> events = await parse(<String>['data: pending']);

      expect(events, isEmpty);
    });

    test('emits each event separately', () async {
      final List<SSEModel> events = await parse(<String>[
        'data: a',
        '',
        'data: b',
        '',
      ]);

      expect(
        events.map((SSEModel event) => event.data).toList(),
        <String>['a', 'b'],
      );
    });
  });
}
