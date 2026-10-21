import 'dart:async';

import 'sse_model.dart';

/// Transforms a stream of SSE text lines into [SSEModel] events.
///
/// Expects input already split into lines (e.g. via `LineSplitter`).
/// Follows the SSE wire format:
/// - Lines starting with `:` are comments (e.g. `:keep-alive`) and ignored.
/// - An empty line dispatches the event accumulated so far.
/// - `field: value` lines populate `event`, `data` and `id`; multiple `data`
///   lines are joined with `\n`.
class SseEventParser extends StreamTransformerBase<String, SSEModel> {
  const SseEventParser();

  @override
  Stream<SSEModel> bind(Stream<String> lines) async* {
    SSEModel currentEvent = SSEModel();

    await for (final String line in lines) {
      // Ignore SSE comment lines (e.g. `:keep-alive`).
      if (line.startsWith(':')) {
        continue;
      }

      // The SSE protocol specifies that an empty line marks the end of an event.
      if (line.isEmpty) {
        // SSE spec dictates removing exactly one trailing newline from data.
        if (currentEvent.data.endsWith('\n')) {
          currentEvent.data = currentEvent.data.substring(
            0,
            currentEvent.data.length - 1,
          );
        }

        yield currentEvent;
        // Reset the model to gather data for the next event.
        currentEvent = SSEModel();
        continue;
      }

      final int colonIndex = line.indexOf(':');
      if (colonIndex != -1) {
        final String field = line.substring(0, colonIndex).trim();
        String value = line.substring(colonIndex + 1);

        // SSE spec dictates removing exactly one leading space if present.
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
}
