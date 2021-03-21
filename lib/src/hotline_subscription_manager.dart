import 'dart:convert';

import '../hotline.dart';
import 'hotline_subscription.dart';

class HotlineSubscriptionManager {
  List<HotlineSubscription> _subscriptions;
  Hotline connection;

  HotlineSubscriptionManager(this.connection) : _subscriptions = [];

  // create a new subscription to a channel.
  // channel is dynamic to allow for complex names when using stream_for: {"channel": "ChannelName", "param": 1}
  // and a string param for `stream_from "ChannelName"` when using ActionCable.server.broadcast("ChannelName", {payload: ...})
  HotlineSubscription create(dynamic channel, {required Function onReceived, required Function onConfirmed, Function? onUnsubscribed, Function? onRejected}) {
    final identifier = _getChannelIdentifier(channel);

    HotlineSubscription subscription = HotlineSubscription(identifier, this, onReceived: onReceived, onConfirmed: onConfirmed, onRejected: onRejected, onUnsubscribed: onUnsubscribed);
    _subscriptions.add(subscription);

    return subscription;
  }

  void unsubscribe(HotlineSubscription subscription) {
    subscription.cancelledBySubscriptionManager = true;
    subscription.unsubscribe();
    _subscriptions.remove(subscription);
  }

  List<HotlineSubscription> get subscriptions => _subscriptions;

  // to allow us to do `hotline.consumer.subscriptions[0] implement []
  // to proxy to the underlying _subscriptions list.
  operator [](int i ) => _subscriptions[i];

  // turn the channel identifier into an encoded string that ActionCable is
  // expecting to receive.
  String _getChannelIdentifier(dynamic identifier) {
    if (identifier is Map<String, dynamic>) {
      return jsonEncode(identifier);
    }else {
      return jsonEncode({"channel": identifier});
    }
  }

  // get a subscription from the collection by looking up its identifier
  HotlineSubscription? getSubscription(String identifier) {
    try {
      return subscriptions.firstWhere((subscription) => subscription.identifier == identifier);
    } catch(e) {
      return null;
    }
  }

  // return a list of all subscriptions that match a given identifier
  // allows for subscribing to a channel multiple times
  List<HotlineSubscription> getAllSubscriptions(String identifier) {
    return subscriptions.where((subscription) => subscription.identifier == identifier).toList();
  }

  // called when our 'confirmed' callback is triggered by a 'confirm_subscription' event
  void confirmSubscription(String identifier) {
    subscriptions.where((subscription) => subscription.identifier == identifier).forEach((subscription) {
      subscription.confirmed();
    });
  }
}
