## 0.1.0

### Added
* **Dynamic Header Provider (`SseHeadersProvider`)**: Support dynamically resolving headers before every connection and automatic reconnection attempt, enabling transparent token rotation.
* **Auth-aware Recovery (`onUnauthorized` & `SseAuthDecision`)**: Handle 401/403 status codes by refreshing credentials and returning `SseAuthDecision.retry` or `SseAuthDecision.stop`.
* **Bounded Auth Retries (`maxAuthRetries`)**: Added configurable `maxAuthRetries` (default 10) to prevent infinite connection loops when credentials remain rejected.
* **Automatic `Last-Event-ID` Resumption**: Automatically tracks received event IDs and includes the `Last-Event-ID` header on reconnects.
* **Connection Lifecycle Monitoring (`SseConnectionStatus` & `statusStream`)**: Observe granular lifecycle states (`idle`, `connecting`, `connected`, `reconnecting`, `refreshingAuth`, `unauthorized`, `disconnected`).
* **Resource Cleanup (`dispose`)**: Permanently close internal stream controllers and terminate active connections.

### Fixed
* **Race Condition Prevention**: Implemented `SseSession` cancellation token pattern so rapid `disconnect()` followed by `connect()` never results in concurrent loops or duplicate events.
* **Keep-Alive Comment Parsing**: Pure comment blocks (e.g. `:keep-alive\n\n`) no longer emit empty `SSEModel` instances into the stream.

### Changed
* **Breaking Change**: `connect()` parameter `headers` now accepts a `SseHeadersProvider?` callback (`FutureOr<Map<String, String>> Function()`) instead of a static `Map<String, String>?`.

## 0.0.2

* Updated `README.md` with comprehensive, separate English and Vietnamese documentation sections.
* Added detailed API reference tables and usage examples.
* Cleaned up test imports for `flutter analyze` compliance.

## 0.0.1

* Initial release of `flutter_sse_flow`.
* Added robust Server-Sent Events (SSE) client implementation (`FlutterSseFlow`).
* Added `SSEModel` to represent event data.
* Handled automatic reconnections and edge cases like 401 Unauthorized.
* Implemented proper SSE stream parsing using `utf8.decoder` and `LineSplitter`.
* Configured automated publishing to pub.dev via GitHub Actions with OIDC.
* Added unit tests for `FlutterSseFlow` and `SSEModel`.
