import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class ScreenSharingService {
  static const MethodChannel _projectionChannel = MethodChannel('media_projection');

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
        _screenStream = await navigator.mediaDevices.getDisplayMedia({'video': true, 'audio': true});
      } else {
        if (WebRTC.platformIsAndroid) {
          final granted = await Helper.requestCapturePermission();
          if (!granted) {
            debugPrint('Screen sharing permission denied.');
            return null;
          }

          await _projectionChannel.invokeMethod<void>('startProjectionService');
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }

        _screenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': {'mediaSource': 'screen'},
          'audio': false,
        });
      }

      if (_screenStream != null && _screenRenderer != null) {
        _screenRenderer!.srcObject = _screenStream;
        _isScreenSharing = true;
      }

      return _screenStream;
    } catch (e) {
      debugPrint('Screen sharing error: $e');
      await _stopProjectionService();
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
    await _stopProjectionService();
  }

  void dispose() {
    stopScreenShare();
    _screenRenderer?.dispose();
  }

  Future<void> _stopProjectionService() async {
    if (kIsWeb || !WebRTC.platformIsAndroid) return;

    try {
      await _projectionChannel.invokeMethod<void>('stopProjectionService');
    } catch (e) {
      debugPrint('Failed to stop screen sharing service: $e');
    }
  }
}
