import 'dart:convert';

import 'package:mockito/mockito.dart';

import 'package:hotline/hotline.dart';
import 'package:hotline/src/hotline_subscription_manager.dart';
import 'package:web_socket_channel/io.dart';


class MockHotline extends Mock implements Hotline {
  @override
  late final HotlineSocketConnectionState connectionState;

  late HotlineSubscriptionManager subscriptions;
  IOWebSocketChannel socketChannel = IOWebSocketChannel.connect('ws://localhost');

  Function onConnect;
  Function onDisconnect;

  MockHotline({required this.onConnect, required this.onDisconnect}) {
    subscriptions = HotlineSubscriptionManager(this);
    connectionState = HotlineSocketConnectionState(onConnect: onConnect, onDisconnect: onDisconnect);
    connectionState.stateType = HotlineSocketConnectionType.connecting;
  }

  void dispatch(Map payload) {
    if(payload['type'] == null) {
      subscriptions.getAllSubscriptions(jsonEncode(payload['identifier'])).forEach((subscription) {
        subscription.handleResponse(payload);
      });
    }else {
      switch(payload['type']) {
        case "welcome":
          this._onConnect();
          break;
        case "disconnect":
          this._onDisconnect();
          break;
        case "confirm_subscription":
          subscriptions.confirmSubscription(jsonEncode(payload["identifier"]));
          break;
        case "reject_subscription":
          final callback = this.onConnectionRefused;
          if(callback != null) {
            callback();
          }
          break;
      }
    }
  }

  void _onConnect() {
    connectionState.stateType = HotlineSocketConnectionType.connected;
    onConnect();
  }

  void _onDisconnect() {
    connectionState.stateType = HotlineSocketConnectionType.disconnected;
    onDisconnect();
  }

  void disconnect() {
    connectionState.stateType = HotlineSocketConnectionType.disconnected;
  }
}
