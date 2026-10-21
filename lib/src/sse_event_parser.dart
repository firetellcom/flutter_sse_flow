import 'dart:async';

import 'sse_model.dart';

/// Transforms a stream of SSE text lines into [SSEModel] events.
///
/// Expects input already split into lines (e.g. via `LineSplitter`).
/// Follows the SSE wire format:
/// - Lines starting with `:` are comments (e.g. `:keep-alive`) and ignored.
/// - An empty line dispatches the event accumulated so far, but only if at
///   least one `event`, `data` or `id` field was read. Blocks made only of
///   comments (keep-alive pings) therefore never produce an event.
/// - `field: value` lines populate `event`, `data` and `id`; multiple `data`
///   lines are joined with `\n`.
/// - A line without a colon is treated as a field name with an empty value.
///
/// Note: unlike the WHATWG spec, events without a `data` field (e.g.
/// `event: ping`) are still dispatched, so consumers relying on data-less
/// events keep receiving them.
class SseEventParser extends StreamTransformerBase<String, SSEModel> {
  const SseEventParser();

  @override
  Stream<SSEModel> bind(Stream<String> lines) async* {
    final StringBuffer dataBuffer = StringBuffer();
    String eventType = '';
    String id = '';
    bool hasFields = false;

    await for (final String line in lines) {
      // The SSE protocol specifies that an empty line marks the end of an event.
      if (line.isEmpty) {
        if (hasFields) {
          final String data = dataBuffer.toString();
          yield SSEModel(
            id: id,
            event: eventType,
            // Every `data` line appends '\n'; drop exactly the last one.
            data: data.endsWith('\n')
                ? data.substring(0, data.length - 1)
                : data,
          );
        }
        dataBuffer.clear();
        eventType = '';
        id = '';
        hasFields = false;
        continue;
      }

      // Ignore SSE comment lines (e.g. `:keep-alive`).
      if (line.startsWith(':')) {
        continue;
      }

      final int colonIndex = line.indexOf(':');
      final String field = colonIndex == -1
          ? line
          : line.substring(0, colonIndex);
      String value = colonIndex == -1 ? '' : line.substring(colonIndex + 1);

      // SSE spec dictates removing exactly one leading space if present.
      if (value.startsWith(' ')) {
        value = value.substring(1);
      }

      switch (field) {
        case 'event':
          eventType = value;
          hasFields = true;
        case 'data':
          dataBuffer
            ..write(value)
            ..write('\n');
          hasFields = true;
        case 'id':
          id = value;
          hasFields = true;
      }
    }
  }
}
