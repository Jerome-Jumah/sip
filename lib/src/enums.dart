import 'package:flutter/widgets.dart';

/// Defines the direction of a communication,
/// indicating whether it is outgoing or incoming.
///
/// Used to specify the flow of calls or messages.
enum Direction {
  /// Represents an outgoing call or message.
  outgoing(name: 'outgoing'),

  /// Represents an incoming call or message.
  incoming(name: 'incoming');

  final String name;
  const Direction({required this.name});
}

// convert string from enum
String directionToString(Direction direction) {
  return direction.name;
}

Direction stringToDirection(String name) {
  debugPrint('stringToDirection: $name');
  return Direction.values.firstWhere(
    (e) => e.name.toUpperCase() == name.toUpperCase(),
  );
}

/// Identifies the originator of a communication,
/// specifying whether the initiator is local or remote.
///
/// This is useful for determining who started the call or message.
enum Originator {
  /// Represents the user of this device initiated the communication.
  local,

  /// Represents the communication was initiated by someone else.
  remote,

  /// Represents that the communication was initiated by the system (e.g., automated processes).
  system,
}

Originator stringToOriginator(String name) {
  debugPrint('stringToOriginator: $name');
  return Originator.values.firstWhere(
    (e) => e.name.toUpperCase() == name.toUpperCase(),
  );
}

/// Represents the type of SDP (Session Description Protocol) message
/// used in a communication session.
///
/// SDP messages are exchanged between peers during the setup of a media connection.
enum SdpType {
  /// Represents an SDP offer, which is the initial proposal sent to set up a media session.
  offer,

  /// Represents an SDP answer, which is the response to an SDP offer,
  /// confirming or adjusting the session parameters.
  answer,
}
