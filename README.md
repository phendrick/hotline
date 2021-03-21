# Hotline
Create connections to an ActionCable server with an ActionCable-like subscriptions API. 

## Dart example

```dart
void main() {
  // create a connection with the necessary callbacks 
  final onConnect = (Hotline connection) => print('Connected');
  final onDisconnect = () => print('Disconnected');
  Hotline hotline = Hotline('ws://localhost:3000/cable', 
      onConnect: onConnect, 
      onDisconnect: onDisconnect
  );

  // Create a subscription to one of your ActionCable channels
  final confirmed = (HotlineSubscription subscription) => print('Subscription Confirmed');
  final received  = (Map data) => print('Received: $data');
  final rejected  = () => print('Subscription Rejected');

  // ActionCable.server.broadcast("Chat Room", {hello: "Chat room!"})
  // `simpleChannel` onReceived callback will be called when subscribing
  // to a simple channel name using `stream_from`
  HotlineSubscription simpleChannel = hotline.subscriptions.create(
    'Chat Room', 
    onConfirmed: confirmed, 
    onReceived: received,
    onRejected: rejected
  );

  // If you want to broadcast to a resource-specific channel, like this:
  // ChatRoomChannel.broadcast_to(ChatRoom.find(1), {hello: "Chat Room 1"})
  // then use a parameterised constructor that and pass the params into your `stream_for` method 
  HotlineSubscription resourceChannel = hotline.subscriptions.create(
    {'channel': 'Chat Room', 'id': 1}, 
    onConfirmed: confirmed, 
    onReceived: received,
    onRejected: rejected
  );
}
```

## Flutter
It's easy to use Hotline in a Flutter app; simply instantiate your Hotline connection in an initState, along with your channel subscriptions and then, in an `onReceived` subscription callback, call `updateState(...)`

## Flutter + Bloc
For a more comprehensive integration, it's possible to use Blocs. 

Create your `HotlineConnectionBloc`, `HotlineConnectionEvent` and `HotlineConnectionState` classes, something like: 

## The connection bloc

### Events

```dart
// We need to pass parameters to some of our events, so define an abstract class to implement
abstract class HotlineConnectionEvent {}
```

```dart
// initialising a connection
class HotlineConnectionInitialiseConnection extends HotlineConnectionEvent {
  String url;
  Function onConnect;
  Function onDisconnect;

  HotlineConnectionInitialiseConnection(
    this.url, {this.onConnect, this.onDisconnect}
  );
}
```

```dart
// successfully connected
class HotlineConnectionDidConnect extends HotlineConnectionEvent {
  Hotline connection;
  HotlineConnectionDidConnect(this.connection);
}
```

### States

```dart
// As with events, our States require parameterising so 
// define an abstract class that we can sub-class
abstract class HotlineConnectionState extends Equatable {
  @override
  List<Object> get props => [];
}
```

```dart
// Default initial state
class HotlineConnectionInitialState extends HotlineConnectionState {}
```

```dart
// Connecting state - requires the params & callbacks to initialise connection
class HotlineConnectionConnecting extends HotlineConnectionState {
  late final Hotline connection;

  late final Function? onConnected;
  late final Function? onDisconnected;

  HotlineConnectionConnecting(url, {this.onConnected, this.onDisconnected}) {
    this.connection = Hotline(url,
      onConnect: this.onConnected,
      onDisconnect: this.onDisconnected
    );
  }
}
```

```dart
// Connection succeeded
class HotlineConnectionConnected extends HotlineConnectionState {}
```

### And finally, the bloc
```dart
class HotlineConnectionBloc extends Bloc<HotlineConnectionEvent, HotlineConnectionState> {
  Hotline? connection;

  HotlineConnectionBloc(HotlineConnectionState state) : super(state);

  @override
  Stream<HotlineConnectionState> mapEventToState(HotlineConnectionEvent event) async* {
    if(event is HotlineConnectionInitialiseConnection) {
      yield HotlineConnectionConnecting(event.url, onConnected: event.onConnected);
    }else if(event is HotlineConnectionDidConnect) {
      this.connection = event.connection;
      yield HotlineConnectionConnected();
    }
  }
}
```

## Next, the subscription bloc...

### Events 
```dart
abstract class HotlineSubscriptionEvent {}
```

```dart
class HotlineSubscriptionRequest extends HotlineSubscriptionEvent {
  Hotline connection;
  dynamic channel;
  Map<String, Function>? channelCallbacks;

  HotlineSubscriptionRequest(this.connection, this.channel, {this.channelCallbacks});
}
```

```dart
class HotlineSubscriptionSucceeded extends HotlineSubscriptionEvent {
  HotlineSubscription subscription;
  HotlineSubscriptionSucceeded(this.subscription);
}
```

### States
```dart
abstract class HotlineSubscriptionState extends Equatable {
  @override
  List<Object> get props => [];
}
```

