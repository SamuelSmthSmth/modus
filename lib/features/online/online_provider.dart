import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/settings_provider.dart';
import '../tasks/task_provider.dart';
import '../timer/timer_logic.dart';

class OnlineProvider extends ChangeNotifier {
  static const String _messageTypeKey = 'type';
  static const String _timerDataType = 'timer_data';
  static const String _nudgeType = 'nudge';
  static const String _chatType = 'chat';
  static const String _chatSenderKey = 'sender';
  static const String _chatTextKey = 'text';

  OnlineProvider({
    required TimerProvider timerProvider,
    required TaskProvider taskProvider,
    required SettingsProvider settingsProvider,
  }) : _timerProvider = timerProvider,
       _taskProvider = taskProvider,
       _settingsProvider = settingsProvider {
    unawaited(_fetchLocalIp());
  }

  TimerProvider _timerProvider;
  TaskProvider _taskProvider;
  SettingsProvider _settingsProvider;
  final AudioPlayer _audioPlayer = AudioPlayer();

  HttpServer? _server;
  Timer? _broadcastTimer;
  final List<WebSocket> _clients = [];
  WebSocket? _clientSocket;

  String _hostIpAddress = 'Detecting LAN IP...';
  String? _connectedIpAddress;
  String? _friendName;
  Map<String, dynamic>? _lastRemoteStatus;
  final List<Map<String, String>> chatMessages = [];

  bool _isHosting = false;
  bool _isConnected = false;

  String get hostIpAddress => _hostIpAddress;
  bool get isHosting => _isHosting;
  bool get isConnected => _isConnected;
  int get connectedPeersCount => _clients.length;
  String? get connectedIpAddress => _connectedIpAddress;
  String? get friendName => _friendName;
  Map<String, dynamic>? get lastRemoteStatus => _lastRemoteStatus;

  void update(TimerProvider timerProvider, TaskProvider taskProvider) {
    _timerProvider = timerProvider;
    _taskProvider = taskProvider;
  }

  void updateSettings(SettingsProvider settingsProvider) {
    _settingsProvider = settingsProvider;
  }

  void updateDependencies({
    required TimerProvider timerProvider,
    required TaskProvider taskProvider,
    required SettingsProvider settingsProvider,
  }) {
    update(timerProvider, taskProvider);
    updateSettings(settingsProvider);
  }

  Future<void> startHosting() async {
    if (_isHosting) return;

    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      8080,
      shared: true,
    );

    _isHosting = true;
    notifyListeners();

