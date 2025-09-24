import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';
import 'package:sip_ua/sip_ua.dart';
import 'package:webrtc/src/about.dart';
import 'package:webrtc/src/callscreen.dart';
import 'package:webrtc/src/dialpad.dart';
import 'package:webrtc/src/register.dart';
import 'package:webrtc/src/theme_provider.dart';
import 'package:webrtc/src/user_state/sip_user_cubit.dart';

void main() {
  Logger.level = Level.warning;
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => ThemeProvider())],
      child: MyApp(),
    ),
  );
}

typedef PageContentBuilder =
    Widget Function([SIPUAHelper? helper, Object? arguments]);

// ignore: must_be_immutable
class MyApp extends StatelessWidget {
  final SIPUAHelper _helper = SIPUAHelper();
  Map<String, PageContentBuilder> routes = {
    '/': ([SIPUAHelper? helper, Object? arguments]) => DialPadWidget(helper),
    '/register': ([SIPUAHelper? helper, Object? arguments]) =>
        RegisterWidget(helper),
    '/callscreen': ([SIPUAHelper? helper, Object? arguments]) =>
        CallScreenWidget(helper, arguments as Call?),
    '/about': ([SIPUAHelper? helper, Object? arguments]) => AboutWidget(),
  };

  MyApp({super.key});

  Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final String? name = settings.name;
    final PageContentBuilder? pageContentBuilder = routes[name!];
    if (pageContentBuilder != null) {
      if (settings.arguments != null) {
        final Route route = MaterialPageRoute<Widget>(
          builder: (context) => pageContentBuilder(_helper, settings.arguments),
        );
        return route;
      } else {
        final Route route = MaterialPageRoute<Widget>(
          builder: (context) => pageContentBuilder(_helper),
        );
        return route;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SIPUAHelper>.value(value: _helper),
        Provider<SipUserCubit>(
          create: (context) => SipUserCubit(sipHelper: _helper),
        ),
      ],
      child: MaterialApp(
        title: 'Flutter Demo',
        theme: Provider.of<ThemeProvider>(context).currentTheme,
        initialRoute: '/',
        onGenerateRoute: _onGenerateRoute,
      ),
    );
  }
}
