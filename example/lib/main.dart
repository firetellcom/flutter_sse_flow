import 'package:flutter/material.dart';
import 'package:flutter_sse_flow/flutter_sse_flow.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter SSE Flow Demo',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SSEHomeScreen(),
    );
  }
}

class SSEHomeScreen extends StatefulWidget {
  const SSEHomeScreen({super.key});

  @override
  State<SSEHomeScreen> createState() => _SSEHomeScreenState();
}

class _SSEHomeScreenState extends State<SSEHomeScreen> {
  final FlutterSseFlow _sseClient = FlutterSseFlow();
  final List<SSEModel> _events = [];

  @override
  void initState() {
    super.initState();
    // Listen to the global stream
    _sseClient.sseStream.listen((event) {
      setState(() {
        _events.insert(0, event);
      });
    });
  }

  void _connect() {
    // Example URL. Replace with a real SSE endpoint to test.
    _sseClient.connect(
      url: 'https://api.example.com/v1/stream',
      headers: {
        'Authorization': 'Bearer YOUR_TOKEN_HERE',
      },
    );
  }

  void _disconnect() {
    _sseClient.disconnect();
    setState(() {}); // to update UI
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SSE Flow Example'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _sseClient.isConnected ? null : _connect,
                  child: const Text('Connect'),
                ),
                ElevatedButton(
                  onPressed: _sseClient.isConnected ? _disconnect : null,
                  child: const Text('Disconnect'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _events.length,
              itemBuilder: (context, index) {
                final event = _events[index];
                return ListTile(
                  title: Text(event.event.isEmpty ? 'Unknown Event' : event.event),
                  subtitle: Text(event.data.isEmpty ? 'No data' : event.data),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
