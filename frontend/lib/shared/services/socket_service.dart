import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  io.Socket? _socket;
  
  void connect({
    required String? userId,
    required String? email,
    required void Function(Map<String, dynamic> notification) onNotificationReceived,
  }) {
    if (_socket != null) {
      _socket!.disconnect();
    }

    final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://localhost:4000';
    debugPrint('Connecting to Socket.IO server at: $baseUrl');

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Connected to Socket.IO server');
      _socket!.emit('join', {
        if (userId != null && userId.isNotEmpty) 'userId': userId,
        if (email != null && email.isNotEmpty) 'email': email,
      });
    });

    _socket!.onDisconnect((_) {
      debugPrint('Disconnected from Socket.IO server');
    });

    _socket!.on('notification', (data) {
      debugPrint('Socket.IO notification received: $data');
      if (data is Map) {
        onNotificationReceived(Map<String, dynamic>.from(data));
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket = null;
    }
  }
}
