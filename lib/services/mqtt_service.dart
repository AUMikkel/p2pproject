import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  late MqttServerClient client;

  factory MQTTService() {
    return _instance;
  }

  MQTTService._internal();

  Future<void> initializeMQTT() async {
    client = MqttServerClient.withPort('myggen.mooo.com', 'mqtt_flutter_client', 8883);
    client.secure = true;
    client.logging(on: true);
    client.keepAlivePeriod = 60;
    client.onConnected = onConnected;
    client.onDisconnected = onDisconnected;
    client.onUnsubscribed = onUnsubscribed;
    client.onSubscribed = onSubscribed;
    client.onSubscribeFail = onSubscribeFail;
    client.pongCallback = pong;
    client.autoReconnect = true;
    client.onAutoReconnect = onAutoReconnect;
    client.onAutoReconnected = onAutoReconnected;

    final connMessage = MqttConnectMessage()
        .authenticateAs(dotenv.env['MQTT_USERNAME']!, dotenv.env['MQTT_PASSWORD']!)
        .withWillTopic('willtopic')
        .withWillMessage('My Will message')
        .startClean() // Non persistent session for testing
        .withWillQos(MqttQos.atLeastOnce); // Set the QoS level for the last will message

    client.connectionMessage = connMessage;

    try {
      print('Connecting');
      await client.connect();
      print('Connected successfully');
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
      print('Disconnected due to an error');
    }

    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMessage = c![0].payload as MqttPublishMessage;
      final payload = MqttPublishPayload.bytesToStringAsString(recMessage.payload.message);
      print('Received message: $payload from topic: ${c[0].topic}');
    });
  }

  // Connected callback
  void onConnected() {
    print('Connected to MQTT Server');
  }

  // Disconnected callback
  void onDisconnected() {
    print('Disconnected from MQTT Server');
  }

  // Subscribed callback
  void onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  // Subscribed failed callback
  void onSubscribeFail(String topic) {
    print('Failed to subscribe to topic: $topic');
  }

  // Unsubscribed callback
  void onUnsubscribed(String? topic) {
    print('Unsubscribed from topic: $topic');
  }

  // Ping callback
  void pong() {
    print('Ping response client callback invoked');
  }

  /// The pre auto reconnect callback
  void onAutoReconnect() {
    print('Client auto reconnection sequence will start');
  }

  /// The post auto reconnect callback
  void onAutoReconnected() {
    print('Client auto reconnection sequence has completed');
  }

  Future<void> publishMessage(String topic, String message) async {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage('Delta/$topic', MqttQos.atLeastOnce, builder.payload!);
  }
}
