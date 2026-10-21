# Flutter SSE Flow

[![pub package](https://img.shields.io/pub/v/flutter_sse_flow.svg)](https://pub.dev/packages/flutter_sse_flow)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/firetellcom/flutter_sse_flow/blob/main/LICENSE)

A robust, enterprise-grade, standard-compliant Server-Sent Events (SSE) client for Flutter and Dart. Engineered with dynamic auth rotation, granular connection lifecycle monitoring, automatic `Last-Event-ID` resumption, and race-condition prevention.

---

🌐 **Languages / Ngôn ngữ:**
- [English Documentation](#-english-documentation)
- [Tài liệu Tiếng Việt](#-tài-liệu-tiếng-việt)

---

# 🇬🇧 English Documentation

## Why Flutter SSE Flow?

Many existing SSE packages suffer from stale auth headers across reconnections, persistent tight loops on `401 Unauthorized`, race conditions during quick reconnects, or broken parsing of multi-line payloads. **flutter_sse_flow** provides an end-to-end resilient solution:

1. **Standard-Compliant Parsing (W3C Spec):**
   Uses `utf8.decoder` and `LineSplitter()` to parse streams line by line. Properly strips optional leading spaces after colons, concatenates multi-line `data:` payloads (essential for LLM/AI streaming responses), and ignores `:keep-alive` comments without emitting ghost events.

2. **Dynamic Header Resolution & Token Rotation:**
   Instead of capturing static headers at initialization, `headers` is a provider callback (`SseHeadersProvider`) evaluated before **every** connection attempt (initial and reconnects). Rotating tokens in the background seamlessly applies on the next reconnect.

3. **Auth-Aware Recovery (`onUnauthorized` & `maxAuthRetries`):**
   Recovers from `401 Unauthorized` or `403 Forbidden` via an asynchronous `onUnauthorized` handler. Refresh your credentials and return `SseAuthDecision.retry` or `SseAuthDecision.stop`. Built-in `maxAuthRetries` (default 10) prevents infinite tight-loops and self-DDoS if credentials remain rejected.

4. **Automatic `Last-Event-ID` Tracking:**
   Tracks non-empty `id:` fields and automatically transmits the `Last-Event-ID` header on auto-reconnections, ensuring zero message loss across network drops.

5. **Granular Lifecycle Monitoring (`statusStream`):**
   Track real-time connection state (`idle`, `connecting`, `connected`, `reconnecting`, `refreshingAuth`, `unauthorized`, `disconnected`).

6. **Race-Condition & Concurrency Prevention (`SseSession`):**
   Calling `disconnect()` then `connect()` immediately cancels the previous connection lifecycle cleanly, preventing concurrent loops and duplicate message deliveries.

7. **Clean Resource Teardown (`dispose`):**
   Distinguishes between pausing a stream (`disconnect()`) and permanently freeing memory and stream controllers (`dispose()`).

---

## Installation

Add `flutter_sse_flow` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_sse_flow: ^0.1.0
```

Or run:

```bash
flutter pub add flutter_sse_flow
```

---

## Quick Start

### 1. Import the package

```dart
import 'package:flutter_sse_flow/flutter_sse_flow.dart';
```

### 2. Instantiate the client

```dart
final FlutterSseFlow _sseClient = FlutterSseFlow(
  reconnectDelay: const Duration(seconds: 2),
  maxAuthRetries: 10,
);
```

### 3. Listen to events and status

```dart
// Listen to incoming SSE messages
_sseClient.sseStream.listen(
  (SSEModel event) {
    print('Event: ${event.event}, ID: ${event.id}, Data: ${event.data}');
  },
  onError: (Object error) {
    print('Stream error: $error');
  },
);

// Monitor connection lifecycle status
_sseClient.statusStream.listen((SseConnectionStatus status) {
  print('Current connection status: $status');
});
```

### 4. Connect with Dynamic Auth and 401 Recovery

```dart
_sseClient.connect(
  url: 'https://api.example.com/v1/stream',
  // Dynamic headers: re-evaluated on every connect/reconnect attempt
  headers: () async => <String, String>{
    'Authorization': 'Bearer ${await authService.getFreshAccessToken()}',
  },
  unauthorizedStatusCodes: const <int>{401, 403},
  onUnauthorized: () async {
    final bool refreshed = await authService.refreshToken();
    return refreshed ? SseAuthDecision.retry : SseAuthDecision.stop;
  },
);
```

### 5. Disconnect and Dispose

```dart
// Temporary disconnect (can reconnect later via connect())
_sseClient.disconnect();

// Permanent disposal (e.g. inside a State's dispose() method)
@override
void dispose() {
  _sseClient.dispose();
  super.dispose();
}
```

---

## API Reference

### `FlutterSseFlow`

| Member | Type | Description |
|---|---|---|
| `FlutterSseFlow({Duration reconnectDelay, int maxAuthRetries})` | Constructor | Creates a new client. Defaults: `reconnectDelay = 2s`, `maxAuthRetries = 10`. |
| `sseStream` | `Stream<SSEModel>` | Broadcast stream emitting incoming server events. |
| `status` | `SseConnectionStatus` | Current connection lifecycle status. |
| `statusStream` | `Stream<SseConnectionStatus>` | Broadcast stream emitting connection lifecycle transitions. |
| `lastEventId` | `String?` | The last received event ID sent on auto-reconnection. |
| `connect(...)` | `void` | Connects to the SSE endpoint with optional dynamic headers and auth recovery. |
| `disconnect()` | `void` | Closes active socket and aborts reconnect loop. Instance remains reusable. |
| `dispose()` | `Future<void>` | Disconnects and closes internal stream controllers permanently. |

### `SseConnectionStatus`

- `idle`: Client has not connected yet.
- `connecting`: Establishing HTTP connection to the SSE server.
- `connected`: Actively connected and receiving events.
- `reconnecting`: Network disconnected; waiting `reconnectDelay` before retrying.
- `refreshingAuth`: Received 401/403; executing `onUnauthorized` handler.
- `unauthorized`: Authentication failed or max retries exceeded; client stopped.
- `disconnected`: Manually disconnected via `disconnect()`.

### `SSEModel`

| Property | Type | Default | Description |
|---|---|---|---|
| `id` | `String` | `''` | Event identifier. |
| `event` | `String` | `''` | Event name or type. |
| `data` | `String` | `''` | Event payload (concatenated multi-line string). |

---

## Migration Guide (0.0.x ➔ 0.1.0)

1. **`headers` is now a provider function:**
   - *Old:* `connect(url: url, headers: {'Authorization': 'Bearer ...'})`
   - *New:* `connect(url: url, headers: () async => {'Authorization': 'Bearer ...'})`
2. **Resource Cleanup:**
   - Call `dispose()` when permanently destroying the client instead of only `disconnect()`.

---

# 🇻🇳 Tài liệu Tiếng Việt

## Tại sao nên chọn Flutter SSE Flow?

Nhiều package SSE hiện nay dễ gặp lỗi token hết hạn khi reconnect, vòng lặp spam request vô tận khi gặp `401 Unauthorized`, xung đột kết nối khi gọi `disconnect()` và `connect()` liên tục, hoặc không ghép các dòng `data:` nhiều dòng theo chuẩn W3C. **flutter_sse_flow** giải quyết triệt để toàn bộ các vấn đề này:

1. **Phân tích cú pháp chuẩn SSE (W3C Standard):**
   Sử dụng `utf8.decoder` kết hợp `LineSplitter()` đọc luồng dữ liệu theo từng dòng. Tự động bỏ khoảng trắng sau dấu hai chấm, ghép nối các dòng `data:` nhiều dòng (chuẩn cho stream LLM/AI chat), và bỏ qua các dòng comment `:keep-alive` mà không bắn ra các event rỗng.

2. **Cập nhật Header động & Xoay Token tự động:**
   Tham số `headers` là một hàm callback (`SseHeadersProvider`) được thực thi lại trước **mỗi** lần kết nối và kết nối lại. Khi token được làm mới, kết nối tiếp theo sẽ tự động nhận token mới nhất.

3. **Khôi phục lỗi xác thực thông minh (`onUnauthorized` & `maxAuthRetries`):**
   Khi server trả về mã 401/403, client sẽ gọi callback `onUnauthorized`. Bạn có thể làm mới token bất đồng bộ và trả về `SseAuthDecision.retry` để thử lại ngay, hoặc `SseAuthDecision.stop` để dừng hẳn. Cơ chế `maxAuthRetries` (mặc định 10 lần) ngăn ngừa hoàn toàn tình trạng spam request và tự DDoS server.

4. **Tự động lưu và gửi `Last-Event-ID`:**
   Tự động ghi nhớ `id:` sự kiện gần nhất và gửi kèm header `Last-Event-ID` khi reconnect, giúp bảo đảm không bị mất mát dữ liệu khi chập chờn mạng.

5. **Theo dõi vòng đời kết nối chi tiết (`statusStream`):**
   Cung cấp stream trạng thái trực quan (`idle`, `connecting`, `connected`, `reconnecting`, `refreshingAuth`, `unauthorized`, `disconnected`).

6. **Chống xung đột Race Condition (`SseSession`):**
   Khi gọi `disconnect()` rồi `connect()` liên tiếp, phiên cũ sẽ lập tức bị hủy bỏ thông qua Cancellation Token, không bao giờ xảy ra tình trạng 2 vòng lặp chạy song song gây trùng lặp tin nhắn.

7. **Dọn dẹp bộ nhớ triệt để (`dispose`):**
   Cung cấp hàm `dispose()` đóng vĩnh viễn các `StreamController` và socket kết nối.

---

## Cài đặt

Thêm package vào file `pubspec.yaml`:

```yaml
dependencies:
  flutter_sse_flow: ^0.1.0
```

Hoặc chạy lệnh:

```bash
flutter pub add flutter_sse_flow
```

---

## Hướng dẫn sử dụng nhanh

### 1. Import package

```dart
import 'package:flutter_sse_flow/flutter_sse_flow.dart';
```

### 2. Khởi tạo client

```dart
final FlutterSseFlow _sseClient = FlutterSseFlow(
  reconnectDelay: const Duration(seconds: 2),
  maxAuthRetries: 10,
);
```

### 3. Lắng nghe dữ liệu và trạng thái

```dart
// Lắng nghe dữ liệu SSE từ server
_sseClient.sseStream.listen(
  (SSEModel event) {
    print('Sự kiện: ${event.event}, ID: ${event.id}, Nội dung: ${event.data}');
  },
  onError: (Object error) {
    print('Lỗi luồng: $error');
  },
);

// Lắng nghe trạng thái kết nối
_sseClient.statusStream.listen((SseConnectionStatus status) {
  print('Trạng thái kết nối hiện tại: $status');
});
```

### 4. Kết nối kèm Token động và Xử lý 401

```dart
_sseClient.connect(
  url: 'https://api.example.com/v1/stream',
  // Dynamic headers: tự động gọi lại mỗi lần kết nối lại
  headers: () async => <String, String>{
    'Authorization': 'Bearer ${await authService.getAccessToken()}',
  },
  unauthorizedStatusCodes: const <int>{401, 403},
  onUnauthorized: () async {
    final bool refreshed = await authService.refreshToken();
    return refreshed ? SseAuthDecision.retry : SseAuthDecision.stop;
  },
);
```

### 5. Ngắt kết nối và Hủy tài nguyên

```dart
// Tạm ngắt kết nối (vẫn có thể gọi connect() lại sau)
_sseClient.disconnect();

// Hủy vĩnh viễn (gọi trong hàm dispose() của Widget / Cubit)
@override
void dispose() {
  _sseClient.dispose();
  super.dispose();
}
```

---

## Bảng tham chiếu API

### `FlutterSseFlow`

| Thành phần | Kiểu | Mô tả |
|---|---|---|
| `FlutterSseFlow({Duration reconnectDelay, int maxAuthRetries})` | Constructor | Khởi tạo client với thời gian chờ kết nối lại (mặc định 2s) và giới hạn retry auth (mặc định 10). |
| `sseStream` | `Stream<SSEModel>` | Broadcast stream phát ra các sự kiện SSE nhận từ server. |
| `status` | `SseConnectionStatus` | Trạng thái vòng đời kết nối hiện tại. |
| `statusStream` | `Stream<SseConnectionStatus>` | Broadcast stream phát ra mỗi khi trạng thái kết nối thay đổi. |
| `lastEventId` | `String?` | ID sự kiện gần nhất nhận được. |
| `connect(...)` | `void` | Bắt đầu kết nối đến endpoint SSE kèm headers động và handler 401. |
| `disconnect()` | `void` | Tạm ngắt kết nối và giải phóng HTTP socket. Có thể kết nối lại sau. |
| `dispose()` | `Future<void>` | Ngắt kết nối và đóng vĩnh viễn toàn bộ các stream controller. |

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
