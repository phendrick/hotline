library hotline;

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';

import 'hotline_subscription_manager.dart';
import 'hotline_connection_state.dart';

/// Hotline - an ActionCable-like API to subscribe to ActionCable channels
class Hotline {
  String url;

  /// health-check manager
  late HotlineSocketConnectionState connectionState;
  late StreamSubscription stream;
  late final HotlineSubscriptionManager subscriptions;

  Iterable<String>? protocols;
  Map<String, String>? headers;

  // WebSocket connection callbacks
  Function? onConnect;
  Function? onDisconnect;
  Duration? pingInterval;
  Function? onConnectionRefused;

  // the wrapped socket channel
  late IOWebSocketChannel socketChannel;

  Hotline(this.url, {
        this.onConnect,
        this.onDisconnect,
        this.headers,
        this.protocols,
        this.pingInterval,
        this.onConnectionRefused
      })
  {
    connectionState = HotlineSocketConnectionState(onConnect: _onConnect, onDisconnect: _onDisconnect);
    connectionState.stateType = HotlineSocketConnectionType.connecting;

    _startWebSocketListener();

    /// initialise the subscription manager for this connection
    subscriptions = HotlineSubscriptionManager(this);
  }

  /// allow for listeners on the connection state stream
  Stream<HotlineSocketConnectionType> get status => connectionState.status;

  void reconnect() {
    IOWebSocketChannel.connect(
        url,
        protocols: protocols,
        headers: headers,
        pingInterval: pingInterval
    );
    connectionState = HotlineSocketConnectionState(
        onConnect: _onConnect,
        onDisconnect: _onDisconnect
    );

    connectionState.stateType = HotlineSocketConnectionType.connecting;

    _startWebSocketListener();

    subscriptions.unsuspendAll();
  }

  void _startWebSocketListener() {
    socketChannel = IOWebSocketChannel.connect(
        url,
        protocols: protocols,
        headers: headers,
        pingInterval: pingInterval
    );

    stream = socketChannel.stream.listen((data) {
      final payload = jsonDecode(data);

      if (payload['type'] != null) {
        // if the payload has a type attribute we can assume it's a protocol message
        _dispatchProtocolMessage(payload);
      } else {
        // handle the broadcast....
        _dispatchDataMessage(payload);
      }
    }, onError: (_) {
      _onDisconnect();
    });
  }

  void _onConnect() {
    final callback = onConnect;

    if(callback != null) {
      callback(this);
    }
  }

  void _onDisconnect() {
    final callback = onDisconnect;

    connectionState.stateType = HotlineSocketConnectionType.disconnected;

    if (connectionState.isConnected) {
      socketChannel.sink.close();
    }

    stream.cancel();

    if(callback != null) {
      callback();
    }
  }

  /// connection response dispatcher.
  void _dispatchProtocolMessage(Map payload) {
    switch (payload['type']) {
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

        if (callback != null) {
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

  void suspend() {
    subscriptions.suspendAll();
  }

  void disconnect() {
    connectionState.stateType = HotlineSocketConnectionType.disconnected;
    socketChannel.sink.close();
  }
}
