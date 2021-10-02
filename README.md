# Hotline
Create connections to an ActionCable server with an ActionCable-like subscriptions API. 

## Dart example

```dart
void main() {
  // Create a connection to an ActionCable server
  final hotline = Hotline('ws://localhost:3000/cable');

  // Next, subscribe to a channel
  // ActionCable.server.broadcast("Example Channel", {hello: "Chat room!"})
  // `simpleChannel` onReceived callback will be called when subscribing
  // to a simple channel name using `stream_from`
  final subscription = hotline.subscriptions.create('Example Channel');

  // If you want to broadcast to a resource-specific channel, like this:
  // ChatRoomChannel.broadcast_to(ChatRoom.find(1), {hello: "Chat Room 1"})
  // then use a parameterised constructor that and pass the params into your `stream_for` method
  final subscription = hotline.subscriptions.create({'channel': 'Chat Room', 'id': 1});

  // Or even a Turbo Stream
  final subscription = hotline.subscriptions.create({
    'channel': 'Turbo::StreamsChannel',
    'signed_stream_name': 'IloybGtPaTh2WVhCd0wwSmhjMnRsZEM4eCI=--635611ff87dda934376806f3dbfcdb6b724fa0cbcca9b32684c537ad8eb9390f'
  });

  // Finally, you can listen for the various changes on the connection and the channel itself...
  hotline.status.listen((state) => print('Hotline Connection State: $state'));
  subscription.status.listen((state) => print('Subscription State: $state'));
  subscription.stream.listen((data)  => print('Received On Stream: $data'));
}
```

## Dart example using callbacks rather than streams

```dart
void main() {
  // create a connection with the necessary callbacks 
  final onConnect = (Hotline connection) => print('Hotline Connection State: Connected');
  final onDisconnect = () => print('Hotline Connection State: Disconnected');
  Hotline hotline = Hotline('ws://localhost:3000/cable',
      onConnect: onConnect,
      onDisconnect: onDisconnect
  );

  // Create a subscription to one of your ActionCable channels
  final confirmed = (HotlineSubscription subscription) => print('Subscription State: Confirmed');
  final received  = (Map data) => print('Received On Stream: $data');
  final rejected  = () => print('Subscription State: Rejected');

  // ActionCable.server.broadcast("Example Channel", {hello: "Chat room!"})
  // `simpleChannel` onReceived callback will be called when subscribing
  // to a simple channel name using `stream_from`
  HotlineSubscription simpleChannel = hotline.subscriptions.create(
      'Example Channel',
      onConfirmed: confirmed,
      onReceived: received,
      onRejected: rejected
  );

  // If you want to broadcast to a resource-specific channel, like this:
  // ChatRoomChannel.broadcast_to(ChatRoom.find(1), {hello: "Chat Room 1"})
  // then use a parameterised constructor and pass the params into your `stream_for` method 
  HotlineSubscription resourceChannel = hotline.subscriptions.create(
      {'channel': 'Chat Room', 'id': 1},
      onConfirmed: confirmed,
      onReceived: received,
      onRejected: rejected
  );
}
```

## Flutter

### It's recommended that you use the stream-based interface, with StreamBuilder widgets. 

```dart
// Create the container widget for instantiating our connection
class HotlineConnectionView extends StatefulWidget {
  final hotline = Hotline('ws://localhost:3000/cable');

  HotlineConnectionView({Key? key}) : super(key: key);

  @override
  State<HotlineConnectionView> createState() => _HotlineConnectionViewState();
}

class _HotlineConnectionViewState extends State<HotlineConnectionView> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: this.widget.hotline.status,
      builder: (BuildContext context, AsyncSnapshot<HotlineSocketConnectionType> snapshot) {
        if(snapshot.data == HotlineSocketConnectionType.connecting) {
          // whilst we're waiting for HotlineSocketConnectionType.connected, show a spinner
          return CircularProgressIndicator();
        }else if(HotlineSocketConnectionType.connected) {
          // if we're here, we can render the HotlineSubscriptionView for the channel 
          // we want to subscribe to, and pass the hotline instance along with it
          return HotlineSubscriptionView({'channel': 'Chat Room', 'id': 1}, this.widget.hotline);
        }else {
          return Text('Not connected');
        }
      }
    );
  }
}

// A widget for creating a HotlineSubscription to the given channel
class HotlineSubscriptionView extends StatefulWidget {
  late final HotlineSubscription subscription;
  HotlineSubscriptionView(Map<String, String> channel, Hotline connection) : subscription = connection.subscriptions.create(channel);

  @override
  _HotlineSubscriptionViewState createState() => _HotlineSubscriptionViewState();
}

class _HotlineSubscriptionViewState extends State<HotlineSubscriptionView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          // StreamBuilder to show the current connection status to the channel
          StreamBuilder(
            stream: this.widget.subscription.status,
            builder: (BuildContext context, AsyncSnapshot<HotlineSubscriptionRequestState> snapshot) {
              return Text('Subscription Status: ${snapshot.data}');
            },
          ),
          // Another StreamBuilder, this time to render data as it comes down the wire
          StreamBuilder(
            stream: this.widget.subscription.stream,
            builder: (BuildContext context, AsyncSnapshot<Map> snapshot) {
              return Text('Data: ${snapshot.data}');
            },
          ),
        ],
      )
    );
  }
}
```

## Thanks
Hotline borrows some implementation from [ActionCable in Dart] by [https://github.com/namiwang]

[ActionCable in Dart]: https://pub.dev/packages/action_cable
[https://github.com/namiwang]: https://github.com/namiwang
