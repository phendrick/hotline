import 'dart:convert';

import 'package:hotline/hotline.dart';

/// Manages the subscriptions for a connection
class HotlineSubscriptionManager {
  final List<HotlineSubscription> _subscriptions;
  Hotline connection;

  HotlineSubscriptionManager(this.connection) : _subscriptions = [];

  /// Create a new subscription to a channel, using a dynamic [channel] type to allow for simple String subscriptions or complex channels with parameters.
  ///
  /// If using stream_for, with resource specific channels use `{'channel': 'ChannelName', 'param': 1}`
  /// alternatively if you're broadcasting via ActionCable.server.broadcast('ChannelName', {payload: ...}) and `stream_from 'ChannelName'` [channel] should be a string
  HotlineSubscription create(dynamic channel, {required Function onReceived, required Function onConfirmed, Function? onUnsubscribed, Function? onRejected}) {
    final identifier = _getChannelIdentifier(channel);

    final subscription = HotlineSubscription(identifier, this, onReceived: onReceived, onConfirmed: onConfirmed, onRejected: onRejected, onUnsubscribed: onUnsubscribed);
    _subscriptions.add(subscription);

    return subscription;
  }

  /// Unsubscribe from the messaging for a given channel
  void unsubscribe(HotlineSubscription subscription) {
    subscription.cancelledBySubscriptionManager = true;
    subscription.unsubscribe();
    _subscriptions.remove(subscription);
  }

  List<HotlineSubscription> get subscriptions => _subscriptions;

  /// allow for `hotline.consumer.subscriptions[0]`
  HotlineSubscription operator [](int i ) => _subscriptions[i];

  /// turn the channel identifier into an encoded string that ActionCable is expecting
  String _getChannelIdentifier(dynamic identifier) {
    if (identifier is Map<String, dynamic>) {
      return jsonEncode(identifier);
    }else {
      return jsonEncode({'channel': identifier});
    }
  }

  /// Find a subscription from the collection by looking up its identifier
  HotlineSubscription? getSubscription(String identifier) {
    try {
      return subscriptions.firstWhere((subscription) => subscription.identifier == identifier);
    } catch(e) {
      return null;
    }
  }

  /// return a list of all subscriptions that match a given [identifier]
  ///
  /// allows for subscribing to a channel multiple times
  List<HotlineSubscription> getAllSubscriptions(String identifier) {
    return subscriptions.where((subscription) => subscription.identifier == identifier).toList();
  }

  /// called when our `confirmed` callback is triggered by a 'confirm_subscription' event
  void confirmSubscription(String identifier) {
    subscriptions.where((subscription) => subscription.identifier == identifier).forEach((subscription) {
      subscription.confirmed();
    });
  }
}
