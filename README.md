# Flutter SIP UA Client

Simple Flutter client for testing SIP-over-WebSocket calls against the FreeSWITCH/WebRTC signaling hub.

The app uses:

- `sip_ua` for SIP registration, INVITE, ACK, BYE, and SIP-over-WS transport.
- `flutter_webrtc` for local/remote media streams, camera, microphone, and screen sharing.
- The local signaling hub as the SIP-over-WebSocket endpoint.

## Local Setup

Clone and start the signaling hub first:

```sh
git clone https://github.com/Jerome-Jumah/free-switch-webrtc.git
cd free-switch-webrtc
npm install
npm run dev
```

Hub repo: [Jerome-Jumah/free-switch-webrtc](https://github.com/Jerome-Jumah/free-switch-webrtc)

Then run this Flutter app:

```sh
cd /Users/quing/projects/sip
flutter run
```

## Registration Settings

For local testing against the hub, use:

- WebSocket: `ws://localhost:4500/`
- SIP URI: `sip:1001@localhost:4500`
- Transport: `WS`
- Password: leave empty unless the hub is changed to enforce auth

For a physical phone on the same network, replace `localhost` with the computer LAN IP, for example:

- WebSocket: `ws://192.168.1.5:4500/`
- SIP URI: `sip:1004@192.168.1.5:4500`

Use `wss://` with a valid certificate for production or remote/mobile network testing.

## Calling

Web to Flutter:

1. Register the web client in the hub UI.
2. Register this Flutter client with a different extension.
3. Dial the Flutter extension from the web UI.
4. Accept on mobile.

Flutter to web:

1. Register both clients.
2. In the Flutter dial pad, enter the web SIP URI or extension, for example `sip:1001@192.168.1.5:4500`.
3. Start an audio or video call.
4. Accept on the web UI.

## Notes

- The hub expects SIP-native clients to include ICE candidates inside SDP. This app sets a longer SIP UA ICE gathering timeout for that reason.
- The web client uses JSON signaling internally, and the hub translates between JSON WebRTC messages and SIP-over-WS messages.
- After a call ends, keep the current SIP registration active. Avoid forced unregister/re-register loops unless the transport actually disconnected.

## Troubleshooting

- If only local video appears, check that both clients are on reachable network addresses and that the SDP contains ICE candidates.
- If the hub cannot see the Flutter app after hangup, fully restart the app and register again. The app should not auto re-register after every ended call.
- If Android/iOS cannot connect to `localhost`, use the computer LAN IP instead.
- If browser media fails, make sure the web UI is opened from a secure context when required by the browser.
