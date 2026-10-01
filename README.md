# Flutter SSE Flow

[![pub package](https://img.shields.io/pub/v/flutter_sse_flow.svg)](https://pub.dev/packages/flutter_sse_flow)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/firetellcom/flutter_sse_flow/blob/main/LICENSE)

A robust, simple, and standard-compliant Server-Sent Events (SSE) client package for Flutter and Dart. Designed with resilience, null-safety, and clean lifecycle management.

---

🌐 **Languages / Ngôn ngữ:**
- [English Documentation](#-english-documentation)
- [Tài liệu Tiếng Việt](#-tài-liệu-tiếng-việt)

---

# 🇬🇧 English Documentation

## Why Flutter SSE Flow?

Many existing SSE packages suffer from persistent reconnection loops, incorrect parsing of multi-line payloads, or rigid singleton architectures. **flutter_sse_flow** was built to solve these issues:

1. **Standard-Compliant Parsing (W3C Spec):**
   Uses `utf8.decoder` and `LineSplitter()` to process stream chunks line by line. Properly handles arbitrary field order, strips the optional leading space after colons, and correctly concatenates multi-line `data:` fields (essential for large payloads like LLM/AI streaming responses).

2. **Clean Reconnection Logic (No Zombie Tasks):**
   Operates on a controlled `while (_isConnected)` loop. Invoking `disconnect()` cleanly breaks the loop and aborts future retries, avoiding hidden background tasks and battery drain.

3. **Smart 401 Unauthorized Handling:**
   If the server responds with HTTP `401 Unauthorized`, reconnection attempts stop immediately. This prevents token-spamming loops and allows your application to trigger a logout or token-refresh flow gracefully.

4. **Instance-Based Architecture:**
   `FlutterSseFlow` is an instantiable class rather than a singleton. You can manage multiple concurrent, independent SSE streams in parallel without collisions.

5. **Memory Leak Prevention:**
   Closes the underlying `http.Client` and cancels stream subscriptions upon `disconnect()`, ensuring no dangling network sockets.

6. **100% Sound Null-Safety:**
   `SSEModel` uses non-nullable `String` fields with empty string defaults (`''`), eliminating `NullPointerExceptions` when rendering data in your UI.

---

## Features

- Connect to any SSE stream with custom HTTP headers (e.g. `Authorization: Bearer <token>`).
- Automatic reconnection with backoff upon network interruption.
- Immediate teardown on `401 Unauthorized`.
- Standard Dart `Stream<SSEModel>` interface.
- Lightweight, zero heavy third-party dependencies (only `http`).

---

## Installation

Add `flutter_sse_flow` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_sse_flow: ^0.0.1
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
final FlutterSseFlow _sseClient = FlutterSseFlow();
```

### 3. Listen to incoming events

Listen to `sseStream` to process incoming `SSEModel` events:

```dart
@override
void initState() {
  super.initState();

  _sseClient.sseStream.listen(
    (SSEModel event) {
      print('ID: ${event.id}');
      print('Event: ${event.event}');
      print('Data: ${event.data}');
    },
    onError: (error) {
      print('Stream error: $error');
    },
  );
}
```

### 4. Connect to the stream

Call `connect()` with the target URL and any optional headers:

```dart
_sseClient.connect(
  url: 'https://api.example.com/v1/stream',
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN_HERE',
    'Accept': 'text/event-stream',
  },
);
```

### 5. Disconnect and clean up

When the stream is no longer needed (e.g., in `dispose()`), call `disconnect()`:

```dart
@override
void dispose() {
  _sseClient.disconnect();
  super.dispose();
}
```

---

## API Reference

### `FlutterSseFlow`

| Member | Type | Description |
|---|---|---|
| `sseStream` | `Stream<SSEModel>` | Broadcast stream emitting incoming server events. |
| `isConnected` | `bool` | Current connection status (`true` if connected or actively reconnecting). |
| `connect({required String url, Map<String, String>? headers})` | `void` | Connects to the SSE endpoint and begins processing data. |
| `disconnect()` | `void` | Stops reconnection, closes the HTTP client, and releases resources. |

### `SSEModel`

| Property | Type | Default | Description |
|---|---|---|---|
| `id` | `String` | `''` | Event identifier. |
| `event` | `String` | `''` | Event name or type. |
| `data` | `String` | `''` | Event payload (concatenated multi-line string). |

---

## Example Application

Check out the [`example/`](example/) folder for a complete, runnable Flutter app demo.

---

# 🇻🇳 Tài liệu Tiếng Việt

## Tại sao nên chọn Flutter SSE Flow?

Nhiều package SSE hiện nay dễ gặp lỗi lặp kết nối vô hạn (tạo task chạy ngầm gây tốn pin), không ghép các dòng `data:` nhiều dòng theo chuẩn W3C, hoặc dùng singleton khiến khó quản lý nhiều luồng. **flutter_sse_flow** được thiết kế để khắc phục triệt để các hạn chế này:

1. **Phân tích cú pháp chuẩn SSE (W3C Standard):**
   Sử dụng `utf8.decoder` kết hợp `LineSplitter()` đọc luồng dữ liệu theo từng dòng. Xử lý chính xác thứ tự trường bất kỳ, tự động bỏ khoảng trắng sau dấu hai chấm, và ghép nối các dòng `data:` liền nhau (đặc biệt hữu ích cho các payload JSON lớn hoặc stream chat từ LLM/AI).

2. **Cơ chế Reconnect tin cậy (Không lo Zombie Task):**
   Vận hành trên vòng lặp `while (_isConnected)`. Khi gọi `disconnect()`, cờ kết nối lập tức chuyển thành `false` và thoát vòng lặp, bảo đảm tiến trình dọn dẹp sạch sẽ, không âm thầm chạy ngầm làm hao pin.

3. **Xử lý thông minh khi gặp lỗi 401 Unauthorized:**
   Nếu server phản hồi mã HTTP `401`, client sẽ tự động dừng thử lại ngay lập tức. Điều này giúp ngăn ngừa việc spam request liên tục lên server và cho phép ứng dụng điều hướng người dùng đăng nhập lại hoặc làm mới token.

4. **Kiến trúc Hướng đối tượng (Instance-based):**
   `FlutterSseFlow` là class có thể khởi tạo nhiều lần. Bạn có thể mở đồng thời nhiều luồng kết nối SSE độc lập trong cùng một ứng dụng mà không lo xung đột.

5. **Giải phóng tài nguyên & Chống rò rỉ bộ nhớ:**
   Tự động đóng `http.Client` nội bộ và hủy các socket ngay khi gọi `disconnect()`.

6. **Hỗ trợ Sound Null-Safety 100%:**
   `SSEModel` sử dụng các trường kiểu `String` non-nullable kèm giá trị mặc định là chuỗi rỗng `''`, ngăn chặn triệt để lỗi `NullPointerException` khi render dữ liệu trên giao diện.

---

## Các tính năng chính

- Kết nối tới luồng SSE hỗ trợ tùy biến HTTP headers (ví dụ: `Authorization: Bearer <token>`).
- Tự động kết nối lại khi mất mạng hoặc rớt kết nối.
- Dừng kết nối an toàn khi server trả về HTTP `401 Unauthorized`.
- Dữ liệu cung cấp qua Dart `Stream<SSEModel>` broadcast tiện dụng.
- Nhẹ nhàng, không phụ thuộc thư viện bên thứ ba cồng kềnh (chỉ dùng `http`).

---

## Cài đặt

Thêm package vào file `pubspec.yaml` của bạn:

```yaml
dependencies:
  flutter_sse_flow: ^0.0.1
```

Hoặc chạy lệnh:

```bash
flutter pub add flutter_sse_flow
```

---

## Hướng dẫn sử dụng

### 1. Import package

```dart
import 'package:flutter_sse_flow/flutter_sse_flow.dart';
```

### 2. Khởi tạo client

```dart
final FlutterSseFlow _sseClient = FlutterSseFlow();
```

### 3. Lắng nghe luồng sự kiện

Lắng nghe `sseStream` để nhận các sự kiện `SSEModel` được gửi từ server:

```dart
@override
void initState() {
  super.initState();

  _sseClient.sseStream.listen(
    (SSEModel event) {
      print('ID: ${event.id}');
      print('Event: ${event.event}');
      print('Data: ${event.data}');
    },
    onError: (error) {
      print('Lỗi luồng stream: $error');
    },
  );
}
```

### 4. Kết nối tới server

Gọi hàm `connect()` kèm URL và các headers cần thiết:

```dart
_sseClient.connect(
  url: 'https://api.example.com/v1/stream',
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN_HERE',
    'Accept': 'text/event-stream',
  },
);
```

### 5. Ngắt kết nối và giải phóng

Khi không còn sử dụng (ví dụ khi widget bị hủy trong `dispose()`), hãy gọi `disconnect()`:

```dart
@override
void dispose() {
  _sseClient.disconnect();
  super.dispose();
}
```

---

## Bảng tham chiếu API

### `FlutterSseFlow`

| Thành phần | Kiểu | Mô tả |
|---|---|---|
| `sseStream` | `Stream<SSEModel>` | Broadcast stream phát ra các sự kiện SSE nhận từ server. |
| `isConnected` | `bool` | Trạng thái kết nối hiện tại (`true` nếu đang kết nối hoặc đang tự động kết nối lại). |
| `connect({required String url, Map<String, String>? headers})` | `void` | Bắt đầu kết nối đến endpoint SSE và nhận luồng dữ liệu. |
| `disconnect()` | `void` | Hủy kết nối, đóng HTTP client và giải phóng toàn bộ tài nguyên. |

### `SSEModel`

| Thuộc tính | Kiểu | Mặc định | Mô tả |
|---|---|---|---|
| `id` | `String` | `''` | Mã định danh sự kiện. |
| `event` | `String` | `''` | Tên/loại sự kiện. |
| `data` | `String` | `''` | Dữ liệu nội dung (đã được tự động ghép nối theo chuẩn SSE nếu có nhiều dòng). |

---

## Ứng dụng mẫu

Tham khảo thư mục [`example/`](example/) để xem mã nguồn ví dụ ứng dụng Flutter hoàn chỉnh có thể chạy trực tiếp.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
