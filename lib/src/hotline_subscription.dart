import 'dart:convert';
import 'hotline_subscription_manager.dart';

/// The valid states for a subscription
enum HotlineSubscriptionRequestState {
  initial,
  subscribing,
  unsubscribed,
  granted,
  rejected,
  suspended
}

/// A subscription instance for handling channel-specific messages
class HotlineSubscription {
  String identifier;
  HotlineSubscriptionManager subscriptionManager;

  HotlineSubscriptionRequestState state =
      HotlineSubscriptionRequestState.initial;

  /// set the state of this subscription
  set stateType(HotlineSubscriptionRequestState type) => state = type;

  /// required subscription callbacks
  Function onReceived;
  Function onConfirmed;

  /// optional subscription callbacks
  Function? onUnsubscribed;
  Function? onRejected;

  final _SUBSCRIPTION_REQUEST_TIMEOUT = 500;

  /// when cancelled by the subscription manager no additional work is required to remove this from the pool
  var _cancelledBySubscriptionManager = false;
  set cancelledBySubscriptionManager(bool cancelled) =>
      _cancelledBySubscriptionManager = cancelled;

  HotlineSubscription(this.identifier, this.subscriptionManager,
      {required this.onReceived,
      required this.onConfirmed,
      this.onUnsubscribed,
      this.onRejected}) {
    final subscriptionParameters =
        jsonEncode({'identifier': identifier, 'command': 'subscribe'});

    /// dispatch the subscription
    _sendSubscriptionRequest(subscriptionParameters);
    stateType = HotlineSubscriptionRequestState.subscribing;

    /// if the subscription hasn't been accepted with n milliseconds, assume it's been rejected or the server has gone away
    Future.delayed(Duration(milliseconds: _SUBSCRIPTION_REQUEST_TIMEOUT), () {
      if (state != HotlineSubscriptionRequestState.granted) rejected();
    });
  }

  /// dispatch a new subscription request
  void _sendSubscriptionRequest(String payload) =>
      subscriptionManager.connection.socketChannel.sink.add(payload);

  /// called by the Hotline connection dispatcher
  void confirmed() {
    state = HotlineSubscriptionRequestState.granted;
    onConfirmed(this);
  }

  /// stop receiving messages for this channel
  void unsubscribe() {
    final callback = onUnsubscribed;
    final unsubscribeParameters = {
      'identifier': identifier,
      'command': 'unsubscribe'
    };

    state = HotlineSubscriptionRequestState.unsubscribed;
    subscriptionManager.connection.socketChannel.sink
        .add(unsubscribeParameters);

    /// ask the subscriptionManager to unsubscribe so that everything is cleaned up properly
    if (!_cancelledBySubscriptionManager) {
      subscriptionManager.unsubscribe(this);
    } else if (callback != null) {
      callback();
    }
  }

  /// the subscription request was not granted
  void rejected() {
    final callback = onRejected;
    state = HotlineSubscriptionRequestState.rejected;

    if (callback != null) {
      callback();
    }

    unsubscribe();
  }

  /// determine how to handle this response and call the relevant handler...
  void handleResponse(Map payload) {
    if (state == HotlineSubscriptionRequestState.suspended) return;

    onReceived(payload);
  }

  /// send a message to a WebSocket channel on the server to its corresponding channel [action]
  void perform(String action, [Map<String, dynamic>? params]) {
    if (state == HotlineSubscriptionRequestState.suspended) return;

    final actionParams = {'action': action, 'id': 1};

    subscriptionManager.connection.socketChannel.sink.add(jsonEncode({
      'identifier': identifier,
      'command': 'message',
      'data': jsonEncode(actionParams),
    }));
  }
}
