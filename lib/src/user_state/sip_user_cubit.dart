import 'package:flutter/foundation.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:webrtc/src/user_state/sip_user.dart';
import "package:flutter_bloc/flutter_bloc.dart";

class SipUserCubit extends Cubit<SipUser?> {
  final SIPUAHelper sipHelper;
  SipUserCubit({required this.sipHelper}) : super(null);

  void register(SipUser user) {
    UaSettings settings = UaSettings();
    debugPrint('Registering user: $user');
    final sipUri = user.sipUri ?? '';
    final normalizedContactUri = sipUri.startsWith('sip:') ? sipUri : 'sip:$sipUri';
    settings.port = user.port;
    settings.webSocketSettings.extraHeaders = user.wsExtraHeaders ?? {};
    settings.webSocketSettings.allowBadCertificate = true;
    //settings.webSocketSettings.userAgent = 'Dart/2.8 (dart:io) for OpenSIPS.';
    settings.tcpSocketSettings.allowBadCertificate = true;
    settings.transportType = user.selectedTransport;
    settings.uri = user.sipUri;
    settings.webSocketUrl = user.wsUrl;
    settings.host = sipUri.replaceFirst(RegExp(r'^sip:'), '').split('@').last;
    settings.authorizationUser = user.authUser;
    settings.password = user.password;
    settings.displayName = user.displayName;
    settings.userAgent = 'Dart SIP Client v1.0.0';
    settings.dtmfMode = DtmfMode.RFC2833;
    settings.iceGatheringTimeout = 2000;
    settings.contact_uri = normalizedContactUri;

    emit(user);
    sipHelper.start(settings);
  }
}
