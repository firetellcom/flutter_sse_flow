# Flutter SSE Flow

A robust and simple Server-Sent Events (SSE) client package for Flutter.
*(Một package SSE mạnh mẽ và đơn giản dành cho Flutter.)*

## Why choose this package? / Tại sao nên chọn package này?

**1. Standard-Compliant Parsing (Robustness against complex data):**
Processes the stream line-by-line using `LineSplitter()`. It perfectly handles arbitrary field orders, missing fields, and concatenates multi-line data chunks (like large JSON payloads) exactly according to the SSE standard.

**2. Bug-free Reconnection Logic (No Zombie Futures):**
Uses a robust `while (_isConnected)` loop. A call to `disconnect()` immediately breaks the loop, ensuring 100% clean teardown. No background battery drain.

**3. Null-Safety & Strict Model:**
`SSEModel` uses strict non-nullable `String` fields with actual empty string defaults, guaranteeing no NullPointerExceptions in your UI.

**4. Smart Authentication Handling (401 Unauthorized):**
Gracefully catches HTTP 401. If the token is invalid, it stops retrying immediately, allowing your app to log the user out or refresh the token without spamming the server.

**5. Instance-based (Supports multiple concurrent SSE streams):**
`FlutterSseFlow` is an instantiable class. You can create multiple instances for multiple parallel SSE streams without them colliding.

**6. Memory Leak Prevention:**
Explicitly closes the internal HTTP client and frees socket resources upon disconnect.

---

## Features / Các tính năng chính

🇬🇧 **English**
- Connect to SSE streams with custom headers (e.g., Authorization Bearer tokens).
- Automatically reconnects when the connection is lost.
- Safely stops reconnecting when receiving a `401 Unauthorized` HTTP status.
- Exposes a clean, standard Dart `Stream<SSEModel>`.

🇻🇳 **Tiếng Việt**
- Kết nối tới các luồng SSE hỗ trợ tùy chỉnh headers (ví dụ: Authorization Bearer tokens).
- Tự động kết nối lại khi mạng bị lỗi hoặc rớt kết nối.
- Dừng kết nối an toàn khi server trả về lỗi `401 Unauthorized`.
- Cung cấp dữ liệu dạng `Stream<SSEModel>` thuần Dart cực kỳ dễ sử dụng.

---

## Installation / Cài đặt

Add this to your package's `pubspec.yaml` file:
*(Thêm dòng sau vào file `pubspec.yaml` của bạn:)*

```yaml
dependencies:
  flutter_sse_flow: ^0.0.1
```

Then run / *(Sau đó chạy)*:
```bash
flutter pub get
```

---

## Usage / Hướng dẫn sử dụng

### 1. Import the package / *Import package*

```dart
import 'package:flutter_sse_flow/flutter_sse_flow.dart';
```

### 2. Initialize the client / *Khởi tạo client*

```dart
final FlutterSseFlow _sseClient = FlutterSseFlow();
```

### 3. Listen to the stream / *Lắng nghe dữ liệu*

Listen to `sseStream` to receive incoming events.
*(Lắng nghe `sseStream` để nhận các sự kiện trả về từ server.)*

```dart
@override
void initState() {
  super.initState();
  
  _sseClient.sseStream.listen((SSEModel event) {
    print('Id: ${event.id}');
    print('Event: ${event.event}');
    print('Data: ${event.data}');
  });
}
```

### 4. Connect to the stream / *Bắt đầu kết nối*

Call `connect` with your URL and any necessary headers (like authentication tokens).
*(Gọi hàm `connect` với URL và các headers cần thiết như token xác thực.)*

```dart
_sseClient.connect(
  url: 'https://api.example.com/v1/stream',
  headers: {
    'Authorization': 'Bearer YOUR_TOKEN_HERE',
    // 'Custom-Header': 'Value',
  },
);
```

### 5. Disconnect / *Ngắt kết nối*

When you no longer need the stream (e.g., when the widget is disposed), call `disconnect()`.
*(Khi không cần sử dụng nữa, ví dụ như lúc hủy Widget, hãy gọi hàm `disconnect()`.)*

```dart
@override
void dispose() {
  _sseClient.disconnect();
  super.dispose();
}
```

---

## Example / Ví dụ

See the `example/` folder for a complete, runnable example application.
*(Xem thư mục `example/` để có một ví dụ ứng dụng Flutter hoàn chỉnh có thể chạy được.)*