```dart
// Default initial state
class HotlineSubscriptionInitialState extends HotlineSubscriptionState {}
```

```dart
// A HotlineSubscriptionSubscribing state requires all 
// the params to be passed to hotline.subscriptions.create(...)
class HotlineSubscriptionSubscribing extends HotlineSubscriptionState {
  late final HotlineSubscription subscription;

  final Hotline connection;
  final dynamic channel;
  final Map<String, Function>? channelCallbacks;

  HotlineSubscriptionSubscribing(this.connection, this.channel, {this.channelCallbacks}) {
    this.subscription = this.connection.subscriptions.create(this.channel, this.channelCallbacks);
  }
}
```

```dart
class HotlineSubscriptionGranted extends HotlineSubscriptionState {
}

class HotlineSubscriptionRejected extends HotlineSubscriptionState {
}
```

And then the subscription bloc:

```dart
class HotlineSubscriptionBloc extends Bloc<HotlineSubscriptionEvent, HotlineSubscriptionState> {
  HotlineSubscription? subscription;

  HotlineSubscriptionBloc(HotlineSubscriptionState state) : super(state);

  @override
  Stream<HotlineSubscriptionState> mapEventToState(HotlineSubscriptionEvent event) async* {
    if(event is HotlineSubscriptionRequest) {
      yield HotlineSubscriptionSubscribing(...);
    }else if(event is HotlineSubscriptionSucceeded) {
      yield HotlineSubscriptionGranted();
    }
  }
}
```

```dart
  BlocProvider(
    create: (context) => HotlineConnectionBloc(HotlineConnectionInitialState()),
    child: HotlineConnectionView()
  )
```

### In a HotlineConnectionView stateful widget...
```dart
class _HotlineConnectionViewState extends State<HotlineConnectionView> {
  @override
  void initState() {
    context.read<HotlineConnectionBloc>().add(
      HotlineConnectionInitialiseConnection('ws://localhost:3000/cable', onConnected: _onConnected)
    );

    super.initState();
  }

  void _onConnected(Hotline connection) {
    context.read<HotlineConnectionBloc>().add(HotlineConnectionDidConnect(connection));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Column(
        children: [
          Text('HotlineConnectedView - ${context.read<HotlineConnectionBloc>().state}'),
          Divider(color: Colors.black),

          if(context.read<HotlineConnectionBloc>().state is HotlineConnectionConnected)
          HotlineSubscriptionsView()
        ],
      )
    );
  }
}
```

If the bloc state is `HotlineConnectionConnected`, we render another stateful widget: `HotlineSubscriptionsView`...

```dart
class _HotlineSubscriptionsViewState extends State<HotlineSubscriptionsView> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(10),
      color: Colors.blue,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Text('HotlineConnection: ${context.read<HotlineConnectionBloc>().state}'),
            Divider(color: Colors.black26),

            BlocProvider(
              create: (context) => HotlineSubscriptionBloc(HotlineSubscriptionInitialState()),
              child: Container(
                color: Colors.green,
                child: HotlineSubscriber(channel: {"channel": "Chat Room", "id": 1})
              )
            )
          ],
        ),
      ),
    );
  }
}
```

and finally, the `HotlineSubscriber` stateful widget...

```dart
class _HotlineSubscriberState extends State<HotlineSubscriber> {
  Map<String, dynamic> _json = {};
  String lastMessage = '';

  void _onConfirmed(HotlineSubscription subscription) {
    context.read<HotlineSubscriptionBloc>().add(HotlineSubscriptionSucceeded(subscription));
  }

  void _onReceived(data) {
    _json = (data as Map<String, dynamic>);

    setState(() {
      lastMessage = jsonEncode(_json['message']);
    });
  }
  
  void _onUnsubscribed() {
  }
  
  void _onRejected() {
  } 
  
  @override
  void initState() {
    final channelIdentifier = this.widget.channel;

    context.read<HotlineSubscriptionBloc>().add(
      HotlineSubscriptionRequest(
        context.read<HotlineConnectionBloc>().connection!, 
        channelIdentifier, 
        onReceived: _onReceived, 
        onConfirmed: _onConfirmed, 
        onUnsubscribed: _onUnsubscribed, 
        onRejected: _onRejected 
      )
    );

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HotlineSubscriptionBloc, HotlineSubscriptionState>(
      builder: (BuildContext context, HotlineSubscriptionState state) {
        return Column(
          children: [
            Text('channel ${this.widget.channel}'),
            Text('${context.read<HotlineSubscriptionBloc>().state}: $lastMessage'),
          ],
        );
      },
    );
  }
}
```

## Thanks
Hotline borrows some implementation from [ActionCable in Dart] by [https://github.com/namiwang]

[ActionCable in Dart]: https://pub.dev/packages/action_cable
[https://github.com/namiwang]: https://github.com/namiwang