    unawaited(
      _server!.forEach((request) async {
        await _handleRequest(request);
      }),
    );

    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _broadcastStatus();
    });
  }

  Future<void> stopHosting() async {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;

    for (final client in List<WebSocket>.from(_clients)) {
      await client.close(WebSocketStatus.normalClosure);
    }
    _clients.clear();

    await _server?.close(force: true);
    _server = null;
    _isHosting = false;
    notifyListeners();
  }

  Future<void> joinSession(String ipAddress) async {
    final trimmedIp = ipAddress.trim();
    if (trimmedIp.isEmpty) return;

    _connectedIpAddress = trimmedIp;
    _isConnected = false;
    _friendName = null;
    _lastRemoteStatus = null;
    notifyListeners();

    await _clientSocket?.close(WebSocketStatus.normalClosure);
    _clientSocket = null;

    try {
      final socket = await WebSocket.connect('ws://$trimmedIp:8080');
      _clientSocket = socket;

      socket.listen(
        (message) {
          final decoded = _decodeMessage(message);
          if (decoded == null) {
            return;
          }

          final type = decoded[_messageTypeKey];
          if (type == _timerDataType) {
            final data = decoded['data'];
            if (data is! Map<String, dynamic>) {
              return;
            }

            _lastRemoteStatus = data;
            _friendName = (data['deviceName'] as String?) ?? trimmedIp;
            _isConnected = true;
            notifyListeners();
            return;
          }

          if (type == _nudgeType) {
            _handleIncomingNudge();
            return;
          }

          if (type == _chatType) {
            final sender = decoded[_chatSenderKey];
            final text = decoded[_chatTextKey];
            if (sender is! String || text is! String) {
              return;
            }

            chatMessages.add({_chatSenderKey: sender, _chatTextKey: text});
            notifyListeners();
          }
        },
        onDone: _resetClientState,
        onError: (_) => _resetClientState(),
        cancelOnError: true,
      );
    } catch (_) {
      _resetClientState();
    }
  }

  Future<void> disconnectSession() async {
    await _clientSocket?.close(WebSocketStatus.normalClosure);
    _clientSocket = null;
    _resetClientState();
  }

  Future<void> sendNudge() async {
    final nudgePayload = jsonEncode({_messageTypeKey: _nudgeType});

    if (_isHosting) {
      for (final client in List<WebSocket>.from(_clients)) {
        try {
          client.add(nudgePayload);
        } catch (_) {
          _clients.remove(client);
        }
      }
      notifyListeners();
      return;
    }

    final socket = _clientSocket;
    if (socket == null || !_isConnected) {
      return;
    }

    try {
      socket.add(nudgePayload);
    } catch (_) {
      _resetClientState();
    }
  }

  Future<void> sendChatMessage(String text) async {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return;
    }

    final sender = _isHosting ? 'Host' : 'Peer';
    final payload = jsonEncode({
      _messageTypeKey: _chatType,
      _chatSenderKey: sender,
      _chatTextKey: trimmedText,
    });

    chatMessages.add({_chatSenderKey: sender, _chatTextKey: trimmedText});
    notifyListeners();

    if (_isHosting) {
      for (final client in List<WebSocket>.from(_clients)) {
        try {
          client.add(payload);
        } catch (_) {
          _clients.remove(client);
        }
      }
      return;
    }

    final socket = _clientSocket;
    if (socket == null || !_isConnected) {
      return;
    }

    try {
      socket.add(payload);
    } catch (_) {
      _resetClientState();
    }
  }

  void _resetClientState() {
    _connectedIpAddress = null;
    _friendName = null;
    _lastRemoteStatus = null;
    _isConnected = false;
    notifyListeners();
  }

  Future<void> _fetchLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      InternetAddress? selectedAddress;
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type != InternetAddressType.IPv4 || address.isLoopback) {
            continue;
          }

          if (_isPrivateAddress(address.address)) {
            _hostIpAddress = address.address;
            notifyListeners();
            return;
          }

          selectedAddress ??= address;
        }
      }

      if (selectedAddress != null) {
        _hostIpAddress = selectedAddress.address;
      } else {
        _hostIpAddress = 'Unable to detect LAN IP';
      }
    } catch (error) {
      debugPrint('Failed to detect local IP: $error');
      _hostIpAddress = 'Unable to detect LAN IP';
    }

    notifyListeners();
  }

  bool _isPrivateAddress(String address) {
    if (address.startsWith('10.')) {
      return true;
    }

    if (address.startsWith('192.168.')) {
      return true;
    }

    if (address.startsWith('172.')) {
      final parts = address.split('.');
      if (parts.length < 2) {
        return false;
      }

      final secondOctet = int.tryParse(parts[1]);
      return secondOctet != null && secondOctet >= 16 && secondOctet <= 31;
    }

    return false;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (WebSocketTransformer.isUpgradeRequest(request)) {
      final socket = await WebSocketTransformer.upgrade(request);
      _clients.add(socket);
      notifyListeners();

      socket.listen(
        (message) {
          final decoded = _decodeMessage(message);
          if (decoded == null) {
            return;
          }

          final type = decoded[_messageTypeKey];
          if (type == _nudgeType) {
            _handleIncomingNudge();
            return;
          }

          if (type == _chatType) {
            final sender = decoded[_chatSenderKey];
            final text = decoded[_chatTextKey];
            if (sender is! String || text is! String) {
              return;
            }

            chatMessages.add({_chatSenderKey: sender, _chatTextKey: text});

            if (message is String) {
              for (final client in List<WebSocket>.from(_clients)) {
                if (identical(client, socket)) {
                  continue;
                }

                try {
                  client.add(message);
                } catch (_) {
                  _clients.remove(client);
                }
              }
            }

            notifyListeners();
          }
        },
        onDone: () {
          _clients.remove(socket);
          notifyListeners();
        },
        onError: (_) {
          _clients.remove(socket);
          notifyListeners();
        },
        cancelOnError: true,
      );
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    request.response.write('Not Found');
    await request.response.close();
  }

  void _handleIncomingNudge() {
    if (_settingsProvider.hapticsEnabled) {
      unawaited(HapticFeedback.heavyImpact());
    }

    if (_settingsProvider.soundEnabled) {
      unawaited(_audioPlayer.play(AssetSource('audio/nudge.mp3')));
    }
  }

  void _broadcastStatus() {
    if (!_isHosting || _clients.isEmpty) {
      return;
    }

    final payload = jsonEncode({
      _messageTypeKey: _timerDataType,
      'data': _buildStatusPayload(),
    });

    for (final client in List<WebSocket>.from(_clients)) {
      try {
        client.add(payload);
      } catch (_) {
        _clients.remove(client);
      }
    }

    notifyListeners();
  }

  Map<String, dynamic>? _decodeMessage(dynamic message) {
    if (message is! String) {
      return null;
    }

    try {
      final decoded = jsonDecode(message);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _buildStatusPayload() {
    final task = _taskProvider.activeTask;

    return {
      'deviceName': Platform.localHostname,
      'timer': {
        'remainingSeconds': _timerProvider.remaining.inSeconds,
        'isRunning': _timerProvider.isRunning,
      },
      'task': {
        'title': task.title,
        'currentPhaseIndex': task.currentPhaseIndex,
        'phases': task.phases
            .map(
              (phase) => {
                'name': phase.name,
                'durationSeconds': phase.duration.inSeconds,
                'autoStartNext': phase.autoStartNext,
              },
            )
            .toList(),
      },
    };
  }

  @override
  void dispose() {
    _broadcastTimer?.cancel();
    for (final client in List<WebSocket>.from(_clients)) {
      unawaited(client.close(WebSocketStatus.normalClosure));
    }
    _server?.close(force: true);
    unawaited(_audioPlayer.dispose());
    super.dispose();
  }
}
