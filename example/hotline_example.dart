import 'package:hotline/hotline.dart';

void main() async {
  final hotline = Hotline('ws://localhost:3000/cable');
  final subscription = hotline.subscriptions.create({
    'channel': 'Turbo::StreamsChannel',
    'signed_stream_name': 'IloybGtPaTh2WVhCd0wwSmhjMnRsZEM4eCI=--635611ff87dda934376806f3dbfcdb6b724fa0cbcca9b32684c537ad8eb9390f'
  });

  /// listen for changes on the connection state...
  hotline.status.listen((state) => print('Hotline Connection State: $state'));
  /// listen for changes on the subscription state...
  subscription.status.listen((state) => print('\tSubscription State: $state'));
  /// listen for data being dispatched to the subscription...
  subscription.stream.listen((data)  => print('\t\tReceived On Stream: \n\t$data'));

  /// ActionCable.server.broadcast("Chat Room", {hello: "Chat room!"})
  /// `simpleChannel` onReceived callback will be called when subscribing
  /// to a simple channel name using `stream_from`
  /// final subscription = hotline.subscriptions.create('Chat Room');

  /// If you want to broadcast to a resource-specific channel, like this:
  /// ChatRoomChannel.broadcast_to(ChatRoom.find(1), {hello: "Chat Room 1"})
  /// then use a parameterised constructor that and pass the params into your `stream_for` method

  /*
  Hotline with callbacks
   */
  /// create a connection with the necessary callbacks
  final onConnect = (Hotline connection) => print('Connected!!!');
  final onDisconnect = () => print('Disconnected');

  final hotlineWithCallbacks = Hotline('ws://localhost:3000/cable', onConnect: onConnect, onDisconnect: onDisconnect);

  /// Create a subscription to one of your ActionCable channels
  final confirmed = (HotlineSubscription subscription) => print('Subscription Confirmed ${subscription}');
  final received = (Map data) => print('Received: $data');
  final rejected = () => print('Subscription Rejected');
  final _ = hotlineWithCallbacks.subscriptions.create({
    'channel': 'Turbo::StreamsChannel',
    'signed_stream_name': 'IloybGtPaTh2WVhCd0wwSmhjMnRsZEM4eCI=--635611ff87dda934376806f3dbfcdb6b724fa0cbcca9b32684c537ad8eb9390f'
  },
      onConfirmed: confirmed,
      onReceived: received,
      onRejected: rejected
  );

  /// Disconnect from the server
  // Future.delayed(Duration(milliseconds: 250), () {
  //   hotline.disconnect();
  //   print(hotline.connectionState.state);
  // });
  //
  // /// try to reconnect an existing connection
  // Future.delayed(Duration(milliseconds: 500), () {
  //   hotline.reconnect();
  // });
}
