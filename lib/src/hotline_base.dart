library hotline;

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';

import 'hotline_subscription_manager.dart';

enum HotlineSocketConnectionType {
  initial, connecting, connected, disconnected
}

class HotlineSocketConnectionState {
  Function onConnect;
  Function onDisconnect;

  late Timer _timer;
  late DateTime? _lastPing;
  HotlineSocketConnectionType state = HotlineSocketConnectionType.initial;

  HotlineSocketConnectionState({required this.onConnect, required this.onDisconnect});

  // setter to change our state and trigger additional effects such as our
  // onConnect callback, or cancelling the health-check timer
  set stateType(HotlineSocketConnectionType type) {
    state = type;

    switch(state) {
      case HotlineSocketConnectionType.initial:
        break;
      case HotlineSocketConnectionType.connecting:
        break;
      case HotlineSocketConnectionType.connected:
        onConnect();
        startTimer();
        break;
      case HotlineSocketConnectionType.disconnected:
        _timer.cancel();
        break;
    }
  }

  set lastPing(DateTime ping) => _lastPing = ping;

  // periodically check the ping times to ensure we're still connected
  void startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), _connectionHealthCheck);
  }

  void _connectionHealthCheck(_) {
    if(_lastPing == null) return;

    if(DateTime.now().difference(_lastPing!) > Duration(seconds: 5)) {
      onDisconnect();
    }
  }
}

// Hotline - an ActionCable-like API to subscribe to ActionCable channels
class Hotline {
  // healthcheck manager
  late final HotlineSocketConnectionState connectionState;

  String url;
  late final StreamSubscription stream;

  late final HotlineSubscriptionManager subscriptions;

  Iterable<String>? protocols;
  Map<String, String>? headers;

  // websocket connection callbacks
  Function onConnect;
  Function onDisconnect;
  Duration? pingInterval;
  Function? onConnectionRefused;

  // the wrapped socket channel
  late final IOWebSocketChannel socketChannel;

  Hotline(this.url, {required this.onConnect, required this.onDisconnect, this.headers, this.protocols, this.pingInterval, this.onConnectionRefused}) {
    socketChannel   = IOWebSocketChannel.connect(url);
    connectionState = HotlineSocketConnectionState(onConnect: _onConnect, onDisconnect: _onDisconnect);
    connectionState.stateType = HotlineSocketConnectionType.connecting;

    stream = socketChannel.stream.listen((data) {
      final payload = jsonDecode(data);

      if(payload['type'] != null) {
        // if the payload has a type attribute we can assume it's a protocol message
        _dispatchProtocolMessage(payload);
      }else {
        // handle the broadcast....
        _dispatchDataMessage(payload);
      }
    }, onError: (_)  {
      _onDisconnect();
    });

    // initialise the subscription manager for this connection
    subscriptions = HotlineSubscriptionManager(this);
  }

  void _onConnect() {
    onConnect(this);
  }

  void _onDisconnect() {
    socketChannel.sink.close();
    stream.cancel();

    onDisconnect();
  }

  // connection response dispatcher.
  void _dispatchProtocolMessage(Map payload) {
    switch(payload['type']) {
      case 'welcome':
        connectionState.stateType = HotlineSocketConnectionType.connected;
        break;
      case 'disconnect':
        connectionState.stateType = HotlineSocketConnectionType.disconnected;
        break;
      case 'confirm_subscription':
        subscriptions.confirmSubscription(payload['identifier']);
        break;
      case 'reject_subscription':
        final callback = onConnectionRefused;

        if(callback != null) {
          callback();
        }
        break;
      case 'ping':
        connectionState.lastPing = DateTime.fromMillisecondsSinceEpoch(payload['message'] * 1000);
        break;
    }
  }

  void _dispatchDataMessage(Map payload) {
    // get our subscription from the subscription manager and
    // pass the payload on to it...
    final allSubscriptions = subscriptions.getAllSubscriptions(payload['identifier']);
    allSubscriptions.forEach((subscription) => subscription.handleResponse(payload));
  }

  void disconnect() {
    connectionState.stateType = HotlineSocketConnectionType.disconnected;
  }
}
