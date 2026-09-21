/// Represents a single Server-Sent Event (SSE).
class SSEModel {
  /// The ID of the event.
  String id;

  /// The type of the event (e.g., 'message', 'error', 'ping').
  String event;

  /// The data payload of the event.
  String data;

  SSEModel({
    this.id = '',
    this.event = '',
    this.data = '',
  });

  @override
  String toString() {
    return 'SSEModel(id: $id, event: $event, data: $data)';
  }
}
