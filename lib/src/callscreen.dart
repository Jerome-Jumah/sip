import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:webrtc/src/constants.dart';
import 'package:webrtc/src/enums.dart';
import 'package:webrtc/src/screen_share_service.dart';
import 'package:webrtc/src/widgets/transfer_dialog.dart';

import 'widgets/action_button.dart';

class CallScreenWidget extends StatefulWidget {
  final SIPUAHelper? _helper;
  final Call? _call;

  const CallScreenWidget(this._helper, this._call, {super.key});

  @override
  State<CallScreenWidget> createState() => _MyCallScreenWidget();
}

class _MyCallScreenWidget extends State<CallScreenWidget>
    implements SipUaHelperListener {
  RTCVideoRenderer? _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer? _remoteRenderer = RTCVideoRenderer();
  double? _localVideoHeight;
  double? _localVideoWidth;
  EdgeInsetsGeometry? _localVideoMargin;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  bool _showNumPad = false;
  final ValueNotifier<String> _timeLabel = ValueNotifier<String>('00:00');
  bool _audioMuted = false;
  bool _videoMuted = false;
  bool _speakerOn = false;
  bool _hold = false;
  bool _mirror = true;
  Originator? _holdOriginator;
  bool _callConfirmed = false;
  CallStateEnum _state = CallStateEnum.NONE;

  late String _transferTarget;
  late Timer _timer;

  // Screen sharing additions
  final ScreenSharingService _screenSharingService = ScreenSharingService();

  RTCRtpSender? _videoSender;

  SIPUAHelper? get helper => widget._helper;

  bool get voiceOnly => call!.voiceOnly && !call!.remote_has_video;

  String? get remoteIdentity => call!.remote_identity;

  Direction? get direction => stringToDirection(call!.direction);

  Call? get call => widget._call;

  @override
  initState() {
    super.initState();
    _initRenderers();
    helper!.addSipUaHelperListener(this);
    _startTimer();

    _screenSharingService.initializeScreenRenderer();
  }

  @override
  deactivate() {
    super.deactivate();
    helper!.removeSipUaHelperListener(this);
    _disposeRenderers();
    _screenSharingService.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (Timer timer) {
      Duration duration = Duration(seconds: timer.tick);
      if (mounted) {
        _timeLabel.value = [
          duration.inMinutes,
          duration.inSeconds,
        ].map((seg) => seg.remainder(60).toString().padLeft(2, '0')).join(':');
      } else {
        _timer.cancel();
      }
    });
  }

  void _initRenderers() async {
    if (_localRenderer != null) {
      await _localRenderer!.initialize();
    }
    if (_remoteRenderer != null) {
      await _remoteRenderer!.initialize();
    }
  }

  void _disposeRenderers() {
    if (_localRenderer != null) {
      _localRenderer!.dispose();
      _localRenderer = null;
    }
    if (_remoteRenderer != null) {
      _remoteRenderer!.dispose();
      _remoteRenderer = null;
    }
  }

  @override
  void callStateChanged(Call call, CallState callState) {
    if (callState.state == CallStateEnum.HOLD ||
        callState.state == CallStateEnum.UNHOLD) {
      _hold = callState.state == CallStateEnum.HOLD;
      _holdOriginator = stringToOriginator(callState.originator!);
      setState(() {});
      return;
    }

    if (callState.state == CallStateEnum.MUTED) {
      if (callState.audio!) _audioMuted = true;
      if (callState.video!) _videoMuted = true;
      setState(() {});
      return;
    }

    if (callState.state == CallStateEnum.UNMUTED) {
      if (callState.audio!) _audioMuted = false;
      if (callState.video!) _videoMuted = false;
      setState(() {});
      return;
    }

    if (callState.state != CallStateEnum.STREAM) {
      _state = callState.state;
    }

    switch (callState.state) {
      case CallStateEnum.STREAM:
        _handleStreams(callState);
        break;
      case CallStateEnum.ENDED:
      case CallStateEnum.FAILED:
        _backToDialPad();
        break;
      case CallStateEnum.UNMUTED:
      case CallStateEnum.MUTED:
      case CallStateEnum.CONNECTING:
      case CallStateEnum.PROGRESS:
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        setState(() => _callConfirmed = true);
        break;
      case CallStateEnum.HOLD:
      case CallStateEnum.UNHOLD:
      case CallStateEnum.NONE:
      case CallStateEnum.CALL_INITIATION:
      case CallStateEnum.REFER:
        break;
    }
  }

  @override
  void transportStateChanged(TransportState state) {}

  @override
  void registrationStateChanged(RegistrationState state) {}

  void _cleanUp() {
    if (_localStream == null) return;
    _localStream?.getTracks().forEach((track) {
      track.stop();
    });
    _localStream!.dispose();
    _localStream = null;
  }

  void _backToDialPad() {
    _timer.cancel();
    Timer(Duration(seconds: 2), () {
      Navigator.of(context).pop();
    });
    _cleanUp();
  }

  void _handleStreams(CallState event) async {
    MediaStream? stream = event.stream;
    if (event.originator?.toUpperCase() ==
        Originator.local.name.toUpperCase()) {
      if (_localRenderer != null) {
        _localRenderer!.srcObject = stream;
      }
      _localStream = stream;
      // Attach sender for switching between camera/screen
      if (call?.session.connection != null) {
        final pc = call!.session.connection!;
        final senders = await pc.getSenders();
        _videoSender = senders.firstWhere((s) => s.track?.kind == 'video');
      }

      if (!kIsWeb &&
          !WebRTC.platformIsDesktop &&
          event.stream?.getAudioTracks().isNotEmpty == true) {
        event.stream?.getAudioTracks().first.enableSpeakerphone(false);
      }
      _localStream = stream;
    }
    if (event.originator?.toUpperCase() ==
        Originator.remote.name.toUpperCase()) {
      if (_remoteRenderer != null) {
        _remoteRenderer!.srcObject = stream;
      }
      _remoteStream = stream;
    }

    setState(() {
      _resizeLocalVideo();
    });
  }

  void _resizeLocalVideo() {
    _localVideoMargin = _remoteStream != null
        ? EdgeInsets.only(top: 15, right: 15)
        : EdgeInsets.all(0);
    _localVideoWidth = _remoteStream != null
        ? MediaQuery.of(context).size.width / 4
        : MediaQuery.of(context).size.width;
    _localVideoHeight = _remoteStream != null
        ? MediaQuery.of(context).size.height / 4
        : MediaQuery.of(context).size.height;
  }

  void _handleHangup() {
    call!.hangup({'status_code': 603});
    _timer.cancel();
  }

  void _handleAccept() async {
    bool remoteHasVideo = call!.remote_has_video;
    final mediaConstraints = <String, dynamic>{
      'audio': true,
      'video': remoteHasVideo
          ? {
              'mandatory': <String, dynamic>{
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '30',
              },
              'facingMode': 'user',
              'optional': <dynamic>[],
            }
          : false,
    };
    MediaStream mediaStream;

    if (kIsWeb && remoteHasVideo) {
      mediaStream = await navigator.mediaDevices.getDisplayMedia(
        mediaConstraints,
      );
      MediaStream userStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );
      mediaStream.addTrack(userStream.getAudioTracks()[0], addToNative: true);
    } else {
      if (!remoteHasVideo) {
        mediaConstraints['video'] = false;
      }
      mediaStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    }

    call!.answer(
      helper!.buildCallOptions(!remoteHasVideo),
      mediaStream: mediaStream,
    );
  }

  void _switchCamera() {
    if (_localStream != null) {
      Helper.switchCamera(_localStream!.getVideoTracks()[0]);
      setState(() {
        _mirror = !_mirror;
      });
    }
  }

  void _muteAudio() {
    if (_audioMuted) {
      call!.unmute(true, false);
    } else {
      call!.mute(true, false);
    }
  }

  void _muteVideo() {
    if (_videoMuted) {
      call!.unmute(false, true);
    } else {
      call!.mute(false, true);
    }
  }

  void _handleHold() {
    if (_hold) {
      call!.unhold();
    } else {
      call!.hold();
    }
  }

  void _handleTransfer() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TransferCallDialog(
          onTransferTarget: (String text) {
            setState(() {
              _transferTarget = text;
            });
          },
          onOk: () {
            call!.refer(_transferTarget);
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  Future<void> _toggleScreenShare() async {
    if (_screenSharingService.isScreenSharing) {
      // Stop sharing
      await _screenSharingService.stopScreenShare();

      if (_localStream != null && _videoSender != null) {
        // Restore camera video track
        final camTrack = _localStream!.getVideoTracks().first;
        await _videoSender!.replaceTrack(camTrack);

        // Restore preview
        _localRenderer?.srcObject = _localStream;
      }

      setState(() {});
    } else {
      // Start sharing
      final screenStream = await _screenSharingService.startScreenShare();
      if (screenStream != null) {
        final screenTrack = screenStream.getVideoTracks().first;

        // Bind to preview
        _localRenderer?.srcObject = screenStream;

        // Replace outgoing video track
        if (_videoSender == null && call?.session.connection != null) {
          final pc = call!.session.connection!;
          final senders = await pc.getSenders();
          _videoSender = senders.firstWhere((s) => s.track?.kind == 'video');
        }

        if (_videoSender != null) {
          await _videoSender!.replaceTrack(screenTrack);
        }

        screenStream.getVideoTracks().first.onEnded = () {
          _toggleScreenShare(); // auto revert to camera
        };
      }

      setState(() {});
    }
  }

  void _handleDtmf(String tone) {
    print('Dtmf tone => $tone');
    call!.sendDTMF(tone);
  }

  void _handleKeyPad() {
    setState(() {
      _showNumPad = !_showNumPad;
    });
  }

  void _handleVideoUpgrade() {
    if (voiceOnly) {
      setState(() {
        call!.voiceOnly = false;
      });
      helper!.renegotiate(
        call: call!,
        voiceOnly: false,
        done: (IncomingMessage? incomingMessage) {},
      );
    } else {
      helper!.renegotiate(
        call: call!,
        voiceOnly: true,
        done: (IncomingMessage? incomingMessage) {},
      );
    }
  }

  void _toggleSpeaker() {
    if (_localStream != null) {
      _speakerOn = !_speakerOn;
      if (!kIsWeb) {
        _localStream!.getAudioTracks()[0].enableSpeakerphone(_speakerOn);
      }
    }
  }

  List<Widget> _buildNumPad() {
    return labels
        .map(
          (row) => Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row
                  .map(
                    (label) => ActionButton(
                      title: label.keys.first,
                      subTitle: label.values.first,
                      onPressed: () => _handleDtmf(label.keys.first),
                      number: true,
                    ),
                  )
                  .toList(),
            ),
          ),
        )
        .toList();
  }

  Widget _buildActionButtons() {
    final hangupBtn = ActionButton(
      title: "hangup",
      onPressed: () => _handleHangup(),
      icon: Icons.call_end,
      fillColor: Colors.red,
    );

    final hangupBtnInactive = ActionButton(
      title: "hangup",
      onPressed: () {},
      icon: Icons.call_end,
      fillColor: Colors.grey,
    );

    final basicActions = <Widget>[];
    final advanceActions = <Widget>[];
    final advanceActions2 = <Widget>[];

    switch (_state) {
      case CallStateEnum.NONE:
      case CallStateEnum.CONNECTING:
        if (direction == Direction.incoming) {
          basicActions.add(
            ActionButton(
              title: "Accept",
              fillColor: Colors.green,
              icon: Icons.phone,
              onPressed: () => _handleAccept(),
            ),
          );
          basicActions.add(hangupBtn);
        } else {
          basicActions.add(hangupBtn);
        }
        break;
      case CallStateEnum.ACCEPTED:
      case CallStateEnum.CONFIRMED:
        {
          advanceActions.add(
            ActionButton(
              title: _audioMuted ? 'unmute' : 'mute',
              icon: _audioMuted ? Icons.mic_off : Icons.mic,
              checked: _audioMuted,
              onPressed: () => _muteAudio(),
            ),
          );

          if (voiceOnly) {
            advanceActions.add(
              ActionButton(
                title: "keypad",
                icon: Icons.dialpad,
                onPressed: () => _handleKeyPad(),
              ),
            );
          } else {
            advanceActions.add(
              ActionButton(
                title: "switch camera",
                icon: Icons.switch_video,
                onPressed: () => _switchCamera(),
              ),
            );
          }

          if (voiceOnly) {
            advanceActions.add(
              ActionButton(
                title: _speakerOn ? 'speaker off' : 'speaker on',
                icon: _speakerOn ? Icons.volume_off : Icons.volume_up,
                checked: _speakerOn,
                onPressed: () => _toggleSpeaker(),
              ),
            );
            advanceActions2.add(
              ActionButton(
                title: 'request video',
                icon: Icons.videocam,
                onPressed: () => _handleVideoUpgrade(),
              ),
            );
          } else {
            advanceActions.add(
              ActionButton(
                title: _videoMuted ? "camera on" : 'camera off',
                icon: _videoMuted ? Icons.videocam : Icons.videocam_off,
                checked: _videoMuted,
                onPressed: () => _muteVideo(),
              ),
            );
          }

          advanceActions2.add(
            ActionButton(
              title: _screenSharingService.isScreenSharing
                  ? 'Stop Share'
                  : 'Share',
              icon: _screenSharingService.isScreenSharing
                  ? Icons.stop_screen_share
                  : Icons.screen_share,
              checked: _screenSharingService.isScreenSharing,
              onPressed: () => _toggleScreenShare(),
            ),
          );

          basicActions.add(
            ActionButton(
              title: _hold ? 'unhold' : 'hold',
              icon: _hold ? Icons.play_arrow : Icons.pause,
              checked: _hold,
              onPressed: () => _handleHold(),
            ),
          );

          basicActions.add(hangupBtn);

          if (_showNumPad) {
            basicActions.add(
              ActionButton(
                title: "back",
                icon: Icons.keyboard_arrow_down,
                onPressed: () => _handleKeyPad(),
              ),
            );
          } else {
            basicActions.add(
              ActionButton(
                title: "transfer",
                icon: Icons.phone_forwarded,
                onPressed: () => _handleTransfer(),
              ),
            );
          }
        }
        break;
      case CallStateEnum.FAILED:
      case CallStateEnum.ENDED:
        basicActions.add(hangupBtnInactive);
        break;
      case CallStateEnum.PROGRESS:
        basicActions.add(hangupBtn);
        break;
      default:
        print('Other state => $_state');
        break;
    }

    final actionWidgets = <Widget>[];

    if (_showNumPad) {
      actionWidgets.addAll(_buildNumPad());
    } else {
      if (advanceActions2.isNotEmpty) {
        actionWidgets.add(
          Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: advanceActions2,
            ),
          ),
        );
      }
      if (advanceActions.isNotEmpty) {
        actionWidgets.add(
          Padding(
            padding: const EdgeInsets.all(3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: advanceActions,
            ),
          ),
        );
      }
    }

    actionWidgets.add(
      Padding(
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: basicActions,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.end,
      children: actionWidgets,
    );
  }

  Widget _buildContent() {
    Color? textColor = Theme.of(context).textTheme.bodyMedium?.color;
    final stackWidgets = <Widget>[];

    if (!voiceOnly && _remoteStream != null) {
      stackWidgets.add(
        Center(
          child: RTCVideoView(
            _remoteRenderer!,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      );
    }

    if (!voiceOnly && _localStream != null) {
      stackWidgets.add(
        AnimatedContainer(
          height: _localVideoHeight,
          width: _localVideoWidth,
          alignment: Alignment.topRight,
          duration: Duration(milliseconds: 300),
          margin: _localVideoMargin,
          child: RTCVideoView(
            _localRenderer!,
            mirror: _mirror,
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        ),
      );
    }
    if (voiceOnly || !_callConfirmed) {
      stackWidgets.addAll([
        Positioned(
          top: MediaQuery.of(context).size.height / 8,
          left: 0,
          right: 0,
          child: Center(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      (voiceOnly ? 'VOICE CALL' : 'VIDEO CALL') +
                          (_hold ? ' PAUSED BY ${_holdOriginator!.name}' : ''),
                      style: TextStyle(fontSize: 24, color: textColor),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      '$remoteIdentity',
                      style: TextStyle(fontSize: 18, color: textColor),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: ValueListenableBuilder<String>(
                      valueListenable: _timeLabel,
                      builder: (context, value, child) {
                        return Text(
                          _timeLabel.value,
                          style: TextStyle(fontSize: 14, color: textColor),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ]);
    }

    if (_screenSharingService.isScreenSharing &&
        _screenSharingService.screenRenderer != null) {
      stackWidgets.add(
        Positioned(
          bottom: 100,
          right: 10,
          child: SizedBox(
            height: 150,
            width: 200,
            child: RTCVideoView(_screenSharingService.screenRenderer!),
          ),
        ),
      );
    }

    return Stack(children: stackWidgets);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('[$direction] ${_state.name}'),
      ),
      body: _buildContent(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        width: 320,
        padding: EdgeInsets.only(bottom: 24.0),
        child: _buildActionButtons(),
      ),
    );
  }

  @override
  void onNewReinvite(ReInvite event) {
    if (event.accept == null) return;
    if (event.reject == null) return;
    if (voiceOnly && (event.hasVideo ?? false)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Upgrade to video?'),
            content: Text('$remoteIdentity is inviting you to video call'),
            alignment: Alignment.center,
            actionsAlignment: MainAxisAlignment.spaceBetween,
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () {
                  event.reject!.call({'status_code': 607});
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  event.accept!.call({});
                  setState(() {
                    call!.voiceOnly = false;
                    _resizeLocalVideo();
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void onNewMessage(SIPMessageRequest msg) {
    // NO OP
  }

  @override
  void onNewNotify(Notify ntf) {
    // NO OP
  }
}
