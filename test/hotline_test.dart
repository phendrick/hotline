import 'package:hotline/src/hotline_connection_state.dart';
import 'package:hotline/src/hotline_subscription.dart';
import 'package:test/test.dart';
import 'package:hotline/hotline.dart';

import 'test_helpers.dart';

void main() {
  var receivedCallback = 0;

  final onConfirmedCallback = (HotlineSubscription subscription) {};
  final onReceivedCallback = (Map data) {
    receivedCallback += 1;
  };

  group('Connections', () {
    late MockHotline connection;

    setUp(() {
      connection = MockHotline(onConnect: () => {}, onDisconnect: () => {});
    });

    tearDown(() {
      connection.disconnect();
    });

    group('Connection Callbacks', () {
      test('It receives a confirmation callback', () {
        expect(connection.connectionState.state,
            HotlineSocketConnectionType.connecting);

        connection.dispatch({
          'type': 'welcome',
          'identifier': {'channel': 'Some Channel'}
        });

        expect(connection.connectionState.state,
            HotlineSocketConnectionType.connected);
      });

      test('It can be disconnected remotely', () async {
        expect(connection.connectionState.state,
            HotlineSocketConnectionType.connecting);

        connection.dispatch({
          'type': 'welcome',
          'identifier': {'channel': 'Some Channel'}
        });

        connection.dispatch({'type': 'disconnect'});

        expect(connection.connectionState.state,
            HotlineSocketConnectionType.disconnected);
      });
    });
  });

  group('Subscriptions', () {
    late MockHotline connection;

    setUp(() {
      connection = MockHotline(onConnect: () => {}, onDisconnect: () => {});
    });

    group('Subscription Callbacks', () {
      test('It creates a subscription', () {
        final _ = connection.subscriptions.create('Some Channel',
            onReceived: onReceivedCallback, onConfirmed: onConfirmedCallback);

        expect(connection.subscriptions.subscriptions.length, 1);
      });

      test('It confirms a subscription', () {
        final subscription = connection.subscriptions.create('Some Channel',
            onReceived: onReceivedCallback, onConfirmed: onConfirmedCallback);

        expect(subscription.state == HotlineSubscriptionRequestState.granted,
            false);

        connection.dispatch({
          'type': 'confirm_subscription',
          'identifier': {'channel': 'Some Channel'}
        });
        expect(subscription.state, HotlineSubscriptionRequestState.granted);
      });

      test('It receives data', () {
        receivedCallback = 0;
        final _ = connection.subscriptions.create('Some Channel',
            onConfirmed: onConfirmedCallback, onReceived: onReceivedCallback);

        connection.dispatch({
          'message': 'confirm_subscription',
          'identifier': {'channel': 'Some Channel'}
        });

        expect(receivedCallback, 1);
      });

      test('It allows for multiple subscriptions to the same channel', () {
        final _ = connection.subscriptions.create('Some Channel',
            onReceived: onReceivedCallback, onConfirmed: onConfirmedCallback);
        final __ = connection.subscriptions.create('Some Channel',
            onReceived: onReceivedCallback, onConfirmed: onConfirmedCallback);

        connection.dispatch({
          'type': 'confirm_subscription',
          'identifier': {'channel': 'Some Channel'}
        });
        connection.dispatch({
          'type': 'confirm_subscription',
          'identifier': {'channel': 'Some Channel'}
        });

        expect(connection.subscriptions.subscriptions.length, 2);
      });

      test('It doesn\t dispatch messages from suspended subscriptions', () {
        receivedCallback = 0;

        var subscription = connection.subscriptions.create('Test Channel',
            onReceived: (Map data) {
          receivedCallback += 1;
          print('received data: $data - $receivedCallback');
        }, onConfirmed: onConfirmedCallback);

        expect(subscription.state == HotlineSubscriptionRequestState.granted,
            false);

        connection.dispatch({
          'type': 'confirm_subscription',
          'identifier': {'channel': 'Test Channel'}
        });

        expect(subscription.state, HotlineSubscriptionRequestState.granted);

        subscription.suspend();

        connection.dispatch({
          'identifier': {'channel': 'Test Channel'},
          'something': 'hello'
        });

        expect(receivedCallback, 0);
      });
    });

    group('Multiple Subscriptions', () {
      test('It allows duplicate subscriptions to receive data', () {
        receivedCallback = 0;

        final _ = connection.subscriptions.create('Some Channel',
            onConfirmed: onConfirmedCallback, onReceived: onReceivedCallback);
        final __ = connection.subscriptions.create('Some Channel',
            onConfirmed: onConfirmedCallback, onReceived: onReceivedCallback);

        connection.dispatch({
          'message': 'confirm_subscription',
          'identifier': {'channel': 'Some Channel'}
        });

        expect(receivedCallback, connection.subscriptions.subscriptions.length);
      });
    });

    group('Subscription Manager', () {
      test(
          'It allows subscriptions to be unsubscribed by the subscription manager',
          () {
        final subscription = connection.subscriptions.create('Some Channel',
            onConfirmed: onConfirmedCallback, onReceived: onReceivedCallback);
        connection.dispatch({
          'message': 'confirm_subscription',
          'identifier': {'channel': 'Some Channel'}
        });

        connection.subscriptions.unsubscribe(subscription);
        expect(connection.subscriptions.subscriptions.length, 0);
      });

      test('It allows subscriptions to unsubscribe themselves', () {
        final subscription = connection.subscriptions.create('Some Channel',
            onConfirmed: onConfirmedCallback, onReceived: onReceivedCallback);
        connection.dispatch({
          'message': 'confirm_subscription',
          'identifier': {'channel': 'Some Channel'}
        });

        subscription.unsubscribe();
        expect(connection.subscriptions.subscriptions.length, 0);
      });
    });

    group('Subscription Rejections', () {
      test('It handles rejected subscriptions', () async {
        final subscription = connection.subscriptions.create('Some Channel',
            onConfirmed: onConfirmedCallback, onReceived: onReceivedCallback);
        connection.dispatch({
          'message': 'reject_subscription',
          'identifier': {'channel': 'Some Channel'}
        });

        expect(connection.subscriptions.subscriptions.length, 1);

        expect(connection.subscriptions.subscriptions.where((subscription) {
          return subscription.state ==
              HotlineSubscriptionRequestState.subscribing;
        }), [subscription]);

        // wait for subscription confirmation callback to fail and check that it is removed from the pool
        expect(
            await Future.delayed(Duration(milliseconds: 550), () {
              return connection.subscriptions.subscriptions.length;
            }),
            0);
      });

      test('It received an onRejected callback', () async {
        var callbackCount = 0;

        final _ = connection.subscriptions.create('Some Channel',
            onConfirmed: onConfirmedCallback,
            onReceived: onReceivedCallback,
            onRejected: () => callbackCount += 1);

        connection.dispatch({
          'message': 'reject_subscription',
          'identifier': {'channel': 'Some Channel'}
        });

        expect(
            await Future.delayed(
                Duration(milliseconds: 550), () => callbackCount),
            1);
      });
    });
  });
}
