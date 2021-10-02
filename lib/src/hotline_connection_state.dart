import 'dart:async';

/// The possible states for a HotlineConnectionState
enum HotlineSocketConnectionType {
  initial,
  connecting,
  connected,
  disconnected
}

/// State manager for a Hotline connection
class HotlineSocketConnectionState {
  Function? onConnect;
  Function? onDisconnect;

  // Vars for periodically check the status of the connection
  Timer? _timer;
  DateTime? _lastPing;
  HotlineSocketConnectionType state = HotlineSocketConnectionType.initial;

  // Stream controller for sending connection state events
  final StreamController<HotlineSocketConnectionType> _controller = StreamController<HotlineSocketConnectionType>();

  HotlineSocketConnectionState({required this.onConnect, required this.onDisconnect});

  /// setter to change our state and trigger additional effects such as our
  /// onConnect callback, or cancelling the health-check timer
  set stateType(HotlineSocketConnectionType type) {
    state = type;

    switch (state) {
      case HotlineSocketConnectionType.initial:
        _controller.add(HotlineSocketConnectionType.initial);
        break;
      case HotlineSocketConnectionType.connecting:
        _controller.add(HotlineSocketConnectionType.connecting);
        break;
      case HotlineSocketConnectionType.connected:
        _controller.add(HotlineSocketConnectionType.connected);
        _startTimer();
        _handleConnectedEvent();
        break;
      case HotlineSocketConnectionType.disconnected:
        _controller.add(HotlineSocketConnectionType.disconnected);
        _stopTimer();
        break;
    }
  }

  /// check whether the connection is still connected
  bool get isConnected => state == HotlineSocketConnectionType.connected;

  /// Set the latest ping time from the socket
  set lastPing(DateTime ping) => _lastPing = ping;

  /// allow for listeners on the connection state
  Stream<HotlineSocketConnectionType> get status async* {
    yield HotlineSocketConnectionType.initial;
    yield* _controller.stream;
  }

  /// periodically check the ping times to ensure we're still connected
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), _connectionHealthCheck);
  }
  
  void _stopTimer() {
    _timer?.cancel();
  }

  void _handleConnectedEvent() {
    final callback = onConnect;
    if(callback != null) {
      callback();
    }
  }

  void _connectionHealthCheck(_) {
    if (_lastPing == null) return;

    if (DateTime.now().difference(_lastPing!) > Duration(seconds: 5)) {
      final callback = onDisconnect;

      if(callback != null) {
        callback();
      }
    }
  }
}
