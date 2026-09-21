## 0.0.1

* Initial release of `flutter_sse_flow`.
* Added robust Server-Sent Events (SSE) client implementation (`FlutterSseFlow`).
* Added `SSEModel` to represent event data.
* Handled automatic reconnections and edge cases like 401 Unauthorized.
* Implemented proper SSE stream parsing using `utf8.decoder` and `LineSplitter`.
* Configured automated publishing to pub.dev via GitHub Actions with OIDC.
* Added unit tests for `FlutterSseFlow` and `SSEModel`.
