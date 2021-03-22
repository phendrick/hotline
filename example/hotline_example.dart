import 'package:hotline/hotline.dart';

void main() {
  // create a connection with the necessary callbacks
  final onConnect = (Hotline connection) => print('Connected');
  final onDisconnect = () => print('Disconnected');
  final hotline = Hotline('ws://localhost:3000/cable',
      onConnect: onConnect, onDisconnect: onDisconnect);

  // Create a subscription to one of your ActionCable channels
  final confirmed = () => print('Subscription Confirmed');
  final received = (Map data) => print('Received: $data');
  final rejected = () => print('Subscription Rejected');

  // ActionCable.server.broadcast("Chat Room", {hello: "Chat room!"})
  // `simpleChannel` onReceived callback will be called when subscribing
  // to a simple channel name using `stream_from`
  final _ = hotline.subscriptions.create('Chat Room',
      onConfirmed: confirmed, onReceived: received, onRejected: rejected);

  // If you want to broadcast to a resource-specific channel, like this:
  // ChatRoomChannel.broadcast_to(ChatRoom.find(1), {hello: "Chat Room 1"})
  // then use a parameterised constructor that and pass the params into your `stream_for` method
  final __ = hotline.subscriptions.create({'channel': 'Chat Room', 'id': 1},
      onConfirmed: confirmed, onReceived: received, onRejected: rejected);
}
