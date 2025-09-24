import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ScreenSharingService {
  MediaStream? _screenStream;
  RTCVideoRenderer? _screenRenderer;
  bool _isScreenSharing = false;

  bool get isScreenSharing => _isScreenSharing;
  MediaStream? get screenStream => _screenStream;
  RTCVideoRenderer? get screenRenderer => _screenRenderer;

  Future<void> initializeScreenRenderer() async {
    _screenRenderer = RTCVideoRenderer();
    await _screenRenderer!.initialize();
  }

  Future<MediaStream?> startScreenShare() async {
    try {
      if (kIsWeb) {
        // Web implementation
        _screenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': true,
          'audio': true, // Include system audio if needed
        });
      } else {
        // Mobile implementation
        _screenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': {
            'deviceId': 'screen',
            'mandatory': {
              'minWidth': 1280,
              'minHeight': 720,
              'maxWidth': 1920,
              'maxHeight': 1080,
            },
          },
        });
      }

      if (_screenStream != null && _screenRenderer != null) {
        _screenRenderer!.srcObject = _screenStream;
        _isScreenSharing = true;
      }

      return _screenStream;
    } catch (e) {
      debugPrint('Screen sharing error: $e');
      return null;
    }
  }

  Future<void> stopScreenShare() async {
    if (_screenStream != null) {
      _screenStream!.getTracks().forEach((track) {
        track.stop();
      });
      _screenStream = null;
    }

    if (_screenRenderer != null) {
      _screenRenderer!.srcObject = null;
    }

    _isScreenSharing = false;
  }

  void dispose() {
    stopScreenShare();
    _screenRenderer?.dispose();
  }
}
